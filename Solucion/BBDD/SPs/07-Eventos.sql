/* BBDD/SPs/Eventos.sql
 * Fecha: 18/10/2026
 * Lista, Matías Josué.
 * Descripción: Crea todos los store procedures, funciones, y vistas del schema [Eventos].
 **/
 
USE GestionDelMundial;
GO


CREATE OR ALTER FUNCTION Eventos.fn_tiempo(
    @Minuto SMALLINT, 
    @Extra  SMALLINT, 
    @Tiempo SMALLINT
)
RETURNS VARCHAR(100)
AS
BEGIN
	RETURN (
		CONCAT(
			'T', CAST(@Tiempo as CHAR(1)), '-',
			CAST(@Minuto as CHAR(2)), '''',
			IIF(@Extra > 0, CONCAT('+', CAST(@Extra as CHAR(2)), ''''),'')
		)
	)
END
GO

CREATE OR ALTER FUNCTION Eventos.fn_mapear_fase (
	@fase VARCHAR(25)
)
RETURNS INT
AS
BEGIN RETURN CASE 
		WHEN @fase = 'FINAL'         THEN 1
		WHEN @fase = 'SEMIFINAL'     THEN 2
		WHEN @fase = 'TERCER_PUESTO' THEN 2
		WHEN @fase = 'CUARTOS'       THEN 3
		WHEN @fase = 'OCTAVOS'       THEN 4
		WHEN @fase = 'DIECISEISAVOS' THEN 5
		WHEN @fase = 'GRUPOS'        THEN 6
	END
END
GO

-- Las reglas establecen que solo pueden patear penales una vez cada uno de los jugadores presentes en el ultimo minuto del partido.
-- Por otro lado, establece que puede repetirse el tiro de un jugador, si ya patearon los ONCE jugadores.
-- EN el mundial de futbol masculino no pasó nunca, por lo tanto, de momento, solo voy a comprobar que no se repitan.
CREATE OR ALTER PROCEDURE Eventos.sp_registrar_penal_de_tanda
	@PartidoID INT,
	@JugadorID INT,
	@Convirtio INT
AS 
BEGIN

	SET NOCOUNT ON;
	
	DECLARE @errores VARCHAR(4000) = '';

	if @JugadorID is null
		SET @errores = @errores + '- Debe indicar jugador' + CHAR(13) + CHAR(10);
	else IF NOT EXISTS (SELECT 1 FROM Equipos.IntegranteSeleccion WHERE id = @JugadorID)
		SET @errores = @errores + '- El jugador no existe' + CHAR(13) + CHAR(10);

	if @PartidoID is null
		SET @errores = @errores + '- Debe indicar partido' + CHAR(13) + CHAR(10);
	else IF NOT EXISTS (SELECT 1 FROM Partidos.Partidos WHERE id = @PartidoID)
		SET @errores = @errores + '- El partido no existe' + CHAR(13) + CHAR(10);

	IF @Convirtio IS NULL 
		SET @errores = @errores + '- Debe indicar si convirtio' + CHAR(13) + CHAR(10);

	IF @errores <> '' THROW 50001, @errores, 1;

	IF EXISTS (SELECT 1 FROM Eventos.PenalesDeTanda WHERE jugador_id = @JugadorID AND partido_id = @PartidoID) 
		SET @errores = @errores + '- El jugador ya pateó un penal en ese partido' + CHAR(13) + CHAR(10);

	IF NOT EXISTS (SELECT 1 
				FROM Partidos.fn_jugadores_en_cancha(@PartidoID, 15, 45, 4) -- Máximo  
				WHERE jugador_id = @JugadorID) 
		SET @errores = @errores + '- El jugador no estaba en la cancha en ese momento' + CHAR(13) + CHAR(10);

	IF @errores <> '' THROW 50001, @errores, 1;

	-- TODO: Se debería validar de alguna forma si el partido terminó o si los penales terminaron

	INSERT INTO Eventos.PenalesDeTanda 
		(partido_id, jugador_id, convirtio)
		VALUES
		(@PartidoID, @JugadorID, @Convirtio);

END
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
	ELSE IF @Motivo not in ('TACTICO', 'LESION', 'PRECAUCION', 'EXPULSION')
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


-- Reglas de negocio:
--  *  Dos amarillas en un partido: Expulsión del jugador en el partido actual (un evento de cambio sin entrada),
--     y suspensión para el proximo partido.
--  *  Dos amarillas entre dos partidos: continúa jugando el partido, pero se registra un impedimento para el próximo partido
--  *  La cantidad de amarillas acumuladas se reinicia en distintas fases, en cada mundial. Por ejemplo, el 2022, es solo en semifinal, y en el 2026, fue mundial y grupos.
---    Por lo tanto sumo reglas en la creacion del mundial (REINICIA_AMARILLAS_EN_FASE_DE_GRUPOS, REINICIA_AMARILLAS_EN_SEMIFINAL)
--  *  El TP solicita que se pueda parametrizar el criterio de expulsión. Voy a hacer una regla "AMARILLAS_PARA_EXPULSION"

CREATE OR ALTER PROCEDURE Eventos.sp_registrar_amonestacion 
	@Minuto SMALLINT,
	@Extra SMALLINT,
	@Tiempo SMALLINT,
	@PartidoID INT,
	@JugadorID INT,
	@Tarjeta CHAR(1),
	@Motivo VARCHAR(200) = NULL,
	@PartidosSuspendidos INT = 1
AS 
BEGIN

	SET NOCOUNT ON;
	
	DECLARE @errores VARCHAR(4000) = '';

	IF @PartidosSuspendidos is not null and @PartidosSuspendidos <= 0
		SET @errores = @errores + '- La suspensión debe ser mayor a 0.' + CHAR(13) + CHAR(10);

	IF @Tarjeta is null
		SET @errores = @errores + '- Se debe indicar una tarjeta' + CHAR(13) + CHAR(10);
	ELSE IF @Tarjeta not in ('A', 'R')
		SET @errores = @errores + '- La tarjeta solo puede ser amarilla (A) o roja (R)' + CHAR(13) + CHAR(10);

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

	IF @JugadorID is NOT null and NOT EXISTS (SELECT 1 FROM Equipos.IntegranteSeleccion WHERE id = @JugadorID)
		SET @errores = @errores + '- El jugador que entra no existe' + CHAR(13) + CHAR(10);

	if @PartidoID is null
		SET @errores = @errores + '- Debe indicar partido' + CHAR(13) + CHAR(10);

	DECLARE @añoMundial INT = NULL;
	DECLARE @fase VARCHAR(25) = NULL;

	SELECT @añoMundial = mundial_id, @fase = fase FROM Partidos.Partidos WHERE id = @PartidoID;

	IF @añoMundial is null 
		SET @errores = @errores + '- El partido no existe' + CHAR(13) + CHAR(10);

	IF @errores <> '' THROW 50001, @errores, 1;

	-- No es necesario qeu esté en cancha, pero sí que esté en el partido.
	IF NOT EXISTS (SELECT 1 
				FROM Partidos.JugadorPosicionInicial
				WHERE partido_id = @PartidoID AND jugador_id = @JugadorID
		) 
		SET @errores = @errores + '- El jugador que debería ser amonestado no estaba en ese partido' + CHAR(13) + CHAR(10);

	IF @errores <> '' THROW 50001, @errores, 1;

	--- Para este punto, ya determinamos que ES POSIBLE asignarle una amonestación a este jugador.
	-- ahora evalúo si amerita expulsión o no.
	DECLARE @ameritaExpulsion BIT = 0;
	DECLARE @alcanzaLimiteAmarillas BIT = 0;
	DECLARE @ameritaImpedimento BIT = 0;
	
	IF @Tarjeta = 'R' BEGIN
		SET @ameritaExpulsion  = 1;
		SET @ameritaImpedimento = 1;
	END ELSE IF @Tarjeta = 'A' BEGIN
		-- hay que ver si llegó al limite de amarillas en un mismo partido.
		DECLARE @limiteDeAmarillas INT;
		
		EXEC Administracion.sp_obtener_regla
			 @AñoMundial = @añoMundial,
			 @Codigo = 'AMARILLAS_PARA_EXPULSION',
			 @Valor = @limiteDeAmarillas OUTPUT;

		IF (SELECT count(*) 
			FROM Eventos.Amonestaciones 
			WHERE tarjeta = 'A' and partido_id = @PartidoID 
			      and jugador_id = @JugadorID) + 1 = @limiteDeAmarillas
		BEGIN
			SET @ameritaExpulsion = 1;
			SET @alcanzaLimiteAmarillas = 1;
		END ELSE BEGIN
			-- Si no alcanza el límite de amarillas en ese partido, hay que ver, la cantidad de amarillas, en el mundial.

			-- Mapear fases:

			DECLARE @faseMinimaAConsiderar VARCHAR(25) = 'GRUPOS'; -- Por defecto, todo el mundial

			-- Si es después de LA SEMIFINAL
			IF Eventos.fn_mapear_fase(@fase) <= Eventos.fn_mapear_fase('SEMIFINAL') BEGIN
				
				DECLARE @reiniciaEnSemifinal BIT;
				EXEC Administracion.sp_obtener_regla
					 @AñoMundial = @añoMundial,
					 @Codigo = 'REINICIA_AMARILLAS_EN_SEMIFINAL',
					 @Valor = @reiniciaEnSemifinal OUTPUT;

				IF @reiniciaEnSemifinal = 1 
					SET @faseMinimaAConsiderar = 'SEMIFINAL';

			-- Si está entre GRUPOS y SEMIFINAL
			END ELSE IF Eventos.fn_mapear_fase(@fase) <= Eventos.fn_mapear_fase('GRUPOS') BEGIN

				DECLARE @reiniciaEnGrupos BIT;
				EXEC Administracion.sp_obtener_regla
					 @AñoMundial = @añoMundial,
					 @Codigo = 'REINICIA_AMARILLAS_EN_FASE_DE_GRUPOS',
					 @Valor = @reiniciaEnGrupos OUTPUT;

				IF @reiniciaEnGrupos = 1 
					SET @faseMinimaAConsiderar = 'DIECISEISAVOS'; -- POST GRUPOS

			END

			IF (SELECT count(1) 
				FROM Eventos.Amonestaciones A
				INNER JOIN Partidos.Partidos P ON P.id = A.partido_id 
				WHERE A.tarjeta = 'A' and eventos.fn_mapear_fase(P.fase) <= Eventos.fn_mapear_fase(@faseMinimaAConsiderar)
				      and A.jugador_id = @JugadorID and P.mundial_id = @añoMundial) + 1 = @limiteDeAmarillas
			BEGIN
				set @ameritaImpedimento = 1;
			END

		END

	END -- End @Tarjeta = 'A'

	-- En este punto tenemos que falta es, si amerita impedimento, y si amerita expulsion.


	BEGIN TRY
	BEGIN TRANSACTION 
	SAVE TRANSACTION sp_registrar_amonestacion
	
		INSERT INTO Eventos.Amonestaciones
			(partido_id, jugador_id, tarjeta, 
			 alcanza_acumulacion_amarillas,
			 motivo, minuto, extra, tiempo)
			VALUES 
			(@PartidoID, @JugadorID, @Tarjeta, 
			 @alcanzaLimiteAmarillas, 
			 @Motivo, @Minuto, @Extra, @Tiempo);

		IF @ameritaExpulsion = 1
			EXEC Eventos.sp_registrar_cambio
				 @Minuto = @Minuto,
				 @Extra  = @Extra,
				 @Tiempo = @Tiempo,
				 @PartidoID = @PartidoID,
				 @Motivo = 'EXPULSION',
				 @JugadorSaleID = @JugadorID;

		IF @ameritaImpedimento = 1
			INSERT INTO Eventos.Impedimentos 
				(jugador_id, partido_origen_id, cantidad_de_partidos, cantidad_restante)
				VALUES
				(@JugadorID, @PartidoID, @PartidosSuspendidos, @PartidosSuspendidos);

	COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		if @@TRANCOUNT > 0
			ROLLBACK TRANSACTION sp_registrar_amonestacion;
		throw
	END CATCH
END
GO