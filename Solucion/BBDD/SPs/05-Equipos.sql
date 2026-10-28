/* BBDD/SPs/Equipos.sql
 * Fecha: 9/10/2026
 * Lista, Matías Josué.
 * Descripción: Crea todos los store procedures, funciones, y vistas del schema [Equipos].
 **/
 
USE GestionDelMundial;
GO

CREATE OR ALTER FUNCTION Equipos.fn_obtener_integrante_id (@Nombre VARCHAR(100), @Apellido VARCHAR(100), @FNacimiento DATE, @CodigoPais CHAR(3))
RETURNS INT
AS
BEGIN
	DECLARE @miembroId INT = (SELECT id
								FROM Equipos.IntegranteSeleccion
								WHERE nombre = @Nombre and apellido = @Apellido 
									  and (f_nacimiento = @FNacimiento OR (f_nacimiento is null and @FNacimiento is null) )
									  and pais_id = @CodigoPais);

	RETURN @miembroId;
END
GO

CREATE OR ALTER PROCEDURE Equipos.sp_crear_integrante_seleccion
	@CodigoPais CHAR(3),
	@Nombre VARCHAR(100), -- Hay jugadores que no tienen registrado nombre, pero figuran "unavailable".
	@Apellido VARCHAR(100),
	@FNacimiento DATE = NULL, -- Hay jugadores de los cuales no se tiene registro de cuándo nacieron (los primeros mundiales).
	@ID INT = NULL OUTPUT
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @errores VARCHAR(500) = '';

	IF @CodigoPais  is null SET @errores = '- Se debe indicar un país' + CHAR(13) + CHAR(10)
	IF @Nombre      is null SET @errores = @errores + '- Se debe indicar un nombre' + CHAR(13) + CHAR(10)
	IF @Apellido    is null SET @errores = @errores + '- Se debe indicar un apellido' + CHAR(13) + CHAR(10)
		
	IF (@CodigoPais IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Administracion.Paises WHERE codigo = @CodigoPais))
		SET @errores = @errores + '- El país no existe' + CHAR(13) + CHAR(10)

	DECLARE @idMiembro INT;
    EXEC @idMiembro = Equipos.fn_obtener_integrante_id @Nombre=@Nombre, @Apellido=@Apellido, @FNacimiento=@FNacimiento, @CodigoPais=@CodigoPais;

	IF @idMiembro is not null
		SET @errores = @errores + '- Ya existe un miembro con esa combinación de datos!' + CHAR(13) + CHAR(10)
	
	if @errores <> ''
		throw 50001, @errores, 1;

	INSERT INTO Equipos.IntegranteSeleccion 
	(pais_id, nombre, apellido, f_nacimiento)
	VALUES
	(@CodigoPais, @Nombre, @Apellido, @FNacimiento);

	SET @ID = SCOPE_IDENTITY();

END
GO

CREATE OR ALTER PROCEDURE Equipos.sp_modificar_integrante_seleccion
	@ID INT,
	@CodigoPais CHAR(3),
	@Nombre VARCHAR(100),
	@Apellido VARCHAR(100),
	@FNacimiento DATE
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @errores VARCHAR(500) = '';

	IF @CodigoPais  is null SET @errores = '- Se debe indicar un país' + CHAR(13) + CHAR(10)
	IF @Nombre      is null SET @errores = @errores + '- Se debe indicar un nombre' + CHAR(13) + CHAR(10)
	IF @Apellido    is null SET @errores = @errores + '- Se debe indicar un apellido' + CHAR(13) + CHAR(10)
	
	IF (@CodigoPais IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Administracion.Paises WHERE codigo = @CodigoPais))
		SET @errores = @errores + '- El país no existe' + CHAR(13) + CHAR(10)

	DECLARE @idMiembro INT;
    EXEC @idMiembro = Equipos.fn_obtener_integrante_id @Nombre=@Nombre, @Apellido=@Apellido, @FNacimiento=@FNacimiento, @CodigoPais=@CodigoPais;

	IF @idMiembro is not null and @idMiembro <> @ID
		SET @errores = @errores + '- Las modificaciones colisionan con otro integrante de seleccion!' + CHAR(13) + CHAR(10)
	
	if @errores <> ''
		throw 50001, @errores, 1;

	UPDATE Equipos.IntegranteSeleccion
		SET pais_id = @CodigoPais,
			nombre = @Nombre,
			apellido = @Apellido,
			f_nacimiento = @FNacimiento
		WHERE id = @ID;
END
GO

CREATE OR ALTER PROCEDURE Equipos.sp_convocar_jugador
	@AñoMundial INT,
	@MiembroID INT,
	@FConvocacion DATE,
	@Dorsal SMALLINT,
	@ClubID INT = NULL	

AS
BEGIN 
	
	SET NOCOUNT ON

	DECLARE @errores VARCHAR(500) = '';

	
	IF @AñoMundial  is null SET @errores = @errores + '- Se debe indicar un mundial' + CHAR(13) + CHAR(10)
	IF @MiembroID  is null SET @errores = @errores + '- Se debe indicar un miembro de seleccion' + CHAR(13) + CHAR(10)
	IF @FConvocacion  is null SET @errores = @errores + '- Se debe indicar una fecha de convocacion' + CHAR(13) + CHAR(10)
	IF @Dorsal  is null SET @errores = @errores + '- Se debe indicar un numero de dorsal' + CHAR(13) + CHAR(10)

	DECLARE @fechaDelMundial DATE = (SELECT f_inicio FROM Mundial.Mundiales WHERE año = @AñoMundial);

	IF (@fechaDelMundial IS NULL)
		SET @errores = @errores + '- El mundial no existe' + CHAR(13) + CHAR(10);
	ELSE IF (@fechaDelMundial < @FConvocacion)
		SET @errores = @errores + '- La convocacion debe suceder antes del mundial' + CHAR(13) + CHAR(10);

	IF @ClubID is not null and not exists (SELECT 1 FROM Administracion.Clubes WHERE id = @ClubID)
		SET @errores = @errores + '- El club indicado no existe.' + CHAR(13) + CHAR(10);

	
	DECLARE @codigoPais CHAR(3) = (SELECT pais_id FROM Equipos.IntegranteSeleccion WHERE id = @MiembroID);

	if @codigoPais is null
		SET @errores = @errores + '- El miembro de seleccion indicado no existe.' + CHAR(13) + CHAR(10);

	-- El país del jugador participa en este mundial?
	
	DECLARE @seleccionId INT = (SELECT seleccion_id FROM Mundial.Paises_Participes WHERE pais_id = @codigoPais and mundial_id = @AñoMundial);
	if @seleccionId is null
		SET @errores = @errores + '- El país del miembro de seleccion indicado no participa de este mundial.' + CHAR(13) + CHAR(10);

	-- Las convocaciones de cada selección tienen un límite diferente para jugadores y para staff (todo lo que no sea jugador).
	DECLARE @maxConvocados INT;
	exec Administracion.sp_obtener_regla 
		 @AñoMundial = @AñoMundial, @Codigo = 'MAX_CONVOCADOS', @Valor = @maxConvocados;

	DECLARE @cantidadConvocadosActivos INT = (SELECT count(*) 
				FROM Equipos.ConvocacionEnSeleccion
				WHERE tipo = 'Jugador' AND f_fin is NULL AND seleccion_id = @seleccionId); 
				
	if (@maxConvocados < @cantidadConvocadosActivos)
		SET @errores = @errores + '- La selección alcanzó el máximo de convocados activos para este mundial.' + CHAR(13) + CHAR(10);

	if @errores <> ''
		throw 50001, @errores, 1;

	INSERT INTO Equipos.ConvocacionEnSeleccion
		(seleccion_id, miembro_id, tipo, f_convocacion, dorsal, club_id)
		VALUES
		(@seleccionId, @MiembroId, 'Jugador', @FConvocacion, @Dorsal, @ClubID);

END
GO

CREATE OR ALTER PROCEDURE Equipos.sp_convocar_staff
	@AñoMundial INT,
	@MiembroID INT,
	@Tipo VARCHAR(50),
	@FConvocacion DATE
AS
BEGIN 
	-- ACá hay un límite para STAFF y un límite para jugadores

	-- pseudocodigo:
	-- 1. Validar NyA, Año Mundial, País, Fechas.
	-- 2. Obtener el límite para staff (Regla)
	-- 3. (contar la cantidad de registros, 
	--    con ese mundial, para ese país, con el tipo <> jugador, sin fecha de fin)
	--	  Esto podría ser una vista o SP
	-- 4. Insertar solo sí no se superó el máximo.
	
	
	SET NOCOUNT ON

	DECLARE @errores VARCHAR(500) = '';

	
	IF @AñoMundial  is null SET @errores = @errores + '- Se debe indicar un mundial' + CHAR(13) + CHAR(10)
	IF @MiembroID  is null SET @errores = @errores + '- Se debe indicar un miembro de seleccion' + CHAR(13) + CHAR(10)
	IF @FConvocacion  is null SET @errores = @errores + '- Se debe indicar una fecha de convocacion' + CHAR(13) + CHAR(10)

	DECLARE @fechaDelMundial DATE = (SELECT f_inicio FROM Mundial.Mundiales WHERE año = @AñoMundial);

	IF (@fechaDelMundial IS NULL)
		SET @errores = @errores + '- El mundial no existe' + CHAR(13) + CHAR(10);
	ELSE IF (@fechaDelMundial < @FConvocacion)
		SET @errores = @errores + '- La convocacion debe suceder antes del mundial' + CHAR(13) + CHAR(10);

	DECLARE @codigoPais CHAR(3) = (SELECT pais_id FROM Equipos.IntegranteSeleccion WHERE id = @MiembroID);

	if @codigoPais is null
		SET @errores = @errores + '- El miembro de seleccion indicado no existe.' + CHAR(13) + CHAR(10);

	-- El país del jugador participa en este mundial?
	
	DECLARE @seleccionId INT = (SELECT seleccion_id FROM Mundial.Paises_Participes WHERE pais_id = @codigoPais and mundial_id = @AñoMundial);
	if @seleccionId is null
		SET @errores = @errores + '- El país del miembro de seleccion indicado no participa de este mundial.' + CHAR(13) + CHAR(10);

	-- Las convocaciones de cada selección tienen un límite diferente para jugadores y para staff (todo lo que no sea jugador).
	DECLARE @maxConvocados INT;
	exec Administracion.sp_obtener_regla 
		 @AñoMundial = @AñoMundial, @Codigo = 'MAX_CONVOCADOS', @Valor = @maxConvocados;

	DECLARE @cantidadConvocadosActivos INT = (SELECT count(*) 
				FROM Equipos.ConvocacionEnSeleccion
				WHERE tipo = 'Jugador' AND f_fin is NULL AND seleccion_id = @seleccionId); 
				
	if (@maxConvocados < @cantidadConvocadosActivos)
		SET @errores = @errores + '- La selección alcanzó el máximo de convocados activos para este mundial.' + CHAR(13) + CHAR(10);


		
	if @errores <> ''
		throw 50001, @errores, 1;

	INSERT INTO Equipos.ConvocacionEnSeleccion
		(seleccion_id, miembro_id, tipo, f_convocacion)
		VALUES
		(@seleccionId, @MiembroId, 'Jugador', @FConvocacion);

END
GO

CREATE OR ALTER PROCEDURE Equipos.sp_cancelar_convocacion
	@AñoMundial INT,
	@CodigoPais INT,
	@Nombre VARCHAR(100),
	@Apellido VARCHAR(100),
	@FFin DATE,
	@Motivo VARCHAR(300)
AS
BEGIN

	-- Acá se podría chequear con una regla "TIEMPO_LIMITE_RECONVOCAR"
	
	DECLARE @seleccionId INT = (SELECT seleccion_id FROM Mundial.Paises_Participes WHERE pais_id = @CodigoPais and mundial_id = @AñoMundial);

	DECLARE @miembroId INT = (SELECT id FROM Equipos.IntegranteSeleccion WHERE nombre = @Nombre and apellido = @Apellido and pais_id = @CodigoPais);

	UPDATE Equipos.ConvocacionEnSeleccion 
		SET f_fin = @FFin, motivo = @Motivo
		WHERE miembro_id = @miembroId and seleccion_id = @seleccionId;
END
GO


--TOASK: Deberíamos tener diferentes SPs para "el uso normal de la aplicación" y "el proceso de importacion" ?
--		 Porque, por ejemplo, en el dataset de partidos, te vienen todos los partidos juntos,
--       Si tengo que validar todo, (como en un uso normal), no puedo importar todos los partidos juntos. tengo que importar la info de un partido,
--		 Después, los goles, y recién ahí, puedo decir si ganó o perdió, y pasar al siguiente..
--		 Entonces, hago sps distintos? o tengo que cargar todos los datasets requeridos en tablas temporales diferentes, y gestioanr ese paso a paso?

CREATE OR ALTER FUNCTION Equipos.fn_obtener_jugadores_convocados (@SeleccionID INT)
RETURNS TABLE
AS
RETURN (
    SELECT *
    FROM Equipos.ConvocacionEnSeleccion
    WHERE seleccion_id = @SeleccionID and f_fin is null
);

GO
