/* BBDD/SPs/Arbitraje.sql
 * Fecha: 10/10/2026
 * Integrantes: Lista, Matías Josué. Maldonado Medrano, Milagros.
 * Descripción: Crea todos los store procedures, funciones, y vistas del schema [Arbitraje].
 **/

USE GestionDelMundial;
GO


CREATE OR ALTER PROCEDURE Arbitraje.sp_crear_arbitro
	@CodigoPais CHAR(3),
	@Nombre VARCHAR(100),
	@Apellido VARCHAR(100)
AS
BEGIN
	DECLARE @errores NVARCHAR(500) = '';

	IF NOT EXISTS (SELECT 1 FROM Administracion.Paises WHERE codigo = @CodigoPais)
		SET @errores = @errores + 'El país no existe. ';

	IF (@Nombre IS NULL OR TRIM(@Nombre) = '')
		SET @errores = @errores + 'Debe ingresar el nombre del árbitro. ';

	IF (@Apellido IS NULL OR TRIM(@Apellido) = '')
		SET @errores = @errores + 'Debe ingresar el apellido del árbitro. ';

	IF EXISTS (SELECT 1 FROM Arbitraje.Arbitros WHERE nombre = @Nombre AND apellido = @Apellido AND pais_id = @CodigoPais)
		SET @errores = @errores + 'Ya existe un árbitro con ese nombre y apellido para ese país.';

	IF (@errores <> '')
		THROW 50001, @errores, 1;

	INSERT INTO Arbitraje.Arbitros
		(pais_id, nombre, apellido)
		VALUES
		(@CodigoPais, TRIM(@Nombre), TRIM(@Apellido)); --trim limpia los espacios en blanco al inicio y fin 
END
GO

CREATE OR ALTER PROCEDURE Arbitraje.sp_modificar_arbitro
	@ID INT,
	@CodigoPais CHAR(3),
	@Nombre VARCHAR(100),
	@Apellido VARCHAR(100)
AS
BEGIN
	DECLARE @errores NVARCHAR(500) = '';

	IF NOT EXISTS (SELECT 1 FROM Arbitraje.Arbitros WHERE id = @ID)
		SET @errores = @errores + 'No existe un árbitro con ese ID. ';

	IF NOT EXISTS (SELECT 1 FROM Administracion.Paises WHERE codigo = @CodigoPais)
		SET @errores = @errores + 'El país no existe. ';

	IF (@Nombre IS NULL OR TRIM(@Nombre) = '')
		SET @errores = @errores + 'Debe indicar el nombre del árbitro. ';

	IF (@Apellido IS NULL OR TRIM(@Apellido) = '')
		SET @errores = @errores + 'Debe indicar el apellido del árbitro. ';

	IF EXISTS (SELECT 1 FROM Arbitraje.Arbitros WHERE nombre = @Nombre AND apellido = @Apellido AND pais_id = @CodigoPais AND id <> @ID)
		SET @errores = @errores + 'Otro árbitro ya tiene ese nombre y apellido para ese país.';

	IF (@errores <> '')
		THROW 50001, @errores, 1;

	UPDATE Arbitraje.Arbitros
		SET pais_id = @CodigoPais, nombre = TRIM(@Nombre), apellido = TRIM(@Apellido)
		WHERE id = @ID;
END
GO


CREATE OR ALTER FUNCTION Arbitraje.fn_obtener_arbitro_id (@Nombre VARCHAR(100), @Apellido VARCHAR(100), @CodigoPais CHAR(3))
RETURNS INT
AS
BEGIN
	DECLARE @arbitroId INT = (SELECT id
								FROM Arbitraje.Arbitros
								WHERE nombre = @Nombre AND apellido = @Apellido AND pais_id = @CodigoPais);

	RETURN @arbitroId;
END
GO


CREATE OR ALTER PROCEDURE Arbitraje.sp_asociar_idioma_a_arbitro
	@ArbitroID INT,
	@CodigoIdioma CHAR(2)
AS
BEGIN
	DECLARE @errores NVARCHAR(500) = '';

	IF NOT EXISTS (SELECT 1 FROM Arbitraje.Arbitros WHERE id = @ArbitroID)
		SET @errores = @errores + 'El árbitro no existe. ';

	IF NOT EXISTS (SELECT 1 FROM Administracion.Idiomas WHERE codigo = @CodigoIdioma)
		SET @errores = @errores + 'El idioma no existe. ';

	IF EXISTS (SELECT 1 FROM Arbitraje.Arbitro_Habla WHERE arbitro_id = @ArbitroID AND idioma_id = @CodigoIdioma)
		SET @errores = @errores + 'El árbitro ya tiene asociado ese idioma.';

	IF (@errores <> '')
		THROW 50001, @errores, 1;

	INSERT INTO Arbitraje.Arbitro_Habla
		(arbitro_id, idioma_id)
		VALUES
		(@ArbitroID, @CodigoIdioma);
END
GO

--entiendo que en este caso no hay mas que validar 
CREATE OR ALTER PROCEDURE Arbitraje.sp_desasociar_idioma_de_arbitro
	@ArbitroID INT,
	@CodigoIdioma CHAR(2)
AS
BEGIN
	DECLARE @errores NVARCHAR(500) = '';

	IF NOT EXISTS (SELECT 1 FROM Arbitraje.Arbitro_Habla WHERE arbitro_id = @ArbitroID AND idioma_id = @CodigoIdioma)
		SET @errores = @errores + 'El árbitro no tiene asociado ese idioma.';

	IF (@errores <> '')
		THROW 50001, @errores, 1;

	DELETE FROM Arbitraje.Arbitro_Habla
		WHERE arbitro_id = @ArbitroID AND idioma_id = @CodigoIdioma;
END
GO



CREATE OR ALTER PROCEDURE Arbitraje.sp_registrar_informe_arbitro
	@ArbitroID INT,
	@FReporte DATE,
	@Motivo VARCHAR(250),
	@PartidoID INT = NULL
AS
BEGIN
	DECLARE @errores NVARCHAR(500) = '';

	DECLARE @fechaPartido DATE = (SELECT CAST(fecha_y_hora AS DATE) FROM Partidos.Partidos WHERE id = @PartidoID);

	IF NOT EXISTS (SELECT 1 FROM Arbitraje.Arbitros WHERE id = @ArbitroID)
		SET @errores = @errores + 'El árbitro no existe. ';

	IF (@Motivo IS NULL OR TRIM(@Motivo) = '')
		SET @errores = @errores + 'Debe indicar el motivo del informe. ';

	IF (@FReporte IS NULL OR @FReporte > CAST(GETDATE() AS DATE))
		SET @errores = @errores + 'La fecha del informe es obligatoria y no puede ser futura. ';

	IF (@PartidoID IS NOT NULL AND @fechaPartido IS NULL)
		SET @errores = @errores + 'El partido no existe. ';

	IF (@PartidoID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Arbitraje.ArbitroAsignadoPartido WHERE arbitro_id = @ArbitroID AND partido_id = @PartidoID))
		SET @errores = @errores + 'El árbitro no estuvo designado en ese partido. ';

	IF (@FReporte < @fechaPartido)
		SET @errores = @errores + 'El informe no puede ser anterior al partido.';

	IF (@errores <> '')
		THROW 50001, @errores, 1;

	INSERT INTO Arbitraje.InformesArbitros
		(arbitro_id, partido_id, f_reporte, motivo)
		VALUES
		(@ArbitroID, @PartidoID, @FReporte, @Motivo);
END
GO




CREATE OR ALTER PROCEDURE Arbitraje.sp_modificar_informe_arbitro
	@ID INT,
	@FReporte DATE,
	@Motivo VARCHAR(250)
AS
BEGIN
	DECLARE @errores NVARCHAR(500) = '';

	DECLARE @fechaPartido DATE = (SELECT CAST(P.fecha_y_hora AS DATE)
									FROM Arbitraje.InformesArbitros I
									INNER JOIN Partidos.Partidos P ON P.id = I.partido_id
									WHERE I.id = @ID);

	IF NOT EXISTS (SELECT 1 FROM Arbitraje.InformesArbitros WHERE id = @ID)
		SET @errores = @errores + 'No existe un informe con ese ID. ';

	IF (@Motivo IS NULL OR TRIM(@Motivo) = '')
		SET @errores = @errores + 'Debe indicar el motivo del informe. ';

	IF (@FReporte IS NULL OR @FReporte > CAST(GETDATE() AS DATE))
		SET @errores = @errores + 'La fecha del informe es obligatoria y no puede ser futura. ';

	IF (@FReporte < @fechaPartido)
		SET @errores = @errores + 'El informe no puede ser anterior al partido. ';

	IF (@errores <> '')
		THROW 50001, @errores, 1;

	UPDATE Arbitraje.InformesArbitros
		SET f_reporte = @FReporte, motivo = @Motivo
		WHERE id = @ID;
END
GO

CREATE OR ALTER FUNCTION Arbitraje.fn_historial_arbitro (@ArbitroID INT)
RETURNS TABLE
AS
RETURN (
	SELECT
		P.id            AS partido_id,
		P.mundial_id,
		P.fecha_y_hora,
		P.fase,
		S.nombre        AS sede,
		SA.pais_id      AS seleccion_A,
		SB.pais_id      AS seleccion_B,
		A.rol,
		(SELECT STRING_AGG(I.motivo, ' | ')
			FROM Arbitraje.InformesArbitros I
			WHERE I.arbitro_id = A.arbitro_id AND I.partido_id = P.id) AS informes
	FROM Arbitraje.ArbitroAsignadoPartido A
	INNER JOIN Partidos.Partidos P    ON P.id  = A.partido_id
	INNER JOIN Administracion.Sedes S ON S.id  = P.sede_id
	INNER JOIN Mundial.Selecciones SA ON SA.id = P.seleccion_A_id
	INNER JOIN Mundial.Selecciones SB ON SB.id = P.seleccion_B_id
	WHERE A.arbitro_id = @ArbitroID
);
GO

--------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE Arbitraje.sp_eliminar_arbitro
	@ID INT
AS
BEGIN
	DECLARE @errores NVARCHAR(500) = '';

	IF NOT EXISTS (SELECT 1 FROM Arbitraje.Arbitros WHERE id = @ID)
		SET @errores = @errores + 'No existe un árbitro con ese ID. ';

	IF EXISTS (SELECT 1 FROM Arbitraje.ArbitroAsignadoPartido WHERE arbitro_id = @ID)
		SET @errores = @errores + 'El árbitro tiene partidos designados. ';

	IF EXISTS (SELECT 1 FROM Arbitraje.InformesArbitros WHERE arbitro_id = @ID)
		SET @errores = @errores + 'El árbitro tiene informes registrados. ';

	IF EXISTS (SELECT 1 FROM Mundial.Habilitacion_Arbitro WHERE arbitro_id = @ID)
		SET @errores = @errores + 'El árbitro está habilitado en uno o más mundiales. ';

	IF EXISTS (SELECT 1 FROM Arbitraje.Arbitro_Habla WHERE arbitro_id = @ID)
		SET @errores = @errores + 'El árbitro tiene idiomas asociados.';

	IF (@errores <> '')
		THROW 50001, @errores, 1;

	DELETE FROM Arbitraje.Arbitros
		WHERE id = @ID;
END
GO



CREATE OR ALTER PROCEDURE Arbitraje.sp_eliminar_informe_arbitro
	@ID INT
AS
BEGIN
	DECLARE @errores NVARCHAR(500) = '';

	IF NOT EXISTS (SELECT 1 FROM Arbitraje.InformesArbitros WHERE id = @ID)
		SET @errores = @errores + 'No existe un informe con ese ID.';

	IF (@errores <> '')
		THROW 50001, @errores, 1;

	DELETE FROM Arbitraje.InformesArbitros
		WHERE id = @ID;
END
GO

 