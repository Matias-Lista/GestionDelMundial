/* BBDD/Seguridad/Cifrado.sql
 * Fecha: 9/10/2026
 * Lista, Matías Josué.
 * Descripción: Este script se encarga de cifrar el campo "apellido" de la tabla arbitro, modificando todos 
 				los objetos que utilizan el campo.
 **/

USE GestionDelMundial;
GO

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Arbitraje.Arbitros') AND name = 'apellido_cifrado')
BEGIN
	-- Agregamos un campo para los datos cifrados
	ALTER TABLE Arbitraje.Arbitros
	ADD apellido_cifrado VARBINARY(256);
END;
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Arbitraje.Arbitros') AND name = 'apellido_cifrado')
   AND EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Arbitraje.Arbitros') AND name = 'apellido')
BEGIN

	EXEC('
	UPDATE Arbitraje.Arbitros
	SET apellido_cifrado = EncryptByPassPhrase(''QuieroMiPanDanes'', apellido, 0)');

	/* Usando el ID de salt! No lo hago porque después complica el insert.
	SET apellido_cifrado = EncryptByPassPhrase(@claveDeCifrado,
	apellido, 1, CONVERT(varbinary, id));*/

	ALTER TABLE Arbitraje.Arbitros DROP CONSTRAINT UQ_Nombre_Apellido_Pais_Arbitro;
	ALTER TABLE Arbitraje.Arbitros DROP COLUMN apellido;
END;
GO

-- SELECT 
--     id, nombre, apellido_cifrado,
--     CONVERT(VARCHAR(100), DecryptByPassPhrase(N'QuieroMiPanDanes', apellido_cifrado, 0)) AS apellido_descifrado
-- FROM Arbitraje.Arbitros;
-- GO

/****************************/
/* MODIFICACION DE PROCESOS */
/****************************/

---- envuelvo esto en EXEC para evitar que sql servers me de errores al importarlo sin ejecutar en reinicio
EXEC('
CREATE OR ALTER PROCEDURE Arbitraje.sp_crear_arbitro
	@CodigoPais CHAR(3),
	@Nombre VARCHAR(100),
	@Apellido VARCHAR(100),
	@EsMujer BIT = 1,
	@ConfederacionID INT = NULL,
	@ID INT = NULL OUTPUT
AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @errores NVARCHAR(500) = '''';
	DECLARE @claveDeCifrado NVARCHAR(50) = N''QuieroMiPanDanes'';

	IF (@Nombre IS NULL)
		SET @errores = @errores + ''- Debe ingresar el nombre del árbitro. '' + CHAR(13) + CHAR(10);

	IF (@Apellido IS NULL)
		SET @errores = @errores + ''- Debe ingresar el apellido del árbitro. '' + CHAR(13) + CHAR(10);

	IF (@CodigoPais IS NULL)
		SET @errores = @errores + ''- Debe ingresar un país. '' + CHAR(13) + CHAR(10);	

	IF @CodigoPais IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Administracion.Paises WHERE codigo = @CodigoPais)
		SET @errores = @errores + ''- El país no existe. '' + CHAR(13) + CHAR(10);

	IF @CodigoPais IS NOT NULL AND @Nombre IS NOT NULL AND @Apellido IS NOT NULL 
	   AND EXISTS (
			SELECT 1 
			FROM Arbitraje.Arbitros 
			WHERE nombre = @Nombre 
			  AND pais_id = @CodigoPais
			  AND CONVERT(VARCHAR(100), DecryptByPassPhrase(@claveDeCifrado, apellido_cifrado)) = @Apellido
	   )
		SET @errores = @errores + ''- Ya existe un árbitro con ese nombre y apellido para ese país. '' + CHAR(13) + CHAR(10);

	IF @ConfederacionID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Administracion.Confederaciones WHERE id = @ConfederacionID)
		SET @errores = @errores + ''- La confederacion indicada no existe. '' + CHAR(13) + CHAR(10);

	IF (@errores <> '''')
		THROW 50001, @errores, 1;

	INSERT INTO Arbitraje.Arbitros
		(pais_id, nombre, apellido_cifrado, es_mujer, confederacion_id)
	VALUES
		(@CodigoPais, @Nombre, EncryptByPassPhrase(@claveDeCifrado, @Apellido), @EsMujer, @ConfederacionID);

	SET @ID = SCOPE_IDENTITY();
END
');
GO

EXEC('
CREATE OR ALTER PROCEDURE Arbitraje.sp_modificar_arbitro
	@ID INT,
	@Nombre VARCHAR(100),
	@Apellido VARCHAR(100)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @errores NVARCHAR(500) = '''';
	DECLARE @claveDeCifrado NVARCHAR(50) = N''QuieroMiPanDanes'';
	DECLARE @codigoPais CHAR(3) = NULL;

	IF (@ID IS NULL)
		SET @errores = @errores + ''- Debe ingresar un arbitro. '' + CHAR(13) + CHAR(10);
	ELSE 
		SELECT @codigoPais = pais_id FROM Arbitraje.Arbitros WHERE id = @ID;

	IF (@Nombre IS NULL)
		SET @errores = @errores + ''- Debe ingresar un nombre. '' + CHAR(13) + CHAR(10);

	IF (@Apellido IS NULL)
		SET @errores = @errores + ''- Debe ingresar un apellido. '' + CHAR(13) + CHAR(10);

	IF @codigoPais IS NULL AND @ID IS NOT NULL
		SET @errores = @errores + ''- No existe un árbitro con ese ID. '' + CHAR(13) + CHAR(10);

	IF EXISTS (
		SELECT 1 
		FROM Arbitraje.Arbitros 
		WHERE nombre = @Nombre 
		  AND pais_id = @codigoPais 
		  AND id <> @ID
		  AND CONVERT(VARCHAR(100), DecryptByPassPhrase(@claveDeCifrado, apellido_cifrado)) = @Apellido
	)
		SET @errores = @errores + ''- Otro árbitro del mismo país ya tiene ese nombre y apellido. '' + CHAR(13) + CHAR(10);

	IF (@errores <> '''')
		THROW 50001, @errores, 1;

	UPDATE Arbitraje.Arbitros
		SET nombre = @Nombre, 
		    apellido_cifrado = EncryptByPassPhrase(@claveDeCifrado, @Apellido)
		WHERE id = @ID;
END
');
GO

EXEC('
CREATE OR ALTER FUNCTION Arbitraje.fn_obtener_arbitro_id 
(
	@Nombre VARCHAR(100), 
	@Apellido VARCHAR(100), 
	@CodigoPais CHAR(3)
)
RETURNS INT
AS
BEGIN
	DECLARE @claveDeCifrado NVARCHAR(50) = N''QuieroMiPanDanes'';

	DECLARE @arbitroId INT = (
		SELECT id
		FROM Arbitraje.Arbitros
		WHERE nombre = @Nombre 
		  AND pais_id = @CodigoPais
		  AND CONVERT(VARCHAR(100), DecryptByPassPhrase(@claveDeCifrado, apellido_cifrado)) = @Apellido
	);

	RETURN @arbitroId;
END
');
GO

EXEC('
CREATE OR ALTER PROCEDURE Reportes.sp_resumen_de_arbitro 
	@ArbitroID INT
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @claveDeCifrado NVARCHAR(50) = N''QuieroMiPanDanes'';

	SELECT 
		A.nombre, 
		CONVERT(VARCHAR(100), DecryptByPassPhrase(@claveDeCifrado, A.apellido_cifrado)) AS apellido, 
		A.pais_id, 
		CONCAT(PP_A.pais_id, '' vs '', PP_B.pais_id) AS partido, 
		P.mundial_id,
		SUM(CASE WHEN AMO.tarjeta = ''R'' THEN 1 ELSE 0 END) AS rojas_directas,
		SUM(CASE WHEN AMO.alcanza_acumulacion_amarillas = 1 THEN 1 ELSE 0 END) AS roja_por_limite_de_amarillas,
		SUM(CASE WHEN AMO.tarjeta = ''A'' THEN 1 ELSE 0 END) AS amarillas
	FROM Arbitraje.ArbitroAsignadoPartido AAP
	INNER JOIN Partidos.Partidos P ON P.id = AAP.partido_id
	LEFT  JOIN Eventos.Amonestaciones AMO ON AMO.partido_id = AAP.partido_id
	INNER JOIN Arbitraje.Arbitros A ON A.id = AAP.arbitro_id
	INNER JOIN Mundial.Paises_Participes PP_A ON PP_A.seleccion_id = P.seleccion_A_id
	INNER JOIN Mundial.Paises_Participes PP_B ON PP_B.seleccion_id = P.seleccion_B_id
	WHERE AAP.arbitro_id = @ArbitroID
	GROUP BY 
		A.nombre, 
		A.apellido_cifrado, 
		A.pais_id, 
		P.id, 
		AAP.partido_id, 
		PP_A.pais_id, 
		PP_B.pais_id, 
		P.mundial_id;
END
');
GO