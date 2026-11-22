/* BBDD/Testeos/21-Testing-Rol-Cargador-Resultados.sql
 * Fecha: 21/11/2026
 * Lista, Matías Josué.
 * Descripción: Verifica los permisos otorgados y denegados para el usuario
 *              [usr_cargador_de_resultados] asociado al rol [rol_cargador_de_resultados].
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
		@Nombre = 'Confederacion Test Res',
		@siglas = 'CTR',
		@FFundacion = '2000-01-01',
		@ID = @confederacionIDTest OUTPUT;

	EXEC Administracion.sp_crear_pais @Nombre = 'Pais Res A', @Codigo = 'XXR', @ConfederacionID = @confederacionIDTest;
	EXEC Administracion.sp_crear_pais @Nombre = 'Pais Res B', @Codigo = 'XXS', @ConfederacionID = @confederacionIDTest;
	UPDATE Administracion.Paises SET zona_horaria = 'UTC' WHERE codigo = 'XXR';

	DECLARE @sedeIDTest INT;
	EXEC Administracion.sp_crear_sede 
		@CodigoPais = 'XXR',
		@Nombre = 'Estadio Test Resultados',
		@Ciudad = 'Ciudad Test',
		@Capacidad = 50000,
		@ID = @sedeIDTest OUTPUT;

	DECLARE @clubIDTest INT;
	EXEC Administracion.sp_crear_club 
		@Nombre = 'Club Test Resultados FC',
		@ID = @clubIDTest OUTPUT;

	DECLARE @añoMundialTest INT = 9999;
	EXEC Mundial.sp_crear_mundial 
		@FInicio = '9999-01-01',
		@FFin = '9999-02-02',
		@LimiteJugadoresConvocados = 26,
		@LimiteStaffConvocados = 10,
		@ArbitroDeVarRequerido = 1,
		@CantidadDeEquipos = 16;

	EXEC Mundial.sp_incluir_pais @CodigoPais = 'XXR', @AñoMundial = @añoMundialTest, @Grupo = 'A';
	EXEC Mundial.sp_incluir_pais @CodigoPais = 'XXS', @AñoMundial = @añoMundialTest, @Grupo = 'A';

	DECLARE @selRID INT = (SELECT seleccion_id FROM Mundial.Paises_Participes WHERE mundial_id = @añoMundialTest AND pais_id = 'XXR');
	DECLARE @selSID INT = (SELECT seleccion_id FROM Mundial.Paises_Participes WHERE mundial_id = @añoMundialTest AND pais_id = 'XXS');

	DECLARE @partidoIDTest INT;
	EXEC Partidos.sp_crear_partido 
		@AñoMundial = @añoMundialTest,
		@SeleccionAID = @selRID,
		@SeleccionBID = @selSID,
		@SedeID = @sedeIDTest,
		@FechaYHora = '9999-01-05 18:00:00',
		@Fase = 'CUARTOS',
		@ID = @partidoIDTest OUTPUT;

	-- Creamos, convocamos y definimos formación inicial de 12 jugadores (11 titulares + 1 suplente)
	DECLARE @JugadoresTest TABLE (nro INT IDENTITY(1,1), jugador_id INT);
	DECLARE @i INT = 1;
	DECLARE @jugTempID INT;
	DECLARE @nomTemp VARCHAR(100);

	WHILE @i <= 12
	BEGIN
		SET @nomTemp = CONCAT('JugadorRes_', @i);
		EXEC Equipos.sp_crear_integrante_seleccion 
			@CodigoPais = 'XXR',
			@Nombre = @nomTemp,
			@Apellido = 'TestRes',
			@FNacimiento = '1996-05-10',
			@ID = @jugTempID OUTPUT;

		INSERT INTO @JugadoresTest (jugador_id) VALUES (@jugTempID);

		EXEC Equipos.sp_convocar_jugador 
			@AñoMundial = @añoMundialTest,
			@MiembroID = @jugTempID,
			@FConvocacion = '9998-12-01',
			@Dorsal = @i,
			@ClubID = @clubIDTest;

		IF @i <= 11
			EXEC Partidos.sp_definir_formacion_inicial 
				@Jugando = 1, @Posicion = 'MC', @PartidoID = @partidoIDTest, @JugadorID = @jugTempID, @SeleccionID = @selRID;
		ELSE
			EXEC Partidos.sp_definir_formacion_inicial 
				@Jugando = 0, @Posicion = 'DL', @PartidoID = @partidoIDTest, @JugadorID = @jugTempID, @SeleccionID = @selRID;

		SET @i = @i + 1;
	END;

	DECLARE @titular1ID INT = (SELECT jugador_id FROM @JugadoresTest WHERE nro = 1);
	DECLARE @titular2ID INT = (SELECT jugador_id FROM @JugadoresTest WHERE nro = 2);
	DECLARE @titular3ID INT = (SELECT jugador_id FROM @JugadoresTest WHERE nro = 3);
	DECLARE @suplenteID INT = (SELECT jugador_id FROM @JugadoresTest WHERE nro = 12);

	---------------------------------------------------------
	-- 2. CAMBIO DE CONTEXTO AL USUARIO A TESTEAR
	---------------------------------------------------------
	EXECUTE AS USER = 'usr_cargador_de_resultados';

	PRINT '====================================================';
	PRINT 'INICIO TESTEOS ROL: rol_cargador_de_resultados (usr_cargador_de_resultados)';
	PRINT '====================================================';

	---------------------------------------------------------
	-- CASOS POSITIVOS (Lo que SÍ puede hacer)
	---------------------------------------------------------

	SET @NombreTesteo = '[PERMITIDO] Registrar gol con asistencia y amonestación en el partido';
	BEGIN TRY
		EXEC Eventos.sp_registrar_gol 
			@Minuto = 12,
			@Extra = 0,
			@Tiempo = 1,
			@PartidoID = @partidoIDTest,
			@Tipo = 'N',
			@JugadorID = @titular1ID,
			@JugadorAsistenteID = @titular2ID;

		EXEC Eventos.sp_registrar_amonestacion 
			@Minuto = 30,
			@Extra = 0,
			@Tiempo = 1,
			@PartidoID = @partidoIDTest,
			@JugadorID = @titular3ID,
			@Tarjeta = 'A',
			@Motivo = 'Falta táctica en mediocampo';

		IF NOT EXISTS (SELECT 1 FROM Eventos.Goles WHERE partido_id = @partidoIDTest AND jugador_autor_id = @titular1ID)
			THROW 50001, 'No se registró el gol.', 1;

		IF NOT EXISTS (SELECT 1 FROM Eventos.Amonestaciones WHERE partido_id = @partidoIDTest AND jugador_id = @titular3ID)
			THROW 50001, 'No se registró la amonestación.', 1;

		PRINT 'Testeo exitoso: ' + @NombreTesteo;
	END TRY
	BEGIN CATCH
		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;
	END CATCH

	---------------------------------------------------------

	SET @NombreTesteo = '[PERMITIDO] Registrar cambio, penal de tanda y consultar resumen del partido';
	BEGIN TRY
		EXEC Eventos.sp_registrar_cambio 
			@Minuto = 20,
			@Extra = 0,
			@Tiempo = 2,
			@PartidoID = @partidoIDTest,
			@Motivo = 'TACTICO',
			@JugadorEntraID = @suplenteID,
			@JugadorSaleID = @titular2ID;

		-- Verificamos con la función permitida que el suplente ingresó a la cancha
		IF NOT EXISTS (
			SELECT 1 
			FROM Partidos.fn_jugadores_en_cancha(@partidoIDTest, 25, 0, 2) 
			WHERE jugador_id = @suplenteID
		)
			THROW 50001, 'El jugador ingresado no figura en cancha.', 1;

		EXEC Eventos.sp_registrar_penal_de_tanda 
			@PartidoID = @partidoIDTest,
			@JugadorID = @titular1ID,
			@Convirtio = 1;

		-- Consultamos la vista permitida Partidos.vw_resumen_partido
		IF NOT EXISTS (
			SELECT 1 
			FROM Partidos.vw_resumen_partido 
			WHERE id = @partidoIDTest AND goles_A = 1 AND goles_tanda_de_penales_A = 1
		)
			THROW 50001, 'El resumen del partido no refleja los goles/penales cargados.', 1;

		PRINT 'Testeo exitoso: ' + @NombreTesteo;
	END TRY
	BEGIN CATCH
		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;
	END CATCH

	---------------------------------------------------------
	-- CASOS NEGATIVOS (Lo que NO puede hacer)
	---------------------------------------------------------

	SET @NombreTesteo = '[DENEGADO] Ejecutar SP de otro esquema (Partidos.sp_terminar_partido)';
	BEGIN TRY
		EXEC Partidos.sp_terminar_partido 
			@PartidoID = @partidoIDTest;

		THROW 50001, 'ERROR DE SEGURIDAD: El cargador de resultados pudo finalizar un partido.', 1;
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

	SET @NombreTesteo = '[DENEGADO] Ejecutar SP de otro esquema (Partidos.sp_definir_formacion_inicial)';
	BEGIN TRY
		EXEC Partidos.sp_definir_formacion_inicial 
			@Jugando = 1,
			@Posicion = 'AR',
			@PartidoID = @partidoIDTest,
			@JugadorID = @titular1ID,
			@SeleccionID = @selRID;

		THROW 50001, 'ERROR DE SEGURIDAD: El cargador de resultados pudo modificar la formación inicial.', 1;
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

	SET @NombreTesteo = '[DENEGADO] Consultar tabla base sin permiso (Partidos.Partidos)';
	BEGIN TRY
		SELECT * FROM Partidos.Partidos WHERE id = @partidoIDTest;

		THROW 50001, 'ERROR DE SEGURIDAD: El cargador de resultados pudo consultar directamente Partidos.Partidos.', 1;
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

	SET @NombreTesteo = '[DENEGADO] INSERT directo en tabla de su propio esquema (Eventos.Goles)';
	BEGIN TRY
		INSERT INTO Eventos.Goles (partido_id, jugador_autor_id, tipo, minuto, extra, tiempo) 
		VALUES (@partidoIDTest, @titular1ID, 'N', 40, 0, 1);

		THROW 50001, 'ERROR DE SEGURIDAD: Se permitió INSERT directo en Eventos.Goles.', 1;
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

	SET @NombreTesteo = '[DENEGADO] UPDATE directo en tabla de su propio esquema (Eventos.Goles)';
	BEGIN TRY
		UPDATE Eventos.Goles 
		SET minuto = 44 
		WHERE partido_id = @partidoIDTest;

		THROW 50001, 'ERROR DE SEGURIDAD: Se permitió UPDATE directo en Eventos.Goles.', 1;
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

	SET @NombreTesteo = '[DENEGADO] DELETE directo en tabla de su propio esquema (Eventos.Goles)';
	BEGIN TRY
		DELETE FROM Eventos.Goles 
		WHERE partido_id = @partidoIDTest;

		THROW 50001, 'ERROR DE SEGURIDAD: Se permitió DELETE directo en Eventos.Goles.', 1;
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
	PRINT 'TODOS LOS TESTEOS DE [usr_cargador_de_resultados] PASARON OK';
	PRINT '====================================================';

END TRY
BEGIN CATCH
	IF USER_NAME() = 'usr_cargador_de_resultados'
		REVERT;

	IF @@TRANCOUNT > 0
		ROLLBACK TRANSACTION;

	PRINT '';
	PRINT 'Testeo fallido: ' + ISNULL(@NombreTesteo, 'Setup inicial');
	THROW;
END CATCH;
GO