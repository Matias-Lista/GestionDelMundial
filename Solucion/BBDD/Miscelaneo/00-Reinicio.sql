-- Acá podemos usar SQLCMD para ejecutar todos los scripts en orden con un solo archivo (limpieza => tablas => cada archivo de sp => Importacion)

-- Reemplazar esta variable por la ruta a la que se copió el repositorio.

-- Tienen que ser rutas sin espacios, hay que ponerlo sin comillas. 
-- También hay que entrar a Consulta > Modo SQLCMD. Se tendría que poenr gris las lineas que empiezan con ':' para mostrar que está activo

:setvar rutaAlRepositorio C:\Soluciones-SQL\GestionDelMundial

PRINT '[*] Limpiando ...'
:r $(rutaAlRepositorio)\Solucion\BBDD\Miscelaneo\01-Limpieza.sql

PRINT '[*] Creando tablas y SPs ...'
:r $(rutaAlRepositorio)\Solucion\BBDD\SCHEMA\02-TABLAS.sql
:r $(rutaAlRepositorio)\Solucion\BBDD\SPs\03-Administracion.sql
:r $(rutaAlRepositorio)\Solucion\BBDD\SPs\04-Mundial.sql
:r $(rutaAlRepositorio)\Solucion\BBDD\SPs\05-Equipos.sql
:r $(rutaAlRepositorio)\Solucion\BBDD\SPs\06-Partidos.sql
-- :r $(rutaAlRepositorio)\Solucion\BBDD\SPs\07-Eventos.sql
:r $(rutaAlRepositorio)\Solucion\BBDD\SPs\08-Arbitraje.sql
:r $(rutaAlRepositorio)\Solucion\BBDD\SPs\09-Publicidad.sql

PRINT '[*] Testeando ...'
:r $(rutaAlRepositorio)\Solucion\BBDD\Testeos\10-Testing-Administracion.sql
:r $(rutaAlRepositorio)\Solucion\BBDD\Testeos\11-Testing-Mundial.sql
:r $(rutaAlRepositorio)\Solucion\BBDD\Testeos\15-Testing-Arbitraje.sql
GO

PRINT '[*] Limpiando y reconstruyendo objetos ...'
:r $(rutaAlRepositorio)\Solucion\BBDD\Miscelaneo\01-Limpieza.sql

:r $(rutaAlRepositorio)\Solucion\BBDD\SCHEMA\02-TABLAS.sql
:r $(rutaAlRepositorio)\Solucion\BBDD\SPs\03-Administracion.sql
:r $(rutaAlRepositorio)\Solucion\BBDD\SPs\04-Mundial.sql
:r $(rutaAlRepositorio)\Solucion\BBDD\SPs\05-Equipos.sql
:r $(rutaAlRepositorio)\Solucion\BBDD\SPs\06-Partidos.sql
-- :r $(rutaAlRepositorio)\Solucion\BBDD\SPs\07-Eventos.sql
:r $(rutaAlRepositorio)\Solucion\BBDD\SPs\08-Arbitraje.sql
:r $(rutaAlRepositorio)\Solucion\BBDD\SPs\09-Publicidad.sql
-- :r $(rutaAlRepositorio)\Solucion\BBDD\SPs\100-Arbitraje-Logica.sql

PRINT '[*] Creando Objetos de Staging e Importación'

:r $(rutaAlRepositorio)\Solucion\BBDD\Importacion\Staging.sql
:r $(rutaAlRepositorio)\Solucion\BBDD\Importacion\Importacion.sql

/*
PRINT '[*] iMPORTANDO DATOS.'
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
        @MostrarDatos = 1*/

