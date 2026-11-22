/* BBDD/Testeos/17-Testing-Rol-Organizador.sql
 * Fecha: 21/11/2026
 * Lista, Matías Josué.
 * Descripción: Verifica los permisos otorgados y denegados para el usuario
 *              [usr_organizador] asociado al rol [rol_organizador].
 **/

USE GestionDelMundial;
GO
SET NOCOUNT ON;

DECLARE @ErrorRecibido VARCHAR(MAX);
DECLARE @NombreTesteo  VARCHAR(200);

BEGIN TRY
BEGIN TRANSACTION ComienzoTesteo;

	---------------------------------------------------------
	-- 1. crear datos ficticios
	---------------------------------------------------------

	DECLARE @confederacionIDTest INT;
	EXEC Administracion.sp_crear_confederacion 
		@Nombre = 'Confederacion Test Org',
		@siglas = 'CTO',
		@FFundacion = '2000-01-01',
		@ID = @confederacionIDTest OUTPUT;

	-- Países ficticios (XXA y XXB jugarán; XXC será el país del árbitro)
	EXEC Administracion.sp_crear_pais @Nombre = 'Pais Org A', @Codigo = 'XXA', @ConfederacionID = @confederacionIDTest;
	EXEC Administracion.sp_crear_pais @Nombre = 'Pais Org B', @Codigo = 'XXB', @ConfederacionID = @confederacionIDTest;
	EXEC Administracion.sp_crear_pais @Nombre = 'Pais Org C', @Codigo = 'XXC', @ConfederacionID = @confederacionIDTest;

	-- Partidos.sp_crear_partido exige que el país de la sede tenga zona_horaria
	UPDATE Administracion.Paises SET zona_horaria = 'UTC' WHERE codigo = 'XXA';

	DECLARE @sedeIDTest INT;
	EXEC Administracion.sp_crear_sede 
		@CodigoPais = 'XXA',
		@Nombre = 'Estadio Test Organizador',
		@Ciudad = 'Ciudad Test',
		@Capacidad = 50000,
		@ID = @sedeIDTest OUTPUT;

	-- Usamos el SP para que sea compatible tanto con tabla cifrada como sin cifrar
	DECLARE @arbitroIDTest INT;
	EXEC Arbitraje.sp_crear_arbitro 
		@CodigoPais = 'XXC',
		@Nombre = 'Arbitro',
		@Apellido = 'TestOrg',
		@EsMujer = 0,
		@ConfederacionID = @confederacionIDTest,
		@ID = @arbitroIDTest OUTPUT;

	---------------------------------------------------------
	-- 2. CAMBIO DE CONTEXTO AL USUARIO A TESTEAR
	---------------------------------------------------------
	EXECUTE AS USER = 'usr_organizador';

	PRINT '====================================================';
	PRINT 'INICIO TESTEOS ROL: rol_organizador (usr_organizador)';
	PRINT '====================================================';

	---------------------------------------------------------
	-- CASOS POSITIVOS (Lo que SÍ puede hacer)
	---------------------------------------------------------

	SET @NombreTesteo = '[PERMITIDO] Crear Mundial (y registrar reglas internamente vía Ownership Chaining)';
	BEGIN TRY
		DECLARE @añoMundialTest INT = 9999;

		EXEC Mundial.sp_crear_mundial 
			@FInicio = '9999-01-01',
			@FFin = '9999-02-02',
			@LimiteJugadoresConvocados = 26,
			@LimiteStaffConvocados = 10,
			@ArbitroDeVarRequerido = 1,
			@CantidadDeEquipos = 16;

		IF NOT EXISTS (SELECT 1 FROM Mundial.Mundiales WHERE año = @añoMundialTest)
			THROW 50001, 'No se creó el mundial.', 1;

		PRINT 'Testeo exitoso: ' + @NombreTesteo;
	END TRY
	BEGIN CATCH
		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;
	END CATCH

	---------------------------------------------------------

	SET @NombreTesteo = '[PERMITIDO] Incluir países al mundial y habilitar árbitro (Schema Mundial)';
	BEGIN TRY
		EXEC Mundial.sp_incluir_pais @CodigoPais = 'XXA', @AñoMundial = @añoMundialTest, @Grupo = 'A';
		EXEC Mundial.sp_incluir_pais @CodigoPais = 'XXB', @AñoMundial = @añoMundialTest, @Grupo = 'A';
		EXEC Mundial.sp_habilitar_arbitro @AñoMundial = @añoMundialTest, @ArbitroID = @arbitroIDTest;

		PRINT 'Testeo exitoso: ' + @NombreTesteo;
	END TRY
	BEGIN CATCH
		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;
	END CATCH

	---------------------------------------------------------

	SET @NombreTesteo = '[PERMITIDO] Crear partido, designar árbitro, terminar partido y consultar resumen';
	BEGIN TRY
		DECLARE @selAID INT = (SELECT seleccion_id FROM Mundial.Paises_Participes WHERE mundial_id = @añoMundialTest AND pais_id = 'XXA');
		DECLARE @selBID INT = (SELECT seleccion_id FROM Mundial.Paises_Participes WHERE mundial_id = @añoMundialTest AND pais_id = 'XXB');
		DECLARE @partidoIDTest INT;

		EXEC Partidos.sp_crear_partido 
			@AñoMundial = @añoMundialTest,
			@SeleccionAID = @selAID,
			@SeleccionBID = @selBID,
			@SedeID = @sedeIDTest,
			@FechaYHora = '9999-01-05 18:00:00',
			@Fase = 'GRUPOS',
			@ID = @partidoIDTest OUTPUT;

		EXEC Arbitraje.sp_designar_arbitro 
			@PartidoID = @partidoIDTest,
			@ArbitroID = @arbitroIDTest,
			@Rol = 'PRINCIPAL';

		EXEC Partidos.sp_terminar_partido 
			@PartidoID = @partidoIDTest;

		IF NOT EXISTS (SELECT 1 FROM Partidos.vw_resumen_partido WHERE id = @partidoIDTest)
			THROW 50001, 'No pudo consultar el resumen del partido.', 1;

		PRINT 'Testeo exitoso: ' + @NombreTesteo;
	END TRY
	BEGIN CATCH
		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;
	END CATCH

	---------------------------------------------------------
	-- CASOS NEGATIVOS (Lo que NO puede hacer)
	---------------------------------------------------------

	SET @NombreTesteo = '[DENEGADO] Ejecutar SP de Partidos fuera de su alcance (Partidos.sp_definir_formacion_inicial)';
	BEGIN TRY
		EXEC Partidos.sp_definir_formacion_inicial 
			@Jugando = 1,
			@Posicion = 'GK',
			@PartidoID = @partidoIDTest,
			@JugadorID = 1,
			@SeleccionID = @selAID;

		THROW 50001, 'ERROR DE SEGURIDAD: El organizador pudo definir formación inicial.', 1;
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

	SET @NombreTesteo = '[DENEGADO] Ejecutar SP de otro esquema (Eventos.sp_registrar_gol)';
	BEGIN TRY
		EXEC Eventos.sp_registrar_gol 
			@Minuto = 10,
			@Extra = 0,
			@Tiempo = 1,
			@PartidoID = @partidoIDTest,
			@Tipo = 'N',
			@JugadorID = 1;

		THROW 50001, 'ERROR DE SEGURIDAD: El organizador pudo registrar un gol.', 1;
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

	SET @NombreTesteo = '[DENEGADO] Ejecutar SP de otro esquema (Arbitraje.sp_crear_arbitro)';
	BEGIN TRY
		EXEC Arbitraje.sp_crear_arbitro 
			@CodigoPais = 'XXC',
			@Nombre = 'Arbitro',
			@Apellido = 'Ilegal';

		THROW 50001, 'ERROR DE SEGURIDAD: El organizador pudo crear un árbitro.', 1;
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

	SET @NombreTesteo = '[DENEGADO] INSERT directo en tabla de su propio esquema (Mundial.Mundiales)';
	BEGIN TRY
		INSERT INTO Mundial.Mundiales (f_inicio, f_fin) 
		VALUES ('9997-01-01', '9997-02-01');

		THROW 50001, 'ERROR DE SEGURIDAD: Se permitió INSERT directo en Mundial.Mundiales.', 1;
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

	SET @NombreTesteo = '[DENEGADO] UPDATE directo en tabla de su propio ámbito (Partidos.Partidos)';
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

	SET @NombreTesteo = '[DENEGADO] DELETE directo en tabla de su propio esquema (Mundial.Paises_Participes)';
	BEGIN TRY
		DELETE FROM Mundial.Paises_Participes 
		WHERE mundial_id = @añoMundialTest;

		THROW 50001, 'ERROR DE SEGURIDAD: Se permitió DELETE directo en Mundial.Paises_Participes.', 1;
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
	PRINT 'TODOS LOS TESTEOS DE [usr_organizador] PASARON OK';
	PRINT '====================================================';

END TRY
BEGIN CATCH
	IF USER_NAME() = 'usr_organizador'
		REVERT;

	IF @@TRANCOUNT > 0
		ROLLBACK TRANSACTION;

	PRINT '';
	PRINT 'Testeo fallido: ' + ISNULL(@NombreTesteo, 'Setup inicial');
	THROW;
END CATCH;
GO