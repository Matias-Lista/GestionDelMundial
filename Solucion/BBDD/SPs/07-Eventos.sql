/* BBDD/SPs/Eventos.sql
 * Fecha: 18/10/2026
 * Lista, Matías Josué.
 * Descripción: Crea todos los store procedures, funciones, y vistas del schema [Eventos].
 **/
 
USE GestionDelMundial;
GO


CREATE OR ALTER PROCEDURE Eventos.sp_registrar_gol
	@Minuto SMALLINT,
	@Extra SMALLINT,
	@Tiempo SMALLINT,
	@PartidoID SMALLINT,
	@Tipo CHAR(1),
	@JugadorID SMALLINT,
	@JugadorAsistenteID SMALLINT = NULL
AS	
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @errores VARCHAR(4000) = '';

	if @Minuto is null
		SET @errores = @errores + '- Debe indicar minuto' + CHAR(13) + CHAR(10);
	else if @Minuto not between 0 and 45
		SET @errores = @errores + '- El minuto debe estar entre 0 y 45' + CHAR(13) + CHAR(10);

	if @Extra is null
		SET @errores = @errores + '- Debe indicar extra' + CHAR(13) + CHAR(10);
	else if @Extra > 0 and 
			((@Minuto is not null and @Minuto < 45 and @Tiempo is not null and @Tiempo <= 2) OR
			 (@Minuto is not null and @Minuto < 15 and @Tiempo is not null and @Tiempo >= 3)
			 )
		SET @errores = @errores + '- No puede haber extra si no termino el tiempo actual' + CHAR(13) + CHAR(10);

	if @Tiempo is null
		SET @errores = @errores + '- Debe indicar tiempo' + CHAR(13) + CHAR(10);
	else if @Tiempo not between 1 and 4
		SET @errores = @errores + '- Solo hay 4 tiempos en un partido.' + CHAR(13) + CHAR(10);

	if @JugadorID is null
		SET @errores = @errores + '- Debe indicar jugador' + CHAR(13) + CHAR(10);
	else IF NOT EXISTS (SELECT 1 FROM Equipos.IntegranteSeleccion WHERE id = @JugadorID)
		SET @errores = @errores + '- El jugador no existe' + CHAR(13) + CHAR(10);

	IF @JugadorAsistenteID is not null AND NOT EXISTS (SELECT 1 FROM Equipos.IntegranteSeleccion WHERE id = @JugadorAsistenteID)
		SET @errores = @errores + '- El jugador asistente no existe' + CHAR(13) + CHAR(10);

	if @PartidoID is null
		SET @errores = @errores + '- Debe indicar partido' + CHAR(13) + CHAR(10);

	DECLARE @añoMundial INT = (SELECT mundial_id FROM Partidos.Partidos WHERE id = @PartidoID);

	IF @añoMundial is null 
		SET @errores = @errores + '- El partido no existe' + CHAR(13) + CHAR(10);

	IF @JugadorID is not null and @JugadorAsistenteID is not null and @JugadorID = @JugadorAsistenteID
		SET @errores = @errores + '- El jugador no puede asistirse a sí mismo' + CHAR(13) + CHAR(10);

	IF @errores <> '' THROW 50001, @errores, 1;

	-- Lo siguiente es validar si esos jugadores estaban o no en la cancha en ese minuto, extra y tiempo

	IF NOT EXISTS (SELECT 1 
				FROM Partidos.fn_jugadores_en_cancha(@PartidoID, @Minuto, @Extra, @Tiempo) 
				WHERE jugador_id = @JugadorID) 
		SET @errores = @errores + '- El jugador principal no estaba en la cancha en ese momento' + CHAR(13) + CHAR(10);

	IF @JugadorAsistenteID IS NOT NULL 
	   AND NOT EXISTS (SELECT 1 
				FROM Partidos.fn_jugadores_en_cancha(@PartidoID, @Minuto, @Extra, @Tiempo) 
				WHERE jugador_id = @JugadorAsistenteID)  
		SET @errores = @errores + '- El jugador asistente no estaba en la cancha en ese momento' + CHAR(13) + CHAR(10);

	IF @errores <> '' THROW 50001, @errores, 1;

	INSERT INTO Eventos.Goles 
		(partido_id, jugador_autor_id, jugador_asistente_id, tipo,
	    minuto, extra, tiempo)
	    VALUES
		(@PartidoID, @JugadorID, @JugadorAsistenteID, @Tipo,
	    @Minuto, @Extra, @Tiempo);

END
GO

-- Primero, se diseñó la tabla pensando que siempre que alguien salga, entra otro jugador
-- Eso en realidad no pasa. A veces salen o entran jugadores sin que tenga una operacion contraria asociada
-- Asique el SP permite ambas cosas: Atribuir un ingreso a una salida, o hacerlo por separado.

CREATE OR ALTER PROCEDURE Eventos.sp_registrar_cambio
	@Minuto SMALLINT,
	@Extra SMALLINT,
	@Tiempo SMALLINT,
	@PartidoID SMALLINT,
	@Motivo VARCHAR(10),
	@JugadorEntraID SMALLINT = NULL,
	@JugadorSaleID SMALLINT = NULL
AS	
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @errores VARCHAR(4000) = '';

	if @Minuto is null
		SET @errores = @errores + '- Debe indicar minuto' + CHAR(13) + CHAR(10);
	else if @Minuto not between 0 and 45
		SET @errores = @errores + '- El minuto debe estar entre 0 y 45' + CHAR(13) + CHAR(10);

	if @Extra is null
		SET @errores = @errores + '- Debe indicar extra' + CHAR(13) + CHAR(10);
	else if @Extra > 0 and 
			((@Minuto is not null and @Minuto < 45 and @Tiempo is not null and @Tiempo <= 2) OR
			 (@Minuto is not null and @Minuto < 15 and @Tiempo is not null and @Tiempo >= 3)
			 )
		SET @errores = @errores + '- No puede haber extra si no termino el tiempo actual' + CHAR(13) + CHAR(10);

	if @Tiempo is null
		SET @errores = @errores + '- Debe indicar tiempo' + CHAR(13) + CHAR(10);
	else if @Tiempo not between 1 and 4
		SET @errores = @errores + '- Solo hay 4 tiempos en un partido.' + CHAR(13) + CHAR(10);

	IF @JugadorEntraID is NOT null IF NOT EXISTS (SELECT 1 FROM Equipos.IntegranteSeleccion WHERE id = @JugadorEntraID)
		SET @errores = @errores + '- El jugador que entra no existe' + CHAR(13) + CHAR(10);

	IF @JugadorSaleID is not null and @JugadorSaleID is not null AND NOT EXISTS (SELECT 1 FROM Equipos.IntegranteSeleccion WHERE id = @JugadorSaleID)
		SET @errores = @errores + '- El jugador que sale no existe' + CHAR(13) + CHAR(10);

	IF @JugadorSaleID is null and @JugadorEntraID is null
		SET @errores = @errores + '- Se debe definir al menos un jugador que entre o salga' + CHAR(13) + CHAR(10);

	if @PartidoID is null
		SET @errores = @errores + '- Debe indicar partido' + CHAR(13) + CHAR(10);

	DECLARE @añoMundial INT = (SELECT mundial_id FROM Partidos.Partidos WHERE id = @PartidoID);

	IF @añoMundial is null 
		SET @errores = @errores + '- El partido no existe' + CHAR(13) + CHAR(10);

	IF @Motivo is null 
		SET @errores = @errores + '- Debe indicar un motivo' + CHAR(13) + CHAR(10);
	ELSE IF @Motivo not in ('TACTICO', 'LESION', 'PRECAUCION')
		SET @errores = @errores + '- El motivo no es válido' + CHAR(13) + CHAR(10);

	IF @errores <> '' THROW 50001, @errores, 1;

	-- Lo siguiente es validar si esos jugadores estaban o no en la cancha en ese minuto, extra y tiempo

	IF @JugadorSaleID is not null and NOT EXISTS (SELECT 1 
				FROM Partidos.fn_jugadores_en_cancha(@PartidoID, @Minuto, @Extra, @Tiempo) 
				WHERE jugador_id = @JugadorSaleID) 
		SET @errores = @errores + '- El jugador que debería salir no estaba en la cancha en ese momento' + CHAR(13) + CHAR(10);

	IF @JugadorEntraID is not null and EXISTS (SELECT 1 
				FROM Partidos.fn_jugadores_en_cancha(@PartidoID, @Minuto, @Extra, @Tiempo) 
				WHERE jugador_id = @JugadorEntraID)  
		SET @errores = @errores + '- El jugador que debería entrar, ya estaba en la cancha' + CHAR(13) + CHAR(10);

	-- El que entra, no debe haber entrado ni salido ANTES. Y DEBE estar en la formacion inicial (si tenia una roja, no entra)

	IF @JugadorEntraID is not null and NOT EXISTS (SELECT 1 
					FROM Partidos.JugadorPosicionInicial 
					WHERE partido_id = @PartidoID and jugador_id = @JugadorEntraID)
		SET @errores = @errores + '- El jugador que debería entrar, no participó del partido' + CHAR(13) + CHAR(10);

	IF @JugadorEntraID is not null and NOT EXISTS (SELECT 1 
					FROM Partidos.JugadorPosicionInicial 
					WHERE partido_id = @PartidoID and jugador_id = @JugadorEntraID)
		SET @errores = @errores + '- El jugador que debería entrar, no participó del partido' + CHAR(13) + CHAR(10);

	IF EXISTS (SELECT 1 
				FROM Eventos.Cambios 
				WHERE (jugador_entra_id = @JugadorEntraID or jugador_sale_id = @JugadorEntraID)
					and partido_id = @PartidoID)
		SET @errores = @errores + '- El jugador que debería entrar, ya participó del partido' + CHAR(13) + CHAR(10);

	IF @errores <> '' THROW 50001, @errores, 1;


	INSERT INTO Eventos.Cambios 
		(partido_id, jugador_entra_id, jugador_sale_id, motivo,
	    minuto, extra, tiempo)
	    VALUES
		(@PartidoID, @JugadorEntraID, @JugadorSaleID, @Motivo,
	    @Minuto, @Extra, @Tiempo);

	--- TODO: DEBERÍA VALIDAR TAMBIÉN SI LOS JUGADORES SON DE LA MISMA SELECCIÓN!
	--- TODO: debería validar la cantidad de cambios con la regla CANTIDAD_DE_CAMBIOS
	--- TODO: debería validar la cantidad de JUGADORES QUE QUEDAN EN LA CANCHA

END
GO







--Le asigno un numero a cada fase para poder ordenar o comparar facilmente las fases en conusultas
CREATE OR ALTER FUNCTION Eventos.fn_orden_fase (@Fase VARCHAR(15))
RETURNS INT
AS
BEGIN
	RETURN CASE @Fase
		WHEN 'GRUPOS'        THEN 1
		WHEN 'DIECISEISAVOS' THEN 2
		WHEN 'OCTAVOS'       THEN 3
		WHEN 'CUARTOS'       THEN 4
		WHEN 'SEMIFINAL'     THEN 5
		WHEN 'TERCER_PUESTO' THEN 6
		WHEN 'FINAL'         THEN 6
	END;
END
GO

---VALIDA que un evento sucesa en un minuto y tiempo coherente de un partido
CREATE OR ALTER FUNCTION Eventos.fn_validar_momento (@PartidoID INT, @Minuto SMALLINT, @Tiempo CHAR(1)) --le paso el tiempo (primer tiempo, seg, suplementario1 0 2)
RETURNS NVARCHAR(300)
AS
BEGIN
	-- Los minutos son ABSOLUTOS un gol a los 45+2 se carga como minuto 47 DEL TIEMPO 1
	-- (en caso de no cargarse el tiempo adicional se pone una tolerancia de 10 min)
	DECLARE @errores NVARCHAR(300) = '';
	DECLARE @fase VARCHAR(15);
	DECLARE @adicional SMALLINT;

	SELECT @fase = fase,
		   @adicional = CASE @Tiempo
							WHEN '1' THEN tiempo_adicional_1
							WHEN '2' THEN tiempo_adicional_2
							WHEN '3' THEN tiempo_adicional_3
							WHEN '4' THEN tiempo_adicional_4
						END
		FROM Partidos.Partidos
		WHERE id = @PartidoID;

	DECLARE @inicio SMALLINT = CASE @Tiempo WHEN '1' THEN 0  WHEN '2' THEN 45 WHEN '3' THEN 90  WHEN '4' THEN 105 END;
	DECLARE @fin SMALLINT    = CASE @Tiempo WHEN '1' THEN 45 WHEN '2' THEN 90 WHEN '3' THEN 105 WHEN '4' THEN 120 END + ISNULL(@adicional, 10);

	IF (@Tiempo IS NULL OR @Tiempo NOT IN ('1', '2', '3', '4'))
		SET @errores = @errores + 'El tiempo debe ser 1, 2, 3 o 4 (3 y 4 son el suplementario). ';
	ELSE IF (@Minuto IS NULL OR @Minuto NOT BETWEEN @inicio AND @fin)
		SET @errores = @errores + CONCAT('Para el tiempo ', @Tiempo, ' el minuto debe estar entre ', @inicio, ' y ', @fin, '. ');

	IF (@Tiempo IN ('3', '4') AND @fase = 'GRUPOS')
		SET @errores = @errores + 'En fase de grupos no hay tiempo suplementario. ';

	RETURN @errores;
END
GO




CREATE OR ALTER FUNCTION Eventos.fn_resultado_partido (@PartidoID INT)
RETURNS TABLE
AS
RETURN (
	SELECT
		P.id AS partido_id,
		P.seleccion_A_id,
		SUM(CASE WHEN (J.seleccion_id = P.seleccion_A_id AND G.tipo <> 'E')
				   OR (J.seleccion_id = P.seleccion_B_id AND G.tipo = 'E') THEN 1 ELSE 0 END) AS goles_A,
		P.seleccion_B_id,
		SUM(CASE WHEN (J.seleccion_id = P.seleccion_B_id AND G.tipo <> 'E')
				   OR (J.seleccion_id = P.seleccion_A_id AND G.tipo = 'E') THEN 1 ELSE 0 END) AS goles_B
	FROM Partidos.Partidos P
	LEFT JOIN Eventos.Goles G ON G.partido_id = P.id
	LEFT JOIN Partidos.JugadorPosicionInicial J ON J.partido_id = G.partido_id AND J.jugador_id = G.jugador_autor_id
	WHERE P.id = @PartidoID
	GROUP BY P.id, P.seleccion_A_id, P.seleccion_B_id
);
GO

----------------------------------------------------------------------SP-------------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE Eventos.sp_eliminar_amonestacion
	@ID INT
AS
BEGIN
	DECLARE @errores NVARCHAR(500) = '';

	DECLARE @partidoId INT;
	DECLARE @jugadorId INT;
	DECLARE @tarjeta CHAR(1);

	SELECT @partidoId = partido_id, @jugadorId = jugador_id, @tarjeta = tarjeta
		FROM Eventos.Amonestaciones
		WHERE id = @ID;

	IF (@partidoId IS NULL)
		SET @errores = @errores + 'No existe una amonestación con ese ID. ';

	IF (@tarjeta = 'A' AND EXISTS (SELECT 1 FROM Eventos.Amonestaciones WHERE partido_id = @partidoId AND jugador_id = @jugadorId AND es_doble_amarilla = 1))
		SET @errores = @errores + 'La amarilla forma parte de una expulsión por doble amarilla: elimine primero la roja. ';

	IF EXISTS (SELECT 1 FROM Eventos.Impedimentos WHERE partido_origen_id = @partidoId AND jugador_id = @jugadorId)
		SET @errores = @errores + 'El jugador tiene una suspensión generada en este partido: elimínela primero.';

	IF (@errores <> '')
		THROW 50001, @errores, 1;

	DELETE FROM Eventos.Amonestaciones
		WHERE id = @ID;
END
GO





CREATE OR ALTER PROCEDURE Eventos.sp_registrar_impedimento
	@JugadorID INT,
	@PartidoOrigenID INT,
	@PartidosRestantes SMALLINT,
	@Motivo CHAR(1) = 'D'
AS
BEGIN
	DECLARE @errores NVARCHAR(500) = '';

	IF NOT EXISTS (SELECT 1 FROM Partidos.JugadorPosicionInicial WHERE partido_id = @PartidoOrigenID AND jugador_id = @JugadorID)
		SET @errores = @errores + 'El jugador no participó de ese partido. ';

	IF (@PartidosRestantes IS NULL OR @PartidosRestantes <= 0)
		SET @errores = @errores + 'La sanción debe ser de al menos un partido. ';

	IF (@Motivo IS NULL OR @Motivo NOT IN ('A', 'R', 'D'))
		SET @errores = @errores + 'El motivo debe ser A (amarillas), R (roja) o D (disciplinario). ';

	IF EXISTS (SELECT 1 FROM Eventos.Impedimentos WHERE jugador_id = @JugadorID AND partido_origen_id = @PartidoOrigenID AND motivo = @Motivo)
		SET @errores = @errores + 'El jugador ya tiene una sanción con ese motivo originada en ese partido.';

	IF (@errores <> '')
		THROW 50001, @errores, 1;

	INSERT INTO Eventos.Impedimentos
		(jugador_id, partido_origen_id, motivo, partidos_restantes)
		VALUES
		(@JugadorID, @PartidoOrigenID, @Motivo, @PartidosRestantes);
END
GO

CREATE OR ALTER PROCEDURE Eventos.sp_modificar_impedimento
	@ID INT,
	@PartidosRestantes SMALLINT
AS
BEGIN
	-- Corrección manual de los partidos que le quedan (0 = sanción cumplida).
	DECLARE @errores NVARCHAR(500) = '';

	IF NOT EXISTS (SELECT 1 FROM Eventos.Impedimentos WHERE id = @ID)
		SET @errores = @errores + 'No existe un impedimento con ese ID. ';

	IF (@PartidosRestantes IS NULL OR @PartidosRestantes < 0)
		SET @errores = @errores + 'Los partidos restantes no pueden ser negativos.';

	IF (@errores <> '')
		THROW 50001, @errores, 1;

	UPDATE Eventos.Impedimentos
		SET partidos_restantes = @PartidosRestantes
		WHERE id = @ID;
END
GO

CREATE OR ALTER PROCEDURE Eventos.sp_eliminar_impedimento
	@ID INT
AS
BEGIN
	DECLARE @errores NVARCHAR(500) = '';

	IF NOT EXISTS (SELECT 1 FROM Eventos.Impedimentos WHERE id = @ID)
		SET @errores = @errores + 'No existe un impedimento con ese ID.';

	IF (@errores <> '')
		THROW 50001, @errores, 1;

	DELETE FROM Eventos.Impedimentos
		WHERE id = @ID;
END
GO


