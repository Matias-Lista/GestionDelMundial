use GestionDelMundial;
GO

-- Prueba de concepto de la improtación de datos. Es un boceto, probé como se manipulan los .csv de datahub.io/football/worldcup
-- Tiene rutas hardcodeadas, hay que convertir eso a Store Procedure/s. De momento no me imagino que se puedan importar cosas sueltas (por ejemplo,
-- solo los goles de un partido), sino que veo necesario importar todos los datasets juntos. Porque a veces utilizamos cosas como los ids internos del .csv

-- Habría que seguir viendo. Quizás se puede agrupar. Por ejemplo, que se puedan importar partidos y eventos solos. Sin el resto de datasets. Y por otro lado, 
-- Jugadores + paises + confederaciones.

IF OBJECT_ID('tempdb..#Players') IS NOT NULL DROP TABLE #Players;
IF OBJECT_ID('tempdb..#Confederations') IS NOT NULL DROP TABLE #Confederations;
IF OBJECT_ID('tempdb..#Teams') IS NOT NULL DROP TABLE #Teams;
IF OBJECT_ID('tempdb..#Squads') IS NOT NULL DROP TABLE #Squads;
GO 
SET NOCOUNT ON

CREATE TABLE #Confederations (
    key_id INT PRIMARY KEY CLUSTERED,
    confederation_id CHAR(4),
    confederation_name VARCHAR(200),
    confederation_code VARCHAR(8),
    confederation_wikipedia_link VARCHAR(250)
);

BULK INSERT #Confederations
FROM 'C:\Soluciones-SQL\GestionDelMundial\Solucion\BBDD\Importacion\confederations.csv'
WITH (
    FORMAT = 'CSV',
    FIELDQUOTE = '"',         -- Ignora las comas que estén dentro de estas comillas
    FIELDTERMINATOR = ',', 
    ROWTERMINATOR = '0x0a',
    FIRSTROW = 2,             -- Salta los encabezados
    CODEPAGE = '65001'        -- UTF-8
);

-- SELECT * FROM #Confederations


DECLARE @maxConfederacionID INT = (SELECT max(key_id) FROM #Confederations);

DECLARE @idConfederacionActual INT = 1;

DECLARE @confederacionesInsertadas INT = 0;
DECLARE @confederacionesActualizadas INT = 0;

WHILE (@idConfederacionActual <= @maxConfederacionID) BEGIN
    
    DECLARE @nombre VARCHAR(100);
    DECLARE @siglas VARCHAR(8);

    SELECT @nombre = confederation_name, @siglas = confederation_code
    FROM #Confederations
    WHERE key_id = @idConfederacionActual;

    DECLARE @idConfederacion INT = (SELECT id FROM Administracion.Confederaciones WHERE siglas = @siglas);

    if (@idConfederacion is null) BEGIN
        exec Administracion.sp_crear_confederacion @Nombre = @nombre, @Siglas = @siglas;
        SET @confederacionesInsertadas = @confederacionesInsertadas + 1;
    END ELSE BEGIN
        exec Administracion.sp_modificar_confederacion @ID = @idConfederacion, @Nombre = @nombre, @Siglas = @siglas;
        SET @confederacionesActualizadas = @confederacionesActualizadas + 1;
    END


    SET @idConfederacionActual = @idConfederacionActual + 1;
END;

-- SELECT * FROM Administracion.Confederaciones


----- IMPORT DE EQUIPOS 

CREATE TABLE #Teams (
    key_id INT PRIMARY KEY CLUSTERED,
    team_id CHAR(4),
    team_name VARCHAR(200),
    team_code CHAR(3),
    mens_team BIT,
    womens_team BIT,
    federation_name VARCHAR(150),
    region_name VARCHAR(100),
    confederation_id CHAR(4),
    confederation_name VARCHAR(200),
    confederation_code VARCHAR(8),
    mens_team_wikipedia_link VARCHAR(250),
    womens_team_wikipedia_link VARCHAR(250),
    federation_wikipedia_link VARCHAR(250)
);

BULK INSERT #Teams
FROM 'C:\Soluciones-SQL\GestionDelMundial\Solucion\BBDD\Importacion\teams.csv'
WITH (
    FORMAT = 'CSV',
    FIELDQUOTE = '"',         -- Ignora las comas que estén dentro de estas comillas
    FIELDTERMINATOR = ',', 
    ROWTERMINATOR = '0x0a',
    FIRSTROW = 2,             -- Salta los encabezados
    CODEPAGE = '65001'        -- UTF-8
);

-- SELECT * FROM #Teams


DECLARE @maxEquipoID INT = (SELECT max(key_id) FROM #Teams);

DECLARE @idEquipoActual INT = 1;
DECLARE @paisesInsertados INT = 0;
DECLARE @paisesModificados INT = 0;

WHILE (@idEquipoActual <= @maxEquipoID) BEGIN
    
    DECLARE @codigoPais CHAR(3);
    DECLARE @nombrePais VARCHAR(100);
    DECLARE @siglasConfederacion VARCHAR(8);

    
    SELECT @nombrePais = team_name, @siglasConfederacion = confederation_code, @codigoPais = team_code
        FROM #Teams
        WHERE key_id = @idEquipoActual;
    
    DECLARE @_idConfederacion INT = (SELECT id FROM Administracion.Confederaciones WHERE siglas = @siglasConfederacion);

    if (@_idConfederacion is null) BEGIN
        print 'ERROR CON ESTE EQUIPO. La confederacion no está cargada.';
    END

    IF EXISTS (SELECT 1 FROM Administracion.Paises WHERE codigo = @codigoPais) BEGIN
        exec Administracion.sp_modificar_pais @Codigo = @codigoPais, @Nombre = @nombrePais, @ConfederacionID = @_idConfederacion;
        SET @paisesModificados = @paisesModificados + 1;
    END ELSE BEGIN
        exec Administracion.sp_crear_pais @Codigo = @codigoPais, @Nombre = @nombrePais, @ConfederacionID = @_idConfederacion;
        SET @paisesInsertados = @paisesInsertados + 1;
    END;

    SET @idEquipoActual = @idEquipoActual + 1;
END;


print CONCAT('Confederaciones ACTUALIZADAS: ', @confederacionesActualizadas);
print CONCAT('Confederaciones insertadas: ', @confederacionesInsertadas);

-- SELECT * FROM Administracion.Paises

CREATE TABLE #Players (
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



BULK INSERT #Players
FROM 'C:\Soluciones-SQL\GestionDelMundial\Solucion\BBDD\Importacion\players.csv'
WITH (
    FORMAT = 'CSV',
    FIELDQUOTE = '"',         -- Ignora las comas que estén dentro de estas comillas
    FIELDTERMINATOR = ',', 
    ROWTERMINATOR = '0x0a',
    FIRSTROW = 2,             -- Salta los encabezados
    CODEPAGE = '65001'        -- UTF-8
);

DELETE FROM #Players WHERE female = 1; -- Dejamos solo jugadores masculinos
CREATE NONCLUSTERED INDEX IX_Players_Player_ID ON #Players (player_id); -- Utilizado para sumar los paises

ALTER TABLE #Players ADD CodigoPais CHAR(3);
UPDATE #Players 
SET birth_date = NULL 
WHERE TRY_CAST(birth_date AS DATE) IS NULL;

ALTER TABLE #Players ALTER COLUMN birth_date DATE;


CREATE TABLE #Squads (
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
    
    -- ESTA TABLA LA VOY A USAR PARA SUMARLE EL PAIS A LOS JUGADORES
);

BULK INSERT #Squads
FROM 'C:\Soluciones-SQL\GestionDelMundial\Solucion\BBDD\Importacion\squads.csv'
WITH (
    FORMAT = 'CSV',
    FIELDQUOTE = '"',         -- Ignora las comas que estén dentro de estas comillas
    FIELDTERMINATOR = ',', 
    ROWTERMINATOR = '\n',
    FIRSTROW = 2,             -- Salta los encabezados
    CODEPAGE = '65001'        -- UTF-8
);

-- Cargamos la columna "CodigoPais" en #Players.
WITH jugador_pais as (
    SELECT DISTINCT
        player_id, team_code
    FROM #Squads
) 
UPDATE P
SET P.CodigoPais = JP.team_code
FROM #Players P
INNER JOIN jugador_pais JP ON P.player_id = JP.player_id;

DECLARE @maxJugadorID INT = (SELECT max(key_id) FROM #Players);

DECLARE @idJugadorActual INT = 1;

DECLARE @jugadoresModificados INT = 0;
DECLARE @jugadoresInsertados INT = 0;

WHILE (@idJugadorActual < @maxJugadorID) BEGIN

    DECLARE @nombreJugador VARCHAR(100) = NULL;
    DECLARE @apellidoJugador VARCHAR(100) = NULL;
    DECLARE @f_nacimiento DATE = NULL;
    DECLARE @nacionalidad CHAR(3) = NULL;

    SELECT @nombreJugador = given_name, @apellidoJugador = family_name, @f_nacimiento = birth_date, @nacionalidad = CodigoPais
        FROM #Players
        WHERE key_id = @idJugadorActual;

    IF (@nombreJugador is null) BEGIN
        SET @idJugadorActual = @idJugadorActual + 1;
        CONTINUE; -- Con este if, salteamos los baches que quedan por eliminar campos con female=1
    END;

    DECLARE @idJugador INT;
    EXEC @idJugador = Equipos.fn_obtener_integrante_id @Nombre = @nombreJugador, @Apellido = @apellidoJugador, @FNacimiento = @f_nacimiento, @CodigoPais = @nacionalidad;

    if (@idJugador is null) BEGIN
        exec Equipos.sp_crear_integrante_seleccion @CodigoPais = @nacionalidad, @Nombre = @nombreJugador, @Apellido = @apellidoJugador, @FNacimiento = @f_nacimiento;
        SET @jugadoresInsertados = @jugadoresInsertados + 1;
    END
    ELSE BEGIN
        exec Equipos.sp_modificar_integrante_seleccion @ID = @idJugador, @CodigoPais = @nacionalidad, @Nombre = @nombreJugador, @Apellido = @apellidoJugador, @FNacimiento = @f_nacimiento;
        SET @jugadoresModificados = @jugadoresModificados + 1;
        -- print CONCAT(@nombreJugador, @apellidoJugador)
    END
    
    SET @idJugadorActual = @idJugadorActual + 1;

END;
select top 10 * FROM Equipos.IntegranteSeleccion

/*****************************/
/*      Mundiales            */
/*****************************/
-- Hay un problema con los mundiales: no traen reglas en los datasets. Asique, se me ocurren un par de acciones:
-- 1. Cambiar los store procedures para poder sumar mundiales sin reglas
-- 2. Crear un dataset propio de reglas. (La consigna pone que hay que encontrrar el modo de meter todos lso datos que no esten en datasets).
-- Para esta Prueba de Concepto simplemente voy a hardcodear algunas reglas


IF OBJECT_ID('tempdb..#Tournaments') IS NOT NULL DROP TABLE #Tournaments;
CREATE TABLE #Tournaments (
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
    final BIT
);

BULK INSERT #Tournaments
FROM 'C:\Soluciones-SQL\GestionDelMundial\Solucion\BBDD\Importacion\tournaments.csv'
WITH (
    FORMAT = 'CSV',
    FIELDQUOTE = '"',         -- Ignora las comas que estén dentro de estas comillas
    FIELDTERMINATOR = ',', 
    ROWTERMINATOR = '0x0a',
    FIRSTROW = 2,             -- Salta los encabezados
    CODEPAGE = '65001'        -- UTF-8
);

DELETE FROM #Tournaments WHERE tournament_name LIKE  '%Women%';
DELETE FROM #Tournaments WHERE count_teams = 13;
DELETE FROM #Tournaments WHERE count_teams = 15;

UPDATE #Tournaments 
SET end_date = NULL 
WHERE TRY_CAST(end_date AS DATE) IS NULL;


UPDATE #Tournaments 
SET start_date = NULL 
WHERE TRY_CAST(start_date AS DATE) IS NULL;

ALTER TABLE #Tournaments ALTER COLUMN start_date DATE;
ALTER TABLE #Tournaments ALTER COLUMN end_date DATE;

SELECT TOP 5 * FROM #Tournaments


DECLARE @maxMundialID INT = (SELECT max(key_id) FROM #Tournaments);

DECLARE @idMundialActual INT = 1;

DECLARE @mundialesInsertados INT = 0;
DECLARE @mundialesActualizados INT = 0;
DECLARE @mundialesOmitidos INT = 0;

WHILE (@idMundialActual <= @maxMundialID) BEGIN
    -- tournament_name LIKE  '%Women%'
    DECLARE @fechaInicio DATE = NULL;
    DECLARE @fechaFin DATE = NULL;
    DECLARE @cantidadDeEquipos INT = NULL;
    
    SELECT @fechaInicio = start_date, @fechaFin = end_date, @cantidadDeEquipos = count_teams
    FROM #Tournaments
    WHERE key_id = @idMundialActual;

    IF (@fechaInicio is null) BEGIN
        SET @idMundialActual = @idMundialActual + 1;
        CONTINUE; -- Con este if, salteamos los baches que quedan por eliminar campos
    END;

    DECLARE @idMundial INT = (SELECT año FROM Mundial.Mundiales WHERE año = YEAR(@fechaInicio));
    print @idMundial
    print @fechaInicio
    if (@idMundial is null) BEGIN
        exec Mundial.sp_crear_mundial @FInicio = @fechaInicio, @FFin = @fechaFin,  
	                                  @LimiteJugadoresConvocados = 23,  @LimiteStaffConvocados = 23,
                                      @ArbitroDeVarRequerido = 0,
                                      @CantidadDeEquipos = @cantidadDeEquipos;
        SET @mundialesInsertados = @mundialesInsertados + 1;
    END ELSE BEGIN
        SET @mundialesOmitidos = @mundialesOmitidos + 1; --- Los mundiales no se pueden editar.
    END

    SET @idMundialActual = @idMundialActual + 1;
END;


/******************************/
/* Países partícipes y grupos */
/******************************/



IF OBJECT_ID('tempdb..#GroupStandings') IS NOT NULL DROP TABLE #GroupStandings;
CREATE TABLE #GroupStandings (
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

BULK INSERT #GroupStandings
FROM 'C:\Soluciones-SQL\GestionDelMundial\Solucion\BBDD\Importacion\group_standings.csv'
WITH (
    FORMAT = 'CSV',
    FIELDQUOTE = '"',         -- Ignora las comas que estén dentro de estas comillas
    FIELDTERMINATOR = ',', 
    ROWTERMINATOR = '0x0a',
    FIRSTROW = 2,             -- Salta los encabezados
    CODEPAGE = '65001'        -- UTF-8
);

DELETE FROM #GroupStandings WHERE tournament_name LIKE  '%Women%';

SELECT * FROM #GroupStandings


DECLARE @maxSeleccionID INT = (SELECT max(key_id) FROM #GroupStandings);

DECLARE @idSeleccionActual INT = 1;

DECLARE @participacionesInsertadas   INT = 0;
DECLARE @participacionesActualizadas INT = 0;
DECLARE @participacionesOmitidas     INT = 0;

WHILE (@idSeleccionActual <= @maxSeleccionID) BEGIN
    --- NECESITAMOS: CODIGO PAIS - AÑO MUNDIAL - GRUPO. NADA MAS
    DECLARE @__codigoPais char(3) = NULL;
    DECLARE @groupName VARCHAR(15) = NULL;
    DECLARE @tournamentId CHAR(7) = NULL;
    DECLARE @__añoMundial INT = NULL;

    SELECT @__codigoPais = team_code, @groupName = group_name, @tournamentId = tournament_id
    FROM #GroupStandings
    WHERE key_id = @idSeleccionActual;
    
    SET @__añoMundial = REPLACE(@tournamentId, 'WC-', '');

    IF (@__añoMundial is null) BEGIN
        SET @idSeleccionActual = @idSeleccionActual + 1;
        CONTINUE;
    END;
    -- hay grupos que se llaman Group 1...
    BEGIN TRY
           
           DECLARE @GrupoFormateado CHAR(1) = right(@groupName, 1); -- agarra el ultimo char

           if @GrupoFormateado LIKE '[0-9]'
              SET @GrupoFormateado = CHAR(65 + CAST(@GrupoFormateado AS INT)); -- Si es un numero, le suma el valor a la letra A. 0 => A, 1 => B, 2 => C.

        exec Mundial.sp_incluir_pais @CodigoPais = @__codigoPais, @AñoMundial = @__añoMundial, @Grupo = @GrupoFormateado
        set @participacionesInsertadas = @participacionesInsertadas + 1;
    END TRY
    BEGIN CATCH
        print 'skip por error'
        set @participacionesOmitidas = @participacionesOmitidas + 1;
        print ERROR_MESSAGE();
        print @GrupoFormateado
        print @__añoMundial;
    END CATCH

    SET @idSeleccionActual = @idSeleccionActual + 1;
END;


/********************************/
/*      Convocados!             */
/*******************************/

SELECT * FROM Mundial.Paises_Participes

DECLARE @inserciones    INT = @confederacionesInsertadas + @paisesInsertados + @jugadoresInsertados + @mundialesInsertados;
DECLARE @modificaciones INT = @confederacionesActualizadas + @paisesModificados + @jugadoresModificados;

SELECT 
    @confederacionesInsertadas   as 'Confederaciones Insertadas',
    @confederacionesActualizadas as 'Confederaciones Modificadas',
    @paisesInsertados            as 'Paises Insertados',
    @paisesModificados           as 'Paises Modificados', -- Te da al principio editado uno porque hay dos registros diferentes para Alemania.
    @jugadoresInsertados         as 'Jugadores Insertados',
    @jugadoresModificados        as 'Jugadores Modificados',
    @mundialesInsertados         as 'Mundiales Insertados',
    @inserciones                 as 'Inserciones totales',
    @modificaciones              as 'Modificaciones totales';
