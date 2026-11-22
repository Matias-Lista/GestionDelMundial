/* BBDD/Testeos/18-Testing-Rol-Gestor-Fifa.sql
 * Fecha: 21/11/2026
 * Lista, Matías Josué.
 * Descripción: Verifica los permisos otorgados y denegados para el usuario
 *              [usr_gestor_fifa] asociado al rol [rol_gestor_fifa].
 **/

USE GestionDelMundial;
GO
SET NOCOUNT ON;

DECLARE @ErrorRecibido VARCHAR(MAX);
DECLARE @NombreTesteo  VARCHAR(200);

BEGIN TRY
BEGIN TRANSACTION ComienzoTesteo;

	---------------------------------------------------------
	-- SETUP: crear datos ficticios
	---------------------------------------------------------

	DECLARE @confederacionIDTest INT;
	EXEC Administracion.sp_crear_confederacion 
		@Nombre = 'Confederacion Test Fifa',
		@siglas = 'CTF',
		@FFundacion = '2000-01-01',
		@ID = @confederacionIDTest OUTPUT;

	EXEC Administracion.sp_crear_pais 
		@Nombre = 'Pais Fifa Test', 
		@Codigo = 'XXF', 
		@ConfederacionID = @confederacionIDTest;

	EXEC Administracion.sp_crear_idioma 
		@Codigo = 'XF', 
		@Label = 'Idioma Fifa Test';

	DECLARE @añoMundialTest INT = 9999;
	INSERT INTO Mundial.Mundiales (f_inicio, f_fin) 
	VALUES ('9999-01-01', '9999-02-02');

	-- Registros base para probar UPDATE/DELETE directos denegados
	DECLARE @arbitroBaseID INT;
	EXEC Arbitraje.sp_crear_arbitro 
		@CodigoPais = 'XXF',
		@Nombre = 'ArbitroBase',
		@Apellido = 'TestFifa',
		@EsMujer = 0,
		@ConfederacionID = @confederacionIDTest,
		@ID = @arbitroBaseID OUTPUT;

	DECLARE @integranteBaseID INT;
	EXEC Equipos.sp_crear_integrante_seleccion 
		@CodigoPais = 'XXF',
		@Nombre = 'JugadorBase',
		@Apellido = 'TestFifa',
		@FNacimiento = '1995-01-01',
		@ID = @integranteBaseID OUTPUT;

	---------------------------------------------------------
	-- 2. CAMBIO DE CONTEXTO AL USUARIO A TESTEAR
	---------------------------------------------------------
	EXECUTE AS USER = 'usr_gestor_fifa';

	PRINT '====================================================';
	PRINT 'INICIO TESTEOS ROL: rol_gestor_fifa (usr_gestor_fifa)';
	PRINT '====================================================';

	---------------------------------------------------------
	-- CASOS POSITIVOS (Lo que SÍ puede hacer)
	---------------------------------------------------------

	SET @NombreTesteo = '[PERMITIDO] Crear, modificar árbitro, asociar idioma y registrar informe';
	BEGIN TRY
		DECLARE @nuevoArbitroID INT;
		DECLARE @hoy DATE = CAST(GETDATE() AS DATE);

		EXEC Arbitraje.sp_crear_arbitro 
			@CodigoPais = 'XXF',
			@Nombre = 'ArbitroNuevo',
			@Apellido = 'FifaTest',
			@EsMujer = 1,
			@ConfederacionID = @confederacionIDTest,
			@ID = @nuevoArbitroID OUTPUT;

		EXEC Arbitraje.sp_modificar_arbitro 
			@ID = @nuevoArbitroID,
			@Nombre = 'ArbitroModificado',
			@Apellido = 'FifaTest';

		EXEC Arbitraje.sp_asociar_idioma_a_arbitro 
			@ArbitroID = @nuevoArbitroID,
			@CodigoIdioma = 'XF';

		EXEC Arbitraje.sp_registrar_informe_arbitro 
			@ArbitroID = @nuevoArbitroID,
			@FReporte = @hoy,
			@Motivo = 'Informe disciplinario general de prueba';

		IF NOT EXISTS (SELECT 1 FROM Arbitraje.Arbitros WHERE id = @nuevoArbitroID)
			THROW 50001, 'No pudo consultar el árbitro creado.', 1;

		PRINT 'Testeo exitoso: ' + @NombreTesteo;
	END TRY
	BEGIN CATCH
		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;
	END CATCH

	---------------------------------------------------------

	SET @NombreTesteo = '[PERMITIDO] Crear y modificar integrante de selección y consultar tablas permitidas';
	BEGIN TRY
		DECLARE @nuevoIntegranteID INT;

		EXEC Equipos.sp_crear_integrante_seleccion 
			@CodigoPais = 'XXF',
			@Nombre = 'JugadorNuevo',
			@Apellido = 'FifaTest',
			@FNacimiento = '1998-06-15',
			@ID = @nuevoIntegranteID OUTPUT;

		EXEC Equipos.sp_modificar_integrante_seleccion 
			@ID = @nuevoIntegranteID,
			@CodigoPais = 'XXF',
			@Nombre = 'JugadorModificado',
			@Apellido = 'FifaTest',
			@FNacimiento = '1998-06-15';

		IF NOT EXISTS (SELECT 1 FROM Equipos.IntegranteSeleccion WHERE id = @nuevoIntegranteID)
			THROW 50001, 'No pudo consultar el integrante creado.', 1;

		PRINT 'Testeo exitoso: ' + @NombreTesteo;
	END TRY
	BEGIN CATCH
		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;
	END CATCH

	---------------------------------------------------------
	-- CASOS NEGATIVOS (Lo que NO puede hacer)
	---------------------------------------------------------

	SET @NombreTesteo = '[DENEGADO] Ejecutar SP con DENY en Arbitraje (Arbitraje.sp_designar_arbitro)';
	BEGIN TRY
		EXEC Arbitraje.sp_designar_arbitro 
			@PartidoID = 1,
			@ArbitroID = @arbitroBaseID,
			@Rol = 'PRINCIPAL';

		THROW 50001, 'ERROR DE SEGURIDAD: El gestor FIFA pudo designar un árbitro a un partido.', 1;
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

	SET @NombreTesteo = '[DENEGADO] Ejecutar SP con DENY en Equipos (Equipos.sp_convocar_jugador)';
	BEGIN TRY
		EXEC Equipos.sp_convocar_jugador 
			@AñoMundial = @añoMundialTest,
			@MiembroID = @integranteBaseID,
			@FConvocacion = '9998-12-01',
			@Dorsal = 10;

		THROW 50001, 'ERROR DE SEGURIDAD: El gestor FIFA pudo convocar un jugador.', 1;
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

	SET @NombreTesteo = '[DENEGADO] Consultar función con DENY SELECT (Equipos.fn_obtener_jugadores_convocados)';
	BEGIN TRY
		SELECT * FROM Equipos.fn_obtener_jugadores_convocados(1);

		THROW 50001, 'ERROR DE SEGURIDAD: El gestor FIFA pudo consultar jugadores convocados.', 1;
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

	SET @NombreTesteo = '[DENEGADO] Ejecutar SP de otro esquema (Mundial.sp_habilitar_arbitro)';
	BEGIN TRY
		EXEC Mundial.sp_habilitar_arbitro 
			@AñoMundial = @añoMundialTest,
			@ArbitroID = @arbitroBaseID;

		THROW 50001, 'ERROR DE SEGURIDAD: El gestor FIFA pudo habilitar un árbitro en un mundial.', 1;
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

	SET @NombreTesteo = '[DENEGADO] INSERT directo en tabla de su propio ámbito (Equipos.IntegranteSeleccion)';
	BEGIN TRY
		INSERT INTO Equipos.IntegranteSeleccion (pais_id, nombre, apellido, f_nacimiento) 
		VALUES ('XXF', 'Ilegal', 'Directo', '1990-01-01');

		THROW 50001, 'ERROR DE SEGURIDAD: Se permitió INSERT directo en Equipos.IntegranteSeleccion.', 1;
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

	SET @NombreTesteo = '[DENEGADO] UPDATE directo en tabla de su propio ámbito (Arbitraje.Arbitros)';
	BEGIN TRY
		UPDATE Arbitraje.Arbitros 
		SET nombre = 'NombreIlegal' 
		WHERE id = @arbitroBaseID;

		THROW 50001, 'ERROR DE SEGURIDAD: Se permitió UPDATE directo en Arbitraje.Arbitros.', 1;
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

	SET @NombreTesteo = '[DENEGADO] DELETE directo en tabla de su propio ámbito (Equipos.IntegranteSeleccion)';
	BEGIN TRY
		DELETE FROM Equipos.IntegranteSeleccion 
		WHERE id = @integranteBaseID;

		THROW 50001, 'ERROR DE SEGURIDAD: Se permitió DELETE directo en Equipos.IntegranteSeleccion.', 1;
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
	PRINT 'TODOS LOS TESTEOS DE [usr_gestor_fifa] PASARON OK';
	PRINT '====================================================';

END TRY
BEGIN CATCH
	IF USER_NAME() = 'usr_gestor_fifa'
		REVERT;

	IF @@TRANCOUNT > 0
		ROLLBACK TRANSACTION;

	PRINT '';
	PRINT 'Testeo fallido: ' + ISNULL(@NombreTesteo, 'Setup inicial');
	THROW;
END CATCH;
GO