/* BBDD/Testeos/19-Testing-Rol-Delegado-Seleccion.sql
 * Fecha: 21/11/2026
 * Lista, Matías Josué.
 * Descripción: Verifica los permisos otorgados y denegados para el usuario
 *              [usr_delegado_de_seleccion] asociado al rol [rol_delegado_de_seleccion].
 **/

USE GestionDelMundial;
GO
SET NOCOUNT ON;

DECLARE @ErrorRecibido VARCHAR(MAX);
DECLARE @NombreTesteo  VARCHAR(200);

BEGIN TRY
BEGIN TRANSACTION ComienzoTesteo;

	---------------------------------------------------------
	--  crear datos ficticios
	---------------------------------------------------------

	DECLARE @confederacionIDTest INT;
	EXEC Administracion.sp_crear_confederacion 
		@Nombre = 'Confederacion Test Del',
		@siglas = 'CTD',
		@FFundacion = '2000-01-01',
		@ID = @confederacionIDTest OUTPUT;

	-- Países ficticios (XXD será nuestra selección, XXE el rival)
	EXEC Administracion.sp_crear_pais @Nombre = 'Pais Delegado A', @Codigo = 'XXD', @ConfederacionID = @confederacionIDTest;
	EXEC Administracion.sp_crear_pais @Nombre = 'Pais Delegado B', @Codigo = 'XXE', @ConfederacionID = @confederacionIDTest;
	UPDATE Administracion.Paises SET zona_horaria = 'UTC' WHERE codigo = 'XXD';

	DECLARE @sedeIDTest INT;
	EXEC Administracion.sp_crear_sede 
		@CodigoPais = 'XXD',
		@Nombre = 'Estadio Test Delegado',
		@Ciudad = 'Ciudad Test',
		@Capacidad = 50000,
		@ID = @sedeIDTest OUTPUT;

	DECLARE @clubIDTest INT;
	EXEC Administracion.sp_crear_club 
		@Nombre = 'Club Test Delegado FC',
		@ID = @clubIDTest OUTPUT;

	DECLARE @añoMundialTest INT = 9999;
	EXEC Mundial.sp_crear_mundial 
		@FInicio = '9999-01-01',
		@FFin = '9999-02-02',
		@LimiteJugadoresConvocados = 26,
		@LimiteStaffConvocados = 10,
		@ArbitroDeVarRequerido = 1,
		@CantidadDeEquipos = 16;

	EXEC Mundial.sp_incluir_pais @CodigoPais = 'XXD', @AñoMundial = @añoMundialTest, @Grupo = 'A';
	EXEC Mundial.sp_incluir_pais @CodigoPais = 'XXE', @AñoMundial = @añoMundialTest, @Grupo = 'A';

	DECLARE @selDID INT = (SELECT seleccion_id FROM Mundial.Paises_Participes WHERE mundial_id = @añoMundialTest AND pais_id = 'XXD');
	DECLARE @selEID INT = (SELECT seleccion_id FROM Mundial.Paises_Participes WHERE mundial_id = @añoMundialTest AND pais_id = 'XXE');

	DECLARE @partidoIDTest INT;
	EXEC Partidos.sp_crear_partido 
		@AñoMundial = @añoMundialTest,
		@SeleccionAID = @selDID,
		@SeleccionBID = @selEID,
		@SedeID = @sedeIDTest,
		@FechaYHora = '9999-01-05 18:00:00',
		@Fase = 'GRUPOS',
		@ID = @partidoIDTest OUTPUT;

	-- Creamos 12 jugadores en el padrón (11 titulares + 1 suplente para cumplir la regla del banco)
	DECLARE @JugadoresTest TABLE (nro INT IDENTITY(1,1), jugador_id INT);
	DECLARE @i INT = 1;
	DECLARE @jugadorTempID INT;
	DECLARE @nombreTemp VARCHAR(100);

	WHILE @i <= 12
	BEGIN
		SET @nombreTemp = CONCAT('JugadorDel_', @i);
		EXEC Equipos.sp_crear_integrante_seleccion 
			@CodigoPais = 'XXD',
			@Nombre = @nombreTemp,
			@Apellido = 'TestDel',
			@FNacimiento = '1997-03-10',
			@ID = @jugadorTempID OUTPUT;

		INSERT INTO @JugadoresTest (jugador_id) VALUES (@jugadorTempID);
		SET @i = @i + 1;
	END;

	---------------------------------------------------------
	-- 2. CAMBIO DE CONTEXTO AL USUARIO A TESTEAR
	---------------------------------------------------------
	EXECUTE AS USER = 'usr_delegado_de_seleccion';

	PRINT '====================================================';
	PRINT 'INICIO TESTEOS ROL: rol_delegado_de_seleccion (usr_delegado_de_seleccion)';
	PRINT '====================================================';

	---------------------------------------------------------
	-- CASOS POSITIVOS (Lo que SÍ puede hacer)
	---------------------------------------------------------

	SET @NombreTesteo = '[PERMITIDO] Convocar 12 jugadores al mundial y consultar convocados/disponibles';
	BEGIN TRY
		DECLARE @idx INT = 1;
		DECLARE @idActual INT;

		WHILE @idx <= 12
		BEGIN
			SELECT @idActual = jugador_id FROM @JugadoresTest WHERE nro = @idx;

			EXEC Equipos.sp_convocar_jugador 
				@AñoMundial = @añoMundialTest,
				@MiembroID = @idActual,
				@FConvocacion = '9998-12-01',
				@Dorsal = @idx,
				@ClubID = @clubIDTest;

			SET @idx = @idx + 1;
		END;

		IF (SELECT COUNT(*) FROM Equipos.fn_obtener_jugadores_convocados(@selDID)) <> 12
			THROW 50001, 'No se reflejaron los 12 jugadores convocados.', 1;

		IF (SELECT COUNT(*) FROM Partidos.fn_jugadores_disponibles(@partidoIDTest, @selDID)) <> 12
			THROW 50001, 'No se reflejaron los 12 jugadores disponibles para el partido.', 1;

		PRINT 'Testeo exitoso: ' + @NombreTesteo;
	END TRY
	BEGIN CATCH
		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;
	END CATCH

	---------------------------------------------------------

	SET @NombreTesteo = '[PERMITIDO] Definir formación inicial (11 titulares + 1 suplente) y consultar cancha';
	BEGIN TRY
		DECLARE @j INT = 1;
		DECLARE @jugID INT;
		DECLARE @suplenteID INT;

		-- Los primeros 11 arrancan de titulares (@Jugando = 1)
		WHILE @j <= 11
		BEGIN
			SELECT @jugID = jugador_id FROM @JugadoresTest WHERE nro = @j;

			EXEC Partidos.sp_definir_formacion_inicial 
				@Jugando = 1,
				@Posicion = 'MC',
				@PartidoID = @partidoIDTest,
				@JugadorID = @jugID,
				@SeleccionID = @selDID;

			SET @j = @j + 1;
		END;

		-- El jugador 12 arranca en el banco (@Jugando = 0)
		SELECT @suplenteID = jugador_id FROM @JugadoresTest WHERE nro = 12;

		EXEC Partidos.sp_definir_formacion_inicial 
			@Jugando = 0,
			@Posicion = 'DL',
			@PartidoID = @partidoIDTest,
			@JugadorID = @suplenteID,
			@SeleccionID = @selDID;

		-- Al minuto 0 del tiempo 1 deben figurar exactamente 11 jugadores en cancha y no el suplente
		IF (SELECT COUNT(*) FROM Partidos.fn_jugadores_en_cancha(@partidoIDTest, 0, 0, 1)) <> 11
			THROW 50001, 'La cantidad de jugadores en cancha al inicio no es 11.', 1;

		IF EXISTS (SELECT 1 FROM Partidos.fn_jugadores_en_cancha(@partidoIDTest, 0, 0, 1) WHERE jugador_id = @suplenteID)
			THROW 50001, 'El jugador suplente figura erróneamente dentro de la cancha.', 1;

		PRINT 'Testeo exitoso: ' + @NombreTesteo;
	END TRY
	BEGIN CATCH
		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;
	END CATCH

	---------------------------------------------------------
	-- CASOS NEGATIVOS (Lo que NO puede hacer)
	---------------------------------------------------------

	SET @NombreTesteo = '[DENEGADO] Ejecutar SP de Equipos fuera de su alcance (Equipos.sp_crear_integrante_seleccion)';
	BEGIN TRY
		EXEC Equipos.sp_crear_integrante_seleccion 
			@CodigoPais = 'XXD',
			@Nombre = 'JugadorIlegal',
			@Apellido = 'Delegado',
			@FNacimiento = '2000-01-01';

		THROW 50001, 'ERROR DE SEGURIDAD: El delegado pudo dar de alta un integrante de selección.', 1;
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

	SET @NombreTesteo = '[DENEGADO] Ejecutar SP de Partidos fuera de su alcance (Partidos.sp_terminar_partido)';
	BEGIN TRY
		EXEC Partidos.sp_terminar_partido 
			@PartidoID = @partidoIDTest;

		THROW 50001, 'ERROR DE SEGURIDAD: El delegado pudo finalizar un partido.', 1;
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
		DECLARE @primerTitularID INT = (SELECT jugador_id FROM @JugadoresTest WHERE nro = 1);

		EXEC Eventos.sp_registrar_gol 
			@Minuto = 15,
			@Extra = 0,
			@Tiempo = 1,
			@PartidoID = @partidoIDTest,
			@Tipo = 'N',
			@JugadorID = @primerTitularID;

		THROW 50001, 'ERROR DE SEGURIDAD: El delegado pudo registrar un gol.', 1;
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

	SET @NombreTesteo = '[DENEGADO] INSERT directo en tabla de su propio ámbito (Equipos.ConvocacionEnSeleccion)';
	BEGIN TRY
		INSERT INTO Equipos.ConvocacionEnSeleccion 
			(seleccion_id, miembro_id, tipo, f_convocacion, dorsal, club_id)
		VALUES 
			(@selDID, @suplenteID, 'Jugador', '9998-12-01', 25, @clubIDTest);

		THROW 50001, 'ERROR DE SEGURIDAD: Se permitió INSERT directo en Equipos.ConvocacionEnSeleccion.', 1;
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

	SET @NombreTesteo = '[DENEGADO] UPDATE directo en tabla de su propio ámbito (Partidos.JugadorPosicionInicial)';
	BEGIN TRY
		UPDATE Partidos.JugadorPosicionInicial 
		SET posicion = 'AR' 
		WHERE partido_id = @partidoIDTest AND jugador_id = @suplenteID;

		THROW 50001, 'ERROR DE SEGURIDAD: Se permitió UPDATE directo en Partidos.JugadorPosicionInicial.', 1;
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

	SET @NombreTesteo = '[DENEGADO] DELETE directo en tabla de su propio ámbito (Equipos.ConvocacionEnSeleccion)';
	BEGIN TRY
		DELETE FROM Equipos.ConvocacionEnSeleccion 
		WHERE seleccion_id = @selDID;

		THROW 50001, 'ERROR DE SEGURIDAD: Se permitió DELETE directo en Equipos.ConvocacionEnSeleccion.', 1;
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
	PRINT 'TODOS LOS TESTEOS DE [usr_delegado_de_seleccion] PASARON OK';
	PRINT '====================================================';

END TRY
BEGIN CATCH
	IF USER_NAME() = 'usr_delegado_de_seleccion'
		REVERT;

	IF @@TRANCOUNT > 0
		ROLLBACK TRANSACTION;

	PRINT '';
	PRINT 'Testeo fallido: ' + ISNULL(@NombreTesteo, 'Setup inicial');
	THROW;
END CATCH;
GO