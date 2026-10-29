USE GestionDelMundial;
GO

CREATE OR ALTER PROCEDURE Importacion.sp_simular_partido
	@PartidoID INT
AS 
BEGIN 

	-- En un partido:
	----1. Se asignan arbitros.
	----2. Se designan jugadores (de los posibles, convocados menos impedimentos) de los dos equipos.
	----3. Minuto a minuto se plantean eventos. (Cambios, goles, amonestaciones)
	----4. Si al terminar, es empate, y es una fase KO, => alargue y penales.
	----5. Terminar partido. Si fase <> 'GRUPOS', la selección ganadora avanza al siguiente partido.

	EXEC Arbitraje.sp_asginar_terna_arbitros 
		  @PartidoID = @PartidoID;

	DECLARE @SeleccionA INT;
	DECLARE @SeleccionB INT;
	DECLARE @fase VARCHAR(15);

	SELECT @SeleccionA = seleccion_A_id, 
		   @SeleccionB = seleccion_B_id,
		   @fase       = fase
		   FROM Partidos.Partidos 
		   WHERE id = @PartidoID;

	DECLARE @posiciones TABLE (posicion CHAR(2));
	INSERT INTO @posiciones (posicion)
	VALUES ('GK'), ('AA'), ('BB'), ('CC'); ------TODO: VER POSICIONES REALES!


	DECLARE @jugadoresDisponiblesA TABLE (id INT IDENTITY(1,1), jugador_id INT);

	INSERT INTO @jugadoresDisponiblesA (jugador_id)
	SELECT id 
		FROM Partidos.fn_jugadores_disponibles (@PartidoID, @SeleccionA)
	ORDER BY NEWID();

	DECLARE @i INT = 1;
	DECLARE @maxDisponibles INT = (SELECT COUNT(*) FROM @jugadoresDisponiblesA);
	DECLARE @jugando BIT;
	DECLARE @jugadorID INT;

	DECLARE @posicion CHAR(2);

	WHILE @i < (@maxDisponibles + 1) BEGIN

		SET @jugando = IIF(@i < 12, 1, 0);

		SELECT @jugadorID = jugador_id FROM @jugadoresDisponiblesA WHERE id = @i;

		-- Posicion al azar.
		SELECT TOP 1 @posicion = posicion FROM @posiciones ORDER BY NEWID(); 

		EXEC Partidos.sp_definir_formacion_inicial
				@Jugando     = @jugando,
				@Posicion    = @posicion,
				@PartidoID   = @PartidoID,
				@JugadorID   = @jugadorID,
				@SeleccionID = @SeleccionA;

		SET @i = @i + 1;
	END

	DECLARE @jugadoresDisponiblesB TABLE (id INT IDENTITY(1,1), jugador_id INT);

	INSERT INTO @jugadoresDisponiblesB (jugador_id)
	SELECT id 
		FROM Partidos.fn_jugadores_disponibles (@PartidoID, @SeleccionB)
	ORDER BY NEWID();

	SET @i = 1;
	SET @maxDisponibles = (SELECT COUNT(*) FROM @jugadoresDisponiblesB);

	WHILE @i < (@maxDisponibles + 1) BEGIN

		SET @jugando = IIF(@i < 12, 1, 0);

		SELECT @jugadorID = jugador_id FROM @jugadoresDisponiblesB WHERE id = @i;

		-- Posicion al azar.
		SELECT TOP 1 @posicion = posicion FROM @posiciones ORDER BY NEWID(); 

		EXEC Partidos.sp_definir_formacion_inicial
				@Jugando     = @jugando,
				@Posicion    = @posicion,
				@PartidoID   = @PartidoID,
				@JugadorID   = @jugadorID,
				@SeleccionID = @SeleccionB;

		SET @i = @i + 1;
	END

	/*SELECT * FROM Partidos.JugadorPosicionInicial WHERE partido_id = @PartidoID;
	throw 50001, 'xD', 1;*/

	-- Para que los numeros no sean tan irrealistas (tipo, 10 goles por partido jasjdja),
	-- saqué estos numeros del mundial 2022 para cada minuto:
		-- Gol: 2.7% (o 0.027)
		-- Amonestación: 3.6% (o 0.036)
		-- Cambio: 9.0% (o 0.090)
		-- No pasa nada: 84.7% (o 0.847)

	----Simulo el partido minuto a minuto.
	DECLARE @random INT;

	DECLARE @minuto TINYINT = 0;
	DECLARE @tiempo TINYINT = 1;
	DECLARE @extra  TINYINT = 0;

	DECLARE @terminoElPartido BIT = 0;

	DECLARE @eventoA BIT;

	DECLARE @seleccionAux INT;

	WHILE @terminoElPartido = 0 BEGIN

		SET @random = FLOOR(RAND() * (100 - 1 + 1)) + 1;



		IF @random <= 85 BEGIN
			-- Nada
			PRINT CONCAT(Eventos.fn_tiempo(@minuto, @extra, @tiempo), ' nada');
		END ELSE BEGIN

			SET @eventoA = FLOOR(RAND() * 2);

			IF @eventoA = 1 SET @seleccionAux = @SeleccionA;
			ELSE SET @seleccionAux = @SeleccionB;

			SELECT TOP 1 @jugadorID = jugador_id
			FROM Partidos.fn_jugadores_en_cancha (@PartidoID, @minuto, @extra, @tiempo)
			WHERE seleccion_id = @seleccionAux;

			
			IF @random <= 88 BEGIN

				EXEC Eventos.sp_registrar_gol
				 @Minuto    = @minuto,
				 @Extra     = @extra,
				 @Tiempo    = @tiempo,
				 @PartidoID = @PartidoID,
				 @Tipo      = 'N', ---TODO: Generar al azar
				 @JugadorID = @jugadorID,
				 @JugadorAsistenteID = NULL -- TODO: Generar al azar.

				 PRINT CONCAT(Eventos.fn_tiempo(@minuto, @extra, @tiempo), ' gol');

			END ELSE IF @random <= 92 BEGIN
				-- Amonestación
				EXEC Eventos.sp_registrar_amonestacion 
				 @Minuto    = @minuto,
				 @Extra     = @extra,
				 @Tiempo    = @tiempo,
				 @PartidoID = @PartidoID,
				 @JugadorID = @jugadorID,
				 @Tarjeta   = 'A', --- TODO: Hay que hacerlo al azar amarilla / roja
				 @Motivo    = NULL;

				 PRINT CONCAT(Eventos.fn_tiempo(@minuto, @extra, @tiempo), ' amonestacion');

			END ELSE IF @random > 92 BEGIN
				-- Cambio

				EXEC Eventos.sp_registrar_cambio
					 @Minuto    = @minuto,
					 @Extra     = @extra,
					 @Tiempo    = @tiempo,
					 @PartidoID = @PartidoID,
					 @Motivo = 'TACTICO', ---TODO: Al azar
					 @JugadorEntraID = NULL,
					 @JugadorSaleID = @jugadorID; ---TODO: hay que hacer que alguien entre

				PRINT CONCAT(Eventos.fn_tiempo(@minuto, @extra, @tiempo), ' cambio');
			END

		END

		IF @minuto < 45 BEGIN
			SET @minuto = @minuto + 1
		END ELSE BEGIN 
			SET @extra = @extra + 1
		END

		IF @extra > 5 BEGIN -- 5 minutos extras para cualquier tiempo en esta simulacion
			SET @tiempo = @tiempo + 1;
			SET @minuto = 0;
			SET @extra  = 0;
		END

		IF @tiempo = 3 SET @terminoElPartido = 1;

	END 

	-- Acá hay que evaluar si requiere o no requiere prórroga
	IF @fase <> 'GRUPOS' BEGIN
		--
		print 'Evaluo prorroga...' --TODO
	END

	EXEC Partidos.sp_terminar_partido @PartidoID = @PartidoID;

END
GO

CREATE OR ALTER PROCEDURE Importacion.sp_simular_mundial 
	@FechaDeInicio DATE,
	@FechaDeFin    DATE
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @AñoMundial INT = YEAR(@FechaDeInicio);
	IF @AñoMundial is not null and exists (SELECT 1 FROM Mundial.Mundiales WHERE año = @AñoMundial)
		throw 50001, 'Ya existe un mundial en ese año.', 1;

	PRINT CONCAT('Generando mundial ', @AñoMundial, '...');
	
	EXEC Mundial.sp_crear_mundial @FInicio = @FechaDeInicio, @FFin = @FechaDeFin, @LimiteJugadoresConvocados = 26, 
			@LimiteStaffConvocados = 10, @ArbitroDeVarRequerido = 1, @CantidadDeEquipos = 32;
	
    IF OBJECT_ID('tempdb..#Paises') IS NOT NULL DROP TABLE #Paises;
	CREATE TABLE #Paises (id INT PRIMARY KEY IDENTITY(1,1), codigo CHAR(3) UNIQUE);

    IF OBJECT_ID('tempdb..#Integrantes') IS NOT NULL DROP TABLE #Integrantes;
	CREATE TABLE #Integrantes (id INT PRIMARY KEY IDENTITY(1,1), jugador_id INT UNIQUE);
	
	INSERT INTO #Paises (codigo)
	SELECT TOP 32 P.codigo
		FROM Administracion.Paises P
		INNER JOIN Equipos.IntegranteSeleccion I ON I.pais_id = P.codigo
		GROUP BY P.codigo
		HAVING COUNT(*) >= 26 -- Solo tomo países al azar que tengan al menos 26 jugadores registrados.
	ORDER BY CASE when codigo = 'ARG' THEN 0 else 1 end, NEWID();

	DECLARE @codigo CHAR(3) = NULL;
	DECLARE @i INT = 1;
	
	WHILE @i < 33 BEGIN -- Cargar países 
		SELECT @codigo = codigo FROM #Paises WHERE id = @i;
		
		EXEC Mundial.sp_incluir_pais @CodigoPais = @codigo, @AñoMundial = @AñoMundial;

		TRUNCATE TABLE #Integrantes;

		INSERT INTO #Integrantes (jugador_id)
		SELECT TOP 26 id
		FROM Equipos.IntegranteSeleccion
		WHERE pais_id = @codigo
		ORDER BY NEWID();

		DECLARE @j         INT = 1;
		DECLARE @jugadorID INT = NULL;

		WHILE @j < 27 BEGIN -- Cargar Convocados 
		DECLARE @cantidad INT =(SELECT count(*) FROM #Integrantes)
			
			SELECT @jugadorID = jugador_id FROM #Integrantes WHERE id = @j;
			DECLARE @fechaDeConvocacion DATE;

			SET @fechaDeConvocacion = DATEADD(
				DAY,
				-(ABS(CHECKSUM(NEWID())) % 30),
				@FechaDeInicio
			);
			
			EXEC Equipos.sp_convocar_jugador
					@AñoMundial   = @AñoMundial,
					@MiembroID    = @jugadorID,
					@FConvocacion = @fechaDeConvocacion,
					@Dorsal = @j;
			
			SET @j = @j + 1;
		END -- END Cargar Convocados 

		SET @i = @i + 1;
	END -- END Cargar países 
	
	
	-- En este punto: Cargados países y convocados.

	EXEC Partidos.sp_generar_partidos
		 @AñoMundial = @AñoMundial;

	SELECT * FROM Partidos.Partidos WHERE mundial_id = @AñoMundial
	
	-- Asignación de Arbitros aleatorios. (170)
	
    IF OBJECT_ID('tempdb..#Arbitros') IS NOT NULL DROP TABLE #Arbitros;
	CREATE TABLE #Arbitros (id INT PRIMARY KEY IDENTITY(1,1), arbitro_id INT UNIQUE);
	
	INSERT INTO #Arbitros (arbitro_id)
	SELECT TOP 170 A.id
	FROM Arbitraje.Arbitros A
	ORDER BY NEWID();

	DECLARE @arbitroID INT = NULL;
	SET @i = 1;
	WHILE @i < 171 BEGIN

		SELECT @arbitroID = arbitro_id FROM #Arbitros WHERE id = @i;

		EXEC Mundial.sp_habilitar_arbitro
			@AñoMundial = @AñoMundial,
			@ArbitroID  = @arbitroID;

		SET @i = @i + 1;
	END

	SELECT * FROM Mundial.Habilitacion_Arbitro WHERE mundial_id = @AñoMundial;

	DECLARE @partidosDeGrupos TABLE (id INT IDENTITY(1,1), partido_id INT);
	
	INSERT INTO @partidosDeGrupos (partido_id)
		SELECT id
		FROM Partidos.Partidos
		WHERE mundial_id = @AñoMundial and fase = 'GRUPOS'
		ORDER BY fecha_y_hora ASC;

	-- Asignamos arbitro a los partidos de Grupos.
	SET @i = 1;
	DECLARE @partidoID INT = NULL;

	WHILE @i < 49 BEGIN -- Son 48 partidos de grupos para 32 equipos
		SELECT @partidoID = partido_id FROM @partidosDeGrupos WHERE id = @i;

		EXEC Importacion.sp_simular_partido 
			  @PartidoID = @partidoID;

		SET @i = @i + 1;
	END

	-- Ejecuto SP FINALIZAR FASE DE GRUPOS.

	-- Hago otro while con los partidos que quedan

	-- SELECT A.arbitro_id 
	-- FROM Arbitraje.ArbitroAsignadoPartido  A
	-- LEFT JOIN Partidos.Partidos P ON P.id = A.partido_id
	-- WHERE P.mundial_id = @AñoMundial;

	SELECT * FROM Partidos.Partidos WHERE mundial_id = @AñoMundial and fase = 'GRUPOS'
END
GO
/*
BEGIN TRANSACTION

DECLARE @FechaInicioMasUnAño DATE;
DECLARE @FechaFinMasUnAño DATE;

SELECT TOP 1 
    @FechaInicioMasUnAño = DATEADD(YEAR, 1, f_inicio),
    @FechaFinMasUnAño = DATEADD(YEAR, 1, f_fin)
FROM Mundial.Mundiales
ORDER BY año DESC;

EXEC Importacion.sp_simular_mundial 
	  @FechaDeInicio = @FechaInicioMasUnAño,
	  @FechaDeFin    = @FechaFinMasUnAño;

ROLLBACK TRANSACTION;
*/