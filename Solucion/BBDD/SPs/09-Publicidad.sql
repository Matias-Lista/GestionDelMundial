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
	INSERT INTO Publicidad.tarifa 
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
/*SELECT * FROM Publicidad.Anunciantes
SELECT * FROM Mundial.Mundiales
SELECT * FROM Publicidad.Campañas
exec Publicidad.sp_crear_anunciante 'Coca Cola'
exec Publicidad.sp_crear_campaña 'Coca Cola', 1935, 'Campaña1'
INSERT INTO Administracion.Paises (codigo, confederacion_id, nombre) VALUES ('ar', null, 'Argentina');
INSERT INTO Administracion.Paises (codigo, confederacion_id, nombre) VALUES ('es', null, 'España');
INSERT INTO Administracion.Paises (codigo, confederacion_id, nombre) VALUES ('fr', null, 'Francia');

exec Publicidad.sp_crear_pieza_de_contenido 'Campaña1', '', 'ar,es,fr'

SELECT * FROM Publicidad.PaisesInteresados*/
GO

-- TODO: REGISTRAR PIEZA EMITIDA: 
CREATE OR ALTER PROCEDURE Publicidad.sp_definir_pieza_a_emitir
AS
BEGIN
	print '';

	-- Obtener los partidos de interés para los 2 equipos que juegan
	-- Ver el horario del partido en cada país.
	-- Remover los partidos que no entran en los horarios permitidos de los países que juegan.

	-- Evaluar las piezas, seleccionando al hacer de las interesantes, respondiendo a:
	--   1. Prime Time en los dos equipos: 2 y 2 piezas de contenido.
	--   2. Prime Time en un solo equipo: 3 piezas para el prime, 1 para el no prime
	--   3. No Prime Time en ningun equipo: 2 y 2 piezas de contenido


END
GO
