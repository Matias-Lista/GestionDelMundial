/* BBDD/Importacion/Importacion-Arbitros.sql
 * Fecha: 12/10/2026
 * Integrantes: Lista, Matías Josué. Maldonado Medrano, Milagros.
 * Descripción: Importa los árbitros desde referees.csv (github.com/jfjelstul/worldcup).
 *              Hace upsert con los SP de Arbitraje y permite la importación parcial de los registros válidos.
 *              Requiere que los países ya estén cargados (correr antes Importacion.sql).
 **/

USE GestionDelMundial;
GO

IF OBJECT_ID('tempdb..#Referees') IS NOT NULL DROP TABLE #Referees;
GO
SET NOCOUNT ON


-- Las temporales usan la collation de tempdb (no es UTF-8): sin COLLATE DATABASE_DEFAULT
-- se pierden letras como ğ, ı, ě, ľ (Doğan -> Dogan) y fn_obtener_arbitro_id no encuentra al árbitro.
CREATE TABLE #Referees (
    key_id INT PRIMARY KEY CLUSTERED,
    referee_id VARCHAR(10) COLLATE DATABASE_DEFAULT,
    family_name VARCHAR(100) COLLATE DATABASE_DEFAULT,
    given_name VARCHAR(100) COLLATE DATABASE_DEFAULT,
    female BIT,
    country_name VARCHAR(100) COLLATE DATABASE_DEFAULT,
    confederation_id VARCHAR(10) COLLATE DATABASE_DEFAULT,
    confederation_name VARCHAR(200) COLLATE DATABASE_DEFAULT,
    confederation_code VARCHAR(8) COLLATE DATABASE_DEFAULT,
    referee_wikipedia_link VARCHAR(300) COLLATE DATABASE_DEFAULT
);

BULK INSERT #Referees
FROM 'C:\Soluciones-SQL\GestionDelMundial\Solucion\BBDD\Importacion\referees.csv'
WITH (
    FORMAT = 'CSV',
    FIELDQUOTE = '"',         -- Ignora las comas que estén dentro de estas comillas
    FIELDTERMINATOR = ',', 
    ROWTERMINATOR = '0x0a',
    FIRSTROW = 2,             -- Salta los encabezados
    CODEPAGE = '65001'        -- UTF-8
);

DELETE FROM #Referees WHERE female = 1; -- Dejamos solo árbitros del mundial masculino

-- SELECT * FROM #Referees


DECLARE @maxArbitroID INT = (SELECT max(key_id) FROM #Referees);

DECLARE @idArbitroActual INT = 1;

DECLARE @arbitrosInsertados INT = 0;
DECLARE @arbitrosModificados INT = 0;
DECLARE @arbitrosOmitidos INT = 0;

BEGIN TRAN
WHILE (@idArbitroActual <= @maxArbitroID) BEGIN

    DECLARE @nombreArbitro VARCHAR(100) = NULL;
    DECLARE @apellidoArbitro VARCHAR(100) = NULL;
    DECLARE @nombrePais VARCHAR(100) = NULL;
    DECLARE @codigoPais CHAR(3) = NULL;
    DECLARE @idArbitro INT = NULL;

    SELECT @nombreArbitro = given_name, @apellidoArbitro = family_name, @nombrePais = country_name
        FROM #Referees
        WHERE key_id = @idArbitroActual;

    IF (@apellidoArbitro is null) BEGIN
        SET @idArbitroActual = @idArbitroActual + 1;
        CONTINUE; -- Salteamos los huecos que quedan por eliminar las filas con female = 1
    END;

    -- El CSV trae el nombre del país, buscamos su código. Si no está cargado queda en NULL
    -- y sp_crear_arbitro lo rechaza con THROW ('El país no existe').
    SELECT @codigoPais = codigo FROM Administracion.Paises WHERE nombre = @nombrePais;

    BEGIN TRY
        SET @idArbitro = Arbitraje.fn_obtener_arbitro_id(@nombreArbitro, @apellidoArbitro, @codigoPais);

        if (@idArbitro is null) BEGIN
            exec Arbitraje.sp_crear_arbitro @CodigoPais = @codigoPais, @Nombre = @nombreArbitro, @Apellido = @apellidoArbitro;
            SET @arbitrosInsertados = @arbitrosInsertados + 1;
        END
        ELSE BEGIN
            exec Arbitraje.sp_modificar_arbitro @ID = @idArbitro, @CodigoPais = @codigoPais, @Nombre = @nombreArbitro, @Apellido = @apellidoArbitro;
            SET @arbitrosModificados = @arbitrosModificados + 1;
        END
    END TRY
    BEGIN CATCH
        -- Si el error dejó la transacción inutilizable, se deshace todo y se corta la importación.
        IF (XACT_STATE() = -1) BEGIN
            ROLLBACK TRAN;
            THROW;
        END

        print CONCAT('skip por error: ', @nombreArbitro, ' ', @apellidoArbitro, ' (', @nombrePais, ') -> ', ERROR_MESSAGE());
        SET @arbitrosOmitidos = @arbitrosOmitidos + 1;
    END CATCH

    SET @idArbitroActual = @idArbitroActual + 1;
END;
COMMIT TRAN

-- SELECT * FROM Arbitraje.Arbitros

SELECT 
    @arbitrosInsertados  as 'Arbitros Insertados',
    @arbitrosModificados as 'Arbitros Modificados',
    @arbitrosOmitidos    as 'Arbitros Omitidos';