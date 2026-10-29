/* BBDD/SPs/Arbitraje.sql
 * Fecha: 10/10/2026
 * Lista, Matías Josué.
 * Descripción: Crea todos los store procedures, funciones, y vistas del schema [Arbitraje].
 **/

USE GestionDelMundial;
GO

CREATE OR ALTER PROCEDURE Arbitraje.sp_crear_arbitro
	@CodigoPais CHAR(3),
	@Nombre VARCHAR(100),
	@Apellido VARCHAR(100),
	@EsMujer BIT = 1,
	@ConfederacionID INT = NULL,
	@ID INT = NULL OUTPUT
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @errores NVARCHAR(500) = '';

	IF (@Nombre IS NULL)
		SET @errores = @errores + '- Debe ingresar el nombre del árbitro. ' + char(13) + char(10);

	IF (@Apellido IS NULL)
		SET @errores = @errores + '- Debe ingresar el apellido del árbitro. ' + char(13) + char(10);

	IF (@CodigoPais IS NULL)
		SET @errores = @errores + '- Debe ingresar un país. ' + char(13) + char(10);	

	IF @CodigoPais IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Administracion.Paises WHERE codigo = @CodigoPais)
		SET @errores = @errores + '- El país no existe. ' + char(13) + char(10);

	IF @CodigoPais IS NOT NULL AND @Nombre IS NOT NULL AND @Apellido IS NOT NULL AND EXISTS (SELECT 1 FROM Arbitraje.Arbitros WHERE nombre = @Nombre AND apellido = @Apellido AND pais_id = @CodigoPais)
		SET @errores = @errores + '- Ya existe un árbitro con ese nombre y apellido para ese país. ' + char(13) + char(10);

	IF @ConfederacionID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Administracion.Confederaciones WHERE id = @ConfederacionID)
		SET @errores = @errores + '- La confederacion indicada no existe. ' + char(13) + char(10);

	IF (@errores <> '')
		THROW 50001, @errores, 1;

	INSERT INTO Arbitraje.Arbitros
		(pais_id, nombre, apellido, es_mujer, confederacion_id)
		VALUES
		(@CodigoPais, @Nombre, @Apellido, @EsMujer, @ConfederacionID);

	SET @ID = SCOPE_IDENTITY();
END
GO

--  No se modifica el País porque rompe reglas de negocio:
--  La nacionalidad de un arbitro condiciona a qué partido se asigna.
CREATE OR ALTER PROCEDURE Arbitraje.sp_modificar_arbitro
	@ID INT,
	@Nombre VARCHAR(100),
	@Apellido VARCHAR(100)
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @errores NVARCHAR(500) = '';

	DECLARE @codigoPais CHAR(3) = NULL;
	IF (@ID IS NULL)
		SET @errores = @errores + '- Debe ingresar un arbitro. ' + char(13) + char(10);
	ELSE 
		SELECT @codigoPais = pais_id FROM Arbitraje.Arbitros WHERE id = @ID

	IF (@Nombre IS NULL)
		SET @errores = @errores + '- Debe ingresar un nombre. ' + char(13) + char(10);

	IF (@Apellido IS NULL)
		SET @errores = @errores + '- Debe ingresar un apellido. ' + char(13) + char(10);

	IF @codigoPais is NULL and @ID IS NOT NULL
		SET @errores = @errores + '- No existe un árbitro con ese ID. ' + char(13) + char(10);

	IF EXISTS (SELECT 1 FROM Arbitraje.Arbitros WHERE nombre = @Nombre AND apellido = @Apellido AND pais_id = @codigoPais AND id <> @ID)
		SET @errores = @errores + '- Otro árbitro del mismo país ya tiene ese nombre y apellido. ' + char(13) + char(10);

	IF (@errores <> '')
		THROW 50001, @errores, 1;

	UPDATE Arbitraje.Arbitros
		SET nombre = @Nombre, apellido = @Apellido
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
	SET NOCOUNT ON;

	DECLARE @errores NVARCHAR(500) = '';

	IF @ArbitroID IS NULL
		SET @errores = @errores + '- Debe ingresar un arbitro. ' + char(13) + char(10);

	IF @CodigoIdioma IS NULL
		SET @errores = @errores + '- Debe ingresar un idioma. ' + char(13) + char(10);

	IF @ArbitroID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Arbitraje.Arbitros WHERE id = @ArbitroID)
		SET @errores = @errores + '- El árbitro no existe. ' + char(13) + char(10);

	IF @CodigoIdioma IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Administracion.Idiomas WHERE codigo = @CodigoIdioma)
		SET @errores = @errores + '- El idioma no existe. ' + char(13) + char(10);

	IF @ArbitroID IS NOT NULL AND @CodigoIdioma IS NOT NULL AND
	   EXISTS (SELECT 1 FROM Arbitraje.Arbitro_Habla WHERE arbitro_id = @ArbitroID AND idioma_id = @CodigoIdioma)
		SET @errores = @errores + '- El árbitro ya tiene asociado ese idioma.' + char(13) + char(10);

	IF (@errores <> '')
		THROW 50001, @errores, 1;

	INSERT INTO Arbitraje.Arbitro_Habla
		(arbitro_id, idioma_id)
		VALUES
		(@ArbitroID, @CodigoIdioma);
END
GO
 
CREATE OR ALTER PROCEDURE Arbitraje.sp_desasociar_idioma_de_arbitro
	@ArbitroID INT,
	@CodigoIdioma CHAR(2)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @errores NVARCHAR(500) = '';


	IF @ArbitroID IS NULL
		SET @errores = @errores + '- Debe ingresar un arbitro. ' + char(13) + char(10);

	IF @CodigoIdioma IS NULL
		SET @errores = @errores + '- Debe ingresar un idioma. ' + char(13) + char(10);


	IF @ArbitroID IS NOT NULL AND @CodigoIdioma IS NOT NULL AND
	   NOT EXISTS (SELECT 1 FROM Arbitraje.Arbitro_Habla WHERE arbitro_id = @ArbitroID AND idioma_id = @CodigoIdioma)
		SET @errores = @errores + '- El árbitro NO tiene asociado ese idioma.' + char(13) + char(10);

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
	@PartidoID INT = NULL,
	@ID INT = NULL OUTPUT
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @errores NVARCHAR(500) = '';

	DECLARE @fechaPartido DATE = (SELECT CAST(fecha_y_hora AS DATE) FROM Partidos.Partidos WHERE id = @PartidoID);

	IF NOT EXISTS (SELECT 1 FROM Arbitraje.Arbitros WHERE id = @ArbitroID)
		SET @errores = @errores + '- El árbitro no existe. ' + char(13) + char(10);

	IF (@Motivo IS NULL OR TRIM(@Motivo) = '')
		SET @errores = @errores + '- Debe indicar el motivo del informe. ' + char(13) + char(10);

	IF (@FReporte IS NULL OR @FReporte > CAST(GETDATE() AS DATE))
		SET @errores = @errores + '- La fecha del informe es obligatoria y no puede ser futura. ' + char(13) + char(10);

	IF (@PartidoID IS NOT NULL AND @fechaPartido IS NULL)
		SET @errores = @errores + '- El partido no existe. ' + char(13) + char(10);

	IF (@PartidoID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Arbitraje.ArbitroAsignadoPartido WHERE arbitro_id = @ArbitroID AND partido_id = @PartidoID))
		SET @errores = @errores + '- El árbitro no estuvo designado en ese partido. ' + char(13) + char(10);

	IF (@FReporte < @fechaPartido)
		SET @errores = @errores + '- El informe no puede ser anterior al partido. ' + char(13) + char(10);

	IF (@errores <> '')
		THROW 50001, @errores, 1;

	INSERT INTO Arbitraje.InformesArbitros
		(arbitro_id, partido_id, f_reporte, motivo)
		VALUES
		(@ArbitroID, @PartidoID, @FReporte, @Motivo);
		
	SET @ID = SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE Arbitraje.sp_modificar_informe_arbitro
	@ID INT,
	@FReporte DATE,
	@Motivo VARCHAR(250)
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @errores NVARCHAR(500) = '';

	DECLARE @fechaPartido DATE = (SELECT CAST(P.fecha_y_hora AS DATE)
									FROM Arbitraje.InformesArbitros I
									INNER JOIN Partidos.Partidos P ON P.id = I.partido_id
									WHERE I.id = @ID);

	IF NOT EXISTS (SELECT 1 FROM Arbitraje.InformesArbitros WHERE id = @ID)
		SET @errores = @errores + '- No existe un informe con ese ID. ' + char(13) + char(10);

	IF (@Motivo IS NULL OR TRIM(@Motivo) = '')
		SET @errores = @errores + '- Debe indicar el motivo del informe. ' + char(13) + char(10);

	IF (@FReporte IS NULL OR @FReporte > CAST(GETDATE() AS DATE))
		SET @errores = @errores + '- La fecha del informe es obligatoria y no puede ser futura. ' + char(13) + char(10);

	IF (@FReporte < @fechaPartido)
		SET @errores = @errores + '- El informe no puede ser anterior al partido. ' + char(13) + char(10);

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

	IF @ID IS NULL
		SET @errores = @errores + '- Debe ingresar un arbitro. ' + char(13) + char(10);


	IF @ID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Arbitraje.Arbitros WHERE id = @ID)
		SET @errores = @errores + '- No existe un árbitro con ese ID. ' + char(13) + char(10);

	IF EXISTS (SELECT 1 FROM Arbitraje.ArbitroAsignadoPartido WHERE arbitro_id = @ID)
		SET @errores = @errores + '- El árbitro tiene partidos designados. ' + char(13) + char(10);

	IF EXISTS (SELECT 1 FROM Arbitraje.InformesArbitros WHERE arbitro_id = @ID)
		SET @errores = @errores + '- El árbitro tiene informes registrados. ' + char(13) + char(10);

	IF EXISTS (SELECT 1 FROM Mundial.Habilitacion_Arbitro WHERE arbitro_id = @ID)
		SET @errores = @errores + '- El árbitro está habilitado en uno o más mundiales. ' + char(13) + char(10);

	IF (@errores <> '')
		THROW 50001, @errores, 1;

	BEGIN TRY
		BEGIN TRANSACTION
		SAVE TRANSACTION sp_eliminar_arbitro

		DELETE FROM Arbitraje.Arbitro_Habla WHERE arbitro_id = @ID;

		DELETE FROM Arbitraje.Arbitros
			WHERE id = @ID;
		
		COMMIT TRANSACTION

	END TRY
	BEGIN CATCH

		if @@TRANCOUNT > 0
			ROLLBACK TRANSACTION sp_eliminar_arbitro;
		throw

	END CATCH
END
GO



CREATE OR ALTER PROCEDURE Arbitraje.sp_eliminar_informe_arbitro
	@ID INT
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @errores NVARCHAR(500) = '';

	IF NOT EXISTS (SELECT 1 FROM Arbitraje.InformesArbitros WHERE id = @ID)
		SET @errores = @errores + 'No existe un informe con ese ID.';

	IF (@errores <> '')
		THROW 50001, @errores, 1;

	DELETE FROM Arbitraje.InformesArbitros
		WHERE id = @ID;
END
GO

----------------------------------------------

CREATE OR ALTER PROCEDURE Arbitraje.sp_designar_arbitro
    @PartidoID INT,
    @ArbitroID INT,
    @Rol VARCHAR(15) = NULL
AS
BEGIN 

	---- Para asignar arbitro a un partido:
	------ .Si es un partido de Grupos: El arbitro no puede dirigir un partido del grupo de su selección.
	------ .Si es un partido de knockout: El arbitro no puede dirigir un partido de un país que juegue en su misma rama
	------ .Voy a asignar los roles en orden, pero sino, se tiene que validar que no haya un arbitro asignado en ese rol, para ese partido.

	SET NOCOUNT ON;
	
	DECLARE @errores VARCHAR(5000) = '';

	IF @PartidoID IS NULL
		SET @errores = @errores + '- Debe ingresar un partido. ' + char(13) + char(10);

	IF @ArbitroID IS NULL
		SET @errores = @errores + '- Debe ingresar un Arbitro. ' + char(13) + char(10);

	IF @Rol IS NOT NULL AND @Rol not in ('PRINCIPAL', 'ASISTENTE1', 'ASISTENTE2', 'CUARTO', 'VAR')
		SET @errores = @errores + '- Si ingresa un rol debe ser valido. ' + char(13) + char(10);

	DECLARE @añoMundial INT = NULL;
    DECLARE @selA INT = NULL;
    DECLARE @selB INT = NULL;
    DECLARE @fase VARCHAR(15) = NULL;

	IF @PartidoID IS NOT NULL BEGIN
		SELECT @añoMundial = mundial_id, @selA = seleccion_A_id, @selB = seleccion_B_id, @fase = fase 
        FROM Partidos.Partidos WHERE id = @PartidoID;

		IF @añoMundial IS NULL 
			SET @errores = @errores + '- No existe un Partido con ese ID. ' + char(13) + char(10);
	END		

    DECLARE @paisArbitro CHAR(3) = NULL;
	IF @ArbitroID IS NOT NULL BEGIN
        SELECT @paisArbitro = pais_id FROM Arbitraje.Arbitros WHERE id = @ArbitroID;
		IF @paisArbitro IS NULL
		    SET @errores = @errores + '- No existe un Arbitro con ese ID. ' + char(13) + char(10);
    END

	IF @PartidoID is not null and @ArbitroId is not null and 
		EXISTS (SELECT 1 FROM Arbitraje.ArbitroAsignadoPartido where partido_id = @PartidoID and arbitro_id = @ArbitroID)
		SET @errores = @errores + '- El arbitro ya se encuentra asignado al partido. ' + char(13) + char(10);

    -- Validación 1: el país del árbitro no puede ser una de las selecciones enfrentadas
    IF @selA IS NOT NULL AND @selB IS NOT NULL AND @paisArbitro IS NOT NULL BEGIN
        IF EXISTS (SELECT 1 FROM Mundial.Selecciones WHERE id IN (@selA, @selB) AND pais_id = @paisArbitro)
            SET @errores = @errores + '- El árbitro no puede dirigir un partido de su propio país. ' + char(13) + char(10);
    END

    -- Validación 2: Regla de Grupos vs Regla de Knockout
    IF @añoMundial IS NOT NULL AND @paisArbitro IS NOT NULL BEGIN
        
        DECLARE @selArbitro INT = (
					SELECT S.id 
					FROM Mundial.Selecciones S
					JOIN Mundial.Paises_Participes PP ON PP.seleccion_id = S.id
					WHERE S.pais_id = @paisArbitro and PP.mundial_id = @añoMundial);

        IF @fase = 'GRUPOS'
        BEGIN
            DECLARE @GrupoPartido CHAR(1) = (SELECT TOP 1 grupo FROM Mundial.Paises_Participes WHERE mundial_id = @añoMundial AND seleccion_id = @selA);
            DECLARE @GrupoArbitro CHAR(1) = (SELECT TOP 1 grupo FROM Mundial.Paises_Participes WHERE mundial_id = @añoMundial AND seleccion_id = @selArbitro);

            IF @GrupoPartido IS NOT NULL AND @GrupoArbitro IS NOT NULL AND @GrupoPartido = @GrupoArbitro
                SET @errores = @errores + '- El árbitro no puede dirigir un partido del grupo de su selección. ' + char(13) + char(10);
        END
        ELSE IF @fase IS NOT NULL AND @selArbitro IS NOT NULL
        BEGIN
            -- Regla Knockout: CTE para ver si se cruzan en la misma rama (antes de la final)
            DECLARE @MismaRama BIT = 0;

            ;WITH RamaPartido AS (
                SELECT id, siguiente_partido_id, fase FROM Partidos.Partidos WHERE id = @PartidoID
                UNION ALL
                SELECT P.id, P.siguiente_partido_id, P.fase
                FROM Partidos.Partidos P
                INNER JOIN RamaPartido RP ON P.id = RP.siguiente_partido_id
            ),
            PartidosArbitro AS (
                SELECT id, siguiente_partido_id, fase FROM Partidos.Partidos 
                WHERE mundial_id = @añoMundial AND (seleccion_A_id = @selArbitro OR seleccion_B_id = @selArbitro)
            ),
            RamaArbitro AS (
                SELECT id, siguiente_partido_id, fase FROM PartidosArbitro
                UNION ALL
                SELECT P.id, P.siguiente_partido_id, P.fase
                FROM Partidos.Partidos P
                INNER JOIN RamaArbitro RA ON P.id = RA.siguiente_partido_id
            )
            -- FIX ACÁ: Excluimos la final del cruce, ya que TODAS las ramas coinciden en la final
            SELECT TOP 1 @MismaRama = 1 
            FROM RamaPartido RP 
            INNER JOIN RamaArbitro RA ON RP.id = RA.id
            WHERE RP.fase <> 'FINAL';

            IF @MismaRama = 1
                SET @errores = @errores + '- El árbitro no puede dirigir un partido de un país que juegue en su misma rama. ' + char(13) + char(10);
        END
    END

	IF (@errores <> '')
		THROW 50001, @errores, 1;

    DECLARE @usaVar BIT = 0; 
    SELECT @usaVar = CAST(valor AS BIT) FROM Administracion.Reglas WHERE mundial_id = @añoMundial AND codigo = 'ARBITRO_DE_VAR';

    DECLARE @hayPrincipal  BIT = 0;
    DECLARE @hayAsistente1 BIT = 0;
    DECLARE @hayAsistente2 BIT = 0;
    DECLARE @hayCuarto     BIT = 0;
    DECLARE @hayVar        BIT = 0;

	IF exists (SELECT 1 FROM Arbitraje.ArbitroAsignadoPartido WHERE partido_id = @PartidoID and rol = 'PRINCIPAL')
		SET @hayPrincipal = 1;

	IF exists (SELECT 1 FROM Arbitraje.ArbitroAsignadoPartido WHERE partido_id = @PartidoID and rol = 'ASISTENTE1')
		SET @hayAsistente1 = 1;

	IF exists (SELECT 1 FROM Arbitraje.ArbitroAsignadoPartido WHERE partido_id = @PartidoID and rol = 'ASISTENTE2')
		SET @hayAsistente2 = 1;

	IF exists (SELECT 1 FROM Arbitraje.ArbitroAsignadoPartido WHERE partido_id = @PartidoID and rol = 'CUARTO')
		SET @hayCuarto = 1;

	IF exists (SELECT 1 FROM Arbitraje.ArbitroAsignadoPartido WHERE partido_id = @PartidoID and rol = 'VAR')
		SET @hayVar = 1;

	IF @hayPrincipal = 1 and @hayAsistente1 = 1 and @hayAsistente2 = 1 and @hayCuarto = 1 and ((@hayVar = 1 and @usaVar = 1) OR @usaVar = 0)
		SET @errores = @errores + '- NO HAY ROLES DE ARBITRO DISPONIBLES. ' + char(13) + char(10);

	IF @Rol is NULL BEGIN
		IF @hayPrincipal = 0 
			SET @Rol = 'PRINCIPAL'
		ELSE IF @hayAsistente1 = 0
			SET @Rol = 'ASISTENTE1'
		ELSE IF @hayAsistente2 = 0
			SET @Rol = 'ASISTENTE2'
		ELSE IF @hayCuarto = 0
			SET @Rol = 'CUARTO'
		ELSE IF (@hayVar = 0 and @usaVar = 1)
			SET @Rol = 'VAR'
	END

    IF EXISTS (SELECT 1 FROM Arbitraje.ArbitroAsignadoPartido WHERE partido_id = @PartidoID AND rol = @Rol)
        SET @errores = @errores + '- El rol solicitado ya se encuentra ocupado en este partido. ' + char(13) + char(10);

	IF (@errores <> '')
		THROW 50001, @errores, 1;

    INSERT INTO Arbitraje.ArbitroAsignadoPartido (arbitro_id, partido_id, rol)
    VALUES (@ArbitroID, @PartidoID, @Rol);

END
GO

CREATE OR ALTER PROCEDURE Arbitraje.sp_asginar_terna_arbitros 
	@PartidoID INT
AS
BEGIN

	SET NOCOUNT ON;
	
	DECLARE @errores VARCHAR(5000) = '';

	DECLARE @añoMundial INT = NULL;

	IF @PartidoID IS NULL BEGIN
		SET @errores = @errores + '- Debe indicar un partido. ' + char(13) + char(10);
	END ELSE BEGIN
		SELECT @añoMundial = mundial_id
	        FROM Partidos.Partidos WHERE id = @PartidoID;
		IF @añoMundial is null
			SET @errores = @errores + '- El partido no es valido. ' + char(13) + char(10);
    END

	IF (@errores <> '')
		THROW 50001, @errores, 1;

    DECLARE @usaVar BIT = Administracion.fn_obtener_regla (@añoMundial, 'ARBITRO_DE_VAR'); 

    DECLARE @arbitrosIDs TABLE (id INT IDENTITY(1,1), arbitro_id INT);

	DECLARE @PaisA CHAR(3) = NULL; DECLARE @PaisB CHAR(3) = NULL;

	SELECT @PaisA = S.pais_id
		FROM Partidos.Partidos P
		JOIN Mundial.Selecciones S ON S.id = P.seleccion_A_id
		WHERE P.id = @PartidoID;
		
	SELECT @PaisB = S.pais_id
		FROM Partidos.Partidos P
		JOIN Mundial.Selecciones S ON S.id = P.seleccion_B_id
		WHERE P.id = @PartidoID;

	INSERT INTO @arbitrosIDs (arbitro_id)
	SELECT TOP (3 + @usaVar) A.id
	FROM Arbitraje.Arbitros A
	WHERE A.pais_id <> @PaisA and A.pais_id <> @PaisB ---- NO PUEDEN SER ARBITROS DE LOS PAISES QUE JUEGAN.
	ORDER BY NEWID();

	DECLARE @i INT = 1;
	DECLARE @arbitroID INT = NULL;
	WHILE @i < (3 + @usaVar + 1) BEGIN
		
		SELECT @arbitroID = arbitro_id FROM @arbitrosIDs WHERE id = @i;

		EXEC Arbitraje.sp_designar_arbitro
			 @PartidoID = @PartidoID,
			 @ArbitroID = @arbitroID;

		SET @i = @i + 1;
	END


END
GO

-- CREATE OR ALTER PROCEDURE Arbitraje.sp_quitar_designacion
-- 	@PartidoID INT,
-- 	@ArbitroID INT
-- AS
-- BEGIN
-- 	DECLARE @errores NVARCHAR(500) = '';

-- 	IF NOT EXISTS (SELECT 1 FROM Arbitraje.ArbitroAsignadoPartido WHERE partido_id = @PartidoID AND arbitro_id = @ArbitroID)
-- 		SET @errores = @errores + 'El árbitro no está designado en ese partido. ';

-- 	IF EXISTS (SELECT 1 FROM Arbitraje.InformesArbitros WHERE partido_id = @PartidoID AND arbitro_id = @ArbitroID)
-- 		SET @errores = @errores + 'El árbitro tiene informes registrados sobre ese partido. ';

-- 	IF (@errores <> '')
-- 		THROW 50001, @errores, 1;

-- 	DELETE FROM Arbitraje.ArbitroAsignadoPartido
-- 		WHERE partido_id = @PartidoID AND arbitro_id = @ArbitroID;
-- END
-- GO