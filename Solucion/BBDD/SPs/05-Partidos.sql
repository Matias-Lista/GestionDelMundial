/* BBDD/SPs/Partidos.sql
 * Fecha: 9/10/2026
 * Integrantes: Lista, Matías Josué. Maldonado Medrano, Milagros.
 * Descripción: Crea todos los store procedures, funciones, y vistas del schema [Partidos].
 **/
 
USE GestionDelMundial;
GO


 
CREATE OR ALTER PROCEDURE Partidos.sp_definir_formacion_inicial 
	@Jugando BIT,
	@Posicion char(2),
	@PartidoID INT,
	@JugadorID INT,
	@SeleccionID INT
AS
BEGIN

	-- Se obtienen las selecciones que juegan el partido
	-- Se comprueba que el jugador sea de esa Seleccion en ese mundial (y sea jugador)
	-- Se comprueba que el jugador no tenga un impedimento registrado
	-- Se comprueba que no hayan > 11 (si es Jugando true)

	DECLARE @seleccionA INT; DECLARE @seleccionB INT;

	SELECT @seleccionA = seleccion_A_id, @seleccionB = seleccion_B_id 
		FROM Partidos.Partidos
		WHERE id = @PartidoID;

	if (@SeleccionID not in (@seleccionA, @seleccionB)) begin
		print 'esta seleccion no juega';
	end

	if((SELECT 1 FROM Equipos.ConvocacionEnSeleccion WHERE miembro_id = @JugadorID and tipo = 'Jugador' and seleccion_id = @SeleccionID) <> 1) begin
		print 'El miembro no es jugador o no es parte de esa seleccion';
	end

	-- Valido que no esté baneado

	if((SELECT partidos_restantes FROM Eventos.Impedimentos WHERE jugador_id = @JugadorID) > 0) BEGIN
		print 'ERROR ! TIENE UNA ROJA ACTIVA';
	END
	
	if ((SELECT 1 FROM Partidos.JugadorPosicionInicial WHERE jugador_id = @JugadorID) = 1) BEGIN
		print 'El jugador ya está' -- igual daria error por las constraint .. en teoria
	END

	DECLARE @cantidadJugando INT = (select COUNT(1) from Partidos.JugadorPosicionInicial WHERE comienza_jugando = 1 and partido_id = @PartidoID and seleccion_id = @SeleccionID);
	DECLARE @cantidadSuplente INT = (select COUNT(1) from Partidos.JugadorPosicionInicial WHERE comienza_jugando = 0 and partido_id = @PartidoID and seleccion_id = @SeleccionID);
	DECLARE @cantidadAmonestados INT = 0; -- TODO: CANTIDAD DE AMONESTADOS!
	DECLARE @cantidadConvocados INT = (SELECT count(*) FROM Equipos.fn_obtener_jugadores_convocados(@SeleccionID));

	IF (@Jugando = 1) BEGIN 
		IF (@cantidadJugando >= 11) BEGIN
			print 'Limite de jugando';
		END
	END ELSE BEGIN
		if ((@cantidadConvocados - @cantidadAmonestados - 11) <= @cantidadSuplente) BEGIN
			print 'Limite suplentes';
		END
	END;

	INSERT INTO Partidos.JugadorPosicionInicial
		(jugador_id, partido_id, posicion)
		VALUES
		(@JugadorID, @PartidoID, @Posicion);
END
GO