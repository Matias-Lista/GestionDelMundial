/* BBDD/Testeos/11-Testing-Administracion.sql
 * Fecha: 14/10/2026
 * Lista, Matías Josué.
 * Descripción: Ejecuta todos los store procedures del schema [Mundial], 
 				comprobando que las inserciones y modificaciones sean correctas,
 				y que los errores sean los esperados.
 **/

USE GestionDelMundial;
GO
SET NOCOUNT ON

DECLARE @ErrorRecibido VARCHAR(MAX);
DECLARE @ErrorEsperado VARCHAR(MAX);
DECLARE @NombreTesteo  VARCHAR(200);

BEGIN TRY
BEGIN TRANSACTION ComienzoTesteo

---------------------------------------------------------
	-- Creación de datos necesarios para los testeos
	-- Datos iniciales para testear Mundial.sp_eliminar_mundial

	-- 1. Mundial para eliminar exitosamente
	EXEC Mundial.sp_crear_mundial 
		@FInicio = '2042-06-01',
		@FFin = '2042-07-01',
		@LimiteJugadoresConvocados = 26,
		@LimiteStaffConvocados = 15,
		@ArbitroDeVarRequerido = 1,
		@CantidadDeEquipos = 32;

	-- 2. Mundial con dependencias para probar fallas por vinculaciones
	EXEC Mundial.sp_crear_mundial 
		@FInicio = '2046-06-01',
		@FFin = '2046-07-01',
		@LimiteJugadoresConvocados = 26,
		@LimiteStaffConvocados = 15,
		@ArbitroDeVarRequerido = 1,
		@CantidadDeEquipos = 32;

	-- Creamos entidades auxiliares para vincular al mundial 2046
	DECLARE @ConfIDPrueba INT;
	EXEC Administracion.sp_crear_confederacion @Nombre = 'Confed Mundial Test', @siglas = 'CMT', @FFundacion = '2000-01-01', @ID = @ConfIDPrueba OUTPUT;

	EXEC Administracion.sp_crear_pais @Nombre = 'Pais Mundial Test', @Codigo = 'PMT', @ConfederacionID = @ConfIDPrueba;

	DECLARE @SedeMundialID INT;
	EXEC Administracion.sp_crear_sede @CodigoPais = 'PMT', @Nombre = 'Sede Mundial Test', @Ciudad = 'Ciudad Test', @Capacidad = 50000, @ID = @SedeMundialID OUTPUT;

	DECLARE @ConfCONMEBOL INT, @ConfUEFA INT;

	EXEC Administracion.sp_crear_confederacion @Nombre = 'CONMEBOL', @siglas = 'CSF', @FFundacion = '1916-07-09', @ID = @ConfCONMEBOL OUTPUT;
	EXEC Administracion.sp_crear_confederacion @Nombre = 'UEFA', @siglas = 'UEFA', @FFundacion = '1954-06-15', @ID = @ConfUEFA OUTPUT;


	DECLARE @ArbitroMundialID INT;
	INSERT INTO Arbitraje.Arbitros (pais_id, nombre, apellido, es_mujer, confederacion_id) VALUES ('PMT', 'Arbitro', 'Test', 0, @ConfCONMEBOL);
	SET @ArbitroMundialID = SCOPE_IDENTITY();

	-- Insertamos relaciones en cada tabla vinculada
	INSERT INTO Partidos.Partidos (mundial_id, sede_id, fecha_y_hora, fase) VALUES (2046, @SedeMundialID, '2046-06-15 18:00:00', 'GRUPOS');
	INSERT INTO Mundial.Paises_Participes (pais_id, mundial_id) VALUES ('PMT', 2046);
	INSERT INTO Mundial.Habilitacion_Arbitro (mundial_id, arbitro_id) VALUES (2046, @ArbitroMundialID);
	INSERT INTO Publicidad.Tarifas (franja, fase, costo, mundial_id) VALUES ('P', 'GRUPOS', 1000.00, 2046);
	
	---------------------------------------------------------
	-- Setup de datos iniciales para Mundial.sp_incluir_pais
	---------------------------------------------------------
	
	-- Países reales
	EXEC Administracion.sp_crear_pais @Nombre = 'Argentina', @Codigo = 'ARG', @ConfederacionID = @ConfCONMEBOL;
	EXEC Administracion.sp_crear_pais @Nombre = 'Brasil', @Codigo = 'BRA', @ConfederacionID = @ConfCONMEBOL;
	EXEC Administracion.sp_crear_pais @Nombre = 'Uruguay', @Codigo = 'URU', @ConfederacionID = @ConfCONMEBOL;
	EXEC Administracion.sp_crear_pais @Nombre = 'Chile', @Codigo = 'CHI', @ConfederacionID = @ConfCONMEBOL;
	EXEC Administracion.sp_crear_pais @Nombre = 'Colombia', @Codigo = 'COL', @ConfederacionID = @ConfCONMEBOL;
	EXEC Administracion.sp_crear_pais @Nombre = 'Perú', @Codigo = 'PER', @ConfederacionID = @ConfCONMEBOL;
	EXEC Administracion.sp_crear_pais @Nombre = 'Ecuador', @Codigo = 'ECU', @ConfederacionID = @ConfCONMEBOL;
	EXEC Administracion.sp_crear_pais @Nombre = 'Paraguay', @Codigo = 'PAR', @ConfederacionID = @ConfCONMEBOL;
	EXEC Administracion.sp_crear_pais @Nombre = 'Venezuela', @Codigo = 'VEN', @ConfederacionID = @ConfCONMEBOL;
	EXEC Administracion.sp_crear_pais @Nombre = 'Bolivia', @Codigo = 'BOL', @ConfederacionID = @ConfCONMEBOL;
	EXEC Administracion.sp_crear_pais @Nombre = 'Francia', @Codigo = 'FRA', @ConfederacionID = @ConfUEFA;
	EXEC Administracion.sp_crear_pais @Nombre = 'Alemania', @Codigo = 'GER', @ConfederacionID = @ConfUEFA;
	EXEC Administracion.sp_crear_pais @Nombre = 'España', @Codigo = 'ESP', @ConfederacionID = @ConfUEFA;
	EXEC Administracion.sp_crear_pais @Nombre = 'Italia', @Codigo = 'ITA', @ConfederacionID = @ConfUEFA;
	EXEC Administracion.sp_crear_pais @Nombre = 'Inglaterra', @Codigo = 'ENG', @ConfederacionID = @ConfUEFA;
	EXEC Administracion.sp_crear_pais @Nombre = 'Holanda', @Codigo = 'NED', @ConfederacionID = @ConfUEFA;
	EXEC Administracion.sp_crear_pais @Nombre = 'Portugal', @Codigo = 'POR', @ConfederacionID = @ConfUEFA;

	-- Mundial principal para pruebas generales (16 equipos = 4 grupos A, B, C, D) en el año 2050
	EXEC Mundial.sp_crear_mundial 
		@FInicio = '2050-06-01',
		@FFin = '2050-07-01',
		@LimiteJugadoresConvocados = 26,
		@LimiteStaffConvocados = 15,
		@ArbitroDeVarRequerido = 1,
		@CantidadDeEquipos = 16;

	-- Mundial auxiliar para probar cupo alcanzado (16 equipos) en el año 2090
	EXEC Mundial.sp_crear_mundial 
		@FInicio = '2090-06-01',
		@FFin = '2090-07-01',
		@LimiteJugadoresConvocados = 26,
		@LimiteStaffConvocados = 15,
		@ArbitroDeVarRequerido = 1,
		@CantidadDeEquipos = 16;

	-- Llenamos el Grupo B del Mundial 2050 (4 países) para probar "Grupo Lleno"
	EXEC Mundial.sp_incluir_pais @CodigoPais = 'URU', @AñoMundial = 2050, @Grupo = 'B';
	EXEC Mundial.sp_incluir_pais @CodigoPais = 'CHI', @AñoMundial = 2050, @Grupo = 'B';
	EXEC Mundial.sp_incluir_pais @CodigoPais = 'COL', @AñoMundial = 2050, @Grupo = 'B';
	EXEC Mundial.sp_incluir_pais @CodigoPais = 'PER', @AñoMundial = 2050, @Grupo = 'B';

	-- Llenamos completamente el Mundial 2090 (16 países) para probar "Cupo Alcanzado"
	EXEC Mundial.sp_incluir_pais @CodigoPais = 'ARG', @AñoMundial = 2090;
	EXEC Mundial.sp_incluir_pais @CodigoPais = 'BRA', @AñoMundial = 2090;
	EXEC Mundial.sp_incluir_pais @CodigoPais = 'URU', @AñoMundial = 2090;
	EXEC Mundial.sp_incluir_pais @CodigoPais = 'CHI', @AñoMundial = 2090;
	EXEC Mundial.sp_incluir_pais @CodigoPais = 'COL', @AñoMundial = 2090;
	EXEC Mundial.sp_incluir_pais @CodigoPais = 'PER', @AñoMundial = 2090;
	EXEC Mundial.sp_incluir_pais @CodigoPais = 'ECU', @AñoMundial = 2090;
	EXEC Mundial.sp_incluir_pais @CodigoPais = 'PAR', @AñoMundial = 2090;
	EXEC Mundial.sp_incluir_pais @CodigoPais = 'VEN', @AñoMundial = 2090;
	EXEC Mundial.sp_incluir_pais @CodigoPais = 'BOL', @AñoMundial = 2090;
	EXEC Mundial.sp_incluir_pais @CodigoPais = 'FRA', @AñoMundial = 2090;
	EXEC Mundial.sp_incluir_pais @CodigoPais = 'GER', @AñoMundial = 2090;
	EXEC Mundial.sp_incluir_pais @CodigoPais = 'ESP', @AñoMundial = 2090;
	EXEC Mundial.sp_incluir_pais @CodigoPais = 'ITA', @AñoMundial = 2090;
	EXEC Mundial.sp_incluir_pais @CodigoPais = 'ENG', @AñoMundial = 2090;
	EXEC Mundial.sp_incluir_pais @CodigoPais = 'NED', @AñoMundial = 2090;
	
	---------------------------------------------------------
	-- Setup de datos iniciales para Mundial.sp_remover_pais
	---------------------------------------------------------
	-- Mundial 2060
	EXEC Mundial.sp_crear_mundial 
		@FInicio = '2060-06-01',
		@FFin = '2060-07-01',
		@LimiteJugadoresConvocados = 26,
		@LimiteStaffConvocados = 15,
		@ArbitroDeVarRequerido = 1,
		@CantidadDeEquipos = 16;

	-- 1. País sin partidos ni convocados (para remover exitosamente)
	EXEC Mundial.sp_incluir_pais @CodigoPais = 'FRA', @AñoMundial = 2060;

	-- 2. Países para armar un partido
	EXEC Mundial.sp_incluir_pais @CodigoPais = 'GER', @AñoMundial = 2060;
	EXEC Mundial.sp_incluir_pais @CodigoPais = 'ITA', @AñoMundial = 2060;

	DECLARE @SeleccionGER INT = (SELECT seleccion_id FROM Mundial.Paises_Participes WHERE pais_id = 'GER' AND mundial_id = 2060);
	DECLARE @SeleccionITA INT = (SELECT seleccion_id FROM Mundial.Paises_Participes WHERE pais_id = 'ITA' AND mundial_id = 2060);

	DECLARE @SedeRemoverID INT;
	EXEC Administracion.sp_crear_sede @CodigoPais = 'GER', @Nombre = 'Estadio Remover', @Ciudad = 'Berlin', @Capacidad = 70000, @ID = @SedeRemoverID OUTPUT;

	-- 3. País con partidos Y convocados (para probar la acumulación de errores de vinculación)
	EXEC Mundial.sp_incluir_pais @CodigoPais = 'ENG', @AñoMundial = 2060;
	DECLARE @SeleccionENG INT = (SELECT seleccion_id FROM Mundial.Paises_Participes WHERE pais_id = 'ENG' AND mundial_id = 2060);

	-- Partido asignado
	INSERT INTO Partidos.Partidos (seleccion_A_id, seleccion_B_id, mundial_id, sede_id, fecha_y_hora, fase)
	VALUES (@SeleccionENG, @SeleccionITA, 2060, @SedeRemoverID, '2060-06-12 16:00:00', 'GRUPOS');

	-- Convocado asignado
	DECLARE @IntegranteENG INT;
	INSERT INTO Equipos.IntegranteSeleccion (pais_id, nombre, apellido, f_nacimiento)
	VALUES ('ENG', 'Harry', 'Kane', '1993-07-28');
	SET @IntegranteENG = SCOPE_IDENTITY();

	INSERT INTO Equipos.ConvocacionEnSeleccion (seleccion_id, miembro_id, tipo, f_convocacion, dorsal)
	VALUES (@SeleccionENG, @IntegranteENG, 'Jugador', '2060-05-01', 9);

	---------------------------------------------------------
	-- Setup de datos iniciales para Mundial.sp_habilitar_arbitro
	---------------------------------------------------------
	EXEC Mundial.sp_crear_mundial 
		@FInicio = '2070-06-01',
		@FFin = '2070-07-01',
		@LimiteJugadoresConvocados = 26,
		@LimiteStaffConvocados = 15,
		@ArbitroDeVarRequerido = 1,
		@CantidadDeEquipos = 16;

	DECLARE @ArbitroHabilitarID INT;
	INSERT INTO Arbitraje.Arbitros (pais_id, nombre, apellido, es_mujer, confederacion_id) 
	VALUES ('ESP', 'Antonio', 'Mateu Lahoz', 0,@ConfCONMEBOL);
	SET @ArbitroHabilitarID = SCOPE_IDENTITY();

	---------------------------------------------------------
	-- Setup de datos iniciales para Mundial.sp_remover_habilitacion_arbitro
	---------------------------------------------------------
	EXEC Mundial.sp_crear_mundial 
		@FInicio = '2080-06-01',
		@FFin = '2080-07-01',
		@LimiteJugadoresConvocados = 26,
		@LimiteStaffConvocados = 15,
		@ArbitroDeVarRequerido = 1,
		@CantidadDeEquipos = 16;

	-- 1. Árbitro habilitado sin partidos (para remover exitosamente)
	DECLARE @ArbitroRemoverExitoID INT;
	INSERT INTO Arbitraje.Arbitros (pais_id, nombre, apellido, es_mujer, confederacion_id) VALUES ('ARG', 'Patricio', 'Loustau', 0, @ConfCONMEBOL);
	SET @ArbitroRemoverExitoID = SCOPE_IDENTITY();

	EXEC Mundial.sp_habilitar_arbitro @AñoMundial = 2080, @ArbitroID = @ArbitroRemoverExitoID;

	-- 2. Árbitro habilitado y asignado a un partido de ese mundial (para probar falla por vinculación)
	DECLARE @ArbitroConPartidoID INT;
	INSERT INTO Arbitraje.Arbitros (pais_id, nombre, apellido, es_mujer, confederacion_id) VALUES ('BRA', 'Wilton', 'Sampaio', 0, @ConfCONMEBOL);
	SET @ArbitroConPartidoID = SCOPE_IDENTITY();

	EXEC Mundial.sp_habilitar_arbitro @AñoMundial = 2080, @ArbitroID = @ArbitroConPartidoID;

	DECLARE @SedeArbitroID INT;
	EXEC Administracion.sp_crear_sede @CodigoPais = 'ARG', @Nombre = 'Estadio Arbitro Test', @Ciudad = 'Buenos Aires', @Capacidad = 60000, @ID = @SedeArbitroID OUTPUT;

	DECLARE @PartidoArbitroID INT;
	INSERT INTO Partidos.Partidos (mundial_id, sede_id, fecha_y_hora, fase)
	VALUES (2080, @SedeArbitroID, '2080-06-10 18:00:00', 'GRUPOS');
	SET @PartidoArbitroID = SCOPE_IDENTITY();

	INSERT INTO Arbitraje.ArbitroAsignadoPartido (arbitro_id, partido_id, rol)
	VALUES (@ArbitroConPartidoID, @PartidoArbitroID, 'PRINCIPAL');

------------------------------------------------------
print ''
print 'Mundiales -------------'
----------------------------------------------------------------------

	SET @NombreTesteo = 'Crear Mundial Funciona';
	BEGIN TRY

		EXEC Mundial.sp_crear_mundial 
			@FInicio = '2034-06-01',
			@FFin = '2034-07-01',
			@LimiteJugadoresConvocados = 26,
			@LimiteStaffConvocados = 15,
			@ArbitroDeVarRequerido = 1,
			@CantidadDeEquipos = 32;
		
		IF NOT EXISTS (SELECT 1 FROM Mundial.Mundiales WHERE año = 2034)
			THROW 50001, 'No se creó el mundial en la tabla Mundial.Mundiales', 1;

		IF (SELECT COUNT(*) FROM Administracion.Reglas WHERE mundial_id = 2034) <> 4
			THROW 50001, 'No se registraron las 4 reglas requeridas para el mundial', 1;

		-- Muestra evidenciando la inserción en Mundiales y en Reglas
		SELECT * FROM Mundial.Mundiales WHERE año = 2034;
		SELECT * FROM Administracion.Reglas WHERE mundial_id = 2034;

		PRINT 'Testeo exitoso: ' + @NombreTesteo;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Crear Mundial Parámetros Nulos Falla';
	SET @ErrorEsperado = '- Debe indicar una fecha de inicio. ' + CHAR(13) + CHAR(10) +
						 '- Debe indicar una fecha de Fin. ' + CHAR(13) + CHAR(10) +
						 '- Debe indicar un límite de jugadores convocados. ' + CHAR(13) + CHAR(10) +
						 '- Debe indicar un límite de staff convocado. ' + CHAR(13) + CHAR(10) +
						 '- Debe indicar si se requiere un arbitro de var. ' + CHAR(13) + CHAR(10) +
						 '- Debe indicar la cantidad de equipos que juegan. ' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Mundial.sp_crear_mundial 
			@FInicio = NULL,
			@FFin = NULL,
			@LimiteJugadoresConvocados = NULL,
			@LimiteStaffConvocados = NULL,
			@ArbitroDeVarRequerido = NULL,
			@CantidadDeEquipos = NULL;

		THROW 50001, 'Se creó un mundial enviando parámetros NULL', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Crear Mundial Ya Existente Falla';
	SET @ErrorEsperado = '- Ya existe un mundial en ese año. ' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Mundial.sp_crear_mundial 
			@FInicio = '2034-06-01',
			@FFin = '2034-07-01',
			@LimiteJugadoresConvocados = 26,
			@LimiteStaffConvocados = 15,
			@ArbitroDeVarRequerido = 1,
			@CantidadDeEquipos = 32;

		THROW 50001, 'Se creó un mundial en un año que ya existía', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Crear Mundial Parámetros Inválidos Falla';
	SET @ErrorEsperado = '- La fecha de inicio debe ser anterior a la fecha de fin.' + CHAR(13) + CHAR(10) +
						 '- El límite de jugadores convocados debe ser un número positivo.' + CHAR(13) + CHAR(10) +
						 '- El límite de staff convocados debe ser un número positivo.' + CHAR(13) + CHAR(10) +
						 '- La cantidad de Equipos convocados debe ser al menos 16 y múltiplo de 4.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Mundial.sp_crear_mundial 
			@FInicio = '2038-07-01',
			@FFin = '2038-06-01',
			@LimiteJugadoresConvocados = -1,
			@LimiteStaffConvocados = 0,
			@ArbitroDeVarRequerido = 1,
			@CantidadDeEquipos = 18;

		THROW 50001, 'Se creó un mundial con parámetros fuera de regla', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH
----------------------------------------------------------------------

	SET @NombreTesteo = 'Eliminar Mundial Funciona';
	BEGIN TRY

		EXEC Mundial.sp_eliminar_mundial 
			@AñoMundial = 2042;
		
		-- Verificamos que no exista en Mundiales ni en Reglas
		IF EXISTS (SELECT 1 FROM Mundial.Mundiales WHERE año = 2042)
			THROW 50001, 'El mundial no fue eliminado de la tabla Mundial.Mundiales.', 1;

		IF EXISTS (SELECT 1 FROM Administracion.Reglas WHERE mundial_id = 2042)
			THROW 50001, 'No se eliminaron las reglas asociadas al mundial.', 1;

		-- Muestra evidenciando la eliminación
		SELECT * FROM Mundial.Mundiales WHERE año = 2042;
		SELECT * FROM Administracion.Reglas WHERE mundial_id = 2042;

		PRINT 'Testeo exitoso: ' + @NombreTesteo;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Eliminar Mundial Año Nulo Falla';
	SET @ErrorEsperado = '- Debe indicar un mundial. ' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Mundial.sp_eliminar_mundial 
			@AñoMundial = NULL;

		THROW 50001, 'Se eliminó un mundial pasando parámetro NULL', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Eliminar Mundial Inexistente Falla';
	SET @ErrorEsperado = '- No existe un mundial en ese año. ' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Mundial.sp_eliminar_mundial 
			@AñoMundial = 1900;

		THROW 50001, 'Se intentó eliminar un mundial inexistente', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Eliminar Mundial Con Vinculaciones Falla';
	SET @ErrorEsperado = '- Este mundial tiene partidos asignados. ' + CHAR(13) + CHAR(10) +
						 '- Este mundial tiene países asociados. ' + CHAR(13) + CHAR(10) +
						 '- Este mundial tiene arbitros asociados. ' + CHAR(13) + CHAR(10) +
						 '- Este mundial tiene tarifas asociadas. ' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Mundial.sp_eliminar_mundial 
			@AñoMundial = 2046;

		THROW 50001, 'Se eliminó un mundial con dependencias activas', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH
----------------------------------------------------------------------

	SET @NombreTesteo = 'Incluir Pais Asignacion Automatica Grupo Funciona';
	BEGIN TRY

		EXEC Mundial.sp_incluir_pais 
			@CodigoPais = 'ARG',
			@AñoMundial = 2050;
		
		IF NOT EXISTS (SELECT 1 FROM Mundial.Paises_Participes WHERE mundial_id = 2050 AND pais_id = 'ARG')
			THROW 50001, 'No se incluyó el país en Mundial.Paises_Participes', 1;

		-- Muestra del país asignado automáticamente al primer grupo disponible (Grupo A)
		SELECT * FROM Mundial.Paises_Participes WHERE mundial_id = 2050 AND pais_id = 'ARG';

		PRINT 'Testeo exitoso: ' + @NombreTesteo;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Incluir Pais Grupo Especificado Funciona';
	BEGIN TRY

		EXEC Mundial.sp_incluir_pais 
			@CodigoPais = 'BRA',
			@AñoMundial = 2050,
			@Grupo = 'C';
		
		IF NOT EXISTS (SELECT 1 FROM Mundial.Paises_Participes WHERE mundial_id = 2050 AND pais_id = 'BRA' AND grupo = 'C')
			THROW 50001, 'No se registró la selección con el grupo C especificado', 1;

		SELECT * FROM Mundial.Paises_Participes WHERE mundial_id = 2050 AND pais_id = 'BRA';

		PRINT 'Testeo exitoso: ' + @NombreTesteo;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Incluir Pais Parámetros Nulos Falla';
	SET @ErrorEsperado = '- Debe indicar un país.' + CHAR(13) + CHAR(10) +
						 '- Debe indicar un mundial.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Mundial.sp_incluir_pais 
			@CodigoPais = NULL,
			@AñoMundial = NULL;

		THROW 50001, 'Se incluyó un país con parámetros NULL', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Incluir Pais y Mundial Inexistentes Falla';
	SET @ErrorEsperado = '- No hay mundial registrado en ese año.' + CHAR(13) + CHAR(10) +
						 '- El país no se encuentra registrado.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Mundial.sp_incluir_pais 
			@CodigoPais = 'ZZZ',
			@AñoMundial = -1;

		THROW 50001, 'Se incluyó un país o mundial inexistente', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Incluir Pais Ya Participando Falla';
	SET @ErrorEsperado = '- El equipo ya está participando de ese mundial.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		-- Argentina ya fue agregada en el primer test al Mundial 2050
		EXEC Mundial.sp_incluir_pais 
			@CodigoPais = 'ARG',
			@AñoMundial = 2050;

		THROW 50001, 'Se duplicó la participación de un país en el mismo mundial', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Incluir Pais Grupo Inválido Falla';
	SET @ErrorEsperado = '- Si se define un grupo, debe ser válido.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		-- Para 16 equipos (4 grupos: A, B, C, D), la letra 'Z' está fuera de rango
		EXEC Mundial.sp_incluir_pais 
			@CodigoPais = 'ECU',
			@AñoMundial = 2050,
			@Grupo = 'Z';

		THROW 50001, 'Se incluyó un país con letra de grupo fuera del rango permitido', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Incluir Pais Grupo Lleno Falla';
	SET @ErrorEsperado = '- El grupo indicado está lleno.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		-- El Grupo B del Mundial 2050 fue completado con 4 países en el setup inicial
		EXEC Mundial.sp_incluir_pais 
			@CodigoPais = 'ECU',
			@AñoMundial = 2050,
			@Grupo = 'B';

		THROW 50001, 'Se ingresó un país a un grupo que ya superó los 4 participantes', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Incluir Pais Cupo Alcanzado Falla';
	SET @ErrorEsperado = '- Este mundial alcanzo su cupo de participantes.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		-- El Mundial 2090 ya posee los 16 equipos cargados en el setup inicial
		EXEC Mundial.sp_incluir_pais 
			@CodigoPais = 'POR',
			@AñoMundial = 2090;

		THROW 50001, 'Se incluyó un país superando el cupo máximo del mundial', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Remover Pais Funciona';
	BEGIN TRY

		EXEC Mundial.sp_remover_pais 
			@CodigoPais = 'FRA',
			@AñoMundial = 2060;
		
		IF EXISTS (SELECT 1 FROM Mundial.Paises_Participes WHERE mundial_id = 2060 AND pais_id = 'FRA')
			THROW 50001, 'El país sigue figurando en Mundial.Paises_Participes', 1;

		-- Muestra evidenciando que ya no existe la participación
		SELECT * FROM Mundial.Paises_Participes WHERE mundial_id = 2060 AND pais_id = 'FRA';

		PRINT 'Testeo exitoso: ' + @NombreTesteo;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Remover Pais Parámetros Nulos Falla';
	SET @ErrorEsperado = '- Debe indicar un país.' + CHAR(13) + CHAR(10) +
						 '- Debe indicar un mundial.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Mundial.sp_remover_pais 
			@CodigoPais = NULL,
			@AñoMundial = NULL;

		THROW 50001, 'Se removió un país pasando parámetros NULL', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Remover Pais y Mundial Inexistentes Falla';
	SET @ErrorEsperado = '- No hay mundial registrado en ese año.' + CHAR(13) + CHAR(10) +
						 '- El país no se encuentra registrado.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Mundial.sp_remover_pais 
			@CodigoPais = 'ZZZ',
			@AñoMundial = -1;

		THROW 50001, 'Se removió un país con datos de entidades inexistentes', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Remover Pais NO Participando Falla';
	SET @ErrorEsperado = '- El equipo NO está participando de ese mundial.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		-- El país Portugal (POR) existe en la BBDD pero no está anotado en el Mundial 2060
		EXEC Mundial.sp_remover_pais 
			@CodigoPais = 'POR',
			@AñoMundial = 2060;

		THROW 50001, 'Se removió un país que no participaba del mundial', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Remover Pais Con Partidos Y Convocados Falla';
	SET @ErrorEsperado = '- El equipo está asignado a un partido de ese mundial.' + CHAR(13) + CHAR(10) +
						 '- El equipo tiene jugadores convocados.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Mundial.sp_remover_pais 
			@CodigoPais = 'ENG',
			@AñoMundial = 2060;

		THROW 50001, 'Se removió un país que posee partidos y jugadores convocados asociados', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH
----------------------------------------------------------------------

	SET @NombreTesteo = 'Habilitar Arbitro Funciona';
	BEGIN TRY

		EXEC Mundial.sp_habilitar_arbitro 
			@AñoMundial = 2070,
			@ArbitroID = @ArbitroHabilitarID;
		
		IF NOT EXISTS (SELECT 1 FROM Mundial.Habilitacion_Arbitro WHERE mundial_id = 2070 AND arbitro_id = @ArbitroHabilitarID)
			THROW 50001, 'No se registró la habilitación del árbitro', 1;

		-- Muestra de la habilitación registrada
		SELECT * FROM Mundial.Habilitacion_Arbitro WHERE mundial_id = 2070 AND arbitro_id = @ArbitroHabilitarID;

		PRINT 'Testeo exitoso: ' + @NombreTesteo;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Habilitar Arbitro Parámetros Nulos Falla';
	SET @ErrorEsperado = '- Debe indicar un mundial.' + CHAR(13) + CHAR(10) +
						 '- Debe indicar un arbitro.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Mundial.sp_habilitar_arbitro 
			@AñoMundial = NULL,
			@ArbitroID = NULL;

		THROW 50001, 'Se habilitó un árbitro pasando parámetros NULL', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Habilitar Arbitro Entidades Inexistentes Falla';
	SET @ErrorEsperado = '- El arbitro no existe.' + CHAR(13) + CHAR(10) +
						 '- El mundial no existe.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Mundial.sp_habilitar_arbitro 
			@AñoMundial = -1,
			@ArbitroID = -1;

		THROW 50001, 'Se habilitó un árbitro con IDs inexistentes', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Habilitar Arbitro Ya Habilitado Falla';
	SET @ErrorEsperado = '- El arbitro ya está habilitado para ese mundial.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		-- El árbitro ya fue habilitado para el Mundial 2070 en el primer test exitoso
		EXEC Mundial.sp_habilitar_arbitro 
			@AñoMundial = 2070,
			@ArbitroID = @ArbitroHabilitarID;

		THROW 50001, 'Se duplicó la habilitación de un árbitro para el mismo mundial', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH
----------------------------------------------------------------------

	SET @NombreTesteo = 'Remover Habilitación Árbitro Funciona';
	BEGIN TRY

		EXEC Mundial.sp_remover_habilitacion_arbitro 
			@AñoMundial = 2080,
			@ArbitroID = @ArbitroRemoverExitoID;
		
		IF EXISTS (SELECT 1 FROM Mundial.Habilitacion_Arbitro WHERE mundial_id = 2080 AND arbitro_id = @ArbitroRemoverExitoID)
			THROW 50001, 'El árbitro sigue figurando como habilitado en Mundial.Habilitacion_Arbitro', 1;

		-- Muestra evidenciando la eliminación de la habilitación
		SELECT * FROM Mundial.Habilitacion_Arbitro WHERE mundial_id = 2080 AND arbitro_id = @ArbitroRemoverExitoID;

		PRINT 'Testeo exitoso: ' + @NombreTesteo;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Remover Habilitación Parámetros Nulos Falla';
	SET @ErrorEsperado = '- Debe indicar un mundial.' + CHAR(13) + CHAR(10) +
						 '- Debe indicar un arbitro.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Mundial.sp_remover_habilitacion_arbitro 
			@AñoMundial = NULL,
			@ArbitroID = NULL;

		THROW 50001, 'Se removió la habilitación pasando parámetros NULL', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Remover Habilitación Entidades Inexistentes Falla';
	SET @ErrorEsperado = '- El arbitro no existe.' + CHAR(13) + CHAR(10) +
						 '- El mundial no existe.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Mundial.sp_remover_habilitacion_arbitro 
			@AñoMundial = -1,
			@ArbitroID = -1;

		THROW 50001, 'Se removió habilitación con IDs inexistentes', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Remover Habilitación Árbitro NO Habilitado Falla';
	SET @ErrorEsperado = '- El arbitro NO está habilitado para ese mundial.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		-- El árbitro ya fue removido en el primer test exitoso
		EXEC Mundial.sp_remover_habilitacion_arbitro 
			@AñoMundial = 2080,
			@ArbitroID = @ArbitroRemoverExitoID;

		THROW 50001, 'Se intentó remover la habilitación de un árbitro que no estaba habilitado', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Remover Habilitación Árbitro Con Partido Asignado Falla';
	SET @ErrorEsperado = '- El arbitro está asignado en un partido de este mundial.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Mundial.sp_remover_habilitacion_arbitro 
			@AñoMundial = 2080,
			@ArbitroID = @ArbitroConPartidoID;

		THROW 50001, 'Se removió la habilitación de un árbitro asignado a un partido', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
	IF @@TRANCOUNT > 0
		ROLLBACK TRANSACTION
	PRINT '';
	PRINT '';
	PRINT '';
	print 'Testeo fallido: ' + @NombreTesteo;
	-- print ERROR_MESSAGE();
	THROW;
END CATCH

