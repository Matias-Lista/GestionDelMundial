/* BBDD/Testeos/20-Testing-Rol-Gestor-Publicidad.sql
 * Fecha: 21/11/2026
 * Lista, Matías Josué.
 * Descripción: Verifica los permisos otorgados y denegados para el usuario
 *              [usr_gestor_de_publicidad] asociado al rol [rol_gestor_de_publicidad].
 **/

USE GestionDelMundial;
GO
SET NOCOUNT ON;

DECLARE @ErrorRecibido VARCHAR(MAX);
DECLARE @NombreTesteo  VARCHAR(200);

BEGIN TRY
BEGIN TRANSACTION ComienzoTesteo;

	---------------------------------------------------------
	-- crear datos ficticios
	---------------------------------------------------------

	DECLARE @confederacionIDTest INT;
	EXEC Administracion.sp_crear_confederacion 
		@Nombre = 'Confederacion Test Pub',
		@siglas = 'CTP',
		@FFundacion = '2000-01-01',
		@ID = @confederacionIDTest OUTPUT;

	-- Países ficticios con zona horaria configurada (requerida por sp_definir_piezas_a_emitir y sp_matriz_prime_time)
	EXEC Administracion.sp_crear_pais @Nombre = 'Pais Pub A', @Codigo = 'XXP', @ConfederacionID = @confederacionIDTest;
	EXEC Administracion.sp_crear_pais @Nombre = 'Pais Pub B', @Codigo = 'XXQ', @ConfederacionID = @confederacionIDTest;
	UPDATE Administracion.Paises SET zona_horaria = 'UTC' WHERE codigo IN ('XXP', 'XXQ');

	DECLARE @sedeIDTest INT;
	EXEC Administracion.sp_crear_sede 
		@CodigoPais = 'XXP',
		@Nombre = 'Estadio Test Publicidad',
		@Ciudad = 'Ciudad Test',
		@Capacidad = 50000,
		@ID = @sedeIDTest OUTPUT;

	DECLARE @añoMundialTest INT = 9999;
	EXEC Mundial.sp_crear_mundial 
		@FInicio = '9999-01-01',
		@FFin = '9999-02-02',
		@LimiteJugadoresConvocados = 26,
		@LimiteStaffConvocados = 10,
		@ArbitroDeVarRequerido = 1,
		@CantidadDeEquipos = 16;

	EXEC Mundial.sp_incluir_pais @CodigoPais = 'XXP', @AñoMundial = @añoMundialTest, @Grupo = 'A';
	EXEC Mundial.sp_incluir_pais @CodigoPais = 'XXQ', @AñoMundial = @añoMundialTest, @Grupo = 'A';

	DECLARE @selPID INT = (SELECT seleccion_id FROM Mundial.Paises_Participes WHERE mundial_id = @añoMundialTest AND pais_id = 'XXP');
	DECLARE @selQID INT = (SELECT seleccion_id FROM Mundial.Paises_Participes WHERE mundial_id = @añoMundialTest AND pais_id = 'XXQ');

	DECLARE @partidoIDTest INT;
	EXEC Partidos.sp_crear_partido 
		@AñoMundial = @añoMundialTest,
		@SeleccionAID = @selPID,
		@SeleccionBID = @selQID,
		@SedeID = @sedeIDTest,
		@FechaYHora = '9999-01-05 20:00:00',
		@Fase = 'GRUPOS',
		@ID = @partidoIDTest OUTPUT;

	-- Anunciante base para probar UPDATE/DELETE directos denegados
	DECLARE @anuncianteBaseID INT;
	EXEC Publicidad.sp_crear_anunciante 
		@RazonSocial = 'Anunciante Base Setup SA',
		@ID = @anuncianteBaseID OUTPUT;

	---------------------------------------------------------
	-- 2. CAMBIO DE CONTEXTO AL USUARIO A TESTEAR
	---------------------------------------------------------
	EXECUTE AS USER = 'usr_gestor_de_publicidad';

	PRINT '====================================================';
	PRINT 'INICIO TESTEOS ROL: rol_gestor_de_publicidad (usr_gestor_de_publicidad)';
	PRINT '====================================================';

	---------------------------------------------------------
	-- CASOS POSITIVOS (Lo que SÍ puede hacer)
	---------------------------------------------------------

	SET @NombreTesteo = '[PERMITIDO] Crear anunciante, tarifas, campaña y pieza de contenido';
	BEGIN TRY
		DECLARE @nuevoAnuncianteID INT;
		DECLARE @nuevaCampañaID INT;

		EXEC Publicidad.sp_crear_anunciante 
			@RazonSocial = 'Marca Ficticia X SA',
			@ID = @nuevoAnuncianteID OUTPUT;

		-- Tarifas para ambas franjas (Prime Time y Normal) de la fase GRUPOS
		EXEC Publicidad.sp_crear_tarifa 
			@AñoMundial = @añoMundialTest,
			@PrimeTime = 1,
			@Fase = 'GRUPOS',
			@Costo = 500.00;

		EXEC Publicidad.sp_crear_tarifa 
			@AñoMundial = @añoMundialTest,
			@PrimeTime = 0,
			@Fase = 'GRUPOS',
			@Costo = 250.00;

		EXEC Publicidad.sp_crear_campaña 
			@AnuncianteID = @nuevoAnuncianteID,
			@AñoMundial = @añoMundialTest,
			@Nombre = 'Campaña Mundial X',
			@Descripcion = 'Campaña de prueba',
			@HorarioMinimo = 0,
			@HorarioMaximo = 23,
			@ID = @nuevaCampañaID OUTPUT;

		EXEC Publicidad.sp_crear_pieza_de_contenido 
			@CampañaID = @nuevaCampañaID,
			@NombrePieza = 'Spot Televisivo X',
			@Descripcion = 'Spot 30 segundos',
			@PaisesInteresados = 'XXP,XXQ';

		IF NOT EXISTS (SELECT 1 FROM Publicidad.PiezasDeContenido WHERE campaña_id = @nuevaCampañaID)
			THROW 50001, 'No pudo consultar la pieza de contenido recién creada.', 1;

		PRINT 'Testeo exitoso: ' + @NombreTesteo;
	END TRY
	BEGIN CATCH
		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;
	END CATCH

	---------------------------------------------------------

	SET @NombreTesteo = '[PERMITIDO] Definir piezas a emitir y ejecutar reportes publicitarios (Ingresos y Matriz Prime Time)';
	BEGIN TRY
		EXEC Publicidad.sp_definir_piezas_a_emitir 
			@PartidoID = @partidoIDTest;

		IF NOT EXISTS (SELECT 1 FROM Publicidad.RegistroDePiezasEmitidas WHERE partido_id = @partidoIDTest)
			THROW 50001, 'No se registraron emisiones publicitarias para el partido.', 1;

		EXEC Reportes.sp_ingresos_publicitarios 
			@AñoMundial = @añoMundialTest;

		EXEC Reportes.sp_matriz_prime_time 
			@AñoMundial = @añoMundialTest;

		PRINT 'Testeo exitoso: ' + @NombreTesteo;
	END TRY
	BEGIN CATCH
		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;
	END CATCH

	---------------------------------------------------------
	-- CASOS NEGATIVOS (Lo que NO puede hacer)
	---------------------------------------------------------

	SET @NombreTesteo = '[DENEGADO] Ejecutar reporte fuera de su alcance (Reportes.sp_goleadores_por_torneo)';
	BEGIN TRY
		EXEC Reportes.sp_goleadores_por_torneo 
			@AñoMundial = @añoMundialTest;

		THROW 50001, 'ERROR DE SEGURIDAD: El gestor de publicidad pudo ejecutar reportes deportivos.', 1;
	END TRY
	BEGIN CATCH
		IF ERROR_NUMBER() = 229
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
		BEGIN
			SET @ErrorRecibido = ERROR_MESSAGE();
			THROW 50001, @ErrorRecibido, 1;
		END
	END CATCH

	---------------------------------------------------------

	SET @NombreTesteo = '[DENEGADO] Ejecutar SP de otro esquema (Administracion.sp_crear_club)';
	BEGIN TRY
		EXEC Administracion.sp_crear_club 
			@Nombre = 'Club Ilegal Publicidad';

		THROW 50001, 'ERROR DE SEGURIDAD: El gestor de publicidad pudo crear un club.', 1;
	END TRY
	BEGIN CATCH
		IF ERROR_NUMBER() = 229
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
		BEGIN
			SET @ErrorRecibido = ERROR_MESSAGE();
			THROW 50001, @ErrorRecibido, 1;
		END
	END CATCH

	---------------------------------------------------------

	SET @NombreTesteo = '[DENEGADO] INSERT directo en tabla de su propio esquema (Publicidad.Anunciantes)';
	BEGIN TRY
		INSERT INTO Publicidad.Anunciantes (razon_social) 
		VALUES ('Anunciante Insertado Directo');

		THROW 50001, 'ERROR DE SEGURIDAD: Se permitió INSERT directo en Publicidad.Anunciantes.', 1;
	END TRY
	BEGIN CATCH
		IF ERROR_NUMBER() = 229
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
		BEGIN
			SET @ErrorRecibido = ERROR_MESSAGE();
			THROW 50001, @ErrorRecibido, 1;
		END
	END CATCH

	---------------------------------------------------------

	SET @NombreTesteo = '[DENEGADO] UPDATE directo en tabla de su propio esquema (Publicidad.Anunciantes)';
	BEGIN TRY
		UPDATE Publicidad.Anunciantes 
		SET razon_social = 'Anunciante Modificado Directo' 
		WHERE id = @anuncianteBaseID;

		THROW 50001, 'ERROR DE SEGURIDAD: Se permitió UPDATE directo en Publicidad.Anunciantes.', 1;
	END TRY
	BEGIN CATCH
		IF ERROR_NUMBER() = 229
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
		BEGIN
			SET @ErrorRecibido = ERROR_MESSAGE();
			THROW 50001, @ErrorRecibido, 1;
		END
	END CATCH

	---------------------------------------------------------

	SET @NombreTesteo = '[DENEGADO] DELETE directo en tabla de su propio esquema (Publicidad.Anunciantes)';
	BEGIN TRY
		DELETE FROM Publicidad.Anunciantes 
		WHERE id = @anuncianteBaseID;

		THROW 50001, 'ERROR DE SEGURIDAD: Se permitió DELETE directo en Publicidad.Anunciantes.', 1;
	END TRY
	BEGIN CATCH
		IF ERROR_NUMBER() = 229
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
		BEGIN
			SET @ErrorRecibido = ERROR_MESSAGE();
			THROW 50001, @ErrorRecibido, 1;
		END
	END CATCH

	---------------------------------------------------------
	-- 3. RESTAURAR CONTEXTO Y REVERTIR CAMBIOS
	---------------------------------------------------------
	REVERT;
	ROLLBACK TRANSACTION;

	PRINT '====================================================';
	PRINT 'TODOS LOS TESTEOS DE [usr_gestor_de_publicidad] PASARON OK';
	PRINT '====================================================';

END TRY
BEGIN CATCH
	IF USER_NAME() = 'usr_gestor_de_publicidad'
		REVERT;

	IF @@TRANCOUNT > 0
		ROLLBACK TRANSACTION;

	PRINT '';
	PRINT 'Testeo fallido: ' + ISNULL(@NombreTesteo, 'Setup inicial');
	THROW;
END CATCH;
GO