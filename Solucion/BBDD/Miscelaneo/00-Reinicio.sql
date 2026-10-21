/* BBDD/Miscelaneo/00-Reinicio.sql
 * Fecha: 9/10/2026
 * Lista, Matías Josué.
 * Descripción: Este script deja la base de datos en un estado inicial conocido, limpiando y creando de cero sus objetos, además
                de ejecutar sus testeos e importar los datos (según lo configurado en las variables del inicio.
 **/

 --- INSTRUCCIONES:
 ----* Activar SQLCMD (Consulta > Modo SQLCMD), para permitir la ejecución de scripts.
 ----* Reemplazar la ruta en la que se copió el repositorio de este proyecto en la primera instrucción después de estos comentarios.
 ----* Reemplazar las variables de configuración (EjecutarTesteos, ImportarDatos, ImportarUnUnicoMundial, etc.).

:setvar rutaAlRepositorio C:\Soluciones-SQL\GestionDelMundial

:setvar ImportarDatos   1
:setvar EjecutarTesteos 0

PRINT '[*] Limpiando ...'
:r $(rutaAlRepositorio)\Solucion\BBDD\Miscelaneo\01-Limpieza.sql

PRINT '[*] Creando tablas y SPs ...'
:r $(rutaAlRepositorio)\Solucion\BBDD\SCHEMA\02-TABLAS.sql
:r $(rutaAlRepositorio)\Solucion\BBDD\SPs\03-Administracion.sql
:r $(rutaAlRepositorio)\Solucion\BBDD\SPs\04-Mundial.sql
:r $(rutaAlRepositorio)\Solucion\BBDD\SPs\05-Equipos.sql
:r $(rutaAlRepositorio)\Solucion\BBDD\SPs\06-Partidos.sql
:r $(rutaAlRepositorio)\Solucion\BBDD\SPs\07-Eventos.sql
:r $(rutaAlRepositorio)\Solucion\BBDD\SPs\08-Arbitraje.sql
:r $(rutaAlRepositorio)\Solucion\BBDD\SPs\09-Publicidad.sql

IF ($(EjecutarTesteos) = 0) SET NOEXEC ON;
GO
    PRINT '[*] Testeando ...'
    :r $(rutaAlRepositorio)\Solucion\BBDD\Testeos\10-Testing-Administracion.sql
    :r $(rutaAlRepositorio)\Solucion\BBDD\Testeos\11-Testing-Mundial.sql
    :r $(rutaAlRepositorio)\Solucion\BBDD\Testeos\15-Testing-Arbitraje.sql

    PRINT '[*] Limpiando y reconstruyendo objetos ...'
    :r $(rutaAlRepositorio)\Solucion\BBDD\Miscelaneo\01-Limpieza.sql

    :r $(rutaAlRepositorio)\Solucion\BBDD\SCHEMA\02-TABLAS.sql
    :r $(rutaAlRepositorio)\Solucion\BBDD\SPs\03-Administracion.sql
    :r $(rutaAlRepositorio)\Solucion\BBDD\SPs\04-Mundial.sql
    :r $(rutaAlRepositorio)\Solucion\BBDD\SPs\05-Equipos.sql
    :r $(rutaAlRepositorio)\Solucion\BBDD\SPs\06-Partidos.sql
    :r $(rutaAlRepositorio)\Solucion\BBDD\SPs\07-Eventos.sql
    :r $(rutaAlRepositorio)\Solucion\BBDD\SPs\08-Arbitraje.sql
    :r $(rutaAlRepositorio)\Solucion\BBDD\SPs\09-Publicidad.sql

GO
SET NOEXEC OFF; -- Fin testeos
GO

PRINT '[*] Creando Objetos de Staging e Importación'

:r $(rutaAlRepositorio)\Solucion\BBDD\Importacion\Staging.sql
:r $(rutaAlRepositorio)\Solucion\BBDD\Importacion\Importacion.sql

IF ($(ImportarDatos) = 1)
BEGIN
    PRINT '[*] iMPORTANDO DATOS.';
    exec Importacion.PoblarDB 
            @RutaConfederationsCSV = 'C:\Soluciones-SQL\GestionDelMundial\Solucion\BBDD\Importacion\confederations.csv',
            @RutaTeamsCSV = 'C:\Soluciones-SQL\GestionDelMundial\Solucion\BBDD\Importacion\teams.csv',
            @RutaPlayersCSV = 'C:\Soluciones-SQL\GestionDelMundial\Solucion\BBDD\Importacion\players.csv',
            @RutaSquadsCSV = 'C:\Soluciones-SQL\GestionDelMundial\Solucion\BBDD\Importacion\squads.csv',
            @RutaTournamentsCSV = 'C:\Soluciones-SQL\GestionDelMundial\Solucion\BBDD\Importacion\tournaments.csv',
            @RutaGroupStandingsCSV = 'C:\Soluciones-SQL\GestionDelMundial\Solucion\BBDD\Importacion\group_standings.csv',
            @RutaStadiumsCSV = 'C:\Soluciones-SQL\GestionDelMundial\Solucion\BBDD\Importacion\stadiums.csv',
            @RutaMatchesCSV = 'C:\Soluciones-SQL\GestionDelMundial\Solucion\BBDD\Importacion\matches.csv',
            @RutaPlayerAppearancesCSV = 'C:\Soluciones-SQL\GestionDelMundial\Solucion\BBDD\Importacion\player_appearances.csv',
            @RutaRefereesCSV = 'C:\Soluciones-SQL\GestionDelMundial\Solucion\BBDD\Importacion\referees.csv',
            @RutaRefereeAppearancesCSV = 'C:\Soluciones-SQL\GestionDelMundial\Solucion\BBDD\Importacion\referee_appearances.csv',
            @RutaSubstitutionsCSV = 'C:\Soluciones-SQL\GestionDelMundial\Solucion\BBDD\Importacion\substitutions.csv',
            @RutaGoalsCSV = 'C:\Soluciones-SQL\GestionDelMundial\Solucion\BBDD\Importacion\goals.csv',
            @MostrarDatos = 1
END