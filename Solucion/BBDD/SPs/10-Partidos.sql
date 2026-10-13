USE GestionDelMundial;
GO 

-- Esto crea un partido, puede ser con datos pre-conocidos 
-- (por ejemplo países o incluso ganadores), para usarse en una importacion
-- O puede no usarse en otros sps como generar_partidos aplicando reglas de negocio.
CREATE OR ALTER PROCEDURE Partidos.sp_crear_partido
	@AñoMundial INT,
	@SeleccionAID INT = NULL,
    @SeleccionBID INT = NULL,
    @SeleccionGanadoraID INT = NULL,
    @SedeID INT = NULL,
    @FechaYHora DATETIME,
    @Fase VARCHAR(15),
    @SiguientePartidoID INT = NULL,
    @TiempoAdicional_1 SMALLINT = NULL,
    @TiempoAdicional2 SMALLINT = NULL,
    @TiempoAdicional3 SMALLINT = NULL,
    @TiempoAdicional4 SMALLINT = NULL,
    @HuboTiempoSuplementario BIT = NULL,
    @ID int = NULL OUTPUT
AS
BEGIN
	IF @AñoMundial is null	or @SedeID is null
		throw 50001, 'error null', 1;

	INSERT INTO Partidos.Partidos
	(mundial_id, seleccion_A_id, seleccion_B_id, seleccion_ganadora_id, sede_id, 
	fecha_y_hora, fase, siguiente_partido_id, tiempo_adicional_1, tiempo_adicional_2, 
	tiempo_adicional_3, tiempo_adicional_4, hubo_tiempo_suplementario)
	VALUES
	(@AñoMundial, @SeleccionAID, @SeleccionBID, @SeleccionGanadoraID, @SedeID, @FechaYHora, 
		@Fase, @SiguientePartidoID, @TiempoAdicional_1, @TiempoAdicional2, @TiempoAdicional3, 
		@TiempoAdicional4,@HuboTiempoSuplementario);

	SET @ID = SCOPE_IDENTITY();
END
GO

-- GENERA TODOS LOS PARTIDOS DE FORMA RECURSIVA.
-- A los partidos knockout no les pone equipos,
-- a los partidos de grupo, sí.
CREATE OR ALTER PROCEDURE Partidos.sp_generar_partidos
	@AñoMundial INT,
	@PaisesSedes VARCHAR(250) = NULL
AS
BEGIN 
	SET NOCOUNT ON
	
	DECLARE @errores VARCHAR(4000) = '';

	IF @AñoMundial IS NULL
		SET @errores = @errores + 'Debe indicar un mundial.' + CHAR(13) + CHAR(10)

	DECLARE @fechaDeFin DATE = (SELECT f_fin FROM Mundial.Mundiales WHERE año = @AñoMundial);

	IF @fechaDeFin IS NULL
		SET @errores = @errores + 'El mundial no existe.' + CHAR(13) + CHAR(10)

	DECLARE @cantidadDeEquipos INT = Administracion.fn_obtener_regla(@añoMundial, 'CANTIDAD_EQUIPOS');

	DECLARE @equiposParticipando INT = (SELECT COUNT(*) FROM Mundial.Paises_Participes WHERE mundial_id = @AñoMundial);

	IF @equiposParticipando <> @cantidadDeEquipos
		SET @errores = @errores + 'Aún no se inscribieron todos los países.' + CHAR(13) + CHAR(10)

	IF @errores <> '' THROW 50001, @errores, 1;


	DECLARE @FasesEliminatorias INT = CASE 
			WHEN @cantidadDeEquipos = 32 THEN 4
			WHEN @cantidadDeEquipos = 48 THEN 5
			WHEN @cantidadDeEquipos = 64 THEN 5
			ELSE 4 END;

	DECLARE @idGenerado INT;


	IF OBJECT_ID('tempdb..#FaseActual') IS NOT NULL DROP TABLE #FaseActual;
	IF OBJECT_ID('tempdb..#FasePrevia') IS NOT NULL DROP TABLE #FasePrevia;

	CREATE TABLE #FaseActual (id INT, partido_numero INT IDENTITY(1,1));
	CREATE TABLE #FasePrevia (id INT, partido_numero INT IDENTITY(1,1));

	--- TODO: ELEGIR LAS SEDES AL AZAR, de momento hardcodeo un ID de sede y listo.
	EXEC Partidos.sp_crear_partido
		@AñoMundial = @AñoMundial,
	    @SedeID = 1, -- TODO: REEMPLAZAR RANDOM
	    @FechaYHora = @fechaDeFin,
	    @Fase = 'FINAL',
	    @ID = @idGenerado OUTPUT;

	INSERT INTO #FaseActual (id) VALUES (@idGenerado);

	DECLARE @FechaTercerPuesto DATETIME = DATEADD(DAY, -1, @fechaDeFin);
	EXEC Partidos.sp_crear_partido 
	    @AñoMundial = @AñoMundial, @SedeID = 1, @FechaYHora = @FechaTercerPuesto, @Fase = 'TERCER_PUESTO', @SiguientePartidoID = NULL;

	-- La idea es hacer un bucle, que recorra cada nivel de eliminatorias.
	-- Cada nivel, tiene dos a la nivel partidos (final (N1) => 2 partidos, semi (N2) => 4 partidos, cuartos (N3) => 8 partidos...)

	DECLARE @nivelActual INT = 2; -- Semifinales
	
	DECLARE @fechaActual DATETIME = @FechaTercerPuesto;
	DECLARE @partidosEnFase INT;
	DECLARE @i INT;
	DECLARE @siguienteID INT;
	DECLARE @nombreFase VARCHAR(15);

	WHILE @nivelActual <= @FasesEliminatorias
	BEGIN
		
    	SET @partidosEnFase = POWER(2, @NivelActual - 1);

		SET @nombreFase = CASE 
		    WHEN @partidosEnFase = 2 THEN 'SEMIFINAL'
		    WHEN @partidosEnFase = 4 THEN 'CUARTOS'
		    WHEN @partidosEnFase = 8 THEN 'OCTAVOS'
		    WHEN @partidosEnFase = 16 THEN 'DIECISEISAVOS'
		END;

		SET @fechaActual = DATEADD(DAY, -1, @fechaActual); -- Restar días según tu regla de negocio
		-- La idea acá es que podés asociar 2 partidos, a un partido siguiente, usando esta fórmula
		-- (nro de partido actual + 1) / 2 = numero de partido de la siguiente fase

		-- Por ejemplo, semifinal tiene 2 partidos, por lo tanto,
		-- (1 + 1) / 2 = 1 (final) y (2 + 1) / 2 = 1 (final también)

		SET @i = 1;
		
		TRUNCATE TABLE #FasePrevia;
		
		WHILE @i <= @partidosEnFase
		BEGIN
			
			SELECT @siguienteID = id FROM #FaseActual WHERE partido_numero = (@i + 1) / 2;

			EXEC Partidos.sp_crear_partido 
	    		 @AñoMundial = @AñoMundial, @SedeID = 1, @FechaYHora = @fechaActual, 
	    		 @Fase = @nombreFase, @SiguientePartidoID = @siguienteID, 
	    		 @ID = @idGenerado OUTPUT;

	    	INSERT INTO #FasePrevia (id) VALUES (@idGenerado);
	    	SET @i = @i + 1;
		END; -- WHILE;

		-- Muevo los IDs generados de fase previa, a la nueva fase actual
		TRUNCATE TABLE #FaseActual;
		INSERT INTO #FaseActual (id) SELECT id FROM #FasePrevia;

		SET @NivelActual = @NivelActual + 1;

	END; --WHILE; 

	DROP TABLE #FaseActual;
	DROP TABLE #FasePrevia;

	--- Una vez insertada la parte recursiva, hay que insertar todos los partidos de los equipos conocidos: los GRUPOS
	
	IF OBJECT_ID('tempdb..#SeleccionesGrupos') IS NOT NULL DROP TABLE #SeleccionesGrupos;
	CREATE TABLE #SeleccionesGrupos (id INT PRIMARY KEY IDENTITY(1,1), seleccion_a_id INT, seleccion_b_id INT, CONSTRAINT UQ_Selecciones UNIQUE (seleccion_a_id, seleccion_b_id));

	INSERT INTO #SeleccionesGrupos (seleccion_a_id, seleccion_b_id) (
		-- Esta consulta cruza sin repetir todas las selecciones que pertenecen a un mismo grupo.
		SELECT PP1.seleccion_id as 'seleccion_a_id', PP2.seleccion_id as 'seleccion_b_id' FROM Mundial.Paises_Participes PP1
		JOIN Mundial.Paises_Participes PP2 ON PP1.grupo = PP2.grupo AND PP1.pais_id < PP2.pais_id
		WHERE PP1.mundial_id = 2022 and PP2.mundial_id = 2022
	);

	DECLARE @partidosDeGrupos INT = (SELECT count(*) FROM #SeleccionesGrupos);
	SET @i = 1;
	
	DECLARE @seleccionA INT;
	DECLARE @seleccionB INT;

	WHILE @i <= @partidosDeGrupos
	BEGIN
		
		SET @fechaActual = DATEADD(DAY, -1, @fechaActual);

		SELECT @seleccionA = seleccion_a_id, @seleccionB = seleccion_b_id FROM #SeleccionesGrupos WHERE id = @i;
		
		EXEC Partidos.sp_crear_partido 
			 @AñoMundial = @AñoMundial, @SeleccionAID = @seleccionA, @SeleccionBID = @seleccionB,
			 @SedeID = 1, @FechaYHora = @fechaActual, @Fase = 'GRUPOS';

		SET @i = @i + 1;
	END -- while;
	
	DROP TABLE #SeleccionesGrupos;
END
GO


 

/*
SELECT TOP 1 * FROM Mundial.Mundiales ORDER BY año desc

EXEC Partidos.sp_generar_partidos @AñoMundial = 2022, @PaisesSedes = NULL

Select * FROM Partidos.Partidos;*/