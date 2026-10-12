use GestionDelMundial;
GO

IF OBJECT_ID('tempdb..##Confederations') IS NOT NULL DROP TABLE ##Confederations;
IF OBJECT_ID('tempdb..##Teams') IS NOT NULL DROP TABLE ##Teams;
IF OBJECT_ID('tempdb..##Squads') IS NOT NULL DROP TABLE ##Squads;
IF OBJECT_ID('tempdb..##Players') IS NOT NULL DROP TABLE ##Players;
IF OBJECT_ID('tempdb..##Tournaments') IS NOT NULL DROP TABLE ##Tournaments;
IF OBJECT_ID('tempdb..##GroupStandings') IS NOT NULL DROP TABLE ##GroupStandings;
GO

CREATE OR ALTER PROCEDURE Importacion.sp_upsert_confederaciones
AS
BEGIN

    SET NOCOUNT ON

    IF OBJECT_ID('tempdb..##Confederations') IS NULL BEGIN 
        THROW 50001, 'No se importó ningún CSV de confederaciones.', 1;
        RETURN;
    END

    DECLARE @maxID INT = (SELECT max(key_id) FROM ##Confederations);

    DECLARE @idActual INT = 1;

    DECLARE @insertadas   INT = 0;
    DECLARE @actualizadas INT = 0;
    DECLARE @omitidas     INT = 0;

    BEGIN TRAN
    WHILE (@idActual <= @maxID) BEGIN
        
        DECLARE @nombre VARCHAR(100) = NULL;
        DECLARE @siglas VARCHAR(8)   = NULL;

        SELECT @nombre = confederation_name, @siglas = confederation_code
        FROM ##Confederations
        WHERE key_id = @idActual;

        DECLARE @idConfederacion INT = (SELECT id FROM Administracion.Confederaciones WHERE siglas = @siglas);

        if (@idConfederacion is null) BEGIN
            exec Administracion.sp_crear_confederacion @Nombre = @nombre, @Siglas = @siglas;
            SET @insertadas = @insertadas + 1;
        END ELSE BEGIN
            exec Administracion.sp_modificar_confederacion @ID = @idConfederacion, @Nombre = @nombre, @Siglas = @siglas;
            SET @actualizadas = @actualizadas + 1;
        END

        SET @idActual = @idActual + 1;
    END;
    COMMIT TRAN

    SELECT 
        @insertadas as 'Confederaciones insertadas',
        @actualizadas as 'Confederaciones actualizadas',
        @omitidas as 'Confederaciones omitidas';

END
GO


CREATE OR ALTER PROCEDURE Importacion.sp_upsert_paises
AS
BEGIN
    SET NOCOUNT ON

    IF OBJECT_ID('tempdb..##Teams') IS NULL BEGIN 
        THROW 50001, 'No se importó ningún CSV de teams.', 1;
        RETURN;
    END

    DECLARE @maxID INT = (SELECT max(key_id) FROM ##Teams);

    DECLARE @idActual INT = 1;

    DECLARE @insertadas   INT = 0;
    DECLARE @actualizadas INT = 0;
    DECLARE @omitidas     INT = 0;

    BEGIN TRAN
    WHILE (@idActual <= @maxID) BEGIN
            
        DECLARE @codigo CHAR(3) = NULL;
        DECLARE @nombre VARCHAR(100) = NULL;
        DECLARE @siglasConfederacion VARCHAR(8) = NULL;


        SELECT @nombre = team_name, @siglasConfederacion = confederation_code, @codigo = team_code
            FROM ##Teams
            WHERE key_id = @idActual;

        DECLARE @confederacionId INT = (SELECT id FROM Administracion.Confederaciones WHERE siglas = @siglasConfederacion);

        BEGIN TRY
            if (@confederacionId is null) BEGIN
                SET @omitidas = @omitidas + 1;
                DECLARE @msg VARCHAR(100) = 'Error, pais ' + @nombre + 'Confederacion invalida.';
                THROW 50001, @msg, 1;
            END
            ------ ME QUEDE acá

            IF EXISTS (SELECT 1 FROM Administracion.Paises WHERE codigo = @codigo) BEGIN
                exec Administracion.sp_modificar_pais @Codigo = @codigo, @Nombre = @nombre, @ConfederacionID = @confederacionId;
                SET @actualizadas = @actualizadas + 1;
            END ELSE BEGIN
                exec Administracion.sp_crear_pais @Codigo = @codigo, @Nombre = @nombre, @ConfederacionID = @confederacionId;
                SET @insertadas = @insertadas + 1;
            END;
        END TRY
        BEGIN CATCH
            print ERROR_MESSAGE();
        end CATCH

        SET @idActual = @idActual + 1;
    END;
    COMMIT TRAN

    SELECT 
        @insertadas as 'Países insertados',
        @actualizadas as 'Países actualizados',
        @omitidas as 'Países omitidos';

END
GO

CREATE OR ALTER PROCEDURE Importacion.sp_crear_y_cargar_players_csv 
    @Ruta VARCHAR(255)
AS
BEGIN 

CREATE OR ALTER PROCEDURE Importacion.sp_upsert_jugadores
AS
BEGIN
    SET NOCOUNT ON

    IF OBJECT_ID('tempdb..##Players') IS NULL BEGIN 
        THROW 50001, 'No se importó ningún CSV de players.', 1;
        RETURN;
    END

    DECLARE @maxID INT = (SELECT max(key_id) FROM ##Players);

    DECLARE @idActual INT = 1;

    DECLARE @insertadas   INT = 0;
    DECLARE @actualizadas INT = 0;
    DECLARE @omitidas     INT = 0;

    BEGIN TRAN
    WHILE (@idActual <= @maxID) BEGIN
        
        DECLARE @nombre VARCHAR(100) = NULL;
        DECLARE @apellido VARCHAR(100) = NULL;
        DECLARE @f_nacimiento DATE = NULL;
        DECLARE @codigoPais CHAR(3) = NULL;

        SELECT @nombre = given_name, @apellido = family_name, @f_nacimiento = birth_date, @codigoPais = CodigoPais
            FROM ##Players
            WHERE key_id = @idActual;
        
        IF (@nombre is null) BEGIN
            SET @idActual = @idActual + 1;
            CONTINUE; -- Con este if, salteamos los baches que quedan por eliminar campos con female=1
        END;

        DECLARE @idReal INT;
        EXEC @idReal = Equipos.fn_obtener_integrante_id @Nombre = @nombre, @Apellido = @apellido, @FNacimiento = @f_nacimiento, @CodigoPais = @codigoPais;

        BEGIN TRY

            if (@idReal is null) BEGIN
                exec Equipos.sp_crear_integrante_seleccion @CodigoPais = @codigoPais, @Nombre = @nombre, @Apellido = @apellido, @FNacimiento = @f_nacimiento, @ID = @idReal OUTPUT;
                SET @insertadas = @insertadas + 1;
            END
            ELSE BEGIN
                exec Equipos.sp_modificar_integrante_seleccion @ID = @idReal, @CodigoPais = @codigoPais, @Nombre = @nombre, @Apellido = @apellido, @FNacimiento = @f_nacimiento;
                SET @actualizadas = @actualizadas + 1;
            END

            -- Mapear ID.
            UPDATE ##Players
                SET map_id = @idReal
                WHERE key_id = @idActual;

        END TRY
        BEGIN CATCH
            SET @omitidas = @omitidas + 1;
            print ERROR_MESSAGE();
        end CATCH

        SET @idActual = @idActual + 1;
    END;
    COMMIT TRAN

    SELECT 
        @insertadas as 'Jugadores insertados',
        @actualizadas as 'Jugadores actualizados',
        @omitidas as 'Jugadores omitidos';

END
GO


CREATE OR ALTER PROCEDURE Importacion.sp_upsert_mundiales
AS
BEGIN
    SET NOCOUNT ON

    IF OBJECT_ID('tempdb..##Tournaments') IS NULL BEGIN 
        THROW 50001, 'No se importó ningún CSV de Tournaments.', 1;
        RETURN;
    END

    DECLARE @maxID INT = (SELECT max(key_id) FROM ##Tournaments);

    DECLARE @idActual INT = 1;

    DECLARE @insertadas   INT = 0;
    DECLARE @actualizadas INT = 0;
    DECLARE @omitidas     INT = 0;

    BEGIN TRAN
    WHILE (@idActual <= @maxID) BEGIN

        DECLARE @fechaInicio DATE = NULL;
        DECLARE @fechaFin DATE = NULL;
        DECLARE @cantidadDeEquipos INT = NULL;

        SELECT @fechaInicio = start_date, @fechaFin = end_date, @cantidadDeEquipos = count_teams
            FROM ##Tournaments
            WHERE key_id = @idActual;

        BEGIN TRY

            IF (@fechaInicio is null) BEGIN
                DECLARE @msg VARCHAR(50) = CONCAT('Mundial skipeado: ', @idActual);
                THROW 50001, @msg, 1;
            END;

            DECLARE @idReal INT = (SELECT año FROM Mundial.Mundiales WHERE año = YEAR(@fechaInicio));

            if (@idReal is null) BEGIN
                exec Mundial.sp_crear_mundial @FInicio = @fechaInicio, @FFin = @fechaFin,  
                                           @LimiteJugadoresConvocados = 23,  @LimiteStaffConvocados = 23,
                                              @ArbitroDeVarRequerido = 0,
                                              @CantidadDeEquipos = @cantidadDeEquipos;
                SET @insertadas = @insertadas + 1;
            END ELSE BEGIN
                -- Omitir sin error
                SET @omitidas = @omitidas + 1; --- Los mundiales no se pueden editar.
            END
        END TRY
        BEGIN CATCH
            SET @omitidas = @omitidas + 1;
            print ERROR_MESSAGE();
        end CATCH

    SET @idActual = @idActual + 1;
    END;
    COMMIT TRAN


    SELECT 
        @insertadas as 'Mundiales insertados',
        @actualizadas as 'Mundiales actualizados',
        @omitidas as 'Mundiales omitidos';

END
GO


CREATE OR ALTER PROCEDURE Importacion.sp_upsert_jugadores
AS
BEGIN
    SET NOCOUNT ON

    IF OBJECT_ID('tempdb..##Players') IS NULL BEGIN 
        THROW 50001, 'No se importó ningún CSV de players.', 1;
        RETURN;
    END

    DECLARE @maxID INT = (SELECT max(key_id) FROM ##Players);

    DECLARE @idActual INT = 1;

    DECLARE @insertadas   INT = 0;
    DECLARE @actualizadas INT = 0;
    DECLARE @omitidas     INT = 0;

    BEGIN TRAN
    WHILE (@idActual <= @maxID) BEGIN
        
        DECLARE @nombre VARCHAR(100) = NULL;
        DECLARE @apellido VARCHAR(100) = NULL;
        DECLARE @f_nacimiento DATE = NULL;
        DECLARE @codigoPais CHAR(3) = NULL;

        SELECT @nombre = given_name, @apellido = family_name, @f_nacimiento = birth_date, @codigoPais = CodigoPais
            FROM ##Players
            WHERE key_id = @idActual;
        
        IF (@nombre is null) BEGIN
            SET @idActual = @idActual + 1;
            CONTINUE; -- Con este if, salteamos los baches que quedan por eliminar campos con female=1
        END;

        DECLARE @idReal INT;
        EXEC @idReal = Equipos.fn_obtener_integrante_id @Nombre = @nombre, @Apellido = @apellido, @FNacimiento = @f_nacimiento, @CodigoPais = @codigoPais;

        BEGIN TRY

            if (@idReal is null) BEGIN
                exec Equipos.sp_crear_integrante_seleccion @CodigoPais = @codigoPais, @Nombre = @nombre, @Apellido = @apellido, @FNacimiento = @f_nacimiento, @ID = @idReal OUTPUT;
                SET @insertadas = @insertadas + 1;
            END
            ELSE BEGIN
                exec Equipos.sp_modificar_integrante_seleccion @ID = @idReal, @CodigoPais = @codigoPais, @Nombre = @nombre, @Apellido = @apellido, @FNacimiento = @f_nacimiento;
                SET @actualizadas = @actualizadas + 1;
            END

            -- Mapear ID.
            UPDATE ##Players
                SET map_id = @idReal
                WHERE key_id = @idActual;

        END TRY
        BEGIN CATCH
            SET @omitidas = @omitidas + 1;
            print ERROR_MESSAGE();
        end CATCH

        SET @idActual = @idActual + 1;
    END;
    COMMIT TRAN

    SELECT 
        @insertadas as 'Jugadores insertados',
        @actualizadas as 'Jugadores actualizados',
        @omitidas as 'Jugadores omitidos';

END
GO

/******************************/
/* Países partícipes y grupos */
/******************************/


CREATE OR ALTER PROCEDURE Importacion.sp_crear_y_cargar_group_standings_csv 
    @Ruta VARCHAR(255)
AS
BEGIN 
    SET NOCOUNT ON

    IF OBJECT_ID('tempdb..##GroupStandings') IS NOT NULL DROP TABLE ##GroupStandings;


    CREATE TABLE ##GroupStandings (
        key_id INT PRIMARY KEY CLUSTERED,
        tournament_id CHAR(7),
        tournament_name VARCHAR(200),
        stage_number INT,
        stage_name VARCHAR(100),
        group_name VARCHAR(15),
        position INT,
        team_id char(4),
        team_name VARCHAR(100),
        team_code CHAR(3),
        played INT,
        wins INT,
        draws INT,
        losses INT,
        goals_for INT,
        goals_against INT,
        goals_difference INT,
        points INT,
        advanced INT
    );


    DECLARE @importacion VARCHAR(4000);

    BEGIN TRY
        SET @importacion = '
        SET NOCOUNT ON
        BULK INSERT ##GroupStandings
        FROM '''+ @Ruta + '''
        WITH (
            FORMAT = ''CSV'',
            FIELDQUOTE = ''"'',         -- Ignora las comas que estén dentro de estas comillas
            FIELDTERMINATOR = '','', 
            ROWTERMINATOR = ''0x0a'',
            FIRSTROW = 2,             -- Salta los encabezados
            CODEPAGE = ''65001''        -- UTF-8
        );';

        EXEC (@importacion);
    END TRY
    BEGIN CATCH
        DECLARE @ErrorBulk VARCHAR(4000) = ERROR_MESSAGE();
        THROW 50340, @ErrorBulk, 1;
        RETURN;
    END CATCH;

    ALTER TABLE ##GroupStandings 
        DROP COLUMN stage_number,
            stage_name, position, team_name, played, wins, 
            draws, losses, goals_for, goals_against, goals_difference,
            points, advanced;

    DELETE FROM ##GroupStandings WHERE tournament_name LIKE  '%Women%';

    UPDATE ##GroupStandings
        SET group_name = CASE 
            WHEN RIGHT(group_name, 1) LIKE '[0-9]' 
                THEN CHAR(65 + CAST(RIGHT(group_name, 1) AS INT) - 1)
            ELSE RIGHT(group_name, 1)
        END;

    UPDATE ##GroupStandings SET tournament_id = REPLACE(tournament_id, 'WC-', '');

    DECLARE @cantidadRegistrosCrudos INT = (SELECT count(*) FROM ##Players);
    
    -- print 'Cargados en #Confederations de CSV: ' + CAST (@cantidadRegistrosCrudos AS VARCHAR(5));

END
GO

CREATE OR ALTER PROCEDURE Importacion.sp_upsert_paises_participes
AS
BEGIN
    SET NOCOUNT ON

    IF OBJECT_ID('tempdb..##GroupStandings') IS NULL BEGIN 
        THROW 50001, 'No se importó ningún CSV de GroupStandings.', 1;
        RETURN;
    END

    DECLARE @maxID INT = (SELECT max(key_id) FROM ##GroupStandings);

    DECLARE @idActual INT = 1;

    DECLARE @insertadas   INT = 0;
    DECLARE @actualizadas INT = 0;
    DECLARE @omitidas     INT = 0;

    BEGIN TRAN
    WHILE (@idActual <= @maxID) BEGIN
    --- NECESITAMOS: CODIGO PAIS - AÑO MUNDIAL - GRUPO. NADA MAS
        DECLARE @codigoPais char(3) = NULL;
        DECLARE @groupName CHAR(1) = NULL;
        DECLARE @añoMundial INT = NULL;

        SELECT @codigoPais = team_code, @groupName = group_name, @añoMundial = tournament_id
            FROM ##GroupStandings
            WHERE key_id = @idActual;

        BEGIN TRY

            IF (@añoMundial is null) BEGIN
                THROW 50001, 'participacion skippeada (mundial femenino)', 1;
            END;

           EXEC Mundial.sp_incluir_pais @CodigoPais = @codigoPais, @AñoMundial = @añoMundial, @Grupo = @groupName
           SET @insertadas = @insertadas + 1;

        END TRY
        BEGIN CATCH
            SET @omitidas = @omitidas + 1;
            print ERROR_MESSAGE();
        END CATCH

        SET @idActual = @idActual + 1;
    END;
    COMMIT TRAN

    SELECT 
        @insertadas as 'Participaciones insertadas',
        @actualizadas as 'Participaciones actualizados',
        @omitidas as 'Participaciones omitidos';

END
GO


-- /********************************/
-- /*      Convocados!             */
-- /*******************************/


CREATE OR ALTER PROCEDURE Importacion.sp_upsert_convocados
AS
BEGIN
    SET NOCOUNT ON

    IF OBJECT_ID('tempdb..##Squads') IS NULL BEGIN 
        THROW 50001, 'No se importó ningún CSV de SQUADS.', 1;
        RETURN;
    END

    DECLARE @maxID INT = (SELECT max(key_id) FROM ##Squads);

    DECLARE @idActual INT = 1;

    DECLARE @insertadas   INT = 0;
    DECLARE @actualizadas INT = 0;
    DECLARE @omitidas     INT = 0;

    BEGIN TRAN
    WHILE (@idActual <= @maxID) BEGIN

        --- NECESITAMOS: CODIGO PAIS - AÑO MUNDIAL - GRUPO. NADA MAS
        DECLARE @añoMundial INT = NULL;
        DECLARE @IDJugador INT = NULL;
        DECLARE @dorsal INT = NULL;
        DECLARE @PlayerCode VARCHAR(100) = null;


        SELECT @dorsal = shirt_number, @añoMundial = tournament_id, @PlayerCode = player_id
            FROM ##Squads
            WHERE key_id = @idActual;
        
        SET @IDJugador = (SELECT map_id FROM ##Players WHERE player_id = @PlayerCode);



        BEGIN TRY

            IF (@IDJugador is null) BEGIN
                THROW 50001, 'SKIP ID NOT MAPPED', 1;
            END;
 
            EXEC Equipos.sp_convocar_jugador @AñoMundial = @añoMundial, @MiembroID = @IDJugador, @FConvocacion = '01-01-1900', @Dorsal = @dorsal, @ClubId = null
            SET @insertadas = @insertadas + 1;
 
        END TRY
        BEGIN CATCH
            SET @omitidas = @omitidas + 1;
            print ERROR_MESSAGE();
        END CATCH

        SET @idActual = @idActual + 1;
    END;
    COMMIT TRAN

    SELECT 
        @insertadas as 'Convocaciones insertadas',
        @actualizadas as 'Convocaciones actualizados',
        @omitidas as 'Convocaciones omitidos';

END
GO

-- Hay algunos datos que se pueden importar solos ... 
-- por ejemplo, con players.csv y teams.csv (para obtener paises de jugadores)
-- podemos insertar todos los jugadores en Equipos.IntegranteSeleccion
--
-- Pero, no podemos importar por si solas a las convocaciones de squads.csv, porque
-- aunque contienen nombre, apellido y país, no tienen fecha de nacimiento, que es un dato necesario
-- identificar a los integrantes.
-- Para resolver eso uso los ids internos de los datasets (player_id)
-- por eso de momento tiene sentido que la importación sea con todos los archivos.
CREATE OR ALTER PROCEDURE Importacion.PoblarDB 
    @RutaConfederationsCSV VARCHAR(255),
    @RutaTeamsCSV VARCHAR(255),
    @RutaPlayersCSV VARCHAR(255),
    @RutaSquadsCSV VARCHAR(255),
    @RutaTournamentsCSV VARCHAR(255),
    @RutaGroupStandingsCSV VARCHAR(255),
    @MostrarDatos BIT = 0
AS
BEGIN

    -- PSEUDO:
    --  1. Crear y cargar cada tabla temporal. Hace el bulk insert a cada tabla, le crea los
    --     índices, elimina las tablas que sobran, y linkea los datos necesarios
    --  2. Insertar a la db real. Ahí tenemos los while de verdad que insertan datos
    --  3. Limpieza. Eliminar las #tablas.

    -- crear tablas temporales y cargarlas
    EXEC Importacion.sp_crear_y_cargar_confederations_csv     @Ruta = @RutaConfederationsCSV
    EXEC Importacion.sp_crear_y_cargar_teams_csv              @Ruta = @RutaTeamsCSV
    EXEC Importacion.sp_crear_y_cargar_squads_csv             @Ruta = @RutaSquadsCSV
    EXEC Importacion.sp_crear_y_cargar_players_csv            @Ruta = @RutaPlayersCSV
    EXEC Importacion.sp_crear_y_cargar_tournaments_csv        @Ruta = @RutaTournamentsCSV
    EXEC Importacion.sp_crear_y_cargar_group_standings_csv    @Ruta = @RutaGroupStandingsCSV


    -- ejecutar inserción de los datos
    EXEC Importacion.sp_upsert_confederaciones;
    if @MostrarDatos = 1 
        SELECT * FROM Administracion.Confederaciones

    EXEC Importacion.sp_upsert_paises;
    if @MostrarDatos = 1 
        SELECT TOP 5 * FROM Administracion.Paises

    EXEC Importacion.sp_upsert_jugadores;
    if @MostrarDatos = 1 
        SELECT TOP 5 * FROM Equipos.IntegranteSeleccion;

    EXEC Importacion.sp_upsert_mundiales;
    if @MostrarDatos = 1 
        SELECT TOP 5 * FROM Mundial.Mundiales ORDER BY año DESC;

    EXEC Importacion.sp_upsert_paises_participes;
    if @MostrarDatos = 1 
        SELECT TOP 5 * FROM Mundial.Paises_Participes ORDER BY mundial_id DESC;

    EXEC Importacion.sp_upsert_convocados;
    if @MostrarDatos = 1 
            SELECT TOP 5 * FROM Equipos.ConvocacionEnSeleccion


    -- Limpieza
END
GO

-- DESCOMENTAR ALGUNA DE STAS LINEAS PARA IMPORTAR!

/*exec Importacion.PoblarDB 
        @RutaConfederationsCSV = 'C:\Soluciones-SQL\GestionDelMundial\Solucion\BBDD\Importacion\confederations.csv',
        @RutaTeamsCSV = 'C:\Soluciones-SQL\GestionDelMundial\Solucion\BBDD\Importacion\teams.csv',
        @RutaPlayersCSV = 'C:\Soluciones-SQL\GestionDelMundial\Solucion\BBDD\Importacion\players.csv',
        @RutaSquadsCSV = 'C:\Soluciones-SQL\GestionDelMundial\Solucion\BBDD\Importacion\squads.csv',
        @RutaTournamentsCSV = 'C:\Soluciones-SQL\GestionDelMundial\Solucion\BBDD\Importacion\tournaments.csv',
        @RutaGroupStandingsCSV = 'C:\Soluciones-SQL\GestionDelMundial\Solucion\BBDD\Importacion\group_standings.csv',
        @MostrarDatos = 1*/

/*exec Importacion.PoblarDB 
    @RutaConfederationsCSV = 'C:\gits\GestionDelMundial\Solucion\BBDD\Importacion\confederations.csv',
    @RutaTeamsCSV = 'C:\gits\GestionDelMundial\Solucion\BBDD\Importacion\teams.csv',
    @RutaPlayersCSV = 'C:\gits\GestionDelMundial\Solucion\BBDD\Importacion\players.csv',
    @RutaSquadsCSV = 'C:\gits\GestionDelMundial\Solucion\BBDD\Importacion\squads.csv',
    @RutaTournamentsCSV = 'C:\gits\GestionDelMundial\Solucion\BBDD\Importacion\tournaments.csv',
    @RutaGroupStandingsCSV = 'C:\gits\GestionDelMundial\Solucion\BBDD\Importacion\group_standings.csv',
    @MostrarDatos = 1*/