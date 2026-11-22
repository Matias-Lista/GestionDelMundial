/* BBDD/Testeos/22-Testing-Rol-Consulta-Reportes.sql
 * Fecha: 21/11/2026
 * Lista, Matías Josué.
 * Descripción: Verifica los permisos otorgados y denegados para el usuario
 *              [usr_consulta_reportes] asociado al rol [rol_consulta_reportes].
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
		@Nombre = 'Confederacion Test Rep',
		@siglas = 'CTQ',
		@FFundacion = '2000-01-01',
		@ID = @confederacionIDTest OUTPUT;

	EXEC Administracion.sp_crear_pais @Nombre = 'Pais Rep A', @Codigo = 'XXT', @ConfederacionID = @confederacionIDTest;
	EXEC Administracion.sp_crear_pais @Nombre = 'Pais Rep B', @Codigo = 'XXU', @ConfederacionID = @confederacionIDTest;
	UPDATE Administracion.Paises SET zona_horaria = 'UTC' WHERE codigo = 'XXT';

	DECLARE @sedeIDTest INT;
	EXEC Administracion.sp_crear_sede 
		@CodigoPais = 'XXT',
		@Nombre = 'Estadio Test Reportes',
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

	EXEC Mundial.sp_incluir_pais @CodigoPais = 'XXT', @AñoMundial = @añoMundialTest, @Grupo = 'A';
	EXEC Mundial.sp_incluir_pais @CodigoPais = 'XXU', @AñoMundial = @añoMundialTest, @Grupo = 'A';

	DECLARE @selTID INT = (SELECT seleccion_id FROM Mundial.Paises_Participes WHERE mundial_id = @añoMundialTest AND pais_id = 'XXT');
	DECLARE @selUID INT = (SELECT seleccion_id FROM Mundial.Paises_Participes WHERE mundial_id = @añoMundialTest AND pais_id = 'XXU');

	DECLARE @partidoIDTest INT;
	EXEC Partidos.sp_crear_partido 
		@AñoMundial = @añoMundialTest,
		@SeleccionAID = @selTID,
		@SeleccionBID = @selUID,
		@SedeID = @sedeIDTest,
		@FechaYHora = '9999-01-05 18:00:00',
		@Fase = 'GRUPOS',
		@ID = @partidoIDTest OUTPUT;

	EXEC Partidos.sp_terminar_partido 
		@PartidoID = @partidoIDTest;

	---------------------------------------------------------
	-- 2. CAMBIO DE CONTEXTO AL USUARIO A TESTEAR
	---------------------------------------------------------
	EXECUTE AS USER = 'usr_consulta_reportes';

	PRINT '====================================================';
	PRINT 'INICIO TESTEOS ROL: rol_consulta_reportes (usr_consulta_reportes)';
	PRINT '====================================================';

	---------------------------------------------------------
	-- CASOS POSITIVOS (Lo que SÍ puede hacer)
	---------------------------------------------------------

	SET @NombreTesteo = '[PERMITIDO] Ejecutar reportes deportivos (Resultados de encuentros y Goleadores)';
	BEGIN TRY
		EXEC Reportes.sp_resultados_de_encuentros 
			@AñoMundial = @añoMundialTest;

		EXEC Reportes.sp_goleadores_por_torneo 
			@AñoMundial = @añoMundialTest;

		PRINT 'Testeo exitoso: ' + @NombreTesteo;
	END TRY
	BEGIN CATCH
		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;
	END CATCH

	---------------------------------------------------------

	SET @NombreTesteo = '[PERMITIDO] Ejecutar reportes XML (Selecciones e Ingresos publicitarios)';
	BEGIN TRY
		EXEC Reportes.sp_selecciones 
			@AñoMundial = @añoMundialTest;

		EXEC Reportes.sp_ingresos_publicitarios 
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

	SET @NombreTesteo = '[DENEGADO] Ejecutar SP de otro esquema (Administracion.sp_crear_club)';
	BEGIN TRY
		EXEC Administracion.sp_crear_club 
			@Nombre = 'Club Ilegal Reportes';

		THROW 50001, 'ERROR DE SEGURIDAD: El usuario de reportes pudo crear un club.', 1;
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

	SET @NombreTesteo = '[DENEGADO] Ejecutar SP de otro esquema (Partidos.sp_terminar_partido)';
	BEGIN TRY
		EXEC Partidos.sp_terminar_partido 
			@PartidoID = @partidoIDTest;

		THROW 50001, 'ERROR DE SEGURIDAD: El usuario de reportes pudo finalizar un partido.', 1;
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

	SET @NombreTesteo = '[DENEGADO] SELECT directo sobre tabla consultada por reportes (Partidos.Partidos)';
	BEGIN TRY
		SELECT * FROM Partidos.Partidos WHERE id = @partidoIDTest;

		THROW 50001, 'ERROR DE SEGURIDAD: Se permitió SELECT directo en Partidos.Partidos.', 1;
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

	SET @NombreTesteo = '[DENEGADO] INSERT directo en tabla (Administracion.Clubes)';
	BEGIN TRY
		INSERT INTO Administracion.Clubes (nombre) 
		VALUES ('Club Insertado Directo');

		THROW 50001, 'ERROR DE SEGURIDAD: Se permitió INSERT directo en Administracion.Clubes.', 1;
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

	SET @NombreTesteo = '[DENEGADO] UPDATE directo en tabla (Partidos.Partidos)';
	BEGIN TRY
		UPDATE Partidos.Partidos 
		SET fase = 'FINAL' 
		WHERE id = @partidoIDTest;

		THROW 50001, 'ERROR DE SEGURIDAD: Se permitió UPDATE directo en Partidos.Partidos.', 1;
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

	SET @NombreTesteo = '[DENEGADO] DELETE directo en tabla (Partidos.Partidos)';
	BEGIN TRY
		DELETE FROM Partidos.Partidos 
		WHERE id = @partidoIDTest;

		THROW 50001, 'ERROR DE SEGURIDAD: Se permitió DELETE directo en Partidos.Partidos.', 1;
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
	PRINT 'TODOS LOS TESTEOS DE [usr_consulta_reportes] PASARON OK';
	PRINT '====================================================';

END TRY
BEGIN CATCH
	IF USER_NAME() = 'usr_consulta_reportes'
		REVERT;

	IF @@TRANCOUNT > 0
		ROLLBACK TRANSACTION;

	PRINT '';
	PRINT 'Testeo fallido: ' + ISNULL(@NombreTesteo, 'Setup inicial');
	THROW;
END CATCH;
GO