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
    ROWTERMINATOR = '0x0a',
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
        print CONCAT(@nombreJugador, @apellidoJugador)
    END
    
    SET @idJugadorActual = @idJugadorActual + 1;

END;
select top 10 * FROM Equipos.IntegranteSeleccion


DECLARE @inserciones    INT = @confederacionesInsertadas + @paisesInsertados + @jugadoresInsertados;
DECLARE @modificaciones INT = @confederacionesActualizadas + @paisesModificados + @jugadoresModificados;

SELECT 
    @confederacionesInsertadas   as 'Confederaciones Insertadas',
    @confederacionesActualizadas as 'Confederaciones Modificadas',
    @paisesInsertados            as 'Paises Insertados',
    @paisesModificados           as 'Paises Modificados', -- Te da al principio editado uno porque hay dos registros diferentes para Alemania.
    @jugadoresInsertados         as 'Jugadores Insertados',
    @jugadoresModificados        as 'Jugadores Modificados',
    @inserciones                 as 'Inserciones totales',
    @modificaciones              as 'Modificaciones totales';