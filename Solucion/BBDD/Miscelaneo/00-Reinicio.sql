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

-- :setvar rutaAlRepositorio C:\gits\GestionDelMundial
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
            @RutaConfederationsCSV = '$(rutaAlRepositorio)\Solucion\BBDD\Importacion\confederations.csv',
            @RutaTeamsCSV = '$(rutaAlRepositorio)\Solucion\BBDD\Importacion\teams.csv',
            @RutaPlayersCSV = '$(rutaAlRepositorio)\Solucion\BBDD\Importacion\players.csv',
            @RutaSquadsCSV = '$(rutaAlRepositorio)\Solucion\BBDD\Importacion\squads.csv',
            @RutaTournamentsCSV = '$(rutaAlRepositorio)\Solucion\BBDD\Importacion\tournaments.csv',
            @RutaGroupStandingsCSV = '$(rutaAlRepositorio)\Solucion\BBDD\Importacion\group_standings.csv',
            @RutaStadiumsCSV = '$(rutaAlRepositorio)\Solucion\BBDD\Importacion\stadiums.csv',
            @RutaMatchesCSV = '$(rutaAlRepositorio)\Solucion\BBDD\Importacion\matches.csv',
            @RutaPlayerAppearancesCSV = '$(rutaAlRepositorio)\Solucion\BBDD\Importacion\player_appearances.csv',
            @RutaRefereesCSV = '$(rutaAlRepositorio)\Solucion\BBDD\Importacion\referees.csv',
            @RutaRefereeAppearancesCSV = '$(rutaAlRepositorio)\Solucion\BBDD\Importacion\referee_appearances.csv',
            @RutaSubstitutionsCSV = '$(rutaAlRepositorio)\Solucion\BBDD\Importacion\substitutions.csv',
            @RutaGoalsCSV = '$(rutaAlRepositorio)\Solucion\BBDD\Importacion\goals.csv',
            @RutaPenaltyKicksCSV = '$(rutaAlRepositorio)\Solucion\BBDD\Importacion\penalty_kicks.csv',
            @RutaBookingsCSV = '$(rutaAlRepositorio)\Solucion\BBDD\Importacion\bookings.csv',
            @RutaPublicidadJSON = '$(rutaAlRepositorio)\Solucion\BBDD\Importacion\campañas-ficticias-mundial-2022.json',
            @MostrarDatos = 1
END

/*
DECLARE @DebugPartido INT = 48; 
DECLARE @DebugJugador INT = 6406;

SELECT * FROM equipos.IntegranteSeleccion WHERE id = @DebugJugador

SELECT * FROM Partidos.Partidos P
JOIN Mundial.Selecciones S ON S.id = P.seleccion_B_id
WHERE P.id = @DebugPartido;

-- Ver si fue titular o suplente
SELECT * FROM Partidos.JugadorPosicionInicial
WHERE partido_id = @DebugPartido AND jugador_id = @DebugJugador;*/
/*
-- Ver en qué momento entró o salió
SELECT motivo, tiempo, minuto, extra 
FROM Cambios 
WHERE id_partido = @DebugPartido 
  AND (id_jugador_entra = @DebugJugador OR id_jugador_sale = @DebugJugador);*/

--exec Importacion.sp_crear_y_cargar_publicidad_json @Ruta = '$(rutaAlRepositorio)\Solucion\BBDD\Importacion\campañas-ficticias-mundial-2022.json';
-- exec Importacion.sp_crear_y_cargar_publicidad_json @Ruta = '$(rutaAlRepositorio)\scrapper\campañas-procesadas.json'; 
--exec Importacion.sp_upsert_anunciantes;
--exec Importacion.sp_upsert_campañas;
/*SELECT * FROM Publicidad.Anunciantes*/
