/* BBDD/Testeos/11-Testing-Administracion.sql
 * Fecha: 14/10/2026
 * Lista, Matías Josué.
 * Descripción: Ejecuta todos los store procedures del schema [Arbitraje], 
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

	---------------------------------------------------------
	-- Setup de datos iniciales para Arbitraje.sp_crear_arbitro
	---------------------------------------------------------

	DECLARE @ConfId INT;
	exec Administracion.sp_crear_confederacion @Nombre = 'Confederación Sudamericana de Fútbol', @siglas = 'CONMEBOL',
		@FFundacion = '1916-07-09', @ID = @ConfId OUTPUT
	EXEC Administracion.sp_crear_pais @Nombre = 'Argentina', @Codigo = 'ARG', @ConfederacionID = @ConfId;

	INSERT INTO Arbitraje.Arbitros (pais_id, nombre, apellido, es_mujer, confederacion_id)
	VALUES ('ARG', 'Nestor', 'Pitana', 0, @ConfId);

	---------------------------------------------------------
	-- Setup de datos iniciales para Arbitraje.sp_modificar_arbitro
	---------------------------------------------------------

	DECLARE @ConcacafID INT;
	INSERT INTO Administracion.Confederaciones (nombre, siglas, f_fundacion)
	VALUES ('Confederación de Norteamérica', 'CONCACAF', '1961-09-18');
	SET @ConcacafID = SCOPE_IDENTITY();

	INSERT INTO Administracion.Paises (codigo, confederacion_id, nombre)
	VALUES ('MEX', @ConcacafID, 'México');

	DECLARE @ArbitroModificarID INT;
	INSERT INTO Arbitraje.Arbitros (pais_id, nombre, apellido, confederacion_id)
	VALUES ('MEX', 'Cesar', 'Ramos', @ConcacafID);
	SET @ArbitroModificarID = SCOPE_IDENTITY();

	DECLARE @ArbitroExistenteID INT;
	INSERT INTO Arbitraje.Arbitros (pais_id, nombre, apellido, confederacion_id)
	VALUES ('MEX', 'Marco', 'Ortiz', @ConcacafID);
	SET @ArbitroExistenteID = SCOPE_IDENTITY();

	---------------------------------------------------------
	-- Setup de datos iniciales para Arbitraje.sp_asociar_idioma_a_arbitro
	---------------------------------------------------------
	DECLARE @ConfIdIdioma INT;
	INSERT INTO Administracion.Confederaciones (nombre, siglas, f_fundacion)
	VALUES ('Union of European Football Associations', 'UEFA', '1954-06-15');
	SET @ConfIdIdioma = SCOPE_IDENTITY();

	INSERT INTO Administracion.Paises (codigo, confederacion_id, nombre)
	VALUES ('FRA', @ConfIdIdioma, 'Francia');

	DECLARE @ArbitroParaIdiomaID INT;
	INSERT INTO Arbitraje.Arbitros (pais_id, nombre, apellido, es_mujer, confederacion_id)
	VALUES ('FRA', 'Stephanie', 'Frappart', 1, @ConfIdIdioma);
	SET @ArbitroParaIdiomaID = SCOPE_IDENTITY();

	-- Idioma para testear éxito
	INSERT INTO Administracion.Idiomas (codigo, label)
	VALUES ('FR', 'Francés');
	
	-- Idioma para testear duplicado
	INSERT INTO Administracion.Idiomas (codigo, label)
	VALUES ('EN', 'Inglés');
	
	INSERT INTO Arbitraje.Arbitro_Habla (arbitro_id, idioma_id)
	VALUES (@ArbitroParaIdiomaID, 'EN');

	---------------------------------------------------------
	-- Setup de datos iniciales para Arbitraje.sp_desasociar_idioma_de_arbitro
	---------------------------------------------------------
	DECLARE @ConfIdDesasociar INT;
	INSERT INTO Administracion.Confederaciones (nombre, siglas, f_fundacion)
	VALUES ('Oceania Football Confederation', 'OFC', '1966-11-15');
	SET @ConfIdDesasociar = SCOPE_IDENTITY();

	INSERT INTO Administracion.Paises (codigo, confederacion_id, nombre)
	VALUES ('NZL', @ConfIdDesasociar, 'Nueva Zelanda');

	DECLARE @ArbitroDesasociarID INT;
	INSERT INTO Arbitraje.Arbitros (pais_id, nombre, apellido, es_mujer, confederacion_id)
	VALUES ('NZL', 'Matthew', 'Conger', 0, @ConfIdDesasociar);
	SET @ArbitroDesasociarID = SCOPE_IDENTITY();

	INSERT INTO Administracion.Idiomas (codigo, label)
	VALUES ('PT', 'Portugués');
	
	INSERT INTO Arbitraje.Arbitro_Habla (arbitro_id, idioma_id)
	VALUES (@ArbitroDesasociarID, 'PT');

	---------------------------------------------------------
	-- Setup de datos iniciales para Arbitraje.sp_registrar_informe_arbitro
	---------------------------------------------------------
	DECLARE @ConfIdInforme INT;
	INSERT INTO Administracion.Confederaciones (nombre, siglas, f_fundacion)
	VALUES ('Confederación Africana de Fútbol', 'CAF', '1957-02-08');
	SET @ConfIdInforme = SCOPE_IDENTITY();

	INSERT INTO Administracion.Paises (codigo, confederacion_id, nombre)
	VALUES ('MAR', @ConfIdInforme, 'Marruecos'),
		   ('EGY', @ConfIdInforme, 'Egipto');

	DECLARE @ArbitroInformeID INT;
	INSERT INTO Arbitraje.Arbitros (pais_id, nombre, apellido, confederacion_id)
	VALUES ('MAR', 'Redouane', 'Jiyed', @ConfIdInforme);
	SET @ArbitroInformeID = SCOPE_IDENTITY();

	INSERT INTO Mundial.Mundiales (f_inicio, f_fin) 
	VALUES ('2022-11-20', '2022-12-18');
	
	INSERT INTO Mundial.Selecciones (pais_id) VALUES ('MAR'), ('EGY');
	
	DECLARE @SelMar INT = (SELECT id FROM Mundial.Selecciones WHERE pais_id = 'MAR');
	DECLARE @SelEgy INT = (SELECT id FROM Mundial.Selecciones WHERE pais_id = 'EGY');

	DECLARE @SedeInformeID INT;
	INSERT INTO Administracion.Sedes (pais_id, nombre, ciudad, capacidad)
	VALUES ('MAR', 'Estadio de Marrakech', 'Marrakech', 45240);
	SET @SedeInformeID = SCOPE_IDENTITY();

	DECLARE @PartidoInformeID INT;
	INSERT INTO Partidos.Partidos (seleccion_A_id, seleccion_B_id, mundial_id, sede_id, fecha_y_hora, fase)
	VALUES (@SelMar, @SelEgy, 2022, @SedeInformeID, '2022-12-01 15:00:00', 'GRUPOS');
	SET @PartidoInformeID = SCOPE_IDENTITY();

	INSERT INTO Arbitraje.ArbitroAsignadoPartido (arbitro_id, partido_id, rol)
	VALUES (@ArbitroInformeID, @PartidoInformeID, 'PRINCIPAL');

	---------------------------------------------------------
	-- Setup de datos iniciales para Arbitraje.sp_modificar_informe_arbitro
	---------------------------------------------------------
	DECLARE @ConfIdModifInforme INT;
	INSERT INTO Administracion.Confederaciones (nombre, siglas, f_fundacion)
	VALUES ('Confederación Asiática de Fútbol', 'AFC', '1954-05-08');
	SET @ConfIdModifInforme = SCOPE_IDENTITY();

	INSERT INTO Administracion.Paises (codigo, confederacion_id, nombre)
	VALUES ('JPN', @ConfIdModifInforme, 'Japón'),
		   ('KOR', @ConfIdModifInforme, 'Corea del Sur');

	DECLARE @ArbitroModifInformeID INT;
	INSERT INTO Arbitraje.Arbitros (pais_id, nombre, apellido, confederacion_id)
	VALUES ('JPN', 'Yoshimi', 'Yamashita', @ConfIdModifInforme);
	SET @ArbitroModifInformeID = SCOPE_IDENTITY();
	
	INSERT INTO Mundial.Selecciones (pais_id) VALUES ('JPN'), ('KOR');
	
	DECLARE @SelJpn INT = (SELECT id FROM Mundial.Selecciones WHERE pais_id = 'JPN');
	DECLARE @SelKor INT = (SELECT id FROM Mundial.Selecciones WHERE pais_id = 'KOR');

	DECLARE @SedeModifInformeID INT;
	INSERT INTO Administracion.Sedes (pais_id, nombre, ciudad, capacidad)
	VALUES ('JPN', 'Estadio Nacional', 'Tokio', 68000);
	SET @SedeModifInformeID = SCOPE_IDENTITY();

	DECLARE @PartidoModifInformeID INT;
	INSERT INTO Partidos.Partidos (seleccion_A_id, seleccion_B_id, mundial_id, sede_id, fecha_y_hora, fase)
	VALUES (@SelJpn, @SelKor, 2022, @SedeModifInformeID, '2022-12-05 15:00:00', 'OCTAVOS');
	SET @PartidoModifInformeID = SCOPE_IDENTITY();

	INSERT INTO Arbitraje.ArbitroAsignadoPartido (arbitro_id, partido_id, rol)
	VALUES (@ArbitroModifInformeID, @PartidoModifInformeID, 'PRINCIPAL');

	DECLARE @InformeAModificarID INT;
	INSERT INTO Arbitraje.InformesArbitros (arbitro_id, partido_id, f_reporte, motivo)
	VALUES (@ArbitroModifInformeID, @PartidoModifInformeID, '2022-12-06', 'Motivo original');
	SET @InformeAModificarID = SCOPE_IDENTITY();

	---------------------------------------------------------
	-- Setup de datos iniciales para Arbitraje.sp_eliminar_arbitro
	---------------------------------------------------------
	DECLARE @ConfIdElim INT;
	INSERT INTO Administracion.Confederaciones (nombre, siglas, f_fundacion)
	VALUES ('Confederación de Oceanía', 'OFC2', '1990-01-01');
	SET @ConfIdElim = SCOPE_IDENTITY();

	INSERT INTO Administracion.Paises (codigo, confederacion_id, nombre)
	VALUES ('ZAF', @ConfIdElim, 'Sudáfrica');

	-- 1. Árbitro que vamos a eliminar exitosamente
	DECLARE @ArbitroAEliminarID INT;
	INSERT INTO Arbitraje.Arbitros (pais_id, nombre, apellido, confederacion_id)
	VALUES ('ZAF', 'Victor', 'Gomes', @ConfIdElim);
	SET @ArbitroAEliminarID = SCOPE_IDENTITY();

	INSERT INTO Administracion.Idiomas (codigo, label) VALUES ('ZU', 'Zulú');
	INSERT INTO Arbitraje.Arbitro_Habla (arbitro_id, idioma_id) VALUES (@ArbitroAEliminarID, 'ZU');

	-- 2. Árbitro para forzar fallas por reglas de negocio
	DECLARE @ArbitroConErroresID INT;
	INSERT INTO Arbitraje.Arbitros (pais_id, nombre, apellido, confederacion_id)
	VALUES ('ZAF', 'Daniel', 'Bennett', @ConfIdElim);
	SET @ArbitroConErroresID = SCOPE_IDENTITY();

	-- Para forzar errores, necesitamos Mundial, Selección, Sede y Partido
	IF NOT EXISTS (SELECT 1 FROM Mundial.Mundiales WHERE año = 2030)
		INSERT INTO Mundial.Mundiales (f_inicio, f_fin) VALUES ('2030-06-01', '2030-07-01');

	INSERT INTO Mundial.Habilitacion_Arbitro (mundial_id, arbitro_id) VALUES (2030, @ArbitroConErroresID);

	INSERT INTO Mundial.Selecciones (pais_id) VALUES ('ZAF');
	DECLARE @SelZaf INT = SCOPE_IDENTITY();

	DECLARE @SedeElimID INT;
	INSERT INTO Administracion.Sedes (pais_id, nombre, ciudad, capacidad)
	VALUES ('ZAF', 'Soccer City', 'Johannesburgo', 94736);
	SET @SedeElimID = SCOPE_IDENTITY();

	DECLARE @PartidoElimID INT;
	-- Utilizamos una selección ficticia nula en B para poder guardarlo o evadir el check_Selecciones_Enfrentadas_Distintas si fuera necesario (asumo que B es NULL o usamos un ID de un setup anterior, pero usaré NULL ya que el DDL lo permite)
	INSERT INTO Partidos.Partidos (seleccion_A_id, seleccion_B_id, mundial_id, sede_id, fecha_y_hora, fase)
	VALUES (@SelZaf, NULL, 2030, @SedeElimID, '2030-06-15 15:00:00', 'GRUPOS');
	SET @PartidoElimID = SCOPE_IDENTITY();

	INSERT INTO Arbitraje.ArbitroAsignadoPartido (arbitro_id, partido_id, rol)
	VALUES (@ArbitroConErroresID, @PartidoElimID, 'PRINCIPAL');

	INSERT INTO Arbitraje.InformesArbitros (arbitro_id, partido_id, f_reporte, motivo)
	VALUES (@ArbitroConErroresID, @PartidoElimID, '2030-06-16', 'Motivo prueba de errores');



------------------------------------------------------
print ''
print 'ARBITRAJE -------------'
----------------------------------------------------------------------
	SET @NombreTesteo = 'Crear Arbitro Funciona';
	BEGIN TRY

		DECLARE @NuevoArbitroID INT;

		EXEC Arbitraje.sp_crear_arbitro 
			@CodigoPais = 'ARG',
			@Nombre = 'Patricio',
			@Apellido = 'Loustau',
			@EsMujer = 0,
			@ConfederacionID = @ConfId,
			@ID = @NuevoArbitroID OUTPUT;
		
		IF NOT EXISTS (SELECT 1 FROM Arbitraje.Arbitros WHERE id = @NuevoArbitroID)
			THROW 50001, 'No se insertó el árbitro en la base de datos', 1;

		SELECT * FROM Arbitraje.Arbitros WHERE id = @NuevoArbitroID;

		PRINT 'Testeo exitoso: ' + @NombreTesteo;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Crear Arbitro Parámetros Nulos Falla';
	SET @ErrorEsperado = '- Debe ingresar el nombre del árbitro. ' + CHAR(13) + CHAR(10) +
						 '- Debe ingresar el apellido del árbitro. ' + CHAR(13) + CHAR(10) +
						 '- Debe ingresar un país. ' + CHAR(13) + CHAR(10);

	BEGIN TRY

		DECLARE @BasuraID INT;
		EXEC Arbitraje.sp_crear_arbitro 
			@CodigoPais = NULL,
			@Nombre = NULL,
			@Apellido = NULL,
			@ID = @BasuraID OUTPUT;

		THROW 50001, 'Se insertó un árbitro con parámetros nulos', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Crear Arbitro Entidades Inexistentes Falla';
	SET @ErrorEsperado = '- El país no existe. ' + CHAR(13) + CHAR(10) +
						 '- La confederacion indicada no existe. ' + CHAR(13) + CHAR(10);

	BEGIN TRY

		DECLARE @BasuraID2 INT;
		EXEC Arbitraje.sp_crear_arbitro 
			@CodigoPais = 'XYZ',
			@Nombre = 'Pierluigi',
			@Apellido = 'Collina',
			@ConfederacionID = 9999,
			@ID = @BasuraID2 OUTPUT;

		THROW 50001, 'Se insertó un árbitro con país o confederación inexistente', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Crear Arbitro Duplicado Falla';
	SET @ErrorEsperado = '- Ya existe un árbitro con ese nombre y apellido para ese país. ' + CHAR(13) + CHAR(10);

	BEGIN TRY

		DECLARE @BasuraID3 INT;
		EXEC Arbitraje.sp_crear_arbitro 
			@CodigoPais = 'ARG',
			@Nombre = 'Nestor',
			@Apellido = 'Pitana',
			@EsMujer = 0,
			@ID = @BasuraID3 OUTPUT;

		THROW 50001, 'Se insertó un árbitro duplicado', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Modificar Arbitro Funciona';
	BEGIN TRY

		EXEC Arbitraje.sp_modificar_arbitro 
			@ID = @ArbitroModificarID,
			@Nombre = 'Cesar Arturo',
			@Apellido = 'Ramos Palazuelos';
		
		IF NOT EXISTS (SELECT 1 FROM Arbitraje.Arbitros WHERE id = @ArbitroModificarID AND nombre = 'Cesar Arturo' AND apellido = 'Ramos Palazuelos')
			THROW 50001, 'No se actualizó correctamente el árbitro en la base de datos', 1;

		SELECT * FROM Arbitraje.Arbitros WHERE id = @ArbitroModificarID;

		PRINT 'Testeo exitoso: ' + @NombreTesteo;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Modificar Arbitro Parámetros Nulos Falla';
	SET @ErrorEsperado = '- Debe ingresar un arbitro. ' + CHAR(13) + CHAR(10) +
						 '- Debe ingresar un nombre. ' + CHAR(13) + CHAR(10) +
						 '- Debe ingresar un apellido. ' + CHAR(13) + CHAR(10);

	BEGIN TRY

		EXEC Arbitraje.sp_modificar_arbitro 
			@ID = NULL,
			@Nombre = NULL,
			@Apellido = NULL;

		THROW 50001, 'Se modificó un árbitro enviando parámetros nulos', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Modificar Arbitro Inexistente Falla';
	SET @ErrorEsperado = '- No existe un árbitro con ese ID. ' + CHAR(13) + CHAR(10);

	BEGIN TRY

		EXEC Arbitraje.sp_modificar_arbitro 
			@ID = 999999,
			@Nombre = 'Juan',
			@Apellido = 'Perez';

		THROW 50001, 'Se modificó un árbitro con un ID inexistente', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Modificar Arbitro Duplicado Falla';
	SET @ErrorEsperado = '- Otro árbitro del mismo país ya tiene ese nombre y apellido. ' + CHAR(13) + CHAR(10);

	BEGIN TRY

		-- Intentamos ponerle a @ArbitroModificarID el nombre del árbitro existente
		EXEC Arbitraje.sp_modificar_arbitro 
			@ID = @ArbitroModificarID,
			@Nombre = 'Marco',
			@Apellido = 'Ortiz';

		THROW 50001, 'Se modificó un árbitro con nombre y apellido duplicado en el mismo país', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Asociar Idioma A Arbitro Funciona';
	BEGIN TRY

		EXEC Arbitraje.sp_asociar_idioma_a_arbitro 
			@ArbitroID = @ArbitroParaIdiomaID,
			@CodigoIdioma = 'FR';
		
		IF NOT EXISTS (SELECT 1 FROM Arbitraje.Arbitro_Habla WHERE arbitro_id = @ArbitroParaIdiomaID AND idioma_id = 'FR')
			THROW 50001, 'No se asoció correctamente el idioma al árbitro en la base de datos', 1;

		SELECT * FROM Arbitraje.Arbitro_Habla WHERE arbitro_id = @ArbitroParaIdiomaID AND idioma_id = 'FR';

		PRINT 'Testeo exitoso: ' + @NombreTesteo;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Asociar Idioma A Arbitro Nulos Falla';
	SET @ErrorEsperado = '- Debe ingresar un arbitro. ' + CHAR(13) + CHAR(10) +
						 '- Debe ingresar un idioma. ' + CHAR(13) + CHAR(10);

	BEGIN TRY

		EXEC Arbitraje.sp_asociar_idioma_a_arbitro 
			@ArbitroID = NULL,
			@CodigoIdioma = NULL;

		THROW 50001, 'Se asoció enviando parámetros nulos', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Asociar Idioma A Arbitro Inexistentes Falla';
	SET @ErrorEsperado = '- El árbitro no existe. ' + CHAR(13) + CHAR(10) +
						 '- El idioma no existe. ' + CHAR(13) + CHAR(10);

	BEGIN TRY

		EXEC Arbitraje.sp_asociar_idioma_a_arbitro 
			@ArbitroID = 999999,
			@CodigoIdioma = 'ZZ';

		THROW 50001, 'Se asoció un árbitro o idioma inexistente', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Asociar Idioma A Arbitro Duplicado Falla';
	SET @ErrorEsperado = '- El árbitro ya tiene asociado ese idioma.' + CHAR(13) + CHAR(10);

	BEGIN TRY

		EXEC Arbitraje.sp_asociar_idioma_a_arbitro 
			@ArbitroID = @ArbitroParaIdiomaID,
			@CodigoIdioma = 'EN';

		THROW 50001, 'Se permitió asociar un idioma que el árbitro ya hablaba', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Desasociar Idioma De Arbitro Funciona';
	BEGIN TRY

		EXEC Arbitraje.sp_desasociar_idioma_de_arbitro 
			@ArbitroID = @ArbitroDesasociarID,
			@CodigoIdioma = 'PT';
		
		IF EXISTS (SELECT 1 FROM Arbitraje.Arbitro_Habla WHERE arbitro_id = @ArbitroDesasociarID AND idioma_id = 'PT')
			THROW 50001, 'No se eliminó correctamente la asociación del idioma en la base de datos', 1;

		PRINT 'Testeo exitoso: ' + @NombreTesteo;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Desasociar Idioma De Arbitro Nulos Falla';
	SET @ErrorEsperado = '- Debe ingresar un arbitro. ' + CHAR(13) + CHAR(10) +
						 '- Debe ingresar un idioma. ' + CHAR(13) + CHAR(10);

	BEGIN TRY

		EXEC Arbitraje.sp_desasociar_idioma_de_arbitro 
			@ArbitroID = NULL,
			@CodigoIdioma = NULL;

		THROW 50001, 'Se desasoció enviando parámetros nulos', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Desasociar Idioma De Arbitro Inexistente Falla';
	SET @ErrorEsperado = '- El árbitro NO tiene asociado ese idioma.' + CHAR(13) + CHAR(10);

	BEGIN TRY

		EXEC Arbitraje.sp_desasociar_idioma_de_arbitro 
			@ArbitroID = @ArbitroDesasociarID,
			@CodigoIdioma = 'RU'; -- Idioma no asociado o inexistente

		THROW 50001, 'Se permitió eliminar una asociación que no existía', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Registrar Informe Arbitro Con Partido Funciona';
	BEGIN TRY

		DECLARE @NuevoInformeID INT;

		EXEC Arbitraje.sp_registrar_informe_arbitro 
			@ArbitroID = @ArbitroInformeID,
			@FReporte = '2022-12-02',
			@Motivo = 'Comportamiento antideportivo en la grada',
			@PartidoID = @PartidoInformeID,
			@ID = @NuevoInformeID OUTPUT;
		
		IF NOT EXISTS (SELECT 1 FROM Arbitraje.InformesArbitros WHERE id = @NuevoInformeID)
			THROW 50001, 'No se insertó el informe en la base de datos', 1;

		PRINT 'Testeo exitoso: ' + @NombreTesteo;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Registrar Informe Arbitro Parámetros Nulos Falla';
	SET @ErrorEsperado = '- El árbitro no existe. ' + CHAR(13) + CHAR(10) +
						 '- Debe indicar el motivo del informe. ' + CHAR(13) + CHAR(10) +
						 '- La fecha del informe es obligatoria y no puede ser futura. ' + CHAR(13) + CHAR(10);

	BEGIN TRY

		EXEC Arbitraje.sp_registrar_informe_arbitro 
			@ArbitroID = NULL,
			@FReporte = NULL,
			@Motivo = NULL;

		THROW 50001, 'Se registró un informe con parámetros nulos', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Registrar Informe Fecha Anterior Al Partido Falla';
	SET @ErrorEsperado = '- El informe no puede ser anterior al partido. ' + CHAR(13) + CHAR(10);

	BEGIN TRY

		EXEC Arbitraje.sp_registrar_informe_arbitro 
			@ArbitroID = @ArbitroInformeID,
			@FReporte = '2022-11-20', -- El partido se jugó el 2022-12-01
			@Motivo = 'Reporte prematuro',
			@PartidoID = @PartidoInformeID;

		THROW 50001, 'Se permitió registrar un informe con fecha anterior a la del partido', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Registrar Informe Arbitro No Designado Falla';
	SET @ErrorEsperado = '- El árbitro no estuvo designado en ese partido. ' + CHAR(13) + CHAR(10);

	BEGIN TRY

		-- Creamos un partido donde el árbitro no está asignado
		DECLARE @OtroPartidoID INT;
		INSERT INTO Partidos.Partidos (seleccion_A_id, seleccion_B_id, mundial_id, sede_id, fecha_y_hora, fase)
		VALUES (@SelEgy, @SelMar, 2022, @SedeInformeID, '2022-12-05 15:00:00', 'OCTAVOS');
		SET @OtroPartidoID = SCOPE_IDENTITY();

		EXEC Arbitraje.sp_registrar_informe_arbitro 
			@ArbitroID = @ArbitroInformeID,
			@FReporte = '2022-12-06',
			@Motivo = 'Arbitraje desde la casa',
			@PartidoID = @OtroPartidoID;

		THROW 50001, 'Se permitió registrar un informe para un partido sin designación', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Modificar Informe Arbitro Funciona';
	BEGIN TRY

		EXEC Arbitraje.sp_modificar_informe_arbitro 
			@ID = @InformeAModificarID,
			@FReporte = '2022-12-07',
			@Motivo = 'Motivo modificado correctamente';
		
		IF NOT EXISTS (SELECT 1 FROM Arbitraje.InformesArbitros WHERE id = @InformeAModificarID AND motivo = 'Motivo modificado correctamente' AND f_reporte = '2022-12-07')
			THROW 50001, 'No se actualizó el informe en la base de datos', 1;

		SELECT * FROM Arbitraje.InformesArbitros WHERE id = @InformeAModificarID;

		PRINT 'Testeo exitoso: ' + @NombreTesteo;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Modificar Informe Arbitro Nulos E Inexistente Falla';
	SET @ErrorEsperado = '- No existe un informe con ese ID. ' + CHAR(13) + CHAR(10) +
						 '- Debe indicar el motivo del informe. ' + CHAR(13) + CHAR(10) +
						 '- La fecha del informe es obligatoria y no puede ser futura. ' + CHAR(13) + CHAR(10);

	BEGIN TRY

		EXEC Arbitraje.sp_modificar_informe_arbitro 
			@ID = 999999, -- Inexistente
			@FReporte = NULL,
			@Motivo = NULL;

		THROW 50001, 'Se modificó un informe enviando ID inválido y parámetros nulos', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Modificar Informe Arbitro Fecha Futura Falla';
	SET @ErrorEsperado = '- La fecha del informe es obligatoria y no puede ser futura. ' + CHAR(13) + CHAR(10);

	BEGIN TRY

		EXEC Arbitraje.sp_modificar_informe_arbitro 
			@ID = @InformeAModificarID,
			@FReporte = '2050-01-01', -- Fecha muy en el futuro
			@Motivo = 'Prueba fecha futura';

		THROW 50001, 'Se permitió modificar la fecha del informe a un día futuro', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Modificar Informe Arbitro Fecha Anterior Al Partido Falla';
	SET @ErrorEsperado = '- El informe no puede ser anterior al partido. ' + CHAR(13) + CHAR(10);

	BEGIN TRY

		EXEC Arbitraje.sp_modificar_informe_arbitro 
			@ID = @InformeAModificarID,
			@FReporte = '2022-12-04', -- El partido se jugó el 2022-12-05
			@Motivo = 'Prueba fecha previa al partido';

		THROW 50001, 'Se permitió que la fecha del informe sea previa a la fecha del partido', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Eliminar Arbitro Funciona';
	BEGIN TRY

		EXEC Arbitraje.sp_eliminar_arbitro 
			@ID = @ArbitroAEliminarID;
		
		IF EXISTS (SELECT 1 FROM Arbitraje.Arbitros WHERE id = @ArbitroAEliminarID)
			THROW 50001, 'El registro del árbitro sigue existiendo en la tabla principal', 1;

		IF EXISTS (SELECT 1 FROM Arbitraje.Arbitro_Habla WHERE arbitro_id = @ArbitroAEliminarID)
			THROW 50001, 'No se eliminaron los registros dependientes en Arbitro_Habla', 1;

		PRINT 'Testeo exitoso: ' + @NombreTesteo;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Eliminar Arbitro Nulo O Inexistente Falla';
	SET @ErrorEsperado = '- No existe un árbitro con ese ID. ' + CHAR(13) + CHAR(10);

	BEGIN TRY

		EXEC Arbitraje.sp_eliminar_arbitro 
			@ID = 999999;

		THROW 50001, 'Se permitió eliminar un ID inexistente', 1;

	END TRY
	BEGIN CATCH

		SET @ErrorRecibido = ERROR_MESSAGE();

		IF @ErrorRecibido = @ErrorEsperado
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
			THROW 50001, @ErrorRecibido, 1;

	END CATCH

----------------------------------------------------------------------

	SET @NombreTesteo = 'Eliminar Arbitro Con Dependencias Múltiples Falla';
	SET @ErrorEsperado = '- El árbitro tiene partidos designados. ' + CHAR(13) + CHAR(10) +
						 '- El árbitro tiene informes registrados. ' + CHAR(13) + CHAR(10) +
						 '- El árbitro está habilitado en uno o más mundiales. ' + CHAR(13) + CHAR(10);

	BEGIN TRY

		EXEC Arbitraje.sp_eliminar_arbitro 
			@ID = @ArbitroConErroresID;

		THROW 50001, 'Se permitió eliminar un árbitro con dependencias activas', 1;

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

