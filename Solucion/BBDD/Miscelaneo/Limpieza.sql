/* BBDD/Miscelaneo/Limpieza.sql
 * Fecha: 9/10/2026
 * Integrantes: Lista, Matías Josué. Maldonado Medrano, Milagros.
 * Descripción: Este script elimina todos los objetos de la base de datos GestionDelMundial.
				Deja la base de datos en un estado limpio para regenerar todos sus objetos y reimportar sus datos.
 **/

SET NOEXEC OFF;

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'GestionDelMundial')
BEGIN
	SET NOEXEC ON; -- cancela la ejecucion de los siguientes lotes.
	THROW 51000, 'No hay base de datos para limpiar!', 1;
END
GO

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

DROP PROCEDURE IF EXISTS Administracion.sp_registrar_regla;
DROP PROCEDURE IF EXISTS Administracion.sp_obtener_regla;
DROP PROCEDURE IF EXISTS Administracion.sp_crear_confederacion;
DROP PROCEDURE IF EXISTS Administracion.sp_modificar_confederacion;
DROP PROCEDURE IF EXISTS Administracion.sp_crear_pais;
DROP PROCEDURE IF EXISTS Administracion.sp_modificar_pais;
DROP PROCEDURE IF EXISTS Administracion.sp_crear_idioma;
DROP PROCEDURE IF EXISTS Administracion.sp_modificar_idioma
DROP PROCEDURE IF EXISTS Administracion.sp_asociar_idioma_a_pais
DROP PROCEDURE IF EXISTS Administracion.sp_crear_club
DROP PROCEDURE IF EXISTS Administracion.sp_modificar_club;
DROP PROCEDURE IF EXISTS Administracion.sp_eliminar_idioma;
DROP PROCEDURE IF EXISTS Administracion.sp_desasociar_idioma_de_pais;
DROP PROCEDURE IF EXISTS Administracion.sp_eliminar_club;


DROP PROCEDURE IF EXISTS Mundial.sp_crear_mundial;
DROP PROCEDURE IF EXISTS Mundial.sp_incluir_pais;

DROP PROCEDURE IF EXISTS Mundial.sp_habilitar_arbitro;

DROP PROCEDURE IF EXISTS Equipos.sp_crear_integrante_seleccion;
DROP PROCEDURE IF EXISTS Equipos.sp_modificar_integrante_seleccion;
DROP PROCEDURE IF EXISTS Equipos.sp_convocar_jugador;
DROP PROCEDURE IF EXISTS Equipos.sp_convocar_staff;
DROP PROCEDURE IF EXISTS Equipos.sp_cancelar_convocacion;

DROP FUNCTION  IF EXISTS Equipos.fn_obtener_integrante_id;
DROP FUNCTION  IF EXISTS Equipos.fn_obtener_jugadores_convocados

DROP PROCEDURE IF EXISTS Publicidad.sp_crear_tarifa;
DROP PROCEDURE IF EXISTS Publicidad.sp_crear_anunciante;
DROP PROCEDURE IF EXISTS Publicidad.sp_crear_campaña;
DROP PROCEDURE IF EXISTS Publicidad.sp_crear_pieza_de_contenido;
DROP PROCEDURE IF EXISTS Publicidad.sp_asociar_pais_a_contenido;
DROP PROCEDURE IF EXISTS Publicidad.sp_definir_pieza_a_emitir;

DROP PROCEDURE IF EXISTS Partidos.sp_definir_formacion_inicial;

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