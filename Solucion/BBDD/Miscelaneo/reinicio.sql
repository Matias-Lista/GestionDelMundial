-- Acá podemos usar SQLCMD para ejecutar todos los scripts en orden con un solo archivo (limpieza => tablas => cada archivo de sp => Importacion)

-- Reemplazar esta variable por la ruta a la que se copió el repositorio.

-- Tienen que ser rutas sin espacios, hay que ponerlo sin comillas. 
-- También hay que entrar a Consulta > Modo SQLCMD. Se tendría que poenr gris las lineas que empiezan con ':' para mostrar que está activo

:setvar rutaAlRepositorio C:\Soluciones-SQL\GestionDelMundial

/*PRINT 'Ruta al Repositorio: $(rutaAlRepositorio)'
PRINT 'TABLAS: $(rutaAlRepositorio)\Solucion\BBDD\SCHEMA\01-TABLAS.sql'*/

:r $(rutaAlRepositorio)\Solucion\BBDD\Miscelaneo\Limpieza.sql
GO

:r $(rutaAlRepositorio)\Solucion\BBDD\SCHEMA\01-TABLAS.sql
GO

:r $(rutaAlRepositorio)\Solucion\BBDD\SPs\02-Administracion.sql
GO

:r $(rutaAlRepositorio)\Solucion\BBDD\SPs\03-Mundial.sql
GO

:r $(rutaAlRepositorio)\Solucion\BBDD\SPs\04-Equipos.sql
GO

:r $(rutaAlRepositorio)\Solucion\BBDD\SPs\05-Partidos.sql
GO

:r $(rutaAlRepositorio)\Solucion\BBDD\SPs\06-Eventos.sql
GO

:r $(rutaAlRepositorio)\Solucion\BBDD\SPs\07-Arbitraje.sql
GO

:r $(rutaAlRepositorio)\Solucion\BBDD\SPs\08-Publicidad.sql
GO

-- Descomentar para importación de datos:
-- :r $(rutaAlRepositorio)\Solucion\BBDD\Importacion\Importacion.sql
GO