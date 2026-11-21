/* BBDD/SPs/09-Publicidad.sql
 * Fecha: 9/10/2026
 * Lista, Matías Josué.
 * Descripción: Crea todos los store procedures, funciones, y vistas del schema [Publicidad].
 **/
 
USE GestionDelMundial;
GO


CREATE OR ALTER PROCEDURE Publicidad.sp_crear_anunciante
	@RazonSocial VARCHAR(150),
	@ID INT = NULL OUTPUT
AS
BEGIN
	INSERT INTO Publicidad.Anunciantes
	(razon_social)
	VALUES
	(@RazonSocial);

	SET @ID = SCOPE_IDENTITY();
END
GO

-- exec Publicidad.sp_crear_anunciante @RazonSocial = 'Coca Cola CORP.'
-- SELECT * FROM Publicidad.Anunciantes

CREATE OR ALTER PROCEDURE Publicidad.sp_crear_tarifa
	@AñoMundial INT,
	@PrimeTime BIT,
	@Fase VARCHAR(15),
	@Costo DECIMAL(10,2)
AS
BEGIN

	DECLARE @franja CHAR = IIF(@PrimeTime = 1, 'P', 'N');
	INSERT INTO Publicidad.Tarifas 
	(mundial_id, franja, fase, costo)
	VALUES
	(@AñoMundial, @franja, @Fase, @Costo);
END
GO

-- exec Publicidad.sp_crear_tarifa @AñoMundial = 1935, @PrimeTime = 1, @Fase = 'FINAL', @Costo = 150.15
-- SELECT * FROM Publicidad.Tarifa

CREATE OR ALTER PROCEDURE Publicidad.sp_crear_campaña
	@AnuncianteID INT,
	@AñoMundial INT,
	@Nombre VARCHAR(150),
	@Descripcion VARCHAR(300) = NULL,
	@HorarioMinimo INT = NULL,
	@HorarioMaximo INT = NULL,
	@ID INT = NULL OUTPUT
AS
BEGIN

	INSERT INTO Publicidad.Campañas 
		(mundial_id, anunciante_id, nombre, descripcion, horario_minimo, horario_maximo)
		VALUES 
		(@AñoMundial, @AnuncianteID, @Nombre, @Descripcion, @HorarioMinimo, @HorarioMaximo);

	SET @ID = SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE Publicidad.sp_modificar_campaña
	@CampañaID INT,
	@AnuncianteID INT,
	@AñoMundial INT,
	@Nombre VARCHAR(150),
	@Descripcion VARCHAR(300) = NULL,
	@HorarioMinimo INT = NULL,
	@HorarioMaximo INT = NULL
AS
BEGIN


	UPDATE Publicidad.Campañas 
		SET mundial_id = @AñoMundial, anunciante_id = @AnuncianteID, nombre = @Nombre, 
			descripcion = @Descripcion, horario_minimo = @HorarioMinimo, horario_maximo = @HorarioMaximo
		WHERE id = @CampañaID;
END
GO

CREATE OR ALTER PROCEDURE Publicidad.sp_asociar_pais_a_contenido
	@PiezaDeContenidoID INT,
	@CodigoPais CHAR(3)
AS
BEGIN
	INSERT INTO Publicidad.PaisesInteresados 
	(pieza_de_contenido_id, pais_id)
	VALUES
	(@PiezaDeContenidoID, @CodigoPais);
END
GO

--- Recibe países en este formato: "ARG,ESP,USA" ..
CREATE OR ALTER PROCEDURE Publicidad.sp_crear_pieza_de_contenido
	@CampañaID INT,
	@NombrePieza VARCHAR(300),
	@Descripcion VARCHAR(300),
	@PaisesInteresados VARCHAR(MAX) = NULL,
	@ID INT = NULL OUTPUT
AS
BEGIN

	INSERT INTO Publicidad.PiezasDeContenido
		(nombre, campaña_id, descripcion)
		VALUES
		(@NombrePieza, @CampañaID, @Descripcion);

	DECLARE @piezaDeContenidoID INT = SCOPE_IDENTITY();

	INSERT INTO Publicidad.PaisesInteresados (pieza_de_contenido_id, pais_id)
	SELECT
		@piezaDeContenidoID,
		TRIM(value) -- elimina espacios, y da una columna 'value'
	FROM STRING_SPLIT(@PaisesInteresados, ',');

	SET @ID = SCOPE_IDENTITY();
END

GO

-- TODO: REGISTRAR PIEZA EMITIDA: 
CREATE OR ALTER PROCEDURE Publicidad.sp_definir_piezas_a_emitir
	@PartidoID INT
AS
BEGIN

	DECLARE @paisA CHAR(3), @paisB CHAR(3);
	DECLARE @fechaYHora DATETIME;
	DECLARE @zonaHorariaA VARCHAR(250), @zonaHorariaB VARCHAR(250);
	DECLARE @añoMundial SMALLINT, @fase VARCHAR(15);
	-- Obtengo los países y la hora del partido

	SELECT @paisA = PP_A.pais_id, @paisB = PP_B.pais_id, @fechaYHora = P.fecha_y_hora,
		   @zonaHorariaA = Pais_A.zona_horaria, @zonaHorariaB = Pais_B.zona_horaria,
		   @añoMundial = P.mundial_id, @fase = P.fase
	FROM Partidos.Partidos P 
	INNER JOIN Mundial.Paises_Participes PP_A ON PP_A.seleccion_id = P.seleccion_A_id
	INNER JOIN Mundial.Paises_Participes PP_B ON PP_B.seleccion_id = P.seleccion_B_id
	INNER JOIN Administracion.Paises Pais_A   ON Pais_A.codigo     = PP_A.pais_id
	INNER JOIN Administracion.Paises Pais_B   ON Pais_B.codigo     = PP_B.pais_id
	WHERE P.id = @PartidoID;
	
	IF @fechaYHora IS NULL
	BEGIN
		THROW 50002, 'El partido no existe o aún no tiene ambas selecciones definidas.', 1;
	END
	-- Veo el horario en cada país:

	DECLARE @horaLocalA DATETIME = CAST((@fechaYHora AT TIME ZONE @zonaHorariaA AT TIME ZONE 'UTC') AS DATETIME);
	DECLARE @horaLocalB DATETIME = CAST((@fechaYHora AT TIME ZONE @zonaHorariaB AT TIME ZONE 'UTC') AS DATETIME);
	
	DECLARE @horaA TINYINT = DATEPART(HOUR, @horaLocalA);
	DECLARE @horaB TINYINT = DATEPART(HOUR, @horaLocalB);

	-- Chequear Prime Time (19 a 23 hs)
	DECLARE @primeTimeA BIT = IIF(@horaA BETWEEN 19 AND 23, 1, 0);
	DECLARE @primeTimeB BIT = IIF(@horaB BETWEEN 19 AND 23, 1, 0);
	
	-- Determinar cantidad de piezas orientadas a cada país:
	---- Si los dos países están en prime time, o ninguno de los dos: 2 piezas de contenido para cada uno.
	---- Si uno de los dos países está en prime time, 3 y 1.

	DECLARE @piezasA INT = 2;
	DECLARE @piezasB INT = 2;

	IF (@primeTimeA = 1 AND @primeTimeB = 0) BEGIN

		SET @piezasA = 3;
		SET @piezasB = 1;

	END ELSE IF (@primeTimeA = 0 AND @primeTimeB = 1) BEGIN

		SET @piezasA = 1;
		SET @piezasB = 3;

	END

	-- Obtengo las tarifas aplicables según fase, mundial y franja horaria de cada país
	DECLARE @franjaA CHAR(1) = IIF(@primeTimeA = 1, 'P', 'N');
	DECLARE @franjaB CHAR(1) = IIF(@primeTimeB = 1, 'P', 'N');
	DECLARE @costoA DECIMAL(10,2), @costoB DECIMAL(10,2);

	SELECT @costoA = costo
	FROM Publicidad.Tarifas
	WHERE mundial_id = @añoMundial AND fase = @fase AND franja = @franjaA;

	SELECT @costoB = costo
	FROM Publicidad.Tarifas
	WHERE mundial_id = @añoMundial AND fase = @fase AND franja = @franjaB;

	IF @costoA IS NULL OR @costoB IS NULL
	BEGIN
		THROW 50003, 'No se encontraron tarifas configuradas para la fase y franja horaria del partido.', 1;
	END

	-- Seleccionar al azar las piezas válidas para cada país
	DECLARE @PiezasSeleccionadas TABLE (
		pieza_de_contenido_id INT,
		descripcion VARCHAR(200),
		costo DECIMAL(10,2)
	);

	-- Piezas orientadas al País A
	INSERT INTO @PiezasSeleccionadas (pieza_de_contenido_id, descripcion, costo)
	SELECT TOP (@piezasA)
		PC.id,
		CONCAT('Orientada a ', @paisA, ' (Franja ', @franjaA, ' - ', @horaA, 'hs local)'),
		@costoA
	FROM Publicidad.PiezasDeContenido PC
	INNER JOIN Publicidad.Campañas C 
		ON C.id = PC.campaña_id
	INNER JOIN Publicidad.PaisesInteresados PI 
		ON PI.pieza_de_contenido_id = PC.id
	WHERE C.mundial_id = @añoMundial
	  AND PI.pais_id = @paisA
	  AND (
			(C.horario_minimo IS NOT NULL AND C.horario_maximo IS NOT NULL AND (
				(C.horario_minimo <= C.horario_maximo AND @horaA BETWEEN C.horario_minimo AND C.horario_maximo)
				OR (C.horario_minimo > C.horario_maximo AND (@horaA >= C.horario_minimo OR @horaA <= C.horario_maximo))
			))
			OR (C.horario_minimo IS NULL AND (C.horario_maximo IS NULL OR @horaA <= C.horario_maximo))
			OR (C.horario_maximo IS NULL AND @horaA >= C.horario_minimo)
		  )
	ORDER BY NEWID();

	-- Piezas orientadas al País B (excluyendo las ya elegidas para A por si una pieza apunta a ambos)
	INSERT INTO @PiezasSeleccionadas (pieza_de_contenido_id, descripcion, costo)
	SELECT TOP (@piezasB)
		PC.id,
		CONCAT('Orientada a ', @paisB, ' (Franja ', @franjaB, ' - ', @horaB, 'hs local)'),
		@costoB
	FROM Publicidad.PiezasDeContenido PC
	INNER JOIN Publicidad.Campañas C 
		ON C.id = PC.campaña_id
	INNER JOIN Publicidad.PaisesInteresados PI 
		ON PI.pieza_de_contenido_id = PC.id
	WHERE C.mundial_id = @añoMundial
	  AND PI.pais_id = @paisB
	  AND PC.id NOT IN (SELECT pieza_de_contenido_id FROM @PiezasSeleccionadas)
	  AND (
			(C.horario_minimo IS NOT NULL AND C.horario_maximo IS NOT NULL AND (
				(C.horario_minimo <= C.horario_maximo AND @horaB BETWEEN C.horario_minimo AND C.horario_maximo)
				OR (C.horario_minimo > C.horario_maximo AND (@horaB >= C.horario_minimo OR @horaB <= C.horario_maximo))
			))
			OR (C.horario_minimo IS NULL AND (C.horario_maximo IS NULL OR @horaB <= C.horario_maximo))
			OR (C.horario_maximo IS NULL AND @horaB >= C.horario_minimo)
		  )
	ORDER BY NEWID();

	-- Registrar las emisiones definitivas
	INSERT INTO Publicidad.RegistroDePiezasEmitidas
		(pieza_de_contenido_id, descripcion, costo, partido_id)
	SELECT 
		pieza_de_contenido_id,
		descripcion,
		costo,
		@PartidoID
	FROM @PiezasSeleccionadas;
END
GO
/*
SELECT * FROM Partidos.Partidos
exec Publicidad.sp_definir_piezas_a_emitir @PartidoID = 1




*/

/*SELECT * FROM Publicidad.RegistroDePiezasEmitidas*/