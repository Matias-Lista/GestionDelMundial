/* BBDD/SPs/Partidos.sql
 * Fecha: 18/10/2026
 * Lista, Matías Josué.
 * Descripción: Crea todos los store procedures, funciones, y vistas del schema [Partidos].
 **/
 
USE GestionDelMundial;
GO

-- TODO: Manejar bien goles en contra.
CREATE OR ALTER VIEW Partidos.vw_resumen_partido AS
SELECT 
    P.*,
	(SELECT COUNT(*) 
		FROM Eventos.Goles G
		JOIN Equipos.ConvocacionEnSeleccion C ON C.miembro_id = G.jugador_autor_id
		WHERE G.tipo <> 'E' and G.partido_id = P.id and C.seleccion_id = P.seleccion_A_id) as goles_A,
		
	(SELECT COUNT(*) 
		FROM Eventos.Goles G
		JOIN Equipos.ConvocacionEnSeleccion C ON C.miembro_id = G.jugador_autor_id
		WHERE G.tipo <> 'E' and G.partido_id = P.id and C.seleccion_id = P.seleccion_B_id) as goles_B
	FROM Partidos P;
GO

---SELECT * FROM Partidos.vw_resumen_partido
GO

CREATE OR ALTER FUNCTION Partidos.fn_estan_empatados (
	@PartidoID INT
)
RETURNS INT 
AS
RETURN (
	SELECT ISNULL(IIF(goles_A = goles_B, 1, 0), 0)
  FROM Partidos.vw_resumen_partido
  WHERE id = @PartidoID
)
GO
-- Esta función devuelve los jugadores disponibles para un partido, y una selección.
-- Basicamente, toma todos los jugadores convocados, y remueve todos los jugadores con un impedimento activo.

CREATE OR ALTER FUNCTION Partidos.fn_jugadores_disponibles (
	@PartidoID INT,
	@SeleccionID INT
)
RETURNS TABLE
AS 
RETURN (
	SELECT J.*
	FROM Equipos.IntegranteSeleccion J
	JOIN Equipos.ConvocacionEnSeleccion C 
			 ON C.miembro_id = J.id 
			 AND C.f_fin is NULL 
			 AND C.tipo = 'Jugador'
	WHERE C.seleccion_id = @SeleccionID
				AND NOT EXISTS ( -- "Y no exista un impedimento con partidos restantes para el mismo mundial que el partido"
					SELECT 1 
					FROM Eventos.Impedimentos I 
					JOIN Partidos.Partidos P_Origen 
							 ON I.partido_origen_id = P_Origen.id
				  WHERE I.jugador_id = J.id 
							  AND I.cantidad_restante > 0
							  AND P_Origen.mundial_id = (SELECT mundial_id FROM Partidos.Partidos WHERE id = @PartidoID)
				)
)
GO

--- Son los jugadores que están jugando en un instante dado
CREATE OR ALTER FUNCTION Partidos.fn_jugadores_en_cancha (
    @PartidoID INT, 
    @Minuto SMALLINT, 
    @Extra SMALLINT, 
    @Tiempo SMALLINT
)
RETURNS TABLE
AS
RETURN (
    SELECT JPI.jugador_id, JPI.posicion, JPI.seleccion_id, JPI.comienza_jugando, PP.pais_id
    FROM Partidos.JugadorPosicionInicial JPI
    JOIN Mundial.Paises_Participes PP ON PP.seleccion_id = JPI.seleccion_id
    WHERE JPI.partido_id = @PartidoID
      AND (
          -- Arrancó de titular y TODAVÍA NO SALIÓ
          (
              JPI.comienza_jugando = 1 
              AND NOT EXISTS (
                  SELECT 1 
                  FROM Eventos.Cambios C 
                  WHERE C.partido_id = @PartidoID 
                    AND C.jugador_sale_id = JPI.jugador_id
                    -- Condición de tiempo: el cambio ocurrió antes o en el mismo momento que se evalúa
                    AND (
                        C.tiempo < @Tiempo 
                        OR (C.tiempo = @Tiempo AND C.minuto < @Minuto)
                        OR (C.tiempo = @Tiempo AND C.minuto = @Minuto AND C.extra <= @Extra)
                    )
              )
          )
          OR
          -- Arrancó en el banco, YA ENTRÓ, y no volvió a salir
          (
              JPI.comienza_jugando = 0
              -- Ya entró
              AND EXISTS (
                  SELECT 1 
                  FROM Eventos.Cambios C 
                  WHERE C.partido_id = @PartidoID 
                    AND C.jugador_entra_id = JPI.jugador_id
                    AND (
                        C.tiempo < @Tiempo 
                        OR (C.tiempo = @Tiempo AND C.minuto < @Minuto)
                        OR (C.tiempo = @Tiempo AND C.minuto = @Minuto AND C.extra <= @Extra)
                    )
              )
              -- Empezó en el banco, entró, y salió.
              AND NOT EXISTS (
                  SELECT 1 
                  FROM Eventos.Cambios C2
                  WHERE C2.partido_id = @PartidoID 
                    AND C2.jugador_sale_id = JPI.jugador_id
                    AND (
                        C2.tiempo < @Tiempo 
                        OR (C2.tiempo = @Tiempo AND C2.minuto < @Minuto)
                        OR (C2.tiempo = @Tiempo AND C2.minuto = @Minuto AND C2.extra <= @Extra)
                    )
              )
          )
      )
);
GO

--- Se arma una tabla de puntajes
---- Primero por puntos: 3 si ganas, 1 si empatas, 0 si perdés
---- Después se desempata en este orden:
---- .Diferencia de goles, a favor y en contra
---- .Mayor cantidad de goles a favor marcados
---- .Puntos obtenidos en los partidos directos entre los equipos empatados.
---- .Diferencia de goles en los partidos directos entre los equipos empatados.
---- .Goles marcados en los partidos directos entre los equipos empatados.
---- .Puntos de Fair Play (menos tarjetas rojas y amarillas).
---- .Sorteo.

CREATE OR ALTER FUNCTION Partidos.fn_tabla_grupos(@AñoMundial INT)
RETURNS table
RETURN (
	SELECT *, ROW_NUMBER() OVER (
				PARTITION BY grupo 
				ORDER BY puntos DESC, diferencia_de_goles DESC, 
						 goles_a_favor DESC, puntos_de_fair_play ASC
						 --, NEWID() TODO: SQL SERver no le gustan las cosas no deterministicas acá. Hay un workaround que es usando una vista que envuelva un newid
			) as posicion_en_grupo
	FROM Mundial.Paises_Participes
	WHERE mundial_id = @AñoMundial
)
GO

CREATE OR ALTER PROCEDURE Partidos.sp_terminar_fase_de_grupos
	@AñoMundial INT
AS
BEGIN


	DECLARE @cantidadDeEquipos INT = Administracion.fn_obtener_regla(@AñoMundial, 'CANTIDAD_EQUIPOS');

	-- fn_tabla_grupos devuelve el puntaje y la posicion de cada selección dentro de cada grupo.
	-- Necesito tomar los 2 mejores de cada grupo, y los mejorfes terceros, dependiendo de cuantos equipos sean.
	-- Después hay que repartirlos entre los partidos.

	DECLARE @clasificadosFijos INT = @cantidadDeEquipos / 2; -- clasifican 2 de cada grupo de 4

	-- Calculamos la siguiente potencia de 2
	DECLARE @siguientePotenciaDeDos INT = POWER(2, CEILING(LOG(@clasificadosFijos, 2)));

	DECLARE @tercerosFaltantes INT = @siguientePotenciaDeDos - @clasificadosFijos;

	DECLARE @equiposQueAvanzan TABLE (id int IDENTITY(1,1), seleccion_id INT, grupo CHAR(1))


	INSERT INTO @equiposQueAvanzan (seleccion_id, grupo)
	SELECT seleccion_id, grupo
				 FROM Partidos.fn_tabla_grupos(@AñoMundial)
				 WHERE posicion_en_grupo <= 2
				 ORDER BY grupo ASC, posicion_en_grupo ASC -- en teoría ya está ordenado en la funcion igual.

	IF @tercerosFaltantes > 0 BEGIN
		INSERT INTO @equiposQueAvanzan (seleccion_id, grupo)
		SELECT TOP (@tercerosFaltantes) seleccion_id, grupo
					 FROM Partidos.fn_tabla_grupos(@AñoMundial)
					 WHERE posicion_en_grupo = 3
					 ORDER BY puntos DESC
	END

		-- Ahora hay que eliminar a todos los que no están en @equiposQueAvanzan, e ir asignando los que sí avanzan
		-- a los partidos que le siguen a la fase de GRUPOS.
	
	UPDATE Mundial.Paises_Participes
		SET esta_eliminado = 1
		WHERE mundial_id = @AñoMundial
		AND seleccion_id NOT IN (SELECT seleccion_id FROM @equiposQueAvanzan);


	/* ACÁ CARGO LOS PARTIDOS DE LA FASE SIGUIENTE */
	DECLARE @nombreFaseSiguiente VARCHAR(15) = CASE 
		WHEN @siguientePotenciaDeDos = 32 THEN 'DIECISEISAVOS'
		WHEN @siguientePotenciaDeDos = 16 THEN 'OCTAVOS'
		WHEN @siguientePotenciaDeDos = 8  THEN 'CUARTOS'
		WHEN @siguientePotenciaDeDos = 4  THEN 'SEMIFINAL'
	END;

	DECLARE @partidosFaseSiguiente TABLE (
		id INT, 
		nro_partido INT IDENTITY(1,1), -- Al venir ordenados por ID asc, la primera mitad pertenece a una rama de la llave y la segunda a la otra.
		seleccion_A_id INT NULL,
		seleccion_B_id INT NULL
	);

	INSERT INTO @partidosFaseSiguiente (id)
		SELECT id 
		FROM Partidos.Partidos 
		WHERE mundial_id = @AñoMundial AND fase = @nombreFaseSiguiente
		ORDER BY id ASC;

	DECLARE @cantidadPartidos INT = @siguientePotenciaDeDos / 2;


/* REPARTO DE EQUIPOS USANDO WHILE (ALGORITMO ANTI-CRUCE) */
	DECLARE @totalEquipos INT = (SELECT COUNT(*) FROM @equiposQueAvanzan);
	DECLARE @i INT = 1;
	
	DECLARE @curr_seleccion_id INT;
	DECLARE @curr_grupo CHAR(1);
	
	WHILE @i <= @totalEquipos
	BEGIN
		-- 1. Tomamos el equipo actual
		SELECT @curr_seleccion_id = seleccion_id, @curr_grupo = grupo 
		FROM @equiposQueAvanzan 
		WHERE id = @i;

		-- 2. Buscamos de qué lado de la llave ya hay alguien de su grupo (si lo hay)
		DECLARE @mitadOcupada INT = 0; -- 0 = ninguna, 1 = izquierda, 2 = derecha
		
		IF EXISTS (
			SELECT 1 FROM @partidosFaseSiguiente P
			JOIN @equiposQueAvanzan E ON E.seleccion_id IN (P.seleccion_A_id, P.seleccion_B_id)
			WHERE E.grupo = @curr_grupo AND P.nro_partido <= @cantidadPartidos / 2
		) 
			SET @mitadOcupada = 1;
		ELSE IF EXISTS (
			SELECT 1 FROM @partidosFaseSiguiente P
			JOIN @equiposQueAvanzan E ON E.seleccion_id IN (P.seleccion_A_id, P.seleccion_B_id)
			WHERE E.grupo = @curr_grupo AND P.nro_partido > @cantidadPartidos / 2
		) 
			SET @mitadOcupada = 2;

		DECLARE @partidoElegido INT = NULL;
		DECLARE @asignaEnA BIT = 1;

		-- A. Buscar lugar como Equipo A (Local), respetando la mitad libre del cuadro
		SELECT TOP 1 @partidoElegido = id 
		FROM @partidosFaseSiguiente 
		WHERE seleccion_A_id IS NULL
		  AND (@mitadOcupada = 0 OR 
			  (@mitadOcupada = 1 AND nro_partido > @cantidadPartidos / 2) OR 
			  (@mitadOcupada = 2 AND nro_partido <= @cantidadPartidos / 2))
		ORDER BY nro_partido ASC;

		-- B. Si no hay cupo como Equipo A en esa mitad, buscar como Equipo B (Visitante)
		IF @partidoElegido IS NULL
		BEGIN
			SET @asignaEnA = 0;
			SELECT TOP 1 @partidoElegido = id 
			FROM @partidosFaseSiguiente 
			WHERE seleccion_B_id IS NULL
			  -- Asegurar no caer en el MISMO partido que el compañero de grupo
			  AND seleccion_A_id NOT IN (SELECT seleccion_id FROM @equiposQueAvanzan WHERE grupo = @curr_grupo)
			  AND (@mitadOcupada = 0 OR 
				  (@mitadOcupada = 1 AND nro_partido > @cantidadPartidos / 2) OR 
				  (@mitadOcupada = 2 AND nro_partido <= @cantidadPartidos / 2))
			ORDER BY nro_partido ASC;
		END

		-- C. Fallback: Formatos de muchos 3ros pueden forzar colisiones de llave inevitables.
		-- Agarra cualquier partido, pero con la condición estricta de NO cruzarse en primera ronda.
		IF @partidoElegido IS NULL
		BEGIN
			SELECT TOP 1 @partidoElegido = id, @asignaEnA = CASE WHEN seleccion_A_id IS NULL THEN 1 ELSE 0 END
			FROM @partidosFaseSiguiente
			WHERE (seleccion_A_id IS NULL OR seleccion_B_id IS NULL)
			  AND (seleccion_A_id IS NULL OR seleccion_A_id NOT IN (SELECT seleccion_id FROM @equiposQueAvanzan WHERE grupo = @curr_grupo))
			  AND (seleccion_B_id IS NULL OR seleccion_B_id NOT IN (SELECT seleccion_id FROM @equiposQueAvanzan WHERE grupo = @curr_grupo))
			ORDER BY nro_partido ASC;
		END

		-- 3. Guardamos la asignación en la variable temporal
		IF @partidoElegido IS NOT NULL
		BEGIN
			IF @asignaEnA = 1
				UPDATE @partidosFaseSiguiente SET seleccion_A_id = @curr_seleccion_id WHERE id = @partidoElegido;
			ELSE
				UPDATE @partidosFaseSiguiente SET seleccion_B_id = @curr_seleccion_id WHERE id = @partidoElegido;
		END

		-- 4. Avanzar ciclo
		SET @i = @i + 1;
	END;

	/* ACTUALIZACIÓN FINAL EN LA TABLA REAL */
	BEGIN TRY
		BEGIN TRANSACTION
			UPDATE P
			SET P.seleccion_A_id = PF.seleccion_A_id,
				P.seleccion_B_id = PF.seleccion_B_id
			FROM Partidos.Partidos P
			INNER JOIN @partidosFaseSiguiente PF ON P.id = PF.id;
		COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
		THROW;
	END CATCH
END
GO
 
CREATE OR ALTER PROCEDURE Partidos.sp_definir_formacion_inicial 
	@Jugando BIT,
	@Posicion char(2),
	@PartidoID INT,
	@JugadorID INT,
	@SeleccionID INT
AS
BEGIN

	DECLARE @errores VARCHAR(4000) = '';

	if @Jugando is null
		SET @errores = @errores + '- Debe indicar si estaba jugando o no' + CHAR(13) + CHAR(10);

	if @JugadorID is null
		SET @errores = @errores + '- Debe indicar jugador' + CHAR(13) + CHAR(10);

	if @Posicion is null
		SET @errores = @errores + '- Debe indicar posicion' + CHAR(13) + CHAR(10);

	if @SeleccionID is null
		SET @errores = @errores + '- Debe indicar seleccion' + CHAR(13) + CHAR(10);

	if @PartidoID is null
		SET @errores = @errores + '- Debe indicar partido' + CHAR(13) + CHAR(10);

	-- Se obtienen las selecciones que juegan el partido
	-- Se comprueba que el jugador sea de esa Seleccion en ese mundial (y sea jugador)
	-- Se comprueba que el jugador no tenga un impedimento registrado
	-- Se comprueba que no hayan > 11 (si es Jugando true)

	DECLARE @seleccionA INT; DECLARE @seleccionB INT;

	SELECT @seleccionA = seleccion_A_id, @seleccionB = seleccion_B_id 
		FROM Partidos.Partidos
		WHERE id = @PartidoID;

	if (@SeleccionID not in (@seleccionA, @seleccionB)) 
		SET @errores = @errores + '- Esta seleccion no juega este partido' + CHAR(13) + CHAR(10);

	if((SELECT 1 FROM Equipos.ConvocacionEnSeleccion WHERE miembro_id = @JugadorID and tipo = 'Jugador' and seleccion_id = @SeleccionID) <> 1) 
		SET @errores = @errores + '- El miembro no es jugador o no es parte de esa seleccion' + CHAR(13) + CHAR(10);

	-- Valido que no esté baneado

	DECLARE @añoMundial INT = (SELECT mundial_id FROM Partidos.Partidos WHERE id = @PartidoID);

	IF @añoMundial IS NULL
		SET @errores = @errores + '- El partido no existe' + CHAR(13) + CHAR(10);

	-- if (SELECT I.cantidad_restante FROM Eventos.Impedimentos  I
	-- 		INNER JOIN Partidos.Partidos P ON P.id = I.partido_origen_id
	-- 		WHERE I.jugador_id = @JugadorID and P.mundial_id = @añoMundial) > 0
	-- 	SET @errores = @errores + '- El jugador tiene un impedimento activo' + CHAR(13) + CHAR(10);
	
	if EXISTS (SELECT 1 FROM Partidos.JugadorPosicionInicial WHERE jugador_id = @JugadorID and partido_id = @PartidoID) 
		SET @errores = @errores + '- El jugador ya está en este partido' + CHAR(13) + CHAR(10);

	DECLARE @cantidadJugando INT = (select COUNT(1) from Partidos.JugadorPosicionInicial WHERE comienza_jugando = 1 and partido_id = @PartidoID and seleccion_id = @SeleccionID);
	DECLARE @cantidadSuplente INT = (select COUNT(1) from Partidos.JugadorPosicionInicial WHERE comienza_jugando = 0 and partido_id = @PartidoID and seleccion_id = @SeleccionID);
	DECLARE @cantidadAmonestados INT = 0; -- TODO: CANTIDAD DE AMONESTADOS!
	DECLARE @cantidadConvocados INT = (SELECT count(*) FROM Equipos.fn_obtener_jugadores_convocados(@SeleccionID));

	IF (@Jugando = 1) BEGIN 
		IF (@cantidadJugando >= 11) 
			SET @errores = @errores + '- Se alcanzó el limite de jugadores EN LA CANCHA' + CHAR(13) + CHAR(10);
	END ELSE BEGIN
		if ((@cantidadConvocados - @cantidadAmonestados - 11) <= @cantidadSuplente) 
			SET @errores = @errores + '- Se alcanzó el limite de jugadores EN EL BANCO' + CHAR(13) + CHAR(10);
	END;

	if @errores <> ''
		throw 50001, @errores, 1;

	INSERT INTO Partidos.JugadorPosicionInicial
		(jugador_id, partido_id, posicion, seleccion_id, comienza_jugando)
		VALUES
		(@JugadorID, @PartidoID, @Posicion, @SeleccionID, @Jugando);
END
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
	IF @AñoMundial is null	or @SedeID is null or @Fase = NULL
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
		WHERE PP1.mundial_id = @AñoMundial and PP2.mundial_id = @AñoMundial
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

CREATE OR ALTER PROCEDURE Partidos.sp_terminar_partido 
	@PartidoID INT
AS
BEGIN 
	SET NOCOUNT ON

	DECLARE @errores VARCHAR(4000) = '';

	if @PartidoID is null
		SET @errores = @errores + '- Debe indicar partido' + CHAR(13) + CHAR(10);
	ELSE IF NOT EXISTS (SELECT mundial_id FROM Partidos.Partidos WHERE id = @PartidoID)
		SET @errores = @errores + '- El partido no existe' + CHAR(13) + CHAR(10);

	if @errores <> ''
		throw 50001, @errores, 1;

	DECLARE @añoMundial SMALLINT = (SELECT mundial_id FROM Partidos.Partidos WHERE id = @PartidoID);

	-- Tengo que fijarme quién tiene más goles.
	DECLARE @golesA INT = 0;
	DECLARE @golesB INT = 0;
	DECLARE @fase VARCHAR(15);
	DECLARE @seleccionA INT = 0;
	DECLARE @seleccionB INT = 0;
	DECLARE @seleccionGanadora INT = NULL;
	SELECT @fase = fase, 
				 @golesA = goles_A, @golesB = goles_B,
				 @seleccionA = seleccion_A_id, @seleccionB = seleccion_B_id
				 FROM Partidos.vw_resumen_partido WHERE id = @PartidoID;

	IF @golesA > @golesB SET @seleccionGanadora = @seleccionA;
	IF @golesB > @golesA SET @seleccionGanadora = @seleccionB;

	UPDATE Partidos.Partidos 
		SET seleccion_ganadora_id = @seleccionGanadora 
		WHERE id = @PartidoID;

	--------- A PARTIR DE ACÁ, EL COMPORTAMIENTO CAMBIA SEGÚN LA FASE.
	-- GRUPOS: ACTUALIZO PUNTOS.
	-- FINAL: ganador del mundial
	-- SEMIFINAL: Recursividad normal y tercer puesto
	-- TERCER PUESTO: Define 3er y 4to puesto
	-- el resto: recursividad comun (avanza el q gana, eliminado el q pierde)

	-- Si es de grupos, hay que actualizar los datos de puntos!
	IF @fase = 'GRUPOS' BEGIN 
		
		---TODO: hacer los puntos de fair play
		-- TODO: Transaccion

		UPDATE Mundial.Paises_Participes
		SET 
			goles_a_favor   = goles_a_favor + IIF(seleccion_id = @seleccionA, @golesA, @golesB),
			goles_en_contra = goles_en_contra + IIF(seleccion_id = @seleccionA, @golesB, @golesA),
			ganados         = ganados + IIF(seleccion_id = @seleccionGanadora, 1, 0),
			perdidos        = perdidos + IIF(@seleccionGanadora IS NOT NULL AND seleccion_id <> @seleccionGanadora, 1, 0),
			empatados       = empatados + IIF(@seleccionGanadora IS NULL, 1, 0)
		WHERE seleccion_id IN (@seleccionA, @seleccionB);

	END

	-- Si NO es fase de grupos, hay que llevar al ganador al siguiente partido 
	-- IF @fase <> ' GRUPOS'

	-- -- -- -- 


END
GO

/*
SELECT TOP 1 * FROM Mundial.Mundiales ORDER BY año desc

EXEC Partidos.sp_generar_partidos @AñoMundial = 2022, @PaisesSedes = NULL

Select * FROM Partidos.Partidos;*/