USE GestionDelMundial;
GO 

CREATE OR ALTER PROCEDURE Importacion.sp_limpieza_tablas_temporales
AS 
BEGIN
    SET NOCOUNT ON
    
	IF (@@TRANCOUNT > 0)
		ROLLBACK TRANSACTION;

    IF OBJECT_ID('tempdb..##Confederations') IS NOT NULL DROP TABLE ##Confederations;
    IF OBJECT_ID('tempdb..##Teams') IS NOT NULL DROP TABLE ##Teams;
    IF OBJECT_ID('tempdb..##Squads') IS NOT NULL DROP TABLE ##Squads;
    IF OBJECT_ID('tempdb..##Players') IS NOT NULL DROP TABLE ##Players;
    IF OBJECT_ID('tempdb..##Tournaments') IS NOT NULL DROP TABLE ##Tournaments;
    IF OBJECT_ID('tempdb..##GroupStandings') IS NOT NULL DROP TABLE ##GroupStandings;
    IF OBJECT_ID('tempdb..##Stadiums') IS NOT NULL DROP TABLE ##Stadiums;
    IF OBJECT_ID('tempdb..##Matches') IS NOT NULL DROP TABLE ##Matches;
    IF OBJECT_ID('tempdb..##PlayerAppearances') IS NOT NULL DROP TABLE ##PlayerAppearances;
    IF OBJECT_ID('tempdb..##Referees') IS NOT NULL DROP TABLE ##Referees;
    IF OBJECT_ID('tempdb..##RefereeAppearances') IS NOT NULL DROP TABLE ##RefereeAppearances;
    IF OBJECT_ID('tempdb..##Substitutions') IS NOT NULL DROP TABLE ##Substitutions;
    IF OBJECT_ID('tempdb..##Goals') IS NOT NULL DROP TABLE ##Goals;
    IF OBJECT_ID('tempdb..##PenaltyKicks') IS NOT NULL DROP TABLE ##PenaltyKicks;
    IF OBJECT_ID('tempdb..##Bookings') IS NOT NULL DROP TABLE ##Bookings;
    IF OBJECT_ID('tempdb..##Anunciantes') IS NOT NULL DROP TABLE ##Anunciantes;
    IF OBJECT_ID('tempdb..##Campañas') IS NOT NULL DROP TABLE ##Campañas;
    IF OBJECT_ID('tempdb..##PiezasDeContenido') IS NOT NULL DROP TABLE ##PiezasDeContenido;

END
GO

EXEC Importacion.sp_limpieza_tablas_temporales;
go

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
        SET NOCOUNT ON
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
        SET NOCOUNT ON
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
        SET NOCOUNT ON
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

CREATE OR ALTER PROCEDURE Importacion.sp_crear_y_cargar_players_csv 
    @Ruta VARCHAR(255)
AS
BEGIN 

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
        SET NOCOUNT ON
        BULK INSERT ##Players
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

    UPDATE ##Tournaments SET tournament_id = REPLACE(tournament_id, 'WC-', '');

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


CREATE OR ALTER PROCEDURE Importacion.sp_crear_y_cargar_stadiums_csv 
    @Ruta VARCHAR(255)
AS
BEGIN 
    SET NOCOUNT ON

    IF OBJECT_ID('tempdb..##Stadiums') IS NOT NULL DROP TABLE ##Stadiums;

    CREATE TABLE ##Stadiums (
        key_id INT PRIMARY KEY CLUSTERED,
        stadium_id CHAR(5),
        stadium_name VARCHAR(100),
        city_name VARCHAR(100),
        country_name VARCHAR(100),
        stadium_capacity INT,
        stadium_wikipedia_link VARCHAR(200),
        city_wikipedia_link VARCHAR(200)
    );


    DECLARE @importacion VARCHAR(4000);

    BEGIN TRY
        SET @importacion = '
        SET NOCOUNT ON
        BULK INSERT ##Stadiums
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

    ALTER TABLE ##Stadiums 
        DROP COLUMN stadium_wikipedia_link,city_wikipedia_link;


    ALTER TABLE ##Stadiums ADD map_id INT;
    CREATE NONCLUSTERED INDEX IX_Stadium_ID_MAP_ID ON ##Stadiums (stadium_id) INCLUDE(map_id);

    DECLARE @cantidadRegistrosCrudos INT = (SELECT count(*) FROM ##Stadiums);
    
    -- print 'Cargados en #Confederations de CSV: ' + CAST (@cantidadRegistrosCrudos AS VARCHAR(5));

END
GO

/**************/
/*  PARTIDOS  */
/**************/
CREATE OR ALTER PROCEDURE Importacion.sp_crear_y_cargar_matches_csv 
    @Ruta VARCHAR(255)
AS
BEGIN 
    SET NOCOUNT ON

    IF OBJECT_ID('tempdb..##Matches') IS NOT NULL DROP TABLE ##Matches;

    CREATE TABLE ##Matches (
        key_id INT PRIMARY KEY CLUSTERED,
        tournament_id VARCHAR(10),
        tournament_name VARCHAR(100),
        match_id VARCHAR(9),
        match_name VARCHAR(100),
        stage_name VARCHAR(100),
        group_name VARCHAR(25),
        group_stage BIT,
        knockout_stage BIT,
        replayed BIT,
        replay BIT,
        match_date DATE,
        match_time CHAR(5),
        stadium_id CHAR(5),
        stadium_name VARCHAR(250),
        city_name VARCHAR(250),
        country_name VARCHAR(250),
        home_team_id CHAR(4),
        home_team_name VARCHAR(250),
        home_team_code CHAR(3),
        away_team_id CHAR(4),
        away_team_name VARCHAR(250),
        away_team_code CHAR(3),
        score VARCHAR(10),
        home_team_score INT,
        away_team_score INT,
        home_team_score_margin INT,
        away_team_score_margin INT,
        extra_time BIT,
        penalty_shootout BIT,
        score_penalties VARCHAR(5),
        home_team_score_penalties INT,
        away_team_score_penalties INT,
        result VARCHAR(250),
        home_team_win BIT,
        away_team_win BIT,
        draw BIT
    );


    DECLARE @importacion VARCHAR(4000);

    BEGIN TRY
        SET @importacion = '
        SET NOCOUNT ON
        BULK INSERT ##Matches
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

    DELETE FROM ##Matches WHERE tournament_name LIKE  '%Women%';

    UPDATE ##Matches SET tournament_id = REPLACE(tournament_id, 'WC-', '');

    ALTER TABLE ##Matches 
        DROP COLUMN match_name,
        group_stage,
        knockout_stage,
        replayed,
        replay,
        stadium_name,
        city_name,
        country_name,
        home_team_name,
        away_team_name,
        score,
        home_team_score,
        away_team_score,
        home_team_score_margin,
        away_team_score_margin,
        score_penalties,
        home_team_score_penalties,
        away_team_score_penalties,
        draw;


    ALTER TABLE ##Matches ADD map_id INT;
    CREATE NONCLUSTERED INDEX IX_Player_ID_MAP_ID ON ##Matches (match_id) INCLUDE(map_id);

    DECLARE @cantidadRegistrosCrudos INT = (SELECT count(*) FROM ##Matches);
    
    -- print 'Cargados en #Confederations de CSV: ' + CAST (@cantidadRegistrosCrudos AS VARCHAR(5));

END
GO


/*****************/
/*  FORMACIONES  */
/****************/
CREATE OR ALTER PROCEDURE Importacion.sp_crear_y_cargar_player_appearances_csv 
    @Ruta VARCHAR(255)
AS
BEGIN 
    SET NOCOUNT ON

    IF OBJECT_ID('tempdb..##PlayerAppearances') IS NOT NULL DROP TABLE ##PlayerAppearances;

    CREATE TABLE ##PlayerAppearances (
        key_id INT PRIMARY KEY CLUSTERED,
        tournament_id VARCHAR(MAX),
        tournament_name VARCHAR(MAX),
        match_id VARCHAR(MAX),
        match_name VARCHAR(MAX),
        match_date DATE,
        stage_name VARCHAR(MAX),
        group_name VARCHAR(MAX),
        team_id VARCHAR(MAX),
        team_name VARCHAR(MAX),
        team_code VARCHAR(MAX),
        home_team BIT,
        away_team BIT,
        player_id VARCHAR(MAX),
        family_name VARCHAR(MAX),
        given_name VARCHAR(MAX),
        shirt_number INT,
        position_name VARCHAR(MAX),
        position_code VARCHAR(MAX),
        starter BIT,
        substitute BIT
    );


    DECLARE @importacion VARCHAR(4000);

    BEGIN TRY
        SET @importacion = '
        SET NOCOUNT ON
        BULK INSERT ##PlayerAppearances
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

    DELETE FROM ##PlayerAppearances WHERE tournament_name LIKE  '%Women%';

    UPDATE ##PlayerAppearances SET tournament_id = REPLACE(tournament_id, 'WC-', '');

    ALTER TABLE ##PlayerAppearances 
        DROP COLUMN tournament_name, match_name,
        stage_name, team_name, home_team, away_team, family_name, given_name, position_name;

    DECLARE @cantidadRegistrosCrudos INT = (SELECT count(*) FROM ##PlayerAppearances);
    
    -- print 'Cargados en #Confederations de CSV: ' + CAST (@cantidadRegistrosCrudos AS VARCHAR(5));

END
GO


/**************/
/*  ARBITROS  */
/**************/
CREATE OR ALTER PROCEDURE Importacion.sp_crear_y_cargar_referees_csv 
    @Ruta VARCHAR(255)
AS
BEGIN 
    SET NOCOUNT ON

    IF OBJECT_ID('tempdb..##Referees') IS NOT NULL DROP TABLE ##Referees;

    CREATE TABLE ##Referees (
        key_id INT PRIMARY KEY CLUSTERED,
        referee_id CHAR(5),
        family_name VARCHAR(100),
        given_name VARCHAR(100),
        female BIT,
        country_name VARCHAR(100),
        confederation_id CHAR(4),
        confederation_name VARCHAR(100),
        confederation_code VARCHAR(20),
        referee_wikipedia_link VARCHAR(100)
    );


    DECLARE @importacion VARCHAR(4000);

    BEGIN TRY
        SET @importacion = '
        SET NOCOUNT ON
        BULK INSERT ##Referees
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

    ALTER TABLE ##Referees 
        DROP COLUMN referee_wikipedia_link, 
        confederation_id, confederation_name;


    ALTER TABLE ##Referees ADD map_id INT;
    CREATE NONCLUSTERED INDEX IX_Referee_ID_MAP_ID ON ##Referees (referee_id) INCLUDE(map_id);

    DECLARE @cantidadRegistrosCrudos INT = (SELECT count(*) FROM ##Referees);
    
    -- print 'Cargados en #Confederations de CSV: ' + CAST (@cantidadRegistrosCrudos AS VARCHAR(5));

END
GO

/****************************/
/*    RefereeAppearances    */
/****************************/
CREATE OR ALTER PROCEDURE Importacion.sp_crear_y_cargar_referee_appearances_csv 
    @Ruta VARCHAR(255)
AS
BEGIN 
    SET NOCOUNT ON

    IF OBJECT_ID('tempdb..##RefereeAppearances') IS NOT NULL DROP TABLE ##RefereeAppearances;

    CREATE TABLE ##RefereeAppearances (
        key_id INT PRIMARY KEY CLUSTERED,
        tournament_id CHAR(7),
        tournament_name VARCHAR(100),
        match_id VARCHAR(9),
        match_name VARCHAR(100),
        match_date DATE,
        stage_name VARCHAR(100),
        group_name VARCHAR(25),
        referee_id CHAR(5),
        family_name VARCHAR(100),
        given_name VARCHAR(100),
        country_name VARCHAR(100),
        confederation_id CHAR(4),
        confederation_name VARCHAR(100),
        confederation_code VARCHAR(20),
    );


    DECLARE @importacion VARCHAR(4000);

    BEGIN TRY
        SET @importacion = '
        SET NOCOUNT ON
        BULK INSERT ##RefereeAppearances
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

    ALTER TABLE ##RefereeAppearances 
        DROP COLUMN confederation_code, 
        confederation_id, confederation_name, country_name, 
        given_name, family_name, match_name,
        match_date, stage_name, group_name, tournament_name;

    UPDATE ##RefereeAppearances SET tournament_id = REPLACE(tournament_id, 'WC-', '');

    DECLARE @cantidadRegistrosCrudos INT = (SELECT count(*) FROM ##RefereeAppearances);
    
    -- print 'Cargados en #Confederations de CSV: ' + CAST (@cantidadRegistrosCrudos AS VARCHAR(5));

END
GO


/****************************/
/*       SUBSTITUTIONS      */
/****************************/
CREATE OR ALTER PROCEDURE Importacion.sp_crear_y_cargar_substitutions_csv 
    @Ruta VARCHAR(255)
AS
BEGIN 
    SET NOCOUNT ON

    IF OBJECT_ID('tempdb..##Substitutions') IS NOT NULL DROP TABLE ##Substitutions;

    CREATE TABLE ##Substitutions (
        key_id INT PRIMARY KEY CLUSTERED,
        substitution_id VARCHAR(20),
        tournament_id CHAR(7),
        tournament_name VARCHAR(100),
        match_id VARCHAR(9),
        match_name VARCHAR(100),
        match_date DATE,
        stage_name VARCHAR(100),
        group_name VARCHAR(25),
        team_id VARCHAR(MAX),
        team_name VARCHAR(MAX),
        team_code VARCHAR(MAX),
        home_team BIT,
        away_team BIT,
        player_id VARCHAR(MAX),
        family_name VARCHAR(MAX),
        given_name VARCHAR(MAX),
        shirt_number INT,
        minute_label VARCHAR(10),
        minute_regulation INT,
        minute_stoppage INT,
        match_period VARCHAR(100),
        going_off BIT,
        coming_on BIT
    );


    DECLARE @importacion VARCHAR(4000);

    BEGIN TRY
        SET @importacion = '
        SET NOCOUNT ON
        BULK INSERT ##Substitutions
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

    ALTER TABLE ##Substitutions 
        DROP COLUMN match_name, match_date, stage_name, group_name, team_name, 
        home_team, away_team, family_name, given_name, shirt_number, minute_label;

    DELETE FROM ##Substitutions WHERE tournament_name LIKE  '%Women%';
    UPDATE ##Substitutions SET tournament_id = REPLACE(tournament_id, 'WC-', '');
    
    ALTER TABLE ##Substitutions 
        DROP COLUMN tournament_name;        

    DECLARE @cantidadRegistrosCrudos INT = (SELECT count(*) FROM ##Substitutions);
    
    -- print 'Cargados en #Confederations de CSV: ' + CAST (@cantidadRegistrosCrudos AS VARCHAR(5));

END
GO

/****************************/
/*       GOALS      */
/****************************/
CREATE OR ALTER PROCEDURE Importacion.sp_crear_y_cargar_goals_csv 
    @Ruta VARCHAR(255)
AS
BEGIN 
    SET NOCOUNT ON

    IF OBJECT_ID('tempdb..##Goals') IS NOT NULL DROP TABLE ##Goals;

    CREATE TABLE ##Goals (
        key_id INT PRIMARY KEY CLUSTERED,
        goal_id CHAR(6),
        tournament_id CHAR(7),
        tournament_name VARCHAR(100),
        match_id VARCHAR(9),
        match_name VARCHAR(100),
        match_date DATE,
        stage_name VARCHAR(100),
        group_name VARCHAR(25),
        team_id VARCHAR(MAX),
        team_name VARCHAR(MAX),
        team_code VARCHAR(MAX),
        home_team BIT,
        away_team BIT,
        player_id VARCHAR(MAX),
        family_name VARCHAR(MAX),
        given_name VARCHAR(MAX),
        shirt_number INT,
        player_team_id CHAR(4),
        player_team_name VARCHAR(MAX),
        player_team_code CHAR(3),
        minute_label VARCHAR(10),
        minute_regulation INT,
        minute_stoppage INT,
        match_period VARCHAR(100),
        own_goal BIT,
        penalty BIT

    );

    DECLARE @importacion VARCHAR(4000);

    BEGIN TRY
        SET @importacion = '
        SET NOCOUNT ON
        BULK INSERT ##Goals
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

    ALTER TABLE ##Goals 
        DROP COLUMN match_name, match_date, stage_name, group_name, team_name, 
        home_team, away_team, family_name, given_name, shirt_number, minute_label;

    DELETE FROM ##Goals WHERE tournament_name LIKE  '%Women%';
    UPDATE ##Goals SET tournament_id = REPLACE(tournament_id, 'WC-', '');
    
    ALTER TABLE ##Goals 
        DROP COLUMN tournament_name;        

    DECLARE @cantidadRegistrosCrudos INT = (SELECT count(*) FROM ##Goals);
    
    -- print 'Cargados en #Confederations de CSV: ' + CAST (@cantidadRegistrosCrudos AS VARCHAR(5));

END
GO

/****************************/
/*       PenaltyKicks      */
/****************************/
CREATE OR ALTER PROCEDURE Importacion.sp_crear_y_cargar_penalty_kicks_csv 
    @Ruta VARCHAR(255)
AS
BEGIN 
    SET NOCOUNT ON

    IF OBJECT_ID('tempdb..##PenaltyKicks') IS NOT NULL DROP TABLE ##PenaltyKicks;

    CREATE TABLE ##PenaltyKicks (
        key_id INT PRIMARY KEY CLUSTERED,
        penalty_kick_id CHAR(6),
        tournament_id CHAR(7),
        tournament_name VARCHAR(100),
        match_id VARCHAR(9),
        match_name VARCHAR(100),
        match_date DATE,
        stage_name VARCHAR(100),
        group_name VARCHAR(25),
        team_id VARCHAR(MAX),
        team_name VARCHAR(MAX),
        team_code VARCHAR(MAX),
        home_team BIT,
        away_team BIT,
        player_id VARCHAR(MAX),
        family_name VARCHAR(MAX),
        given_name VARCHAR(MAX),
        shirt_number INT,
        converted BIT
    );

    DECLARE @importacion VARCHAR(4000);

    BEGIN TRY
        SET @importacion = '
        SET NOCOUNT ON
        BULK INSERT ##PenaltyKicks
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

    ALTER TABLE ##PenaltyKicks 
        DROP COLUMN match_name, match_date, stage_name, group_name, team_name, 
        home_team, away_team, family_name, given_name, shirt_number;

    DELETE FROM ##PenaltyKicks WHERE tournament_name LIKE  '%Women%';
    UPDATE ##PenaltyKicks SET tournament_id = REPLACE(tournament_id, 'WC-', '');
    
    ALTER TABLE ##PenaltyKicks 
        DROP COLUMN tournament_name;        

    DECLARE @cantidadRegistrosCrudos INT = (SELECT count(*) FROM ##PenaltyKicks);
    
    -- print 'Cargados en #Confederations de CSV: ' + CAST (@cantidadRegistrosCrudos AS VARCHAR(5));

END
GO

/****************************/
/*       BOOKINGS      */
/****************************/
CREATE OR ALTER PROCEDURE Importacion.sp_crear_y_cargar_bookings_csv 
    @Ruta VARCHAR(255)
AS
BEGIN 
    SET NOCOUNT ON

    IF OBJECT_ID('tempdb..##Bookings') IS NOT NULL DROP TABLE ##Bookings;

    CREATE TABLE ##Bookings (
        key_id INT PRIMARY KEY CLUSTERED,
        booking_id CHAR(6),
        tournament_id CHAR(7),
        tournament_name VARCHAR(100),
        match_id VARCHAR(9),
        match_name VARCHAR(100),
        match_date DATE,
        stage_name VARCHAR(100),
        group_name VARCHAR(25),
        team_id VARCHAR(MAX),
        team_name VARCHAR(MAX),
        team_code VARCHAR(MAX),
        home_team BIT,
        away_team BIT,
        player_id VARCHAR(MAX),
        family_name VARCHAR(MAX),
        given_name VARCHAR(MAX),
        shirt_number INT,
        minute_label VARCHAR(10),
        minute_regulation INT,
        minute_stoppage INT,
        match_period VARCHAR(100),
        yellow_card BIT,
        red_card BIT,
        second_yellow_card BIT,
        sending_off BIT
    );

    DECLARE @importacion VARCHAR(4000);

    BEGIN TRY
        SET @importacion = '
        SET NOCOUNT ON
        BULK INSERT ##Bookings
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

    ALTER TABLE ##Bookings 
        DROP COLUMN match_name, match_date, stage_name, group_name, team_name, 
        home_team, away_team, family_name, given_name, shirt_number;

    DELETE FROM ##Bookings WHERE tournament_name LIKE  '%Women%';
    UPDATE ##Bookings SET tournament_id = REPLACE(tournament_id, 'WC-', '');
    
    ALTER TABLE ##Bookings 
        DROP COLUMN tournament_name;        

    DECLARE @cantidadRegistrosCrudos INT = (SELECT count(*) FROM ##Bookings);
    
    -- print 'Cargados en #Confederations de CSV: ' + CAST (@cantidadRegistrosCrudos AS VARCHAR(5));

END
GO

/****************************/
/*        PUBLICIDAD        */
/****************************/
CREATE OR ALTER PROCEDURE Importacion.sp_crear_y_cargar_publicidad_json 
    @Ruta VARCHAR(255)
AS
BEGIN 
    SET NOCOUNT ON

    IF OBJECT_ID('tempdb..##Anunciantes') IS NOT NULL DROP TABLE ##Anunciantes;
    IF OBJECT_ID('tempdb..##Campañas') IS NOT NULL DROP TABLE ##Campañas;
    IF OBJECT_ID('tempdb..##PiezasDeContenido') IS NOT NULL DROP TABLE ##PiezasDeContenido;

    CREATE TABLE ##Anunciantes (
        id INT IDENTITY(1,1) PRIMARY KEY,
        anunciante NVARCHAR(300) UNIQUE,
        map_id INT
    );

    CREATE TABLE ##Campañas (
        id INT IDENTITY(1,1) PRIMARY KEY,
        anunciante_id INT,
        nombre NVARCHAR(200),
        descripcion NVARCHAR(MAX),
        horario_minimo SMALLINT NULL,
        horario_maximo SMALLINT NULL,
        anio_mundial INT,
        map_id INT,
        CONSTRAINT UQ_Staging_Un_Nombre_Por_Mundial UNIQUE (anio_mundial, nombre)
    );

    CREATE TABLE ##PiezasDeContenido (
        id INT IDENTITY(1,1) PRIMARY KEY,
        campania_id INT,
        nombre NVARCHAR(200),
        descripcion NVARCHAR(MAX),
        paises_de_interes NVARCHAR(MAX),
        map_id INT
    );

    DECLARE @importacion NVARCHAR(MAX);

    BEGIN TRY
        SET @importacion = N'
        DECLARE @json NVARCHAR(MAX);

        SELECT @json = CONVERT(VARCHAR(MAX), BulkColumn)
        FROM OPENROWSET(
            BULK ''' + @Ruta + ''',
            SINGLE_BLOB,
            CODEPAGE = ''65001''
        ) AS ImportacionJson;

        CREATE TABLE #AnunciantesRaw (
            id INT IDENTITY(1,1),
            anunciante NVARCHAR(300),
            json_anunciante NVARCHAR(MAX)
        );

        INSERT INTO #AnunciantesRaw (anunciante, json_anunciante)
        SELECT [key], [value]
        FROM OPENJSON(@json)
        WHERE [type] = 5; -- Filtra solo objetos JSON

        INSERT INTO ##Anunciantes (anunciante)
        SELECT anunciante FROM #AnunciantesRaw;

        CREATE TABLE #CampaniasRaw (
            id INT IDENTITY(1,1),
            anunciante_id INT,
            nombre NVARCHAR(200),
            descripcion NVARCHAR(MAX),
            horario_minimo SMALLINT,
            horario_maximo SMALLINT,
            anio_mundial INT,
            piezas_raw NVARCHAR(MAX)
        );

        INSERT INTO #CampaniasRaw (anunciante_id, nombre, descripcion, horario_minimo, horario_maximo, anio_mundial, piezas_raw)
        SELECT 
            ar.id,
            c.nombre,
            c.descripcion,
            c.horario_minimo,
            c.horario_maximo,
            c.anio_mundial,
            c.piezas_raw
        FROM #AnunciantesRaw ar
        CROSS APPLY OPENJSON(ar.json_anunciante, ''$."campanias"'') WITH (
            nombre          NVARCHAR(200)  ''$.nombre'',
            descripcion     NVARCHAR(MAX)  ''$.descripcion'',
            horario_minimo  SMALLINT       ''$.horario_minimo'',
            horario_maximo  SMALLINT       ''$.horario_maximo'',
            anio_mundial    INT            ''$."año_mundial"'',
            piezas_raw      NVARCHAR(MAX)  ''$.piezas_de_contenido'' AS JSON
        ) AS c;

        INSERT INTO ##Campañas (anunciante_id, nombre, descripcion, horario_minimo, horario_maximo, anio_mundial)
        SELECT anunciante_id, nombre, descripcion, horario_minimo, horario_maximo, anio_mundial
        FROM #CampaniasRaw;

        INSERT INTO ##PiezasDeContenido (campania_id, nombre, descripcion, paises_de_interes)
        SELECT 
            cr.id,
            p.nombre,
            p.descripcion,
            STRING_AGG(pais.value, '','') AS paises_de_interes
        FROM #CampaniasRaw cr
        CROSS APPLY OPENJSON(cr.piezas_raw) WITH (
            nombre      NVARCHAR(200)  ''$.nombre'',
            descripcion NVARCHAR(MAX)  ''$.descripcion'',
            paises_raw  NVARCHAR(MAX)  ''$.paises_de_interes'' AS JSON
        ) AS p
        OUTER APPLY OPENJSON(p.paises_raw) AS pais
        GROUP BY cr.id, p.nombre, p.descripcion;
        ';

        EXEC sp_executesql @importacion;
    END TRY
    BEGIN CATCH
        DECLARE @ErrorBulk VARCHAR(4000) = ERROR_MESSAGE();
        THROW 50340, @ErrorBulk, 1;
        RETURN;
    END CATCH;
    
END
GO
