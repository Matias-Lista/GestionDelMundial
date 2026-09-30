
USE GestionDelMundial;
GO

/* ELIMINAR */
-- Eliminar Tablas

DROP TABLE IF EXISTS Publicidad.RegistroDePiezasEmitidas;
DROP TABLE IF EXISTS Publicidad.Tarifa;
DROP TABLE IF EXISTS Publicidad.PaisesInteresados;
DROP TABLE IF EXISTS Publicidad.PiezasDeContenido;
DROP TABLE IF EXISTS Publicidad.Campañas;
DROP TABLE IF EXISTS Publicidad.Anunciantes;
DROP TABLE IF EXISTS Eventos.Goles;
DROP TABLE IF EXISTS Eventos.Cambios;
DROP TABLE IF EXISTS Eventos.Amonestaciones;
DROP TABLE IF EXISTS Eventos.MomentoEvento;
DROP TABLE IF EXISTS Eventos.Impedimentos;
DROP TABLE IF EXISTS Partidos.JugadorPosicionInicial;
DROP TABLE IF EXISTS Arbitraje.InformesArbitros;
DROP TABLE IF EXISTS Arbitraje.ArbitroAsignadoPartido;
DROP TABLE IF EXISTS Partidos.Partidos;
DROP TABLE IF EXISTS Equipos.ConvocacionEnSeleccion;
DROP TABLE IF EXISTS Equipos.IntegranteSeleccion;
DROP TABLE IF EXISTS Administracion.Sedes;
DROP TABLE IF EXISTS Mundial.Habilitacion_Arbitro;
DROP TABLE IF EXISTS Arbitraje.Arbitro_Habla;
DROP TABLE IF EXISTS Arbitraje.Arbitros;
DROP TABLE IF EXISTS Mundial.Paises_Participes;
DROP TABLE IF EXISTS Mundial.Selecciones;
DROP TABLE IF EXISTS Administracion.Pais_Habla;
DROP TABLE IF EXISTS Administracion.Paises;
DROP TABLE IF EXISTS Administracion.Idiomas;
DROP TABLE IF EXISTS Administracion.Reglas;
DROP TABLE IF EXISTS Administracion.Confederaciones;
DROP TABLE IF EXISTS Administracion.Clubes;
DROP TABLE IF EXISTS Mundial.Mundiales;
GO

DROP PROCEDURE IF EXISTS Administracion.sp_registrar_reglas;
DROP PROCEDURE IF EXISTS Mundial.sp_crear_mundial;

-- Eliminar Schemas
DROP SCHEMA IF EXISTS [Administracion]
DROP SCHEMA IF EXISTS [Publicidad]
DROP SCHEMA IF EXISTS [Partidos]
DROP SCHEMA IF EXISTS [Equipos]
DROP SCHEMA IF EXISTS [Mundial]
DROP SCHEMA IF EXISTS [Arbitraje]

GO

/*
USE master;
GO*/
-- Eliminar conexiones activas
/*ALTER DATABASE GestionDelMundial 
SET SINGLE_USER 
WITH ROLLBACK IMMEDIATE;
GO*/

-- Eliminar Base de Datos
/*
USE master
DROP DATABASE IF EXISTS [GestionDelMundial];
GO
*/