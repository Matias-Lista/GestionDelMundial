/* BBDD/Seguridad/Roles.sql
 * Fecha: 21/11/2026
 * Lista, Matías Josué.
 * Descripción: Contiene todos los store procedures necesarios para generar roles.
 **/

USE GestionDelMundial;
GO

CREATE OR ALTER PROCEDURE Seguridad.sp_crear_roles 
AS
BEGIN
	SET NOCOUNT ON

	IF DATABASE_PRINCIPAL_ID('rol_administrador') IS NULL
	    CREATE ROLE rol_administrador;

	GRANT EXECUTE ON SCHEMA::Administracion TO rol_administrador;
	DENY EXECUTE ON Administracion.sp_registrar_regla TO rol_administrador;
	GRANT SELECT ON SCHEMA::Administracion TO rol_administrador;


	IF DATABASE_PRINCIPAL_ID('rol_organizador') IS NULL
	    CREATE ROLE rol_organizador;
		
	-- Este tiene permisos granulares, aparte del schema mundial, SPs específicos de Partidos.

	GRANT EXECUTE ON SCHEMA::Mundial TO rol_organizador;
		
	GRANT EXECUTE ON Partidos.sp_crear_partido            TO rol_organizador;
	GRANT EXECUTE ON Partidos.sp_generar_partidos         TO rol_organizador;
	GRANT EXECUTE ON Partidos.sp_terminar_partido         TO rol_organizador;
	GRANT EXECUTE ON Partidos.sp_terminar_fase_de_grupos  TO rol_organizador;
	GRANT EXECUTE ON Arbitraje.sp_designar_arbitro        TO rol_organizador;
	--GRANT EXECUTE ON Arbitraje.sp_quitar_designacion    TO rol_organizador;
	GRANT EXECUTE ON Arbitraje.sp_asginar_terna_arbitros  TO rol_organizador;

	GRANT SELECT  ON SCHEMA::Mundial TO rol_organizador;
	GRANT SELECT  ON Partidos.Partidos TO rol_organizador;
	GRANT SELECT  ON Partidos.vw_resumen_partido TO rol_organizador;
	GRANT SELECT  ON Partidos.fn_tabla_grupos TO rol_organizador;
	GRANT SELECT  ON Administracion.Paises TO rol_organizador;
	GRANT SELECT  ON Administracion.Sedes TO rol_organizador;
	GRANT SELECT  ON Arbitraje.Arbitros TO rol_organizador;
	GRANT SELECT  ON Arbitraje.ArbitroAsignadoPartido TO rol_organizador;

	IF DATABASE_PRINCIPAL_ID('rol_gestor_fifa') IS NULL
	    CREATE ROLE rol_gestor_fifa;

	GRANT EXECUTE ON SCHEMA::Arbitraje TO rol_gestor_fifa;
	DENY EXECUTE ON Arbitraje.sp_designar_arbitro TO rol_gestor_fifa
	DENY EXECUTE ON Arbitraje.sp_asginar_terna_arbitros TO rol_gestor_fifa

	GRANT EXECUTE ON SCHEMA::Equipos TO rol_gestor_fifa;

	DENY EXECUTE ON Equipos.sp_convocar_jugador TO rol_gestor_fifa
	DENY EXECUTE ON Equipos.sp_convocar_staff TO rol_gestor_fifa
	DENY EXECUTE ON Equipos.sp_cancelar_convocacion TO rol_gestor_fifa
	DENY SELECT  ON Equipos.fn_obtener_jugadores_convocados TO rol_gestor_fifa

	GRANT SELECT  ON Arbitraje.Arbitros TO rol_gestor_fifa;
	GRANT SELECT  ON Arbitraje.Arbitro_Habla TO rol_gestor_fifa;
	GRANT SELECT  ON Arbitraje.InformesArbitros TO rol_gestor_fifa;
	GRANT SELECT  ON Arbitraje.fn_historial_arbitro TO rol_gestor_fifa;
	GRANT SELECT  ON Equipos.IntegranteSeleccion TO rol_gestor_fifa;
	GRANT SELECT  ON Administracion.Paises TO rol_gestor_fifa;
	GRANT SELECT  ON Administracion.Idiomas TO rol_gestor_fifa;
	GRANT SELECT  ON Administracion.Confederaciones TO rol_gestor_fifa;


	IF DATABASE_PRINCIPAL_ID('rol_delegado_de_seleccion') IS NULL
	    CREATE ROLE rol_delegado_de_seleccion;
		
	GRANT EXECUTE ON Equipos.sp_convocar_jugador TO rol_delegado_de_seleccion
	GRANT EXECUTE ON Equipos.sp_convocar_staff TO rol_delegado_de_seleccion
	GRANT EXECUTE ON Equipos.sp_cancelar_convocacion TO rol_delegado_de_seleccion
	GRANT EXECUTE ON Partidos.sp_definir_formacion_inicial TO rol_delegado_de_seleccion

	GRANT SELECT  ON Equipos.fn_obtener_jugadores_convocados TO rol_delegado_de_seleccion;
	GRANT SELECT  ON Partidos.fn_jugadores_disponibles TO rol_delegado_de_seleccion;      
	GRANT SELECT  ON Partidos.fn_jugadores_en_cancha TO rol_delegado_de_seleccion;        
	GRANT SELECT  ON Equipos.IntegranteSeleccion TO rol_delegado_de_seleccion;
	GRANT SELECT  ON Equipos.ConvocacionEnSeleccion TO rol_delegado_de_seleccion;
	GRANT SELECT  ON Administracion.Clubes TO rol_delegado_de_seleccion;
	GRANT SELECT  ON Mundial.Paises_Participes TO rol_delegado_de_seleccion;
	GRANT SELECT  ON Mundial.Selecciones TO rol_delegado_de_seleccion;
	GRANT SELECT  ON Partidos.Partidos TO rol_delegado_de_seleccion;
	GRANT SELECT  ON Partidos.JugadorPosicionInicial TO rol_delegado_de_seleccion;

	IF DATABASE_PRINCIPAL_ID('rol_gestor_de_publicidad') IS NULL 
	    CREATE ROLE rol_gestor_de_publicidad;
		
	GRANT EXECUTE ON SCHEMA::Publicidad TO rol_gestor_de_publicidad;
	GRANT EXECUTE ON Reportes.sp_ingresos_publicitarios TO rol_gestor_de_publicidad;
	GRANT EXECUTE ON Reportes.sp_matriz_prime_time TO rol_gestor_de_publicidad;

	GRANT SELECT  ON SCHEMA::Publicidad TO rol_gestor_de_publicidad;
	GRANT SELECT  ON Administracion.Paises TO rol_gestor_de_publicidad;
	GRANT SELECT  ON Mundial.Mundiales TO rol_gestor_de_publicidad;
	GRANT SELECT ON Partidos.Partidos TO rol_gestor_de_publicidad;
	GRANT SELECT ON Mundial.Paises_Participes TO rol_gestor_de_publicidad;



	IF DATABASE_PRINCIPAL_ID('rol_cargador_de_resultados') IS NULL
	    CREATE ROLE rol_cargador_de_resultados;
	
	GRANT EXECUTE ON SCHEMA::Eventos TO rol_cargador_de_resultados;

	GRANT SELECT  ON SCHEMA::Eventos TO rol_cargador_de_resultados;
	GRANT SELECT  ON Partidos.fn_jugadores_en_cancha TO rol_cargador_de_resultados;
	GRANT SELECT  ON Partidos.vw_resumen_partido TO rol_cargador_de_resultados;
	GRANT SELECT  ON Partidos.JugadorPosicionInicial TO rol_cargador_de_resultados;


	IF DATABASE_PRINCIPAL_ID('rol_consulta_reportes') IS NULL
	    CREATE ROLE rol_consulta_reportes;
	

	GRANT EXECUTE ON SCHEMA::Reportes TO rol_consulta_reportes;

END
GO 

CREATE OR ALTER PROCEDURE Seguridad.sp_crear_usuarios
AS
BEGIN
	IF DATABASE_PRINCIPAL_ID('usr_administracion') IS NULL
	    CREATE USER usr_administracion WITHOUT LOGIN;

	IF DATABASE_PRINCIPAL_ID('usr_organizador') IS NULL
	    CREATE USER usr_organizador WITHOUT LOGIN;

	IF DATABASE_PRINCIPAL_ID('usr_delegado_de_seleccion') IS NULL
	    CREATE USER usr_delegado_de_seleccion WITHOUT LOGIN;

	IF DATABASE_PRINCIPAL_ID('usr_gestor_de_publicidad') IS NULL
	    CREATE USER usr_gestor_de_publicidad WITHOUT LOGIN;

	IF DATABASE_PRINCIPAL_ID('usr_cargador_de_resultados') IS NULL
	    CREATE USER usr_cargador_de_resultados WITHOUT LOGIN;

	IF SUSER_ID('login_consulta_reportes') IS NULL
	BEGIN
	    CREATE LOGIN login_consulta_reportes 
	        WITH PASSWORD = 'PasswordSegura123!',
	             DEFAULT_DATABASE = GestionDelMundial,
	             CHECK_POLICY = OFF;
	END

	IF DATABASE_PRINCIPAL_ID('usr_consulta_reportes') IS NULL
	BEGIN
	    CREATE USER usr_consulta_reportes FOR LOGIN login_consulta_reportes;
	END
	ELSE
	BEGIN
	    ALTER USER usr_consulta_reportes WITH LOGIN = login_consulta_reportes;
	END

	IF SUSER_ID('login_gestor_fifa') IS NULL
	BEGIN
	    CREATE LOGIN login_gestor_fifa 
	        WITH PASSWORD = 'PasswordGestor123!',
	             DEFAULT_DATABASE = GestionDelMundial,
	             CHECK_POLICY = OFF;
	END

	GRANT CONNECT TO usr_consulta_reportes;

	IF DATABASE_PRINCIPAL_ID('usr_gestor_fifa') IS NULL
	    CREATE USER usr_gestor_fifa FOR LOGIN login_gestor_fifa;
	ELSE
	    ALTER USER usr_gestor_fifa WITH LOGIN = login_gestor_fifa;

	GRANT CONNECT TO usr_gestor_fifa;

	
	ALTER ROLE rol_administrador          ADD MEMBER usr_administracion;
	ALTER ROLE rol_organizador            ADD MEMBER usr_organizador;
	ALTER ROLE rol_gestor_fifa            ADD MEMBER usr_gestor_fifa;
	ALTER ROLE rol_delegado_de_seleccion  ADD MEMBER usr_delegado_de_seleccion;
	ALTER ROLE rol_gestor_de_publicidad ADD MEMBER usr_gestor_de_publicidad;
	ALTER ROLE rol_cargador_de_resultados ADD MEMBER usr_cargador_de_resultados;
	ALTER ROLE rol_consulta_reportes      ADD MEMBER usr_consulta_reportes;
END
GO
