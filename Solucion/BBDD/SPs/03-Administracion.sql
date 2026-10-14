/* BBDD/SPs/Administracion.sql
 * Fecha: 9/10/2026
 * Lista, Matías Josué.
 * Descripción: Crea todos los store procedures, funciones, y vistas del schema [Administracion].
 **/

USE GestionDelMundial;
GO


-----------------------
--   REGLAS
-----------------------

CREATE OR ALTER PROCEDURE Administracion.sp_registrar_regla 
	@AñoMundial INT,
	@Codigo VARCHAR(100),
	@Valor VARCHAR(100),
	@ID INT = NULL OUTPUT
AS
BEGIN
	DECLARE @errores NVARCHAR(500) = '';

	IF @AñoMundial is NULL
		SET @errores = @errores + '- Debe indicar un mundial. ' + CHAR(13) + CHAR(10);

	IF @Codigo is NULL
		SET @errores = @errores + '- Debe indicar un codigo. ' + CHAR(13) + CHAR(10);

	IF @Valor is NULL
		SET @errores = @errores + '- Debe indicar un valor. ' + CHAR(13) + CHAR(10);

	IF NOT EXISTS (SELECT 1 FROM Mundial.Mundiales WHERE año = @AñoMundial)
		SET @errores = @errores + '- El mundial no existe. ' + CHAR(13) + CHAR(10);

	IF EXISTS (SELECT 1 FROM Administracion.Reglas WHERE mundial_id = @AñoMundial AND codigo = @Codigo)
		SET @errores = @errores + '- La regla ya está registrada para ese mundial.' + CHAR(13) + CHAR(10);

	IF (@errores <> '')
		THROW 50001, @errores, 1;

	INSERT INTO Administracion.Reglas (mundial_id, codigo, valor) VALUES (@AñoMundial, @codigo, @valor);

	SET @ID = SCOPE_IDENTITY();
END
GO

-- NO HAY SPS PARA ELIMINAR O MODIFICAR REGLAS, PORQUE SOLO SE LLAMA A ESTE SP DENTRO DE LOS SPS DE MUNDIALES.

CREATE OR ALTER PROCEDURE Administracion.sp_obtener_regla
	@AñoMundial INT,
	@Codigo VARCHAR(100),
	@Valor VARCHAR(100) OUTPUT
AS
BEGIN
	SET @Valor = NULL; -- Se suma esta linea porque si @Valor tenía un valor de antes, y la regla es erronea, no se sobreescribe.

	SELECT @Valor = valor 
	FROM Administracion.Reglas 
	WHERE mundial_id = @AñoMundial 
	  AND codigo = @Codigo;
END
GO

-----------------------
--   CONFEDERACIONES
-----------------------

CREATE OR ALTER PROCEDURE Administracion.sp_crear_confederacion 
	@Nombre VARCHAR(100),
	@siglas VARCHAR(8),
	@FFundacion DATE = NULL,
	@ID INT = NULL OUTPUT
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @errores NVARCHAR(500) = '';

	IF (@Nombre IS NULL OR TRIM(@Nombre) = '')
		SET @errores = @errores + '- Debe indicar el nombre de la confederación.' + char(13) + char(10);

	IF (@siglas IS NULL)
		SET @errores = @errores + '- Debe indicar las siglas de la confederación.' + char(13) + char(10);

	IF EXISTS (SELECT 1 FROM Administracion.Confederaciones WHERE nombre = @Nombre)
		SET @errores = @errores + '- Ya existe una confederación con ese nombre.' + char(13) + char(10);

	IF EXISTS (SELECT 1 FROM Administracion.Confederaciones WHERE siglas = @Siglas)
		SET @errores = @errores + '- Ya existe una confederación con esas siglas.' + char(13) + char(10);

	IF (@FFundacion > CAST(GETDATE() AS DATE))
		SET @errores = @errores + '- La fecha de fundación no puede ser futura.' + char(13) + char(10);

	IF (@errores <> '')
		THROW 50001, @errores, 1;

	INSERT INTO Administracion.Confederaciones
		(nombre, siglas, f_fundacion)
		VALUES
		(@Nombre, @Siglas, @FFundacion);

	SET @ID = SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE Administracion.sp_modificar_confederacion 
	@ID INT,
	@Nombre VARCHAR(100),
	@siglas VARCHAR(8),
	@FFundacion DATE = NULL
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @errores NVARCHAR(500) = '';

	IF @ID IS NULL 
		SET @errores = @errores + '- Debe indicar un ID. ' + char(13) + char(10);

	IF NOT EXISTS (SELECT 1 FROM Administracion.Confederaciones WHERE id = @ID)
		SET @errores = @errores + '- No existe una confederación con ese ID. ' + char(13) + char(10);

	IF (@Nombre IS NULL OR TRIM(@Nombre) = '')
		SET @errores = @errores + '- Debe indicar el nombre de la confederación. ' + char(13) + char(10);

	IF EXISTS (SELECT 1 FROM Administracion.Confederaciones WHERE nombre = @Nombre AND id <> @ID)
		SET @errores = @errores + '- Otra confederación ya usa ese nombre. ' + char(13) + char(10);

	IF EXISTS (SELECT 1 FROM Administracion.Confederaciones WHERE siglas = @Siglas AND id <> @ID)
		SET @errores = @errores + '- Otra confederación ya usa esas siglas. ' + char(13) + char(10);

	IF (@FFundacion > CAST(GETDATE() AS DATE))
		SET @errores = @errores + '- La fecha de fundación no puede ser futura. ' + char(13) + char(10);

	IF (@errores <> '')
		THROW 50001, @errores, 1;

	UPDATE Administracion.Confederaciones
		SET nombre = @Nombre, siglas = @siglas, f_fundacion = @FFundacion
		WHERE id = @ID;
END
GO


CREATE OR ALTER PROCEDURE Administracion.sp_eliminar_confederacion 
	@ID INT
AS
BEGIN 

	SET NOCOUNT ON

	DECLARE @errores NVARCHAR(500) = '';

	IF @ID is null
		SET @errores = @errores + '- Debe indicar una confederacion.' + char(13) + char(10);

	IF NOT EXISTS (SELECT 1 FROM Administracion.Confederaciones WHERE id = @ID)
		SET @errores = @errores + '- La confederacion indicada no existe.' + char(13) + char(10);

	IF EXISTS (SELECT TOP 1 1 FROM Administracion.Paises WHERE confederacion_id = @ID)
		SET @errores = @errores + '- Hay países que dependen de esta confederación.' + char(13) + char(10);

	--IF EXISTS (SELECT TOP 1 1 FROM Arbitraje.Arbitros WHERE confederacion_id = @ID)
		--SET @errores = @errores + '- Hay arbitros que dependen de esta confederación.' + char(13) + char(10);

	IF @errores <> '' THROW 50001, @errores, 1;

	DELETE FROM Administracion.Confederaciones WHERE id = @ID;
END
GO

-----------------------
--   PAISES
-----------------------

CREATE OR ALTER PROCEDURE Administracion.sp_crear_pais 
	@Nombre VARCHAR(100),
	@Codigo VARCHAR(3),
	@ConfederacionID INT
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @errores VARCHAR(4000) = '';

	IF @Nombre is null
		SET @errores = @errores + '- Debe indicar un nombre.' + char(13) + char(10);

	IF @Codigo is null
		SET @errores = @errores + '- Debe indicar un código.' + char(13) + char(10);

	IF @ConfederacionID is null
		SET @errores = @errores + '- Debe indicar una confederacion.' + char(13) + char(10);

	IF (@Codigo NOT LIKE '[A-Z][A-Z][A-Z]')
		SET @errores = @errores + '- Debe indicar un código de 3 letras ISO.' + char(13) + char(10);

	IF EXISTS (SELECT 1 FROM Administracion.Paises WHERE codigo = @Codigo)
		SET @errores = @errores + '- El código de país ya está siendo utilizado.' + char(13) + char(10);

	IF EXISTS (SELECT 1 FROM Administracion.Paises WHERE nombre = @Nombre)
		SET @errores = @errores + '- El nombre del país ya está siendo utilizado.' + char(13) + char(10);

	IF NOT EXISTS (SELECT 1 FROM Administracion.Confederaciones WHERE id = @ConfederacionID)
		SET @errores = @errores + '- La confederación no es válida.' + char(13) + char(10);

	IF @errores <> '' THROW 50001, @errores, 1;

	INSERT INTO Administracion.Paises
		(codigo, nombre, confederacion_id)
		VALUES
		(@Codigo, @Nombre, @ConfederacionID);

END
GO

CREATE OR ALTER PROCEDURE Administracion.sp_modificar_pais
	@Codigo CHAR(3),
	@Nombre VARCHAR(100),
	@ConfederacionID INT
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @errores NVARCHAR(4000) = '';

	IF @Nombre is null
		SET @errores = @errores + '- Debe indicar un nombre.' + char(13) + char(10);

	IF @Codigo is null
		SET @errores = @errores + '- Debe indicar un código.' + char(13) + char(10);

	IF @ConfederacionID is null
		SET @errores = @errores + '- Debe indicar una confederacion.' + char(13) + char(10);

	IF (@Codigo NOT LIKE '[A-Z][A-Z][A-Z]')
		SET @errores = @errores + '- El código del país debe tener 3 letras (ISO). ' + char(13) + char(10);

	IF NOT EXISTS (SELECT 1 FROM Administracion.Paises WHERE codigo = @Codigo)
		SET @errores = @errores + '- No existe un país con ese código. ' + char(13) + char(10);

	IF (@ConfederacionID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Administracion.Confederaciones WHERE id = @ConfederacionID))
		SET @errores = @errores + '- La confederación no existe. ' + char(13) + char(10);

	IF EXISTS (SELECT 1 FROM Administracion.Paises WHERE nombre = @Nombre and codigo <> @Codigo)
		SET @errores = @errores + '- El nombre está siendo utilizado por otro pais. ' + char(13) + char(10);

	IF (@errores <> '')
		THROW 50001, @errores, 1;

	UPDATE Administracion.Paises
		SET nombre = @Nombre, confederacion_id = @ConfederacionID
		WHERE codigo = @Codigo;
END
GO

CREATE OR ALTER PROCEDURE Administracion.sp_eliminar_pais 
	@Codigo CHAR(3)
AS
BEGIN 

	SET NOCOUNT ON

	DECLARE @errores NVARCHAR(500) = '';

	IF @Codigo is null
		SET @errores = @errores + '- Debe indicar un código.' + char(13) + char(10);

	IF NOT EXISTS (SELECT 1 FROM Administracion.Paises WHERE codigo = @Codigo)
		SET @errores = @errores + '- El país indicado no existe.' + char(13) + char(10);

	IF EXISTS (SELECT 1 FROM Mundial.Paises_Participes WHERE pais_id = @Codigo)
		SET @errores = @errores + '- Este país participó en mundiales.' + char(13) + char(10);

	IF EXISTS (SELECT 1 FROM Administracion.Sedes WHERE pais_id = @Codigo)
		SET @errores = @errores + '- Este país está vinculado a sedes.' + char(13) + char(10);

	IF EXISTS (SELECT 1 FROM Equipos.IntegranteSeleccion WHERE pais_id = @Codigo)
		SET @errores = @errores + '- Este país está vinculado a integrantes de sleeccion.' + char(13) + char(10);

	IF (@errores <> '') THROW 50001, @errores, 1;

	DELETE FROM Administracion.Paises WHERE codigo = @Codigo;
END
GO

-----------------------
--   IDIOMAS
-----------------------

CREATE OR ALTER PROCEDURE Administracion.sp_crear_idioma
	@Codigo CHAR(2),
	@Label VARCHAR(100)
AS
BEGIN
	DECLARE @errores NVARCHAR(500) = '';

    IF (@Codigo IS NULL)
        SET @errores = @errores + '- Debe ingresar el código del idioma. ' + char(13) + char(10);

    IF (@Label IS NULL)
        SET @errores = @errores + '- Debe ingresar el label del idioma. ' + char(13) + char(10);

    IF EXISTS (SELECT 1 FROM Administracion.Idiomas WHERE codigo = @Codigo)
        SET @errores = @errores + '- Ya existe un idioma con ese código. ' + char(13) + char(10);

    IF EXISTS (SELECT 1 FROM Administracion.Idiomas WHERE label = @Label)
        SET @errores = @errores + '- Ya existe un idioma con ese label. ' + char(13) + char(10);

    IF (@Codigo IS NOT NULL AND @Codigo not like '[A-Z][A-Z]')
        SET @errores = @errores + '- El código de idioma debe ser ISO. (dos letras)' + char(13) + char(10);

    IF (@errores <> '') THROW 50001, @errores, 1;

	INSERT INTO Administracion.Idiomas
		(codigo,label)
		VALUES
		(@Codigo,@Label)
END
GO

CREATE OR ALTER PROCEDURE Administracion.sp_modificar_idioma
	@Codigo CHAR(2),
	@Label VARCHAR(100)
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @errores NVARCHAR(500) = '';

    IF (@Codigo IS NULL)
        SET @errores = @errores + '- Debe ingresar el código del idioma. ' + char(13) + char(10);

    IF (@Label IS NULL)
        SET @errores = @errores + '- Debe ingresar el label del idioma. ' + char(13) + char(10);

    IF NOT EXISTS (SELECT 1 FROM Administracion.Idiomas WHERE codigo = @Codigo)
        SET @errores = @errores + '- No existe un idioma con ese código. ' + char(13) + char(10);

    IF @Codigo is not null and EXISTS (SELECT 1 FROM Administracion.Idiomas WHERE label = @Label and codigo <> @Codigo)
        SET @errores = @errores + '- El label ya está siendo utilizado por otro idioma.' + char(13) + char(10);

    IF (@errores <> '') THROW 50001, @errores, 1;

	UPDATE Administracion.Idiomas
		SET label = @Label WHERE codigo=@Codigo;
END
GO

CREATE OR ALTER PROCEDURE Administracion.sp_asociar_idioma_a_pais
	@CodigoPais char(3),
	@IdiomaID char(2)
AS 
BEGIN
	DECLARE @errores NVARCHAR(500) = '';

    IF (@CodigoPais IS NULL)
        SET @errores = @errores + '- Debe indicar el código del país. ' + char(13) + char(10);

    IF (@IdiomaID IS NULL)
        SET @errores = @errores + '- Debe indicar el código del idioma. ' + char(13) + char(10);

    IF @CodigoPais IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Administracion.Paises WHERE codigo = @CodigoPais)
        SET @errores = @errores + '- El país no existe. ' + char(13) + char(10);

    IF @IdiomaID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Administracion.Idiomas WHERE codigo = @IdiomaID)
        SET @errores = @errores + '- El idioma no existe. ' + char(13) + char(10);

    IF EXISTS (SELECT 1 FROM Administracion.Pais_Habla WHERE pais_id = @CodigoPais AND idioma_id = @IdiomaID)
        SET @errores = @errores + '- El país ya tiene asociado ese idioma. ' + char(13) + char(10);

    IF (@errores <> '') THROW 50001, @errores, 1;
	
	INSERT INTO Administracion.Pais_Habla
		(pais_id,idioma_id)
		VALUES
		(@CodigoPais,@IdiomaID)
END 
GO

CREATE OR ALTER PROCEDURE Administracion.sp_desasociar_idioma_de_pais
	@CodigoPais CHAR(3),
	@CodigoIdioma CHAR(2)
AS
BEGIN
	DECLARE @errores NVARCHAR(500) = '';

	IF (@CodigoPais IS NULL)
		SET @errores = @errores + '- Debe indicar el código del país. ' + char(13) + char(10);

	IF (@CodigoIdioma IS NULL)
		SET @errores = @errores + '- Debe indicar el código del idioma. ' + char(13) + char(10);

	IF @CodigoPais IS NOT NULL AND @CodigoIdioma IS NOT NULL 
	   AND NOT EXISTS (SELECT 1 FROM Administracion.Pais_Habla 
				   WHERE pais_id = @CodigoPais AND idioma_id = @CodigoIdioma)
		SET @errores = @errores + '- El país no tiene asociado ese idioma.' + char(13) + char(10);

	IF (@errores <> '') THROW 50001, @errores, 1;

	DELETE FROM Administracion.Pais_Habla
		WHERE pais_id = @CodigoPais AND idioma_id = @CodigoIdioma;
END
GO

CREATE OR ALTER PROCEDURE Administracion.sp_eliminar_idioma 
	@Codigo CHAR(2)
AS
BEGIN 

	SET NOCOUNT ON

	DECLARE @errores NVARCHAR(500) = '';

	IF @Codigo is null
		SET @errores = @errores + '- Debe indicar un código.' + char(13) + char(10);

	IF NOT EXISTS (SELECT 1 FROM Administracion.Idiomas WHERE codigo = @Codigo)
		SET @errores = @errores + '- El idioma indicado no existe.' + char(13) + char(10);

    IF EXISTS (SELECT 1 FROM Administracion.Pais_Habla WHERE idioma_id = @Codigo)
        SET @errores = @errores + '- Hay países vinculados al idioma. ' + char(13) + char(10);

    IF EXISTS (SELECT 1 FROM Arbitraje.Arbitro_Habla WHERE idioma_id = @Codigo)
        SET @errores = @errores + '- Hay árbitros vinculados al idioma. ' + char(13) + char(10);

	IF (@errores <> '') THROW 50001, @errores, 1;

	DELETE FROM Administracion.Idiomas WHERE codigo = @Codigo;
END
GO

-----------------------
--   CLUBES
-----------------------

CREATE OR ALTER PROCEDURE Administracion.sp_crear_club
	@Nombre VARCHAR(100),
	@ID INT = NULL OUTPUT
AS
BEGIN
	DECLARE @errores NVARCHAR(500) = '';

	IF (@Nombre IS NULL)
		SET @errores = @errores + '- Debe ingresar el nombre del club. ' + char(13) + char(10);

	IF EXISTS (SELECT 1 FROM Administracion.Clubes WHERE nombre = @Nombre)
		SET @errores = @errores + '- Ya existe un club con ese nombre.' + char(13) + char(10);

	IF (@errores <> '')
		THROW 50001, @errores, 1;

	INSERT INTO Administracion.Clubes
		(nombre)
		VALUES
		(@Nombre)

	SET @ID = SCOPE_IDENTITY();
END 
GO

CREATE OR ALTER PROCEDURE Administracion.sp_modificar_club
	@ID INT,
	@Nombre VARCHAR(100)
AS
BEGIN
	DECLARE @errores NVARCHAR(500) = '';

	IF (@ID IS NULL)
		SET @errores = @errores + '- Debe indicar un club. ' + char(13) + char(10);

	IF (@Nombre IS NULL)
		SET @errores = @errores + '- Debe ingresar el nombre del club. ' + char(13) + char(10);

	IF @ID is not null and NOT EXISTS (SELECT 1 FROM Administracion.Clubes WHERE id = @ID)
		SET @errores = @errores + '- No existe un club con ese ID.' + char(13) + char(10);

	IF @Nombre is not null and @ID is not null and
	   EXISTS (SELECT 1 FROM Administracion.Clubes WHERE nombre = @Nombre and id <> @ID)
	   SET @errores = @errores + '- El nombre es utilizado por otro club.' + char(13) + char(10);

	IF (@errores <> '') THROW 50001, @errores, 1;

	UPDATE Administracion.Clubes
		SET nombre=@Nombre WHERE id=@ID;
END
GO

CREATE OR ALTER PROCEDURE Administracion.sp_eliminar_club
	@ID INT
AS
BEGIN
	DECLARE @errores NVARCHAR(500) = '';

	IF (@ID IS NULL)
		SET @errores = @errores + '- Debe indicar el id del club. '+char(13)+char(10);

	IF @ID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Administracion.Clubes WHERE id = @ID)
		SET @errores = @errores + '- El club no existe. '+char(13)+char(10);

	IF @ID is not null and EXISTS (SELECT 1 FROM Equipos.ConvocacionEnSeleccion WHERE club_id = @ID)
		SET @errores = @errores + '- El club tiene jugadores convocados asociados.'+char(13)+char(10);

	IF (@errores <> '') THROW 50001, @errores, 1;

	DELETE FROM Administracion.Clubes
		WHERE id = @ID;
END
GO

CREATE OR ALTER FUNCTION Administracion.fn_obtener_regla (@AñoMundial INT, @Codigo VARCHAR(100))
RETURNS VARCHAR(100)
AS
BEGIN
	-- como sp_obtener_regla pero usable dentro de una expresion o de otra funcion
	RETURN (SELECT valor FROM Administracion.Reglas WHERE mundial_id = @AñoMundial AND codigo = @Codigo);
END
GO

-----------------------
--   SEDES
-----------------------

CREATE OR ALTER PROCEDURE Administracion.sp_crear_sede
    @CodigoPais CHAR(3),
    @Nombre VARCHAR(100),
    @Ciudad VARCHAR(100),
    @Capacidad INT,
    @ID INT = NULL OUTPUT
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @errores NVARCHAR(500) = '';

	IF (@CodigoPais IS NULL)
		SET @errores = @errores + '- Debe indicar un país.' + char(13) + char(10);
		
	IF (@Nombre IS NULL)
		SET @errores = @errores + '- Debe indicar un nombre.' + char(13) + char(10);
		
	IF (@Ciudad IS NULL)
		SET @errores = @errores + '- Debe indicar una ciudad.' + char(13) + char(10);
		
	IF (@Capacidad IS NULL)
		SET @errores = @errores + '- Debe indicar una capacidad.' + char(13) + char(10);
		
	IF (@Capacidad <= 0)
		SET @errores = @errores + '- Debe indicar una capacidad positiva.' + char(13) + char(10);

	IF @CodigoPais IS NOT NULL AND @Nombre IS NOT NULL AND @Ciudad IS NOT NULL AND
		EXISTS (SELECT 1 FROM Administracion.Sedes WHERE pais_id = @CodigoPais and nombre = @Nombre and ciudad = @Ciudad)
		SET @errores = @errores + '- Ya existe una sede así.' + char(13) + char(10);
	
	IF @errores <> '' throw 50001, @errores, 1;
	
	INSERT INTO Administracion.Sedes 
		(pais_id, ciudad, nombre, capacidad)
		VALUES
		(@CodigoPais, @Ciudad, @Nombre, @Capacidad);

	SET @ID = SCOPE_IDENTITY();
END
GO

/*exec Administracion.sp_crear_sede @CodigoPais = 'ARG', @Nombre = 'Lugar genial', @Ciudad='Ciudad', @Capacidad = 1000
SELECT * FROM Administracion.Sedes*/


CREATE OR ALTER PROCEDURE Administracion.sp_modificar_sede
    @ID INT,
	@CodigoPais CHAR(3),
    @Nombre VARCHAR(100),
    @Ciudad VARCHAR(100),
    @Capacidad INT
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @errores NVARCHAR(500) = '';

	IF (@CodigoPais IS NULL)
		SET @errores = @errores + '- Debe indicar un país.' + char(13) + char(10);
		
	IF (@Nombre IS NULL)
		SET @errores = @errores + '- Debe indicar un nombre.' + char(13) + char(10);
		
	IF (@Ciudad IS NULL)
		SET @errores = @errores + '- Debe indicar una ciudad.' + char(13) + char(10);
		
	IF (@Capacidad IS NULL)
		SET @errores = @errores + '- Debe indicar una capacidad.' + char(13) + char(10);
		
	IF (@ID IS NULL)
		SET @errores = @errores + '- Debe indicar una sede.' + char(13) + char(10);
		
	IF (@Capacidad <= 0)
		SET @errores = @errores + '- Debe indicar una capacidad positiva.' + char(13) + char(10);

	IF @ID is not null and NOT EXISTS (SELECT 1 FROM Administracion.Sedes WHERE id = @ID)
		SET @errores = @errores + '- La sede no existe.' + char(13) + char(10);

	IF @CodigoPais IS NOT NULL AND @Nombre IS NOT NULL AND @Ciudad IS NOT NULL AND @Capacidad IS NOT NULL AND @ID is not null
		AND EXISTS (SELECT 1 FROM Administracion.Sedes WHERE pais_id = @CodigoPais and nombre = @Nombre and ciudad = @Ciudad and id <> @ID)
		SET @errores = @errores + '- Los nuevos datos de la sede coinciden con una sede ya existente.' + char(13) + char(10);
	
	IF @errores <> '' throw 50001, @errores, 1;
	
	UPDATE Administracion.Sedes 
		set pais_id = @CodigoPais,
			ciudad = @Ciudad, 
			nombre = @Nombre, 
			capacidad = @Capacidad
		WHERE id = @ID;
END
GO

CREATE OR ALTER PROCEDURE Administracion.sp_eliminar_sede
	@ID INT
AS
BEGIN 

	SET NOCOUNT ON
	DECLARE @errores NVARCHAR(500) = '';

	IF (@ID IS NULL)
		SET @errores = @errores + '- Debe indicar una sede.' + char(13) + char(10);

	IF @ID is not null and NOT EXISTS (SELECT 1 FROM Administracion.Sedes WHERE id = @ID)
		SET @errores = @errores + '- La sede no existe.' + char(13) + char(10);

	IF @ID is not null AND EXISTS (SELECT 1 FROM Partidos.Partidos WHERE sede_id = @ID)
		SET @errores = @errores + '- La sede está vinculada a un partido.' + char(13) + char(10);

	IF @errores <> '' throw 50001, @errores, 1;

	DELETE FROM Administracion.Sedes WHERE id = @ID;

END;
GO