USE GestionDelMundial;
GO 

CREATE OR ALTER PROCEDURE Importacion.sp_crear_y_cargar_confederations_csv 
    @Ruta VARCHAR(255)
AS
BEGIN 

    SET NOCOUNT ON

    IF OBJECT_ID('tempdb..##Confederations') IS NOT NULL DROP TABLE ##Confederations;

    CREATE TABLE ##Confederations (
        key_id INT PRIMARY KEY CLUSTERED,
        confederation_id CHAR(4),
        confederation_name VARCHAR(200),
        confederation_code VARCHAR(8),
        confederation_wikipedia_link VARCHAR(250)
    );

    DECLARE @importacion VARCHAR(4000);

    BEGIN TRY
        SET @importacion = '
        BULK INSERT ##Confederations
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

    ALTER TABLE ##Confederations DROP COLUMN confederation_wikipedia_link;

    DECLARE @cantidadRegistrosCrudos INT = (SELECT count(*) FROM ##Confederations);
    
    -- print 'Cargados en #Confederations de CSV: ' + CAST (@cantidadRegistrosCrudos AS VARCHAR(5));

END
GO


CREATE OR ALTER PROCEDURE Importacion.sp_crear_y_cargar_teams_csv 
    @Ruta VARCHAR(255)
AS
BEGIN 
    SET NOCOUNT ON

    IF OBJECT_ID('tempdb..##Teams') IS NOT NULL DROP TABLE ##Teams;

    CREATE TABLE ##Teams (
        key_id INT PRIMARY KEY CLUSTERED,
        team_id CHAR(4),
        team_name VARCHAR(200),
        team_code CHAR(3),
        mens_team BIT,
        womens_team BIT,
        federation_name VARCHAR(150),
        region_name VARCHAR(100), -- Esto es el continente, capaz después nos convenga insertarlo
        confederation_id CHAR(4),
        confederation_name VARCHAR(200),
        confederation_code VARCHAR(8),
        mens_team_wikipedia_link VARCHAR(250),
        womens_team_wikipedia_link VARCHAR(250),
        federation_wikipedia_link VARCHAR(250)
    );

    DECLARE @importacion VARCHAR(4000);

    BEGIN TRY
        SET @importacion = '
        BULK INSERT ##Teams
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

    ALTER TABLE ##Teams 
        DROP COLUMN mens_team, confederation_name, federation_name,
                    federation_wikipedia_link,
                    confederation_id,
                    womens_team_wikipedia_link,
                    mens_team_wikipedia_link;

    DECLARE @cantidadRegistrosCrudos INT = (SELECT count(*) FROM ##Teams);
    
    -- print 'Cargados en #Confederations de CSV: ' + CAST (@cantidadRegistrosCrudos AS VARCHAR(5));

END
GO


CREATE OR ALTER PROCEDURE Importacion.sp_crear_y_cargar_squads_csv 
    @Ruta VARCHAR(255)
AS
BEGIN 
    SET NOCOUNT ON

    IF OBJECT_ID('tempdb..##Squads') IS NOT NULL DROP TABLE ##Squads;


    CREATE TABLE ##Squads (
        key_id INT PRIMARY KEY CLUSTERED,
        tournament_id CHAR(7),
        tournament_name VARCHAR(100),
        team_id char(4),
        team_name VARCHAR(100),
        team_code CHAR(3),
        player_id CHAR(7),
        family_name VARCHAR(100),
        given_name VARCHAR(100),
        shirt_number INT,
        position_name varchar(100),
        position_code CHAR(2)
        
        -- ESTA TABLA LA VOY A USAR PARA SUMARLE EL PAIS A LOS JUGADORE
    );


    DECLARE @importacion VARCHAR(4000);

    BEGIN TRY
        SET @importacion = '
        BULK INSERT ##Squads
        FROM '''+ @Ruta + '''
        WITH (
            FORMAT = ''CSV'',
            FIELDQUOTE = ''"'',         -- Ignora las comas que estén dentro de estas comillas
            FIELDTERMINATOR = '','', 
            ROWTERMINATOR = ''\n'',
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

    UPDATE ##Squads SET tournament_id = REPLACE(tournament_id, 'WC-', '');

    DECLARE @cantidadRegistrosCrudos INT = (SELECT count(*) FROM ##Squads);

    -- print 'Cargados en #Confederations de CSV: ' + CAST (@cantidadRegistrosCrudos AS VARCHAR(5));

END
GO

    SET NOCOUNT ON

    IF OBJECT_ID('tempdb..##Squads') IS NULL 
        THROW 50001, 'PAra importar plyaers.csv es necesario importar Squads.csv.', 1;

    IF OBJECT_ID('tempdb..##Players') IS NOT NULL DROP TABLE ##Players;


    CREATE TABLE ##Players (
        key_id INT PRIMARY KEY CLUSTERED,
        player_id CHAR(7),
        family_name VARCHAR(100),
        given_name VARCHAR(100),
        birth_date VARCHAR(50), -- temporalmente varchar (algunos campos dicen not available)
        female BIT,
        goal_keeper BIT,
        defender BIT,
        midfielder BIT,
        forward BIT,
        count_torunaments INT,
        list_tournaments VARCHAR(200),
        player_wikipedia_link VARCHAR(300)
    );


    DECLARE @importacion VARCHAR(4000);

    BEGIN TRY
        SET @importacion = '
        BULK INSERT ##Players
        FROM '''+ @Ruta + '''
        WITH (
            FORMAT = ''CSV'',
            FIELDQUOTE = ''"'',         -- Ignora las comas que estén dentro de estas comillas
            FIELDTERMINATOR = '','', 
            ROWTERMINATOR = ''\n'',
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

    ALTER TABLE ##Players 
        DROP COLUMN goal_keeper, defender, midfielder,
            forward, count_torunaments, list_tournaments,
            player_wikipedia_link;


    DELETE FROM ##Players WHERE female = 1; -- Dejamos solo jugadores masculinos
    ALTER TABLE ##Players DROP COLUMN female;

    ALTER TABLE ##Players ADD CodigoPais CHAR(3);
    ALTER TABLE ##Players ADD map_id INT; -- REFERENCES Equipos.IntegranteSeleccion(id);
    CREATE NONCLUSTERED INDEX IX_Player_ID_MAP_ID ON ##Players (player_id) INCLUDE(map_id);

    UPDATE ##Players 
        SET birth_date = NULL 
        WHERE TRY_CAST(birth_date AS DATE) IS NULL;

    ALTER TABLE ##Players ALTER COLUMN birth_date DATE;

    -- Cargamos la columna "CodigoPais" en #Players.
    WITH jugador_pais as (
        SELECT DISTINCT
            player_id, team_code
        FROM ##Squads
    ) 
    UPDATE P
    SET P.CodigoPais = JP.team_code
    FROM ##Players P
    INNER JOIN jugador_pais JP ON P.player_id = JP.player_id;


    DECLARE @cantidadRegistrosCrudos INT = (SELECT count(*) FROM ##Players);
    
    -- print 'Cargados en #Confederations de CSV: ' + CAST (@cantidadRegistrosCrudos AS VARCHAR(5));

END
GO


/*****************************/
/*      Mundiales            */
/*****************************/
-- Hay un problema con los mundiales: no traen reglas en los datasets. Asique, se me ocurren un par de acciones:
-- 1. Cambiar los store procedures para poder sumar mundiales sin reglas
-- 2. Crear un dataset propio de reglas. (La consigna pone que hay que encontrrar el modo de meter todos lso datos que no esten en datasets).
-- Para esta Prueba de Concepto simplemente voy a hardcodear algunas reglas

CREATE OR ALTER PROCEDURE Importacion.sp_crear_y_cargar_tournaments_csv 
    @Ruta VARCHAR(255)
AS
BEGIN 
    SET NOCOUNT ON

    IF OBJECT_ID('tempdb..##Tournaments') IS NOT NULL DROP TABLE ##Tournaments;


    CREATE TABLE ##Tournaments (
        key_id INT PRIMARY KEY CLUSTERED,
        tournament_id CHAR(7),
        tournament_name VARCHAR(200),
        year INT,
        start_date VARCHAR(50),
        end_date  VARCHAR(50),
        host_country VARCHAR(100),
        winner VARCHAR(150),
        host_won BIT,
        count_teams INT,
        group_stage BIT,
        second_group_stage BIT,
        final_round BIT,
        round_of_16 BIT,
        quarter_finals BIT,
        semi_finals BIT,
        third_place_match BIT,
        final INT
    );


    DECLARE @importacion VARCHAR(4000);

    BEGIN TRY
        SET @importacion = '
        SET NOCOUNT ON
        BULK INSERT ##Tournaments
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

    ALTER TABLE ##Tournaments 
        DROP COLUMN host_country, winner,
            host_won, group_stage, second_group_stage,
            final_round, round_of_16, quarter_finals, 
            semi_finals, third_place_match, final;

    DELETE FROM ##Tournaments WHERE tournament_name LIKE  '%Women%';
    DELETE FROM ##Tournaments WHERE count_teams = 13;
    DELETE FROM ##Tournaments WHERE count_teams = 15;

    UPDATE ##Tournaments 
        SET end_date = NULL 
        WHERE TRY_CAST(end_date AS DATE) IS NULL;


    UPDATE ##Tournaments 
        SET start_date = NULL 
        WHERE TRY_CAST(start_date AS DATE) IS NULL;

    ALTER TABLE ##Tournaments ALTER COLUMN start_date DATE;
    ALTER TABLE ##Tournaments ALTER COLUMN end_date DATE;

    DECLARE @cantidadRegistrosCrudos INT = (SELECT count(*) FROM ##Players);
    
    -- print 'Cargados en #Confederations de CSV: ' + CAST (@cantidadRegistrosCrudos AS VARCHAR(5));

END
GO