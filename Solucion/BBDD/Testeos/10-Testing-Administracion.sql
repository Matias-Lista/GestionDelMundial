/* BBDD/Testeos/Testing-Administracion.sql
 * Fecha: 14/10/2026
 * Lista, Matías Josué.
 * Descripción: Ejecuta todos los store procedures del schema [Administracion], 
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

	DECLARE @confederacionID2 INT;

	exec Administracion.sp_crear_confederacion 
		@Nombre = 'mentira 2',
		@siglas = 'YYY',
		@FFundacion = '2000-10-14',
		@ID = @confederacionID2 OUTPUT

	DECLARE @añoMundial1 INT = 9999;
	INSERT INTO Mundial.Mundiales (f_inicio, f_fin) VALUES ('9999-01-01', '9999-02-02');

	EXEC Administracion.sp_crear_pais 
		@Nombre = 'Pais Test 2',
		@Codigo = 'KKK',
		@ConfederacionID = @confederacionID2;

	EXEC Administracion.sp_crear_pais 
		@Nombre = 'Pais Para Eliminar',
		@Codigo = 'PDL',
		@ConfederacionID = @confederacionID2;

	EXEC Administracion.sp_crear_pais 
		@Nombre = 'Pais Con Dependencias',
		@Codigo = 'PDP',
		@ConfederacionID = @confederacionID2;

	EXEC Administracion.sp_crear_pais 
		@Nombre = 'Pais Super test',
		@Codigo = 'TTT',
		@ConfederacionID = @confederacionID2;

	INSERT INTO Mundial.Paises_Participes (pais_id, mundial_id) VALUES ('PDP', @añoMundial1);
	INSERT INTO Administracion.Sedes (pais_id, nombre, ciudad, capacidad) VALUES ('PDP', 'Sede Test', 'Ciudad Test', 1);
	INSERT INTO Equipos.IntegranteSeleccion (pais_id, nombre, apellido) VALUES ('PDP', 'Integrante Test', 'Apellido test');

	EXEC Administracion.sp_crear_idioma 
		@Codigo = 'EN', 
		@Label = 'Inglés';

	EXEC Administracion.sp_crear_idioma 
		@Codigo = 'FR',
		@Label = 'Francés';

	-- Idioma con dependencias (país y árbitro) para probar las fallas por vinculación
	EXEC Administracion.sp_crear_idioma 
		@Codigo = 'IT',
		@Label = 'Italiano';

	-- Vinculamos 'IT' a un país en Pais_Habla (usando el país 'TTT' creado previamente)
	EXEC Administracion.sp_asociar_idioma_a_pais 
		@CodigoPais = 'TTT',
		@IdiomaID = 'IT';

	-- Creamos un árbitro de prueba para vincularlo al idioma 'IT'
	DECLARE @ArbitroIDPrueba INT;
	INSERT INTO Arbitraje.Arbitros (pais_id, nombre, apellido, es_mujer, confederacion_id)
	VALUES ('TTT', 'Néstor', 'Pitana', 0, @confederacionID2);
	SET @ArbitroIDPrueba = SCOPE_IDENTITY();

	-- Vinculamos el árbitro con el idioma 'IT'
	INSERT INTO Arbitraje.Arbitro_Habla (idioma_id, arbitro_id)
	VALUES ('IT', @ArbitroIDPrueba);

	-- Creación de un segundo club para testear colisión de nombres al modificar
	DECLARE @ClubID2 INT;
	EXEC Administracion.sp_crear_club 
		@Nombre = 'Club Secundario Test',
		@ID = @ClubID2 OUTPUT;

	-- Datos para testear sp_eliminar_club
	-- 1. Club para eliminar exitosamente
	DECLARE @ClubIDParaEliminar INT;
	EXEC Administracion.sp_crear_club 
		@Nombre = 'Club Para Eliminar',
		@ID = @ClubIDParaEliminar OUTPUT;

	-- 2. Club con dependencias para probar falla por convocados vinculados
	DECLARE @ClubIDConVinculaciones INT;
	EXEC Administracion.sp_crear_club 
		@Nombre = 'Club Con Vinculaciones',
		@ID = @ClubIDConVinculaciones OUTPUT;

	-- Creamos una Selección e insertamos la convocación asociada al club
	DECLARE @SeleccionIDPrueba INT;
	INSERT INTO Mundial.Selecciones (pais_id) VALUES ('PDP');
	SET @SeleccionIDPrueba = SCOPE_IDENTITY();

	DECLARE @MiembroIDPrueba INT;
	SELECT TOP 1 @MiembroIDPrueba = id FROM Equipos.IntegranteSeleccion WHERE pais_id = 'PDP';

	INSERT INTO Equipos.ConvocacionEnSeleccion 
		(seleccion_id, miembro_id, tipo, f_convocacion, dorsal, club_id)
	VALUES 
		(@SeleccionIDPrueba, @MiembroIDPrueba, 'Jugador', '2026-01-01', 10, @ClubIDConVinculaciones);

	DECLARE @SedeID2 INT;
	EXEC Administracion.sp_crear_sede 
		@CodigoPais = 'TTT',
		@Nombre = 'Estadio Secundario Test',
		@Ciudad = 'Ciudad Test Sede 2',
		@Capacidad = 40000,
		@ID = @SedeID2 OUTPUT;

	-- Datos para testear sp_eliminar_sede
	-- 1. Sede sin dependencias para probar la eliminación exitosa
	DECLARE @SedeIDParaEliminar INT;
	EXEC Administracion.sp_crear_sede 
		@CodigoPais = 'TTT',
		@Nombre = 'Sede Para Eliminar',
		@Ciudad = 'Ciudad Eliminar',
		@Capacidad = 10000,
		@ID = @SedeIDParaEliminar OUTPUT;

	-- 2. Sede vinculada a un partido
	DECLARE @SedeIDConPartidos INT;
	EXEC Administracion.sp_crear_sede 
		@CodigoPais = 'TTT',
		@Nombre = 'Sede Con Partido',
		@Ciudad = 'Ciudad Partido',
		@Capacidad = 20000,
		@ID = @SedeIDConPartidos OUTPUT;

	-- Insertamos un partido de prueba vinculado a esta sede
	INSERT INTO Partidos.Partidos (mundial_id, sede_id, fecha_y_hora, fase)
	VALUES (@añoMundial1, @SedeIDConPartidos, '9999-01-01 15:00:00', 'GRUPOS');

------------------------------------------------------
print 'CONFEDERACIONES -------------'
------------------------------------------------------

	SET @NombreTesteo = 'Crear Confederacion'
	BEGIN TRY
		
		DECLARE @confederacionID1 INT;

		exec Administracion.sp_crear_confederacion 
			@Nombre = 'mentira',
			@siglas = 'ZZZ',
			@FFundacion = '2000-10-14',
			@ID = @confederacionID1 OUTPUT
		
		IF NOT EXISTS (SELECT 1 FROM Administracion.Confederaciones WHERE id = @confederacionID1)
			throw 50001, 'No se insertó la confederación', 1;

		SELECT * FROM Administracion.Confederaciones WHERE id = @confederacionID1;

		PRINT 'Testeo exitoso: ' + @NombreTesteo;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();
		throw 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Crear Confederacion Ya Existente Falla'
	SET @ErrorEsperado = '- Ya existe una confederación con ese nombre.' + CHAR(13) + CHAR(10) +
						 '- Ya existe una confederación con esas siglas.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		exec Administracion.sp_crear_confederacion 
			@Nombre = 'mentira',
			@siglas = 'ZZZ',
			@FFundacion = '2000-10-14';

		THROW 50001, 'Se insertó una confederación erronea', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			throw 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Crear Confederacion Inválida Falla'
	SET @ErrorEsperado = '- Debe indicar el nombre de la confederación.' + char(13) + char(10) +
						 '- Debe indicar las siglas de la confederación.' + char(13) + char(10) +
						 '- La fecha de fundación no puede ser futura.' + char(13) + char(10);

 	BEGIN TRY

		exec Administracion.sp_crear_confederacion 
			@Nombre = NULL,
			@siglas = NULL,
			@FFundacion = '3000-10-14';

		THROW 50001, 'Se insertó una confederación erronea', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			throw 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Modificar Confederacion Funciona'
	SET @ErrorEsperado = '';

 	BEGIN TRY

		exec Administracion.sp_modificar_confederacion 
 			 @ID = @confederacionID1,
			 @Nombre = 'Nuevo Nombre',
			 @siglas = 'AAA',
			 @FFundacion = '1950-10-01'

		SELECT * FROM Administracion.Confederaciones WHERE id = @confederacionID1;

		PRINT 'Testeo exitoso: ' + @NombreTesteo;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();
		throw 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Modificar Confederacion Inválida Falla'
	SET @ErrorEsperado = '- No existe una confederación con ese ID. ' + char(13) + char(10) +
						 '- Debe indicar el nombre de la confederación. ' + char(13) + char(10) +
						 '- La fecha de fundación no puede ser futura. ' + char(13) + char(10);

 	BEGIN TRY
		
		exec Administracion.sp_modificar_confederacion 
 			 @ID = -1,
			 @Nombre = NULL,
			 @siglas = NULL,
			 @FFundacion = '3000-10-01';

		THROW 50001, 'Se insertó una confederación erronea', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			throw 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Modificar Confederacion Existente Falla'
	SET @ErrorEsperado = '- Otra confederación ya usa ese nombre. ' + char(13) + char(10) +
						 '- Otra confederación ya usa esas siglas. ' + char(13) + char(10);

 	BEGIN TRY
		
		exec Administracion.sp_modificar_confederacion 
 			 @ID = @confederacionID2,
			 @Nombre = 'Nuevo Nombre',
			 @siglas = 'AAA',
			 @FFundacion = '2000-10-01';

		THROW 50001, 'Se insertó una confederación erronea', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			throw 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

print ''
print 'REGLAS -------------'
print ''

----------------------------------------------------------------------

	SET @NombreTesteo = 'Registrar Regla Funciona'
	BEGIN TRY
		
		DECLARE @ReglaID INT;

		EXEC Administracion.sp_registrar_regla 
			@AñoMundial = @añoMundial1,
			@Codigo = 'TEST_MAX_JUGADORES',
			@Valor = '26',
			@ID = @ReglaID OUTPUT
		
		IF NOT EXISTS (SELECT 1 FROM Administracion.Reglas WHERE id = @ReglaID)
			THROW 50001, 'No se insertó la regla', 1;

		SELECT * FROM Administracion.Reglas WHERE id = @ReglaID;

		PRINT 'Testeo exitoso: ' + @NombreTesteo;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Registrar Regla Parámetros Nulos Falla'
	SET @ErrorEsperado = '- Debe indicar un mundial. ' + CHAR(13) + CHAR(10) +
						 '- Debe indicar un codigo. ' + CHAR(13) + CHAR(10) +
						 '- Debe indicar un valor. ' + CHAR(13) + CHAR(10) +
						 '- El mundial no existe. ' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Administracion.sp_registrar_regla 
			@AñoMundial = NULL,
			@Codigo = NULL,
			@Valor = NULL;

		THROW 50001, 'Se insertó una regla erronea', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Registrar Regla Mundial Inexistente Falla'
	SET @ErrorEsperado = '- El mundial no existe. ' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		-- Pasamos un año que sabemos que no existe
		EXEC Administracion.sp_registrar_regla 
			@AñoMundial = -1,
			@Codigo = 'OTRO_CODIGO',
			@Valor = '10';

		THROW 50001, 'Se insertó una regla con mundial inexistente', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Registrar Regla Ya Existente Falla'
	SET @ErrorEsperado = '- La regla ya está registrada para ese mundial.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		-- Intentamos insertar exactamente la misma regla que creamos en el primer test
		EXEC Administracion.sp_registrar_regla 
			@AñoMundial = @añoMundial1,
			@Codigo = 'TEST_MAX_JUGADORES',
			@Valor = '50';

		THROW 50001, 'Se duplicó una regla que no debía insertarse', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Obtener Regla Funciona'
	BEGIN TRY
		
		DECLARE @ValorObtenido VARCHAR(100);

		EXEC Administracion.sp_obtener_regla 
			@AñoMundial = @añoMundial1,
			@Codigo = 'TEST_MAX_JUGADORES',
			@Valor = @ValorObtenido OUTPUT;
		
		IF @ValorObtenido IS NULL OR @ValorObtenido <> '26'
			THROW 50001, 'No se obtuvo el valor esperado para la regla.', 1;

		PRINT 'Testeo exitoso: ' + @NombreTesteo + ' (Valor devuelto: ' + ISNULL(@ValorObtenido, 'NULL') + ')';

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Obtener Regla Inexistente Devuelve NULL'
	BEGIN TRY
		
		DECLARE @ValorInexistente VARCHAR(100) = 'VALOR_INICIAL';

		EXEC Administracion.sp_obtener_regla 
			@AñoMundial = @añoMundial1,
			@Codigo = 'CODIGO_QUE_NO_EXISTE',
			@Valor = @ValorInexistente OUTPUT;
		
		IF @ValorInexistente IS NOT NULL
			THROW 50001, 'Se esperaba NULL pero la consulta devolvió un valor.', 1;

		PRINT 'Testeo exitoso: ' + @NombreTesteo;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;

	END CATCH

print ''
print 'PAÍSES -------------'
print ''

----------------------------------------------------------------------

	SET @NombreTesteo = 'Crear Pais Funciona'
	BEGIN TRY
		
		
		EXEC Administracion.sp_crear_pais 
			@Nombre = 'Pais Test',
			@Codigo = 'PTS',
			@ConfederacionID = @confederacionID2;
		
		IF NOT EXISTS (SELECT 1 FROM Administracion.Paises WHERE codigo = 'PTS')
			THROW 50001, 'No se insertó el país', 1;

		SELECT * FROM Administracion.Paises WHERE codigo = 'PTS';

		PRINT 'Testeo exitoso: ' + @NombreTesteo;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Crear Pais Parámetros Nulos Falla'
	SET @ErrorEsperado = '- Debe indicar un nombre.' + CHAR(13) + CHAR(10) +
						 '- Debe indicar un código.' + CHAR(13) + CHAR(10) +
						 '- Debe indicar una confederacion.' + CHAR(13) + CHAR(10) +
						 '- La confederación no es válida.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Administracion.sp_crear_pais 
			@Nombre = NULL,
			@Codigo = NULL,
			@ConfederacionID = NULL;

		THROW 50001, 'Se insertó un país erroneo', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Crear Pais Código ISO Inválido Falla'
	SET @ErrorEsperado = '- Debe indicar un código de 3 letras ISO.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Administracion.sp_crear_pais 
			@Nombre = 'Pais Invalido',
			@Codigo = '123', -- Código no compuesto por 3 letras mayúsculas
			@ConfederacionID = @confederacionID2;

		THROW 50001, 'Se insertó un país con código ISO inválido', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Crear Pais Ya Existente Falla'
	SET @ErrorEsperado = '- El código de país ya está siendo utilizado.' + CHAR(13) + CHAR(10) +
						 '- El nombre del país ya está siendo utilizado.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		-- Mismo nombre y código creados en el test exitoso
		EXEC Administracion.sp_crear_pais 
			@Nombre = 'Pais Test',
			@Codigo = 'PTS',
			@ConfederacionID = @confederacionID2;

		THROW 50001, 'Se insertó un país duplicado', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Crear Pais Confederacion Inexistente Falla'
	SET @ErrorEsperado = '- La confederación no es válida.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Administracion.sp_crear_pais 
			@Nombre = 'Otro Pais',
			@Codigo = 'OTP',
			@ConfederacionID = -1;

		THROW 50001, 'Se insertó un país con confederación inexistente', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Modificar Pais Funciona'
	BEGIN TRY

		EXEC Administracion.sp_modificar_pais 
			@Codigo = 'PTS',
			@Nombre = 'Pais Test Modificado',
			@ConfederacionID = @confederacionID2;
		
		SELECT * FROM Administracion.Paises WHERE codigo = 'PTS';

		PRINT 'Testeo exitoso: ' + @NombreTesteo;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Modificar Pais Parámetros Nulos Falla'
	SET @ErrorEsperado = '- Debe indicar un nombre.' + CHAR(13) + CHAR(10) +
						 '- Debe indicar un código.' + CHAR(13) + CHAR(10) +
						 '- Debe indicar una confederacion.' + CHAR(13) + CHAR(10) +
						 '- No existe un país con ese código. ' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Administracion.sp_modificar_pais 
			@Codigo = NULL,
			@Nombre = NULL,
			@ConfederacionID = NULL;

		THROW 50001, 'Se modificó un país con parámetros nulos', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Modificar Pais Código Inválido e Inexistente Falla'
	SET @ErrorEsperado = '- El código del país debe tener 3 letras (ISO). ' + CHAR(13) + CHAR(10) +
						 '- No existe un país con ese código. ' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Administracion.sp_modificar_pais 
			@Codigo = '123',
			@Nombre = 'Nombre Valido',
			@ConfederacionID = @confederacionID2;

		THROW 50001, 'Se modificó un país con código ISO e ID inexistente', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Modificar Pais Confederacion Inexistente Falla'
	SET @ErrorEsperado = '- La confederación no existe. ' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Administracion.sp_modificar_pais 
			@Codigo = 'PTS',
			@Nombre = 'Pais Test Modificado',
			@ConfederacionID = -1;

		THROW 50001, 'Se modificó un país con confederación inexistente', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Modificar Pais Nombre Usado Por Otro Pais Falla'
	SET @ErrorEsperado = '- El nombre está siendo utilizado por otro pais. ' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		-- Intentamos cambiar el nombre de 'PTS' por 'Pais Test 2' (que le pertenece al otro país creado en setup)
		EXEC Administracion.sp_modificar_pais 
			@Codigo = 'PTS',
			@Nombre = 'Pais Test 2',
			@ConfederacionID = @confederacionID2;

		THROW 50001, 'Se modificó el país usando un nombre ya existente', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Eliminar Pais Funciona'
	BEGIN TRY

		EXEC Administracion.sp_eliminar_pais 
			@Codigo = 'PDL';
		
		-- Verificamos que realmente no exista en la tabla
		IF EXISTS (SELECT 1 FROM Administracion.Paises WHERE codigo = 'PDL')
			THROW 50001, 'El país no fue eliminado de la base de datos.', 1;

		-- Devuelve vacio
		SELECT * FROM Administracion.Paises WHERE codigo = 'PDL';

		PRINT 'Testeo exitoso: ' + @NombreTesteo;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo  = 'Eliminar Pais Código Nulo Falla'
	SET @ErrorEsperado = '- Debe indicar un código.' + CHAR(13) + CHAR(10) +
						 '- El país indicado no existe.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Administracion.sp_eliminar_pais 
			@Codigo = NULL;

		THROW 50001, 'Se eliminó un país con código NULL', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Eliminar Pais Inexistente Falla'
	SET @ErrorEsperado = '- El país indicado no existe.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Administracion.sp_eliminar_pais 
			@Codigo = 'ABC';

		THROW 50001, 'Se intentó eliminar un país inexistente', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Eliminar Pais Con Vinculaciones Falla'
	-- Respetamos el mensaje exacto con el typo del SP ('sleeccion')
	SET @ErrorEsperado = '- Este país participó en mundiales.' + CHAR(13) + CHAR(10) +
						 '- Este país está vinculado a sedes.' + CHAR(13) + CHAR(10) +
						 '- Este país está vinculado a integrantes de sleeccion.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Administracion.sp_eliminar_pais 
			@Codigo = 'PDP';

		THROW 50001, 'Se eliminó un país que posee dependencias activas', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH
----------------------------------------------------------------------

print ''
print 'IDIOMAS -------------'
print ''

----------------------------------------------------------------------

	SET @NombreTesteo = 'Crear Idioma Funciona'
	BEGIN TRY

		EXEC Administracion.sp_crear_idioma 
			@Codigo = 'ES',
			@Label = 'Español';
		
		IF NOT EXISTS (SELECT 1 FROM Administracion.Idiomas WHERE codigo = 'ES')
			THROW 50001, 'No se insertó el idioma', 1;

		SELECT * FROM Administracion.Idiomas WHERE codigo = 'ES';

		PRINT 'Testeo exitoso: ' + @NombreTesteo;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Crear Idioma Parámetros Nulos Falla'
	SET @ErrorEsperado = '- Debe ingresar el código del idioma. ' + CHAR(13) + CHAR(10) +
						 '- Debe ingresar el label del idioma. ' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Administracion.sp_crear_idioma 
			@Codigo = NULL,
			@Label = NULL;

		THROW 50001, 'Se insertó un idioma con parámetros nulos', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Crear Idioma Ya Existente Falla'

	SET @ErrorEsperado = '- Ya existe un idioma con ese código. ' + CHAR(13) + CHAR(10) +
						 '- Ya existe un idioma con ese label. ' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Administracion.sp_crear_idioma 
			@Codigo = 'ES',
			@Label = 'Español';

		THROW 50001, 'Se insertó un idioma duplicado', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Crear Idioma Código ISO Inválido Falla'
	SET @ErrorEsperado = '- El código de idioma debe ser ISO. (dos letras)' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Administracion.sp_crear_idioma 
			@Codigo = '12', -- Código no compuesto por 2 letras ISO
			@Label = 'Idioma Inventado';

		THROW 50001, 'Se insertó un idioma con código ISO inválido', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Modificar Idioma Funciona'
	BEGIN TRY

		EXEC Administracion.sp_modificar_idioma 
			@Codigo = 'ES',
			@Label = 'Español Castellano';
		
		SELECT * FROM Administracion.Idiomas WHERE codigo = 'ES';

		PRINT 'Testeo exitoso: ' + @NombreTesteo;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Modificar Idioma Parámetros Nulos Falla'
	-- Al enviar NULL en el código, también se dispara la verificación de que no existe
	SET @ErrorEsperado = '- Debe ingresar el código del idioma. ' + CHAR(13) + CHAR(10) +
						 '- Debe ingresar el label del idioma. ' + CHAR(13) + CHAR(10) +
						 '- No existe un idioma con ese código. ' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Administracion.sp_modificar_idioma 
			@Codigo = NULL,
			@Label = NULL;

		THROW 50001, 'Se modificó un idioma con parámetros nulos', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Modificar Idioma Inexistente Falla'
	SET @ErrorEsperado = '- No existe un idioma con ese código. ' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Administracion.sp_modificar_idioma 
			@Codigo = 'ZZ',
			@Label = 'Idioma Inventado';

		THROW 50001, 'Se intentó modificar un idioma inexistente', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Modificar Idioma Label Ya Existente Falla'
	SET @ErrorEsperado = '- El label ya está siendo utilizado por otro idioma.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		-- Intentamos cambiar el label de 'ES' por 'Inglés' (que le pertenece al idioma 'EN')
		EXEC Administracion.sp_modificar_idioma 
			@Codigo = 'ES',
			@Label = 'Inglés';

		THROW 50001, 'Se modificó un idioma usando un label ya existente', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Asociar Idioma a Pais Funciona'
	BEGIN TRY

		EXEC Administracion.sp_asociar_idioma_a_pais 
			@CodigoPais = 'PTS',
			@IdiomaID = 'ES';
		
		IF NOT EXISTS (SELECT 1 FROM Administracion.Pais_Habla WHERE pais_id = 'PTS' AND idioma_id = 'ES')
			THROW 50001, 'No se registró la asociación idioma-país', 1;

		SELECT * FROM Administracion.Pais_Habla WHERE pais_id = 'PTS' AND idioma_id = 'ES';

		PRINT 'Testeo exitoso: ' + @NombreTesteo;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Asociar Idioma Parámetros Nulos Falla'

	SET @ErrorEsperado = '- Debe indicar el código del país. ' + CHAR(13) + CHAR(10) +
						 '- Debe indicar el código del idioma. ' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Administracion.sp_asociar_idioma_a_pais 
			@CodigoPais = NULL,
			@IdiomaID = NULL;

		THROW 50001, 'Se asoció un idioma con parámetros nulos', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Asociar Idioma Pais e Idioma Inexistentes Falla'
	SET @ErrorEsperado = '- El país no existe. ' + CHAR(13) + CHAR(10) +
						 '- El idioma no existe. ' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Administracion.sp_asociar_idioma_a_pais 
			@CodigoPais = 'ABC',
			@IdiomaID = 'ZZ';

		THROW 50001, 'Se asoció un idioma con entidades inexistentes', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Asociar Idioma Ya Asociado Falla'
	SET @ErrorEsperado = '- El país ya tiene asociado ese idioma. ' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		-- Volvemos a asociar 'ES' a 'PTS' (ya insertado en el primer test exitoso)
		EXEC Administracion.sp_asociar_idioma_a_pais 
			@CodigoPais = 'PTS',
			@IdiomaID = 'ES';

		THROW 50001, 'Se asoció un idioma duplicado al mismo país', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH
----------------------------------------------------------------------

	SET @NombreTesteo = 'Desasociar Idioma de Pais Funciona'
	BEGIN TRY

		EXEC Administracion.sp_desasociar_idioma_de_pais 
			@CodigoPais = 'PTS',
			@CodigoIdioma = 'ES';
		
		IF EXISTS (SELECT 1 FROM Administracion.Pais_Habla WHERE pais_id = 'PTS' AND idioma_id = 'ES')
			THROW 50001, 'No se desasoció el idioma del país', 1;

		SELECT * FROM Administracion.Pais_Habla WHERE pais_id = 'PTS' AND idioma_id = 'ES';

		PRINT 'Testeo exitoso: ' + @NombreTesteo;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Desasociar Idioma Parámetros Nulos Falla'
	SET @ErrorEsperado = '- Debe indicar el código del país. ' + CHAR(13) + CHAR(10) +
						 '- Debe indicar el código del idioma. ' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Administracion.sp_desasociar_idioma_de_pais 
			@CodigoPais = NULL,
			@CodigoIdioma = NULL;

		THROW 50001, 'Se desasoció un idioma con parámetros nulos', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Desasociar Idioma No Asociado Falla'
	SET @ErrorEsperado = '- El país no tiene asociado ese idioma.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		-- Como ya desasociamos 'ES' de 'PTS' en el primer test, al reintentar debe fallar
		EXEC Administracion.sp_desasociar_idioma_de_pais 
			@CodigoPais = 'PTS',
			@CodigoIdioma = 'ES';

		THROW 50001, 'Se desasoció un idioma que no estaba asociado', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Eliminar Idioma Funciona'
	BEGIN TRY

		EXEC Administracion.sp_eliminar_idioma 
			@Codigo = 'FR';
		
		-- Verificamos que realmente no exista en la tabla Idiomas
		IF EXISTS (SELECT 1 FROM Administracion.Idiomas WHERE codigo = 'FR')
			THROW 50001, 'El idioma no fue eliminado de la tabla Administracion.Idiomas.', 1;

		-- no devuelve filas
		SELECT * FROM Administracion.Idiomas WHERE codigo = 'FR';

		PRINT 'Testeo exitoso: ' + @NombreTesteo;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Eliminar Idioma Código Nulo Falla'
	SET @ErrorEsperado = '- Debe indicar un código.' + CHAR(13) + CHAR(10) +
						 '- El idioma indicado no existe.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Administracion.sp_eliminar_idioma 
			@Codigo = NULL;

		THROW 50001, 'Se eliminó un idioma con código NULL', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Eliminar Idioma Inexistente Falla'
	SET @ErrorEsperado = '- El idioma indicado no existe.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Administracion.sp_eliminar_idioma 
			@Codigo = 'ZZ';

		THROW 50001, 'Se intentó eliminar un idioma inexistente', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Eliminar Idioma Con Vinculaciones Falla'
	SET @ErrorEsperado = '- Hay países vinculados al idioma. ' + CHAR(13) + CHAR(10) +
						 '- Hay árbitros vinculados al idioma. ' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Administracion.sp_eliminar_idioma 
			@Codigo = 'IT';

		THROW 50001, 'Se eliminó un idioma con vinculaciones a países y árbitros', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

print ''
print 'CLUBES -------------'
print ''

----------------------------------------------------------------------

	SET @NombreTesteo = 'Crear Club Funciona'
	BEGIN TRY

		DECLARE @ClubID1 INT;

		EXEC Administracion.sp_crear_club 
			@Nombre = 'Real Madrid Test',
			@ID = @ClubID1 OUTPUT;
		
		IF NOT EXISTS (SELECT 1 FROM Administracion.Clubes WHERE id = @ClubID1)
			THROW 50001, 'No se insertó el club', 1;

		SELECT * FROM Administracion.Clubes WHERE id = @ClubID1;

		PRINT 'Testeo exitoso: ' + @NombreTesteo;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Crear Club Nombre Nulo Falla'
	SET @ErrorEsperado = '- Debe ingresar el nombre del club. ' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Administracion.sp_crear_club 
			@Nombre = NULL;

		THROW 50001, 'Se insertó un club con nombre NULL', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Crear Club Ya Existente Falla'
	SET @ErrorEsperado = '- Ya existe un club con ese nombre.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Administracion.sp_crear_club 
			@Nombre = 'Real Madrid Test';

		THROW 50001, 'Se insertó un club con nombre duplicado', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Modificar Club Funciona'
	BEGIN TRY

		EXEC Administracion.sp_modificar_club 
			@ID = @ClubID1,
			@Nombre = 'Real Madrid Modificado';
		
		SELECT * FROM Administracion.Clubes WHERE id = @ClubID1;

		PRINT 'Testeo exitoso: ' + @NombreTesteo;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Modificar Club Parámetros Nulos Falla'
	SET @ErrorEsperado = '- Debe indicar un club. ' + CHAR(13) + CHAR(10) +
						 '- Debe ingresar el nombre del club. ' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Administracion.sp_modificar_club 
			@ID = NULL,
			@Nombre = NULL;

		THROW 50001, 'Se modificó un club con parámetros nulos', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Modificar Club Inexistente Falla'
	SET @ErrorEsperado = '- No existe un club con ese ID.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Administracion.sp_modificar_club 
			@ID = -1,
			@Nombre = 'Nombre Valido';

		THROW 50001, 'Se intentó modificar un club inexistente', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Modificar Club Nombre Ya Existente Falla'
	SET @ErrorEsperado = '- El nombre es utilizado por otro club.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		-- Intentamos renombrar @ClubID1 usando el nombre de @ClubID2 creado en setup
		EXEC Administracion.sp_modificar_club 
			@ID = @ClubID1,
			@Nombre = 'Club Secundario Test';

		THROW 50001, 'Se modificó un club usando un nombre utilizado por otro club', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Eliminar Club Funciona'
	BEGIN TRY

		EXEC Administracion.sp_eliminar_club 
			@ID = @ClubIDParaEliminar;
		
		-- Verificamos que realmente no exista en la tabla
		IF EXISTS (SELECT 1 FROM Administracion.Clubes WHERE id = @ClubIDParaEliminar)
			THROW 50001, 'El club no fue eliminado de la base de datos.', 1;

		-- Muestra conjunto vacío
		SELECT * FROM Administracion.Clubes WHERE id = @ClubIDParaEliminar;

		PRINT 'Testeo exitoso: ' + @NombreTesteo;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Eliminar Club ID Nulo Falla'
	SET @ErrorEsperado = '- Debe indicar el id del club. ' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Administracion.sp_eliminar_club 
			@ID = NULL;

		THROW 50001, 'Se eliminó un club con ID NULL', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Eliminar Club Inexistente Falla'
	SET @ErrorEsperado = '- El club no existe. ' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Administracion.sp_eliminar_club 
			@ID = -1;

		THROW 50001, 'Se intentó eliminar un club inexistente', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Eliminar Club Con Jugadores Convocados Falla'
	SET @ErrorEsperado = '- El club tiene jugadores convocados asociados.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Administracion.sp_eliminar_club 
			@ID = @ClubIDConVinculaciones;

		THROW 50001, 'Se eliminó un club con jugadores convocados asociados', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

print ''
print 'Sedes -------------'
print ''

----------------------------------------------------------------------

	SET @NombreTesteo = 'Crear Sede Funciona'
	BEGIN TRY

		DECLARE @SedeID1 INT;

		EXEC Administracion.sp_crear_sede 
			@CodigoPais = 'TTT',
			@Nombre = 'Estadio Test',
			@Ciudad = 'Ciudad Test Sede',
			@Capacidad = 50000,
			@ID = @SedeID1 OUTPUT;
		
		IF NOT EXISTS (SELECT 1 FROM Administracion.Sedes WHERE id = @SedeID1)
			THROW 50001, 'No se insertó la sede', 1;

		SELECT * FROM Administracion.Sedes WHERE id = @SedeID1;

		PRINT 'Testeo exitoso: ' + @NombreTesteo;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Crear Sede Parámetros Nulos Falla'
	SET @ErrorEsperado = '- Debe indicar un país.' + CHAR(13) + CHAR(10) +
						 '- Debe indicar un nombre.' + CHAR(13) + CHAR(10) +
						 '- Debe indicar una ciudad.' + CHAR(13) + CHAR(10) +
						 '- Debe indicar una capacidad.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Administracion.sp_crear_sede 
			@CodigoPais = NULL,
			@Nombre = NULL,
			@Ciudad = NULL,
			@Capacidad = NULL;

		THROW 50001, 'Se insertó una sede con parámetros nulos', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Crear Sede Capacidad Invalida Falla'
	SET @ErrorEsperado = '- Debe indicar una capacidad positiva.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Administracion.sp_crear_sede 
			@CodigoPais = 'TTT',
			@Nombre = 'Estadio Capacidad Cero',
			@Ciudad = 'Ciudad Test',
			@Capacidad = 0;

		THROW 50001, 'Se insertó una sede con capacidad menor o igual a cero', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Crear Sede Ya Existente Falla'
	SET @ErrorEsperado = '- Ya existe una sede así.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		-- Intentamos crear la misma sede (mismo país, nombre y ciudad) creada en el primer test
		EXEC Administracion.sp_crear_sede 
			@CodigoPais = 'TTT',
			@Nombre = 'Estadio Test',
			@Ciudad = 'Ciudad Test Sede',
			@Capacidad = 30000;

		THROW 50001, 'Se insertó una sede duplicada', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH
----------------------------------------------------------------------

	SET @NombreTesteo = 'Modificar Sede Funciona'
	BEGIN TRY

		EXEC Administracion.sp_modificar_sede 
			@ID = @SedeID1,
			@CodigoPais = 'TTT',
			@Nombre = 'Estadio Test Modificado',
			@Ciudad = 'Nueva Ciudad',
			@Capacidad = 60000;
		
		SELECT * FROM Administracion.Sedes WHERE id = @SedeID1;

		PRINT 'Testeo exitoso: ' + @NombreTesteo;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Modificar Sede Parámetros Nulos Falla'
	SET @ErrorEsperado = '- Debe indicar un país.' + CHAR(13) + CHAR(10) +
						 '- Debe indicar un nombre.' + CHAR(13) + CHAR(10) +
						 '- Debe indicar una ciudad.' + CHAR(13) + CHAR(10) +
						 '- Debe indicar una capacidad.' + CHAR(13) + CHAR(10) +
						 '- Debe indicar una sede.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Administracion.sp_modificar_sede 
			@ID = NULL,
			@CodigoPais = NULL,
			@Nombre = NULL,
			@Ciudad = NULL,
			@Capacidad = NULL;

		THROW 50001, 'Se modificó una sede con parámetros nulos', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Modificar Sede Capacidad Inválida e ID Inexistente Falla'
	SET @ErrorEsperado = '- Debe indicar una capacidad positiva.' + CHAR(13) + CHAR(10) +
						 '- La sede no existe.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Administracion.sp_modificar_sede 
			@ID = -1,
			@CodigoPais = 'TTT',
			@Nombre = 'Estadio Valido',
			@Ciudad = 'Ciudad Valida',
			@Capacidad = 0;

		THROW 50001, 'Se modificó una sede inexistente con capacidad <= 0', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Modificar Sede Ya Existente Falla'
	SET @ErrorEsperado = '- Los nuevos datos de la sede coinciden con una sede ya existente.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		-- Intentamos modificar @SedeID1 con el mismo nombre y ciudad de @SedeID2 (creada en setup)
		EXEC Administracion.sp_modificar_sede 
			@ID = @SedeID1,
			@CodigoPais = 'TTT',
			@Nombre = 'Estadio Secundario Test',
			@Ciudad = 'Ciudad Test Sede 2',
			@Capacidad = 50000;

		THROW 50001, 'Se modificó una sede haciendo coincidir sus datos con otra existente', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH
----------------------------------------------------------------------

	SET @NombreTesteo = 'Eliminar Sede Funciona'
	BEGIN TRY

		EXEC Administracion.sp_eliminar_sede 
			@ID = @SedeIDParaEliminar;
		
		-- Verificamos que no exista en la tabla
		IF EXISTS (SELECT 1 FROM Administracion.Sedes WHERE id = @SedeIDParaEliminar)
			THROW 50001, 'La sede no fue eliminada de la base de datos.', 1;

		-- Muestra conjunto vacío
		SELECT * FROM Administracion.Sedes WHERE id = @SedeIDParaEliminar;

		PRINT 'Testeo exitoso: ' + @NombreTesteo;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Eliminar Sede ID Nulo Falla'
	SET @ErrorEsperado = '- Debe indicar una sede.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Administracion.sp_eliminar_sede 
			@ID = NULL;

		THROW 50001, 'Se eliminó una sede con ID NULL', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Eliminar Sede Inexistente Falla'
	SET @ErrorEsperado = '- La sede no existe.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Administracion.sp_eliminar_sede 
			@ID = -1;

		THROW 50001, 'Se intentó eliminar una sede inexistente', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Eliminar Sede Con Partidos Vinculados Falla'
	SET @ErrorEsperado = '- La sede está vinculada a un partido.' + CHAR(13) + CHAR(10);

 	BEGIN TRY

		EXEC Administracion.sp_eliminar_sede 
			@ID = @SedeIDConPartidos;

		THROW 50001, 'Se eliminó una sede vinculada a un partido', 1;

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
	ROLLBACK TRANSACTION
	PRINT '';
	PRINT '';
	PRINT '';
	print 'Testeo fallido: ' + @NombreTesteo;
	-- print ERROR_MESSAGE();
	THROW;
END CATCH