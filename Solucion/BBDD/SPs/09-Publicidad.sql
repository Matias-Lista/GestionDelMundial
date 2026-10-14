/* BBDD/SPs/Publicidad.sql
 * Fecha: 9/10/2026
 * Integrantes: Lista, Matías Josué. Maldonado Medrano, Milagros.
 * Descripción: Crea todos los store procedures, funciones, y vistas del schema [Publicidad].
 **/
 
USE GestionDelMundial;
GO


CREATE OR ALTER PROCEDURE Publicidad.sp_crear_anunciante
	@RazonSocial VARCHAR(150)
AS
BEGIN
	INSERT INTO Publicidad.Anunciantes
	(razon_social)
	VALUES
	(@RazonSocial);
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
	@Anunciante VARCHAR(150),
	@AñoMundial INT,
	@Nombre VARCHAR(150),
	@Descripcion VARCHAR(300) = NULL,
	@HorarioMinimo INT = NULL,
	@HorarioMaximo INT = NULL
AS
BEGIN
	
	DECLARE @anuncianteId INT = (SELECT id FROM Publicidad.Anunciantes WHERE razon_social = @Anunciante);

	INSERT INTO Publicidad.Campañas 
		(mundial_id, anunciante_id, nombre, descripcion, horario_minimo, horario_maximo)
		VALUES 
		(@AñoMundial, @anuncianteId, @Nombre, @Descripcion, @HorarioMinimo, @HorarioMaximo);
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

-- TOASK: Cómo debería ordenar estos STORED Procedure? Debería de dar una posibilidad de insertar un @CampañaID nullable, y que el programa elija?
-- Debería directamente admitir solo el ID de la campaña, o debería tener un sp distinto para la importación por nombre
CREATE OR ALTER PROCEDURE Publicidad.sp_crear_pieza_de_contenido
	@NombreCampaña VARCHAR(150),
	@Descripcion VARCHAR(300),
	@PaisesInteresados VARCHAR(MAX) = NULL
AS
BEGIN
	-- TODO: atomico
	DECLARE @campañaId INT = (SELECT id FROM Publicidad.Campañas WHERE nombre = @NombreCampaña);

	INSERT INTO Publicidad.PiezasDeContenido
		(campaña_id, descripcion)
		VALUES
		(@campañaId, @Descripcion);

	DECLARE @piezaDeContenidoID INT = SCOPE_IDENTITY();

	INSERT INTO Publicidad.PaisesInteresados (pieza_de_contenido_id, pais_id)
	SELECT
		@piezaDeContenidoID,
		TRIM(value) -- elimina espacios, y da una columna 'value'
	FROM STRING_SPLIT(@PaisesInteresados, ',');
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
