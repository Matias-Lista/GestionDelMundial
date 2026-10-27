use GestionDelMundial;
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
            IF ERROR_MESSAGE() NOT LIKE '%skipeado%'
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

            IF ERROR_MESSAGE() NOT LIKE '%skippeada%'
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

            IF @añoMundial IS NULL 
                THROW 50001, 'Convocacion skipeada', 1;

            IF (@IDJugador is null) BEGIN
                print '-----'
                print @dorsal;
                print @añoMundial;
                print @PlayerCode;
                THROW 50001, 'Convocacion erronea', 1;
            END;
 
            EXEC Equipos.sp_convocar_jugador @AñoMundial = @añoMundial, @MiembroID = @IDJugador, @FConvocacion = '01-01-1900', @Dorsal = @dorsal, @ClubId = null
            SET @insertadas = @insertadas + 1;
 
        END TRY
        BEGIN CATCH
            SET @omitidas = @omitidas + 1;

            IF ERROR_MESSAGE() NOT LIKE '%skipeada%'
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

/********/
/* SEDE */
/********/
CREATE OR ALTER PROCEDURE Importacion.sp_upsert_sedes
AS
BEGIN
    SET NOCOUNT ON

    IF OBJECT_ID('tempdb..##Stadiums') IS NULL BEGIN 
        THROW 50001, 'No se importó ningún CSV de Stadiums.', 1;
        RETURN;
    END

    DECLARE @maxID INT = (SELECT max(key_id) FROM ##Stadiums);

    DECLARE @idActual INT = 1;

    DECLARE @insertadas   INT = 0;
    DECLARE @actualizadas INT = 0;
    DECLARE @omitidas     INT = 0;

    BEGIN TRAN
    WHILE (@idActual <= @maxID) BEGIN

        DECLARE @nombrePais VARCHAR(100) = NULL;
        DECLARE @nombreCiudad VARCHAR(100) = NULL;
        DECLARE @nombre VARCHAR(100) = NULL;
        DECLARE @codigoPais CHAR(3) = NULL;
        DECLARE @capacidad INT = NULL;


        SELECT @nombrePais = country_name,
               @nombreCiudad = city_name,
               @capacidad = stadium_capacity,
               @nombre = stadium_name
            FROM ##Stadiums
            WHERE key_id = @idActual;
        
        SET @codigoPais = (SELECT codigo FROM Administracion.Paises WHERE nombre = @nombrePais);

        BEGIN TRY

            IF (@codigoPais is null) BEGIN
                DECLARE @msg VARCHAR(250) = CONCAT('SKIP PAÍS INVÁLIDO O NO REGISTRADO: ', @nombrePais);
                THROW 50001, @msg, 1;
            END;


            DECLARE @idReal INT = (SELECT id FROM Administracion.Sedes 
                                   WHERE pais_id = @codigoPais and nombre = @nombre 
                                     and ciudad = @nombreCiudad);

            IF @idReal is NULL BEGIN

                 exec Administracion.sp_crear_sede
                    @CodigoPais = @codigoPais,
                    @Nombre = @nombre,
                    @Ciudad = @nombreCiudad,
                    @Capacidad = @capacidad,
                    @ID = @idReal OUTPUT;

                    SET @insertadas = @insertadas + 1;
            END ELSE BEGIN

                 exec Administracion.sp_modificar_sede
                    @ID = @idReal,
                    @CodigoPais = @codigoPais,
                    @Nombre = @nombre,
                    @Ciudad = @nombreCiudad,
                    @Capacidad = @capacidad;

                    SET @actualizadas = @actualizadas + 1;

            END

            UPDATE ##Stadiums
                SET map_id = @idReal
                WHERE key_id = @idActual;
            
        END TRY
        BEGIN CATCH
            SET @omitidas = @omitidas + 1;
            print ERROR_MESSAGE();
        END CATCH

        SET @idActual = @idActual + 1;
    END;
    COMMIT TRAN

    SELECT 
        @insertadas as 'Sedes insertadas',
        @actualizadas as 'Sedes actualizados',
        @omitidas as 'Sedes omitidos';

END
GO


/********/
/* SEDE */
/********/
CREATE OR ALTER PROCEDURE Importacion.sp_upsert_partidos
AS
BEGIN
    SET NOCOUNT ON

    IF OBJECT_ID('tempdb..##Matches') IS NULL BEGIN 
        THROW 50001, 'No se importó ningún CSV de Matches.', 1;
        RETURN;
    END

    DECLARE @maxID INT = (SELECT max(key_id) FROM ##Matches);

    DECLARE @idActual INT = 1;

    DECLARE @insertadas   INT = 0;
    DECLARE @actualizadas INT = 0;
    DECLARE @omitidas     INT = 0;

    BEGIN TRAN
    WHILE (@idActual <= @maxID) BEGIN

        DECLARE @añoMundial INT = NULL;
        DECLARE @sedeIDCSV VARCHAR(10) = NULL;
        DECLARE @sedeID INT = NULL;
        DECLARE @seleccionA CHAR(3) = NULL;
        DECLARE @seleccionAID INT = NULL;
        DECLARE @seleccionB CHAR(3) = NULL;
        DECLARE @seleccionBID INT = NULL;
        DECLARE @fecha DATE = NULL;
        DECLARE @hora varchar(10) = NULL;
        DECLARE @faseCSV VARCHAR(20) = NULL;
        DECLARE @fase VARCHAR(15) = NULL;
        DECLARE @ganoSeleccionA BIT = NULL;
        DECLARE @ganoSeleccionB BIT = NULL;

        SELECT @añoMundial = tournament_id, @sedeIDCSV = stadium_id,
               @SeleccionA = home_team_code, @SeleccionB = away_team_code,
               @fecha = match_date, @faseCSV = stage_name , @ganoSeleccionA = home_team_win,
               @hora = match_time, @ganoSeleccionB = away_team_win
            FROM ##Matches
            WHERE key_id = @idActual;

        DECLARE @fechaYHora DATETIME = (SELECT CAST(CAST(@fecha AS VARCHAR(10)) + ' ' + @hora AS DATETIME));

        SET @faseCSV = LOWER(LTRIM(RTRIM(@faseCSV)));
            -- 2. Mapear (agregando las fases de grupos históricas)
            SET @fase = CASE @faseCSV 
                WHEN 'final' THEN 'FINAL'
                WHEN 'final round' THEN 'FINAL'
                WHEN 'third-place match' THEN 'TERCER_PUESTO'
                WHEN 'match for third place' THEN 'TERCER_PUESTO'
                WHEN 'semi-final' THEN 'SEMIFINAL'
                WHEN 'semi-finals' THEN 'SEMIFINAL'
                WHEN 'quarter-final' THEN 'CUARTOS'
                WHEN 'quarter-finals' THEN 'CUARTOS'
                WHEN 'round of 16' THEN 'OCTAVOS'
                WHEN 'round of 32' THEN 'DECISEISAVOS'
                WHEN 'group stage' THEN 'GRUPOS'
                WHEN 'first group stage' THEN 'GRUPOS'
                WHEN 'second group stage' THEN 'GRUPOS'
                ELSE NULL END;


        SELECT @sedeID = map_id FROM ##Stadiums WHERE stadium_id = @sedeIDCSV;

        SELECT @seleccionAID = seleccion_id FROM Mundial.Paises_Participes WHERE mundial_id = @añoMundial and pais_id = @seleccionA;
        SELECT @seleccionBID = seleccion_id FROM Mundial.Paises_Participes WHERE mundial_id = @añoMundial and pais_id = @seleccionB;

        -- Partidos.sp_crear_partido
        -- @AñoMundial INT,
        -- @SeleccionAID INT = NULL,
        -- @SeleccionBID INT = NULL,
        -- @SeleccionGanadoraID INT = NULL,
        -- @SedeID INT = NULL,
        -- @FechaYHora DATETIME,
        -- @Fase VARCHAR(15),

        BEGIN TRY

            IF @añoMundial is NULL BEGIN
                throw 50001, 'Partido skipeado', 1;
            END
            
            IF (@fase IS NULL) BEGIN
                DECLARE @msgFase VARCHAR(200) = CONCAT('Fase no mapeada en el CASE: [', ISNULL(@faseCSV, 'NULL'), ']');
                THROW 50001, @msgFase, 1;
            END;
            IF (@sedeID is null) BEGIN
                DECLARE @msg VARCHAR(500) = CONCAT('SKIP PARTIDO SEDE INVÁLIDA O NO REGISTRADA ', @sedeIDCSV);
                THROW 50001, @msg, 1;
            END;

            DECLARE @seleccionGanadoraID INT = NULL;
            IF @ganoSeleccionA = 1 
                SET @seleccionGanadoraID = @seleccionAID;
            ELSE IF @ganoSeleccionB = 1
                SET @seleccionGanadoraID = @seleccionBID;
                -- Sino null

            DECLARE @idInsertado INT = NULL;

            EXEC Partidos.sp_crear_partido
                @AñoMundial = @añoMundial,
                @SeleccionAID = @seleccionAID,
                @SeleccionBID = @seleccionBID,
                @SeleccionGanadoraID = @seleccionGanadoraID,
                @SedeID = @sedeID,
                @FechaYHora = @fechaYHora,
                @Fase = @fase,
                @ID = @idInsertado OUTPUT;     

            SET @insertadas = @insertadas + 1;
            -- TODO: modificar partido?

            UPDATE ##Matches 
                SET map_id = @idInsertado
                WHERE key_id = @idActual;

        END TRY
        BEGIN CATCH
            SET @omitidas = @omitidas + 1;

            IF ERROR_MESSAGE() NOT LIKE '%skipeado%'
                print ERROR_MESSAGE();

        END CATCH

        SET @idActual = @idActual + 1;
    END;

    -- TODO: DESPUÉS DE IMPORTAR LOS PARTIDOS, HAY QUE PODER OBTENER EL PARTIDO SIGUIENTE

    COMMIT TRAN

    SELECT 
        @insertadas as 'PARTIDOS insertados',
        @actualizadas as 'PARTIDOS actualizados',
        @omitidas as 'PARTIDOS omitidos';

END
GO

/****************/
/* FORMACIONES */
/****************/
CREATE OR ALTER PROCEDURE Importacion.sp_upsert_formaciones
AS
BEGIN
    SET NOCOUNT ON

    IF OBJECT_ID('tempdb..##PlayerAppearances') IS NULL BEGIN 
        THROW 50001, 'No se importó ningún CSV de PlayerAppearances.', 1;
        RETURN;
    END

    DECLARE @maxID INT = (SELECT max(key_id) FROM ##PlayerAppearances);

    DECLARE @idActual INT = 1;

    DECLARE @insertadas   INT = 0;
    DECLARE @actualizadas INT = 0;
    DECLARE @omitidas     INT = 0;

    BEGIN TRAN
    WHILE (@idActual <= @maxID) BEGIN

        DECLARE @añoMundial INT = NULL;
        DECLARE @posicion CHAR(2) = NULL;
        DECLARE @matchIDCSV CHAR(9) = NULL;
        DECLARE @playerIDCSV CHAR(7) = NULL;
        DECLARE @partidoId INT = NULL;
        DECLARE @jugadorId INT = NULL;
        DECLARE @codigoPais CHAR(3) = NULL;
        DECLARE @jugando BIT = NULL;

        SELECT @añoMundial = tournament_id, @posicion = position_code,
                @matchIDCSV = match_id, @playerIDCSV = player_id, @codigoPais = team_code,
                @jugando = starter
            FROM ##PlayerAppearances
            WHERE key_id = @idActual;

        SELECT @partidoId = map_id FROM ##Matches WHERE match_id = @matchIDCSV;
        SELECT @jugadorId = map_id FROM ##Players WHERE player_id = @playerIDCSV;

        DECLARE @seleccionId INT = (SELECT seleccion_id FROM Mundial.Paises_Participes WHERE mundial_id = @añoMundial and pais_id = @codigoPais);

        BEGIN TRY
            
            IF (@añoMundial IS NULL) BEGIN
                THROW 50001, 'FORMACION skipeado, no se insertó', 1;
            END;

            IF (@seleccionId IS NULL) BEGIN
                THROW 50001, 'FORMACION erronea, no se insertó', 1;
            END

            EXEC Partidos.sp_definir_formacion_inicial 
                @Jugando = @jugando,
                @Posicion = @posicion,
                @PartidoID = @partidoid,
                @JugadorID = @jugadorId,
                @SeleccionID = @seleccionId;

            SET @insertadas = @insertadas + 1;
            
        END TRY
        BEGIN CATCH
            SET @omitidas = @omitidas + 1;

            IF ERROR_MESSAGE() NOT LIKE '%skipeado%'
                print ERROR_MESSAGE();
            -- print ERROR_MESSAGE();
            -- print @añoMundial;
            -- print @codigoPais;
            -- PRINT 'El código es: [' + @codigoPais + '] y su longitud es: ' + CAST(DATALENGTH(@codigoPais) AS VARCHAR);
        END CATCH

        SET @idActual = @idActual + 1;
    END;

    -- TODO: DESPUÉS DE IMPORTAR LOS PARTIDOS, HAY QUE PODER OBTENER EL PARTIDO SIGUIENTE

    COMMIT TRAN

    SELECT 
        @insertadas as 'fORMACIONES insertados',
        @actualizadas as 'fORMACIONES actualizados',
        @omitidas as 'fORMACIONES omitidos';

END
GO


/****************/
/*   ARBITROS   */
/****************/
CREATE OR ALTER PROCEDURE Importacion.sp_upsert_arbitros
AS
BEGIN
    SET NOCOUNT ON

    IF OBJECT_ID('tempdb..##Referees') IS NULL BEGIN 
        THROW 50001, 'No se importó ningún CSV de Referees.', 1;
        RETURN;
    END

    DECLARE @maxID INT = (SELECT max(key_id) FROM ##Referees);

    DECLARE @idActual INT = 1;

    DECLARE @insertadas   INT = 0;
    DECLARE @actualizadas INT = 0;
    DECLARE @omitidas     INT = 0;

    BEGIN TRAN
    WHILE (@idActual <= @maxID) BEGIN

        -- necesito: Pais, nombre, apellido, confederacion, esMujer
        DECLARE @nombrePais VARCHAR(100) = NULL;
        DECLARE @nombre VARCHAR(100) = NULL;
        DECLARE @apellido VARCHAR(100) = NULL;
        DECLARE @confederacionCodigo VARCHAR(100) = NULL;
        DECLARE @esMujer BIT = NULL;

        DECLARE @confederacionId INT = NULL;
        DECLARE @codigoPais CHAR(3) = NULL;

        SELECT @nombrePais = country_name, @nombre = given_name,
                @apellido = family_name, @confederacionCodigo = confederation_code, @esMujer = female
            FROM ##Referees
            WHERE key_id = @idActual;

        SELECT @codigoPais = codigo FROM Administracion.Paises WHERE nombre = @nombrePais;
        SELECT @confederacionId = id FROM Administracion.Confederaciones WHERE siglas = @confederacionCodigo;

        DECLARE @arbitroID INT;
        
        BEGIN TRY
            
            IF (@nombre IS NULL) BEGIN
                THROW 50001, 'ARBITRO skipeado, no se insertó', 1;
            END;

            IF (@confederacionId IS NULL OR @codigoPais IS NULL) BEGIN
                THROW 50001, 'ARBITRO erroneo, no se insertó', 1;
            END;

            EXEC Arbitraje.sp_crear_arbitro
                @CodigoPais = @codigoPais,
                @Nombre = @nombre,
                @Apellido = @apellido,
                @EsMujer = @esMujer,
                @ConfederacionID = @confederacionId,
                @ID = @arbitroID OUTPUT 

            UPDATE ##Referees 
                SET map_id = @arbitroID WHERE key_id = @idActual; -- Mapeo.

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
        @insertadas as 'Arbitros insertados',
        @actualizadas as 'Arbitros actualizados',
        @omitidas as 'Arbitros omitidos';

END
GO


/********************************/
/*    ARBITROS ASIGNACIONES     */
/********************************/
CREATE OR ALTER PROCEDURE Importacion.sp_upsert_asignaciones_arbitros
AS
BEGIN
    SET NOCOUNT ON

    IF OBJECT_ID('tempdb..##RefereeAppearances') IS NULL BEGIN 
        THROW 50001, 'No se importó ningún CSV de Referees.', 1;
        RETURN;
    END

    DECLARE @maxID INT = (SELECT max(key_id) FROM ##RefereeAppearances);

    DECLARE @idActual INT = 1;

    DECLARE @insertadas   INT = 0;
    DECLARE @actualizadas INT = 0;
    DECLARE @omitidas     INT = 0;

    BEGIN TRAN
    WHILE (@idActual <= @maxID) BEGIN

        -- Necesito: AñoMundial, ID Arbitro, Partido ID,
        DECLARE @añoMundial INT = NULL;
        DECLARE @arbitroIDCSV VARCHAR(100) = NULL;
        DECLARE @partidoIDCSV VARCHAR(100) = NULL;

        DECLARE @arbitroID INT = NULL;
        DECLARE @partidoID INT = NULL;

        SELECT @añoMundial = tournament_id, @arbitroIDCSV = referee_id,
                @partidoIDCSV = match_id
            FROM ##RefereeAppearances
            WHERE key_id = @idActual;

        SELECT @partidoId = map_id FROM ##Matches WHERE match_id = @partidoIDCSV;
        SELECT @arbitroID = map_id FROM ##Referees WHERE referee_id = @arbitroIDCSV;
        
        BEGIN TRY
            
            IF (@añoMundial IS NULL) BEGIN
                THROW 50001, 'Asignacion de ARBITRO skipeado, no se insertó', 1;
            END;

            IF (@partidoId IS NULL OR @arbitroID IS NULL) BEGIN
                THROW 50001, 'Asignacion de ARBITRO erronea, no se insertó', 1;
            END;

            -- Habilitamos al arbitro para ese mundial si no está habilitado
            IF NOT EXISTS (SELECT 1 FROM Mundial.Habilitacion_Arbitro WHERE mundial_id = @añoMundial and arbitro_id = @arbitroID)
                EXEC Mundial.sp_habilitar_arbitro
                    @AñoMundial = @añoMundial,
                    @ArbitroID = @arbitroID;

            -- Asignamos el árbitro al partido.

            EXEC Arbitraje.sp_designar_arbitro
                @PartidoID = @partidoId,
                @ArbitroID = @arbitroID;

            SET @insertadas = @insertadas + 1;
            
        END TRY
        BEGIN CATCH
            SET @omitidas = @omitidas + 1;
            IF ERROR_MESSAGE() NOT LIKE '%skipeado%'
                print ERROR_MESSAGE();
       END CATCH

        SET @idActual = @idActual + 1;
    END;

    COMMIT TRAN

    SELECT 
        @insertadas as 'Asignacion de Arbitros insertados',
        @actualizadas as 'Asignacion de Arbitros Arbitros actualizados',
        @omitidas as 'Asignacion de Arbitros Arbitros omitidos';

END
GO


/********************************/
/*            CAMBIOS           */
/********************************/
CREATE OR ALTER PROCEDURE Importacion.sp_upsert_cambios
AS
BEGIN
    SET NOCOUNT ON

    IF OBJECT_ID('tempdb..##Substitutions') IS NULL BEGIN 
        THROW 50001, 'No se importó ningún CSV de Substitutions.', 1;
        RETURN;
    END

    DECLARE @maxID INT = (SELECT max(key_id) FROM ##Substitutions);

    DECLARE @idActual INT = 1;

    DECLARE @insertadas   INT = 0;
    DECLARE @actualizadas INT = 0;
    DECLARE @omitidas     INT = 0;

    BEGIN TRAN
    WHILE (@idActual <= @maxID) BEGIN

        -- Necesito: JugadorID, Minuto, Extra, Tiempo, PartidoID, MOTIVO = DEFAULT,

        DECLARE @minuto SMALLINT = NULL
        DECLARE @extra SMALLINT  = NULL;
        DECLARE @periodo VARCHAR(100) = NULL;
        DECLARE @playerIDCSV varchar(20) = NULL;
        DECLARE @saliendo BIT = NULL;
        DECLARE @partidoIDCSV VARCHAR(100) = NULL;


        DECLARE @jugadorID INT = NULL;
        DECLARE @partidoID INT = NULL;

        SELECT @minuto = minute_regulation, @extra = minute_stoppage,
                @partidoIDCSV = match_id, @playerIDCSV = player_id,
                @periodo = match_period, @saliendo = going_off
            FROM ##Substitutions
            WHERE key_id = @idActual;

        SELECT @partidoID = map_id FROM ##Matches WHERE match_id = @partidoIDCSV;
        SELECT @jugadorID = map_id FROM ##Players WHERE player_id = @playerIDCSV;
        
        BEGIN TRY
            
            IF (@minuto IS NULL) BEGIN
                THROW 50001, 'Cambio skipeado, no se insertó', 1;
            END;

            IF (@jugadorID IS NULL OR @partidoID IS NULL) BEGIN
                THROW 50001, 'Cambio erroneo, no se insertó', 1;
            END;

            DECLARE @minutoCorrecto SMALLINT = CASE 
                WHEN @periodo = 'extra time, first half' THEN @minuto - 90
                WHEN @periodo = 'extra time, first half, stoppage time' THEN 15
                WHEN @periodo = 'extra time, second half' THEN @minuto - 105
                WHEN @periodo = 'extra time, second half, stoppage time' THEN 15
                WHEN @periodo = 'first half' THEN @minuto
                WHEN @periodo = 'first half, stoppage time' THEN 45
                WHEN @periodo = 'second half' THEN @minuto - 45
                WHEN @periodo = 'second half, stoppage time' THEN 45
            END

            DECLARE @tiempoCorrecto SMALLINT = CASE 
                WHEN @periodo = 'extra time, first half' THEN 3
                WHEN @periodo = 'extra time, first half, stoppage time' THEN 3
                WHEN @periodo = 'extra time, second half' THEN 4
                WHEN @periodo = 'extra time, second half, stoppage time' THEN 4
                WHEN @periodo = 'first half' THEN 1
                WHEN @periodo = 'first half, stoppage time' THEN 1
                WHEN @periodo = 'second half' THEN 2
                WHEN @periodo = 'second half, stoppage time' THEN 2
            END

            IF @saliendo = 1
                EXEC Eventos.sp_registrar_cambio
                    @Minuto = @minutoCorrecto,
                    @Extra  = @extra,
                    @Tiempo = @tiempoCorrecto,
                    @PartidoID = @partidoID,
                    @Motivo = 'TACTICO', -- HARDCODEADO PORQUE NO ESTA EN EL DATASET
                    @JugadorSaleID = @jugadorID;
            ELSE
                EXEC Eventos.sp_registrar_cambio
                    @Minuto = @minutoCorrecto,
                    @Extra  = @extra,
                    @Tiempo = @tiempoCorrecto,
                    @PartidoID = @partidoID,
                    @Motivo = 'TACTICO', -- HARDCODEADO PORQUE NO ESTA EN EL DATASET
                    @JugadorEntraID = @jugadorID;


            SET @insertadas = @insertadas + 1;
            
        END TRY
        BEGIN CATCH
            SET @omitidas = @omitidas + 1;
            IF ERROR_MESSAGE() NOT LIKE '%skipeado%'
                print ERROR_MESSAGE();
       END CATCH

        SET @idActual = @idActual + 1;
    END;

    COMMIT TRAN

    SELECT 
        @insertadas as 'Cambios insertados',
        @actualizadas as 'Cambios actualizados',
        @omitidas as 'Cambios omitidos';

END
GO


/********************************/
/*            GOLES           */
/********************************/
CREATE OR ALTER PROCEDURE Importacion.sp_upsert_goles
AS
BEGIN
    SET NOCOUNT ON

    IF OBJECT_ID('tempdb..##Goals') IS NULL BEGIN 
        THROW 50001, 'No se importó ningún CSV de Goles.', 1;
        RETURN;
    END

    DECLARE @maxID INT = (SELECT max(key_id) FROM ##Goals);

    DECLARE @idActual INT = 1;

    DECLARE @insertadas   INT = 0;
    DECLARE @actualizadas INT = 0;
    DECLARE @omitidas     INT = 0;

    BEGIN TRAN
    WHILE (@idActual <= @maxID) BEGIN

        -- Necesito: JugadorID, Minuto, Extra, Tiempo, PartidoID, MOTIVO = DEFAULT,

        DECLARE @minuto SMALLINT = NULL
        DECLARE @extra SMALLINT  = NULL;
        DECLARE @periodo VARCHAR(100) = NULL;
        DECLARE @playerIDCSV varchar(20) = NULL;
        DECLARE @partidoIDCSV VARCHAR(100) = NULL;
        DECLARE @penal BIT = NULL;
        DECLARE @enContra BIT = NULL;


        DECLARE @jugadorID INT = NULL;
        DECLARE @partidoID INT = NULL;

        SELECT @minuto = minute_regulation, @extra = minute_stoppage,
                @partidoIDCSV = match_id, @playerIDCSV = player_id,
                @periodo = match_period, @penal = penalty, @enContra = own_goal
            FROM ##Goals
            WHERE key_id = @idActual;

        SELECT @partidoID = map_id FROM ##Matches WHERE match_id = @partidoIDCSV;
        SELECT @jugadorID = map_id FROM ##Players WHERE player_id = @playerIDCSV;
        
        BEGIN TRY
            
            IF (@minuto IS NULL) BEGIN
                THROW 50001, 'Gol skipeado, no se insertó', 1;
            END;

            IF (@jugadorID IS NULL OR @partidoID IS NULL) BEGIN
                THROW 50001, 'GOL erroneo, no se insertó', 1;
            END;

            DECLARE @minutoCorrecto SMALLINT = CASE 
                WHEN @periodo = 'extra time, first half' THEN @minuto - 90
                WHEN @periodo = 'extra time, first half, stoppage time' THEN 15
                WHEN @periodo = 'extra time, second half' THEN @minuto - 105
                WHEN @periodo = 'extra time, second half, stoppage time' THEN 15
                WHEN @periodo = 'first half' THEN @minuto
                WHEN @periodo = 'first half, stoppage time' THEN 45
                WHEN @periodo = 'second half' THEN @minuto - 45
                WHEN @periodo = 'second half, stoppage time' THEN 45
            END

            DECLARE @tiempoCorrecto SMALLINT = CASE 
                WHEN @periodo = 'extra time, first half' THEN 3
                WHEN @periodo = 'extra time, first half, stoppage time' THEN 3
                WHEN @periodo = 'extra time, second half' THEN 4
                WHEN @periodo = 'extra time, second half, stoppage time' THEN 4
                WHEN @periodo = 'first half' THEN 1
                WHEN @periodo = 'first half, stoppage time' THEN 1
                WHEN @periodo = 'second half' THEN 2
                WHEN @periodo = 'second half, stoppage time' THEN 2
            END

            IF @penal = 1
                EXEC Eventos.sp_registrar_gol
                        @Minuto = @minutoCorrecto,
                        @Extra  = @extra,
                        @Tiempo = @tiempoCorrecto,
                        @PartidoID = @partidoID,
                        @JugadorID = @jugadorID,
                        -- @JugadorAsistenteID = NULL, -- NO ESTA EN EL DATASET
                        @Tipo = 'P';
            ELSE IF @enContra = 1
                EXEC Eventos.sp_registrar_gol
                        @Minuto = @minutoCorrecto,
                        @Extra  = @extra,
                        @Tiempo = @tiempoCorrecto,
                        @PartidoID = @partidoID,
                        @JugadorID = @jugadorID,
                        @Tipo = 'E';
            ELSE 
                EXEC Eventos.sp_registrar_gol
                        @Minuto = @minutoCorrecto,
                        @Extra  = @extra,
                        @Tiempo = @tiempoCorrecto,
                        @PartidoID = @partidoID,
                        @JugadorID = @jugadorID,
                        @Tipo = 'N'; -- NORMAL: El dataset no muestra más detalles

            SET @insertadas = @insertadas + 1;
            
        END TRY
        BEGIN CATCH
            SET @omitidas = @omitidas + 1;
            IF ERROR_MESSAGE() NOT LIKE '%skipeado%'
                print ERROR_MESSAGE();
       END CATCH

        SET @idActual = @idActual + 1;
    END;

    COMMIT TRAN

    SELECT 
        @insertadas as 'GOLES insertados',
        @actualizadas as 'GOLES actualizados',
        @omitidas as 'GOLES omitidos';

END
GO

/********************************/
/*            GOLES           */
/********************************/
CREATE OR ALTER PROCEDURE Importacion.sp_upsert_penales_de_tanda
AS
BEGIN
    SET NOCOUNT ON

    IF OBJECT_ID('tempdb..##PenaltyKicks') IS NULL BEGIN 
        THROW 50001, 'No se importó ningún CSV de PenaltyKicks.', 1;
        RETURN;
    END

    DECLARE @maxID INT = (SELECT max(key_id) FROM ##PenaltyKicks);

    DECLARE @idActual INT = 1;

    DECLARE @insertadas   INT = 0;
    DECLARE @actualizadas INT = 0;
    DECLARE @omitidas     INT = 0;

    BEGIN TRAN
    WHILE (@idActual <= @maxID) BEGIN

        -- Necesito: JugadorID, PartidoID, Convirtio.

        DECLARE @playerIDCSV varchar(20) = NULL;
        DECLARE @partidoIDCSV VARCHAR(100) = NULL;
        DECLARE @convirtio BIT = NULL;

        DECLARE @jugadorID INT = NULL;
        DECLARE @partidoID INT = NULL;

        SELECT @partidoIDCSV = match_id, @playerIDCSV = player_id,
                @convirtio = converted
            FROM ##PenaltyKicks
            WHERE key_id = @idActual;

        SELECT @partidoID = map_id FROM ##Matches WHERE match_id = @partidoIDCSV;
        SELECT @jugadorID = map_id FROM ##Players WHERE player_id = @playerIDCSV;
        
        BEGIN TRY
            
            IF (@convirtio IS NULL) BEGIN
                THROW 50001, 'PENAL DE TANDA skipeado, no se insertó', 1;
            END;

            IF (@jugadorID IS NULL OR @partidoID IS NULL) BEGIN
                THROW 50001, 'PENAL DE TANDA erroneo, no se insertó', 1;
            END;

            exec Eventos.sp_registrar_penal_de_tanda
                    @PartidoID = @partidoID,
                    @JugadorID = @jugadorID,
                    @Convirtio = @convirtio
            
            SET @insertadas = @insertadas + 1;
            
        END TRY
        BEGIN CATCH
            SET @omitidas = @omitidas + 1;
            IF ERROR_MESSAGE() NOT LIKE '%skipeado%'
                print ERROR_MESSAGE();
       END CATCH

        SET @idActual = @idActual + 1;
    END;

    COMMIT TRAN

    SELECT 
        @insertadas as 'Penales de tanda insertados',
        @actualizadas as 'Penales de tanda actualizados',
        @omitidas as 'Penales de tanda omitidos';

END
GO

/********************************/
/*         AMONESTACIONES        */
/********************************/
CREATE OR ALTER PROCEDURE Importacion.sp_upsert_amonestaciones
AS
BEGIN
    SET NOCOUNT ON

    IF OBJECT_ID('tempdb..##Bookings') IS NULL BEGIN 
        THROW 50001, 'No se importó ningún CSV de Bookings.', 1;
        RETURN;
    END

    DECLARE @maxID INT = (SELECT max(key_id) FROM ##Bookings);

    DECLARE @idActual INT = 1;

    DECLARE @insertadas   INT = 0;
    DECLARE @actualizadas INT = 0;
    DECLARE @omitidas     INT = 0;

    BEGIN TRAN
    WHILE (@idActual <= @maxID) BEGIN

        -- Necesito: Minuto, Extra, Tiempo, Partido (mapeado), Jugador (mapeado), Tarjeta
        DECLARE @minuto SMALLINT = NULL
        DECLARE @extra SMALLINT  = NULL;
        DECLARE @periodo VARCHAR(100) = NULL;
        DECLARE @fueAmarilla BIT = NULL;
        DECLARE @fueDobleAmarilla BIT = NULL;

        DECLARE @playerIDCSV varchar(20) = NULL;
        DECLARE @partidoIDCSV VARCHAR(100) = NULL;

        DECLARE @jugadorID INT = NULL;
        DECLARE @partidoID INT = NULL;

        SELECT @minuto = minute_regulation, @extra = minute_stoppage,
                @partidoIDCSV = match_id, @playerIDCSV = player_id,
                @periodo = match_period, @fueAmarilla = yellow_card, @fueDobleAmarilla = second_yellow_card
            FROM ##Bookings
            WHERE key_id = @idActual;

        SELECT @partidoID = map_id FROM ##Matches WHERE match_id = @partidoIDCSV;
        SELECT @jugadorID = map_id FROM ##Players WHERE player_id = @playerIDCSV;
        
        BEGIN TRY
            
            IF (@minuto IS NULL) BEGIN
                THROW 50001, 'falta skipeada, no se insertó', 1;
            END;

            IF (@jugadorID IS NULL OR @partidoID IS NULL) BEGIN
                THROW 50001, 'falta erronea, no se insertó', 1;
            END;

            DECLARE @minutoCorrecto SMALLINT = CASE 
                WHEN @periodo = 'extra time, first half' THEN @minuto - 90
                WHEN @periodo = 'extra time, first half, stoppage time' THEN 15
                WHEN @periodo = 'extra time, second half' THEN @minuto - 105
                WHEN @periodo = 'extra time, second half, stoppage time' THEN 15
                WHEN @periodo = 'first half' THEN @minuto
                WHEN @periodo = 'first half, stoppage time' THEN 45
                WHEN @periodo = 'second half' THEN @minuto - 45
                WHEN @periodo = 'second half, stoppage time' THEN 45
            END

            DECLARE @tiempoCorrecto SMALLINT = CASE 
                WHEN @periodo = 'extra time, first half' THEN 3
                WHEN @periodo = 'extra time, first half, stoppage time' THEN 3
                WHEN @periodo = 'extra time, second half' THEN 4
                WHEN @periodo = 'extra time, second half, stoppage time' THEN 4
                WHEN @periodo = 'first half' THEN 1
                WHEN @periodo = 'first half, stoppage time' THEN 1
                WHEN @periodo = 'second half' THEN 2
                WHEN @periodo = 'second half, stoppage time' THEN 2
            END

            -- NOTA: El DATASET guarda las dobles amarillas como una sola. Por lo tanto, en ese caso,
            --       voy a ejecutar el stored procedure dos veces.
            DECLARE @tarjeta CHAR(1) = CASE 
                WHEN @fueAmarilla = 1 THEN 'A'
                ELSE 'R'
            END;

            EXEC Eventos.sp_registrar_amonestacion 
                    @Minuto = @minutoCorrecto,
                    @Extra = @extra,
                    @Tiempo = @tiempoCorrecto,
                    @PartidoID = @partidoID,
                    @JugadorID = @JugadorID,
                    @Tarjeta = @tarjeta;

            IF @fueDobleAmarilla = 1 BEGIN 
                SET @insertadas = @insertadas + 1
                EXEC Eventos.sp_registrar_amonestacion 
                        @Minuto = @minutoCorrecto,
                        @Extra = @extra,
                        @Tiempo = @tiempoCorrecto,
                        @PartidoID = @partidoID,
                        @JugadorID = @JugadorID,
                        @Tarjeta = @tarjeta,
                        @Motivo = 'DOBLE AMARILLA. DATASET';
            END 
            
            SET @insertadas = @insertadas + 1;
            
        END TRY
        BEGIN CATCH
            SET @omitidas = @omitidas + 1;
            IF ERROR_MESSAGE() NOT LIKE '%skipeada%' BEGIN
                print ERROR_MESSAGE();
                PRINT '--- DEBUG AMONESTACIÓN FALLIDA ---'
                PRINT 'ID Partido: ' + ISNULL(CAST(@partidoID AS VARCHAR), 'NULL') + ' | ID Jugador: ' + ISNULL(CAST(@jugadorID AS VARCHAR), 'NULL')
                PRINT 'Tiempo Tarjeta: ' + ISNULL(CAST(@tiempoCorrecto AS VARCHAR), 'NULL') 
                      + ' | Minuto: ' + ISNULL(CAST(@minutoCorrecto AS VARCHAR), 'NULL') 
                      + ' | Extra: ' + ISNULL(CAST(@extra AS VARCHAR), '0')
                PRINT '----------------------------------'
            END
       END CATCH

        SET @idActual = @idActual + 1;
    END;

    COMMIT TRAN

    SELECT 
        @insertadas as 'Amonestaciones insertados',
        @actualizadas as 'Amonestaciones actualizados',
        @omitidas as 'Amonestaciones omitidos';

END
GO

/********************************/
/*         ANUNCIANTES        */
/********************************/
CREATE OR ALTER PROCEDURE Importacion.sp_upsert_anunciantes
AS
BEGIN
    SET NOCOUNT ON

    IF OBJECT_ID('tempdb..##Anunciantes') IS NULL BEGIN 
        THROW 50001, 'No se importó ningún JSON de Publicidad.', 1;
        RETURN;
    END

    DECLARE @maxID INT = (SELECT max(id) FROM ##Anunciantes);

    DECLARE @idActual INT = 1;

    DECLARE @insertados   INT = 0;
    DECLARE @actualizados INT = 0;
    DECLARE @omitidos     INT = 0;

    BEGIN TRAN
    WHILE (@idActual <= @maxID) BEGIN

        -- Necesito nombre nada más

        DECLARE @anunciante VARCHAR(300) = NULL;
        DECLARE @anuncianteID INT = NULL;

        SELECT @anunciante = anunciante
            FROM ##Anunciantes
            WHERE id = @idActual;

        SELECT @anuncianteID = id FROM Publicidad.Anunciantes where razon_social = @anunciante;

        BEGIN TRY
            
            IF (@anunciante IS NULL OR @anuncianteID is not null) BEGIN
                THROW 50001, 'anunciante skipeado, no se insertó', 1;
            END;

            EXEC Publicidad.sp_crear_anunciante 
                    @RazonSocial = @anunciante,
                    @ID = @anuncianteID OUTPUT;

            SET @insertados = @insertados + 1;
            
        END TRY
        BEGIN CATCH
            SET @omitidos = @omitidos + 1;
            IF ERROR_MESSAGE() NOT LIKE '%skipeado%' BEGIN
                print ERROR_MESSAGE();
            END
       END CATCH

       -- MAPEAMOS
       IF @anunciante is not null 
          UPDATE ##Anunciantes 
             SET map_id = @anuncianteID
             WHERE id = @idActual;

        SET @idActual = @idActual + 1;
    END;

    COMMIT TRAN

    SELECT 
        @insertados     as 'Anunciantes insertados',
        @actualizados as 'Anunciantes actualizados',
        @omitidos     as 'Anunciantes omitidos';
END
GO


/********************************/
/*           CAMPAÑAS           */
/********************************/
CREATE OR ALTER PROCEDURE Importacion.sp_upsert_campañas
AS
BEGIN
    SET NOCOUNT ON

    IF OBJECT_ID('tempdb..##Campañas') IS NULL BEGIN 
        THROW 50001, 'No se importó ningún JSON de Publicidad.', 1;
        RETURN;
    END

    DECLARE @maxID INT = (SELECT max(id) FROM ##Campañas);

    DECLARE @idActual INT = 1;

    DECLARE @insertados   INT = 0;
    DECLARE @actualizados INT = 0;
    DECLARE @omitidos     INT = 0;

    BEGIN TRAN
    WHILE (@idActual <= @maxID) BEGIN

        -- Necesito nombre, descripcion, anunciante, añomundial, horario min y max 
        

        DECLARE @nombre VARCHAR(300) = NULL;
        DECLARE @descripcion VARCHAR(300) = NULL;
        DECLARE @horarioMinimo SMALLINT = NULL;
        DECLARE @horarioMaximo SMALLINT = NULL;
        DECLARE @añoMundial INT = NULL;
        
        DECLARE @anuncianteIDJSON INT = NULL;

        DECLARE @anuncianteID INT = NULL;
        DECLARE @campañaID INT = NULL;

        SELECT @nombre = nombre, @descripcion = descripcion, @horarioMinimo = horario_minimo,
               @horarioMaximo = horario_maximo, @añoMundial = anio_mundial, @anuncianteIDJSON = anunciante_id
            FROM ##Campañas
            WHERE id = @idActual;

        SELECT @anuncianteID = map_id FROM ##Anunciantes where id = @anuncianteIDJSON;
        SELECT @campañaID = id FROM Publicidad.Campañas where nombre = @nombre and mundial_id = @añoMundial;

        BEGIN TRY
            
            IF (@nombre IS NULL) BEGIN
                THROW 50001, 'campaña skipeado, no se insertó', 1;
            END;
            IF @campañaID is not null BEGIN

                EXEC Publicidad.sp_modificar_campaña
                    @CampañaID     = @campañaID,
                    @AnuncianteID  = @anuncianteID,
                    @AñoMundial    = @añoMundial,
                    @Nombre        = @nombre,
                    @Descripcion   = @descripcion,
                    @HorarioMinimo = @horarioMinimo,
                    @HorarioMaximo = @horarioMaximo

                SET @actualizados = @actualizados + 1;

            END ELSE BEGIN 

                EXEC Publicidad.sp_crear_campaña
                    @AnuncianteID  = @anuncianteID,
                    @AñoMundial    = @añoMundial,
                    @Nombre        = @nombre,
                    @Descripcion   = @descripcion,
                    @HorarioMinimo = @horarioMinimo,
                    @HorarioMaximo = @horarioMaximo,
                    @ID            = @campañaID OUTPUT;

                SET @insertados = @insertados + 1;
            END
            
        END TRY
        BEGIN CATCH
            SET @omitidos = @omitidos + 1;
            IF ERROR_MESSAGE() NOT LIKE '%skipeado%' BEGIN
                print ERROR_MESSAGE();
            END
       END CATCH

       -- MAPEO
       IF @campañaID is not null 
          UPDATE ##Campañas 
             SET map_id = @campañaID
             WHERE id = @idActual;

        SET @idActual = @idActual + 1;
    END;

    COMMIT TRAN

    SELECT 
        @insertados     as 'Campañas insertadas',
        @actualizados   as 'Campañas actualizadas',
        @omitidos       as 'Campañas omitidas';
END
GO


/********************************/
/*     PIEZAS DE CONTENIDO      */
/********************************/
CREATE OR ALTER PROCEDURE Importacion.sp_upsert_piezas_de_contenido
AS
BEGIN
    SET NOCOUNT ON

    IF OBJECT_ID('tempdb..##PiezasDeContenido') IS NULL BEGIN 
        THROW 50001, 'No se importó ningún JSON de Publicidad.', 1;
        RETURN;
    END

    DECLARE @maxID INT = (SELECT max(id) FROM ##PiezasDeContenido);

    DECLARE @idActual INT = 1;

    DECLARE @insertados   INT = 0;
    DECLARE @actualizados INT = 0;
    DECLARE @omitidos     INT = 0;

    BEGIN TRAN
    WHILE (@idActual <= @maxID) BEGIN

        -- Necesito nombre, descripcion, campaña y paises interesados 

        DECLARE @nombre VARCHAR(300) = NULL;
        DECLARE @descripcion VARCHAR(300) = NULL;
        DECLARE @paisesDeInteres NVARCHAR(MAX) = NULL;

        DECLARE @campañaIDJSON INT = NULL;
        
        DECLARE @campañaID INT = NULL;
        DECLARE @piezaDeContenidoID INT = NULL;

        SELECT @nombre = nombre, @descripcion = descripcion, @paisesDeInteres = paises_de_interes,
               @campañaIDJSON = campania_id
            FROM ##PiezasDeContenido
            WHERE id = @idActual;

        SELECT @campañaID = map_id FROM ##Campañas where id = @campañaIDJSON;

        SELECT @piezaDeContenidoID = id 
               FROM Publicidad.PiezasDeContenido 
               WHERE nombre = @nombre AND campaña_id = @campañaID;

        BEGIN TRY
            
            IF (@nombre IS NULL) BEGIN
                THROW 50001, 'pieza skipeado, no se insertó', 1;
            END;

            IF (@piezaDeContenidoID IS NOT NULL) BEGIN
                -- THROW 50001, 'pieza skipeado, no se insertó', 1;
                PRINT 'hay que editar' -- todo: editar
            END;

            EXEC Publicidad.sp_crear_pieza_de_contenido
                    @CampañaID = @campañaID,
                    @NombrePieza = @nombre,
                    @Descripcion = @descripcion,
                    @PaisesInteresados = @paisesDeInteres        

            SET @insertados = @insertados + 1;
            
        END TRY
        BEGIN CATCH
            SET @omitidos = @omitidos + 1;
            IF ERROR_MESSAGE() NOT LIKE '%skipeado%' BEGIN
                print ERROR_MESSAGE();
            END
       END CATCH

        SET @idActual = @idActual + 1;
    END;

    COMMIT TRAN

    SELECT 
        @insertados     as 'PiezasDeContenido insertadas',
        @actualizados   as 'PiezasDeContenido actualizadas',
        @omitidos       as 'PiezasDeContenido omitidas';
END
GO


CREATE OR ALTER PROCEDURE Importacion.sp_bypass_mundiales_previos
AS
BEGIN
    DECLARE @TableName NVARCHAR(256);
    DECLARE @Sql NVARCHAR(MAX);

    -- 1. Declarar cursor buscando en tempdb solo las tablas globales (##) que tengan el campo tournament_id
    DECLARE cur_TempTables CURSOR LOCAL FOR
    SELECT t.name
    FROM tempdb.sys.tables t
    INNER JOIN tempdb.sys.columns c ON t.object_id = c.object_id
    WHERE t.name LIKE '##%' 
      AND c.name = 'tournament_id';

    OPEN cur_TempTables;
    FETCH NEXT FROM cur_TempTables INTO @TableName;

    -- 2. Recorrer las tablas encontradas
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- 3. Armar el SQL dinámico con manejo de errores interno (TRY...CATCH)
        SET @Sql = N'
        BEGIN TRY
            DELETE FROM [' + @TableName + N'] 
            WHERE tournament_id <> 2022;
            
            --PRINT ''Limpieza exitosa en: ' + @TableName + N''';
        END TRY
        BEGIN CATCH
            -- Atrapa el error y lo imprime, pero no detiene la ejecución del cursor
            PRINT ''Ocurrió un error en la tabla ' + @TableName + N': '' + ERROR_MESSAGE();
        END CATCH;
        ';

        -- 4. Ejecutar el código dinámico
        EXEC sp_executesql @Sql;

        FETCH NEXT FROM cur_TempTables INTO @TableName;
    END

    -- 5. Cerrar y liberar el cursor
    CLOSE cur_TempTables;
    DEALLOCATE cur_TempTables;
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
    @RutaStadiumsCSV VARCHAR(255),
    @RutaMatchesCSV VARCHAR(255),
    @RutaPlayerAppearancesCSV VARCHAR(255),
    @RutaRefereesCSV VARCHAR(255),
    @RutaRefereeAppearancesCSV VARCHAR(255),
    @RutaSubstitutionsCSV VARCHAR(255),
    @RutaGoalsCSV VARCHAR(255),
    @RutaPenaltyKicksCSV VARCHAR(255),
    @RutaBookingsCSV VARCHAR(255),
    @RutaPublicidadJSON VARCHAR(255),
    @MostrarDatos BIT = 0,
    @UnicoMundial INT = NULL 
AS
BEGIN

    exec Importacion.sp_limpieza_tablas_temporales;

    -- PSEUDO:
    --  1. Crear y cargar cada tabla temporal. Hace el bulk insert a cada tabla, le crea los
    --     índices, elimina las tablas que sobran, y linkea los datos necesarios
    --  2. Insertar a la db real. Ahí tenemos los while de verdad que insertan datos
    --  3. Limpieza. Eliminar las #tablas.

    -- crear tablas temporales y cargarlas
    EXEC Importacion.sp_crear_y_cargar_confederations_csv      @Ruta = @RutaConfederationsCSV
    EXEC Importacion.sp_crear_y_cargar_teams_csv               @Ruta = @RutaTeamsCSV
    EXEC Importacion.sp_crear_y_cargar_squads_csv              @Ruta = @RutaSquadsCSV
    EXEC Importacion.sp_crear_y_cargar_players_csv             @Ruta = @RutaPlayersCSV
    EXEC Importacion.sp_crear_y_cargar_tournaments_csv         @Ruta = @RutaTournamentsCSV
    EXEC Importacion.sp_crear_y_cargar_group_standings_csv     @Ruta = @RutaGroupStandingsCSV
    EXEC Importacion.sp_crear_y_cargar_stadiums_csv            @Ruta = @RutaStadiumsCSV
    EXEC Importacion.sp_crear_y_cargar_matches_csv             @Ruta = @RutaMatchesCSV
    EXEC Importacion.sp_crear_y_cargar_player_appearances_csv  @Ruta = @RutaPlayerAppearancesCSV
    EXEC Importacion.sp_crear_y_cargar_referees_csv            @Ruta = @RutaRefereesCSV
    EXEC Importacion.sp_crear_y_cargar_referee_appearances_csv @Ruta = @RutaRefereeAppearancesCSV
    EXEC Importacion.sp_crear_y_cargar_substitutions_csv       @Ruta = @RutaSubstitutionsCSV
    EXEC Importacion.sp_crear_y_cargar_goals_csv               @Ruta = @RutaGoalsCSV
    EXEC Importacion.sp_crear_y_cargar_penalty_kicks_csv       @Ruta = @RutaPenaltyKicksCSV
    EXEC Importacion.sp_crear_y_cargar_bookings_csv            @Ruta = @RutaBookingsCSV
    EXEC Importacion.sp_crear_y_cargar_publicidad_json         @Ruta = @RutaPublicidadJSON

    EXEC Importacion.sp_bypass_mundiales_previos; -- Solo para hacer testeos más rápidos!

    -- ejecutar inserción de los datos
    EXEC Importacion.sp_upsert_confederaciones;
    if @MostrarDatos = 1 
        SELECT * FROM Administracion.Confederaciones

    EXEC Importacion.sp_upsert_paises;
    if @MostrarDatos = 1 
        SELECT TOP 5 * FROM Administracion.Paises
    UPDATE Administracion.Paises set nombre = 'Germany' WHERE nombre = 'West Germany';

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

    EXEC Importacion.sp_upsert_sedes;
    if @MostrarDatos = 1 
            SELECT TOP 5 * FROM Administracion.Sedes

    EXEC Importacion.sp_upsert_arbitros;
    if @MostrarDatos = 1
        SELECT TOP 5 * FROM Arbitraje.Arbitros;

    EXEC Importacion.sp_upsert_partidos;
    if @MostrarDatos = 1 BEGIN
        SELECT TOP 5 * FROM Partidos.Partidos ORDER BY mundial_id DESC;
        SELECT COUNT(*) AS 'Partidos 2022' FROM Partidos.Partidos WHERE mundial_id = 2022;
        END

    EXEC Importacion.sp_upsert_asignaciones_arbitros;
    if @MostrarDatos = 1
        SELECT TOP 5 * FROM Mundial.Habilitacion_Arbitro;
    if @MostrarDatos = 1
        SELECT TOP 5 * FROM Arbitraje.ArbitroAsignadoPartido;

    EXEC Importacion.sp_upsert_formaciones;
    if @MostrarDatos = 1 BEGIN
        SELECT * FROM Administracion.Paises WHERE codigo = 'CRO'
        -- Partidos del mundial 2022 en los que jugó messi (son 7)
        SELECT J.*, PPA.pais_id, PPB.pais_id FROM Partidos.JugadorPosicionInicial J 
        JOIN Partidos.Partidos P ON J.partido_id = P.id
        JOIN Mundial.Paises_Participes PPA ON PPA.seleccion_id = P.seleccion_A_id 
        JOIN Mundial.Paises_Participes PPB ON PPB.seleccion_id = P.seleccion_B_id 
        WHERE P.mundial_id = 2022 AND J.jugador_id = 5133

        SELECT TOP 50  JPI.comienza_jugando, J.nombre, J.apellido, J.pais_id, P.seleccion_A_ID as 'seleccion a', P.seleccion_B_ID as 'seleccion b'
            
            FROM Partidos.JugadorPosicionInicial JPI
            JOIN Partidos.Partidos P ON P.id = JPI.partido_id
            JOIN Equipos.IntegranteSeleccion J ON JPI.jugador_id  = J.id
            WHERE J.pais_id = 'ARG'
            ORDER BY mundial_id DESC;
        
        END

    EXEC Importacion.sp_upsert_cambios;
    if @MostrarDatos = 1 BEGIN
        SELECT TOP 10 * FROM Eventos.Cambios

        DECLARE @partidoID INT = (SELECT id FROM Partidos.Partidos WHERE mundial_id = 2022 and fase = 'FINAL');
        
        --- CAMBIOS DE JUGADORES EN LA FINAL DEL MUNDIAL 2022
        SELECT J.nombre, J.apellido, C.minuto, C.extra, C.tiempo, J.pais_id, 
            (CASE 
                WHEN C.jugador_entra_id is not null THEN 'ENTRO'
                WHEN C.jugador_sale_id  is not null THEN 'SALE'
             END) AS que_paso
        FROM Eventos.Cambios C
        JOIN Equipos.IntegranteSeleccion J ON J.id = C.jugador_entra_id OR J.id = C.jugador_sale_id
        JOIN Partidos.Partidos P ON P.id = C.partido_id
        WHERE P.id = @partidoID
        ORDER BY tiempo, extra, minuto
        
        SELECT J.nombre, J.apellido, J.pais_id
        FROM Partidos.fn_jugadores_en_cancha (@partidoID, 15, 15, 4 ) JEC
        JOIN Equipos.IntegranteSeleccion J ON J.id = JEC.jugador_id;
    END

    EXEC Importacion.sp_upsert_goles;
    if @MostrarDatos = 1 BEGIN
        SELECT TOP 10 * FROM Eventos.Goles
        -- DECLARE @partidoID INT = (SELECT id FROM Partidos.Partidos WHERE mundial_id = 2022 and fase = 'FINAL');
        
        --- GOLES DE LA FINAL
        SELECT J.nombre, J.apellido, G.minuto, G.extra, G.tiempo, J.pais_id, G.tipo
        FROM Eventos.Goles G
        JOIN Equipos.IntegranteSeleccion J ON J.id = G.jugador_autor_id
        JOIN Partidos.Partidos P ON P.id = G.partido_id
        WHERE P.id = @partidoID
        ORDER BY tiempo, extra, minuto

    END

    EXEC Importacion.sp_upsert_penales_de_tanda;
    if @MostrarDatos = 1 BEGIN
        SELECT TOP 10 * FROM Eventos.PenalesDeTanda
        -- DECLARE @partidoID INT = (SELECT id FROM Partidos.Partidos WHERE mundial_id = 2022 and fase = 'FINAL');
        
        --- PENALES DE LA FINAL
        SELECT J.nombre, J.apellido, J.pais_id, PDT.convirtio
            FROM Eventos.PenalesDeTanda PDT
            JOIN Equipos.IntegranteSeleccion J ON J.id = PDT.jugador_id
            JOIN Partidos.Partidos P ON P.id = PDT.partido_id
            WHERE P.id = @partidoID
    END

    --- ERRORES CONOCIDOS:
    --- hay una amonestacion del mundial de argentina que no se inserta porque se vinculo al jugador RicardoGiusti, que no jugo el 2022.
    --- hay una amonestacion de Luka Jović que no se aplica por que el partido del dataset es incorrecta (es el de serbia camerun en el dataset y en realidad es serbia suiza)
    --- hay una amonestacion de predrag rajkovic que no se aplica por que el partido del dataset es incorrecto
    EXEC Importacion.sp_upsert_amonestaciones;
    if @MostrarDatos = 1 BEGIN
        SELECT TOP 10 * FROM Eventos.Amonestaciones;
        SELECT TOP 10 * FROM Eventos.Amonestaciones WHERE motivo is not null;
        SELECT TOP 10 * FROM Eventos.Cambios WHERE motivo = 'EXPULSION';
    END

    EXEC Importacion.sp_upsert_anunciantes
    IF @MostrarDatos = 1 BEGIN
        SELECT * FROM Publicidad.Anunciantes
    END

    EXEC Importacion.sp_upsert_campañas
    IF @MostrarDatos = 1 BEGIN
        SELECT * FROM Publicidad.Campañas
    END

    EXEC Importacion.sp_upsert_piezas_de_contenido
    IF @MostrarDatos = 1 BEGIN
        SELECT * FROM Publicidad.PiezasDeContenido
    END
    
    -- Limpieza
    exec Importacion.sp_limpieza_tablas_temporales;

END
GO

-- exec Importacion.PoblarDB 
--         @RutaConfederationsCSV = 'C:\Soluciones-SQL\GestionDelMundial\Solucion\BBDD\Importacion\confederations.csv',
--         @RutaTeamsCSV = 'C:\Soluciones-SQL\GestionDelMundial\Solucion\BBDD\Importacion\teams.csv',
--         @RutaPlayersCSV = 'C:\Soluciones-SQL\GestionDelMundial\Solucion\BBDD\Importacion\players.csv',
--         @RutaSquadsCSV = 'C:\Soluciones-SQL\GestionDelMundial\Solucion\BBDD\Importacion\squads.csv',
--         @RutaTournamentsCSV = 'C:\Soluciones-SQL\GestionDelMundial\Solucion\BBDD\Importacion\tournaments.csv',
--         @RutaGroupStandingsCSV = 'C:\Soluciones-SQL\GestionDelMundial\Solucion\BBDD\Importacion\group_standings.csv',
--         @RutaStadiumsCSV = 'C:\Soluciones-SQL\GestionDelMundial\Solucion\BBDD\Importacion\stadiums.csv',
--         @RutaMatchesCSV = 'C:\Soluciones-SQL\GestionDelMundial\Solucion\BBDD\Importacion\matches.csv',
--         @RutaPlayerAppearancesCSV = 'C:\Soluciones-SQL\GestionDelMundial\Solucion\BBDD\Importacion\player_appearances.csv',
--         @RutaSubstitutionsCSV = 'C:\Soluciones-SQL\GestionDelMundial\Solucion\BBDD\Importacion\substitutions.csv',
--         @RutaGoalsCSV = 'C:\Soluciones-SQL\GestionDelMundial\Solucion\BBDD\Importacion\goals.csv',
--         @RutaPenaltyKicksCSV = 'C:\Soluciones-SQL\GestionDelMundial\Solucion\BBDD\Importacion\penalty_kicks.csv',
--         @RutaBookingsCSV = 'C:\Soluciones-SQL\GestionDelMundial\Solucion\BBDD\Importacion\bookings.csv',
--         @MostrarDatos = 1,
--         @UnicoMundial = 2022

-- SELECT * FROM Mundial.mundiales

/*SELECT * FROM Partidos.JugadorPosicionInicial WHERE partido_id = 1
SELECT * 
FROM Partidos.fn_jugadores_en_cancha(1, 15, 0, 2);*/