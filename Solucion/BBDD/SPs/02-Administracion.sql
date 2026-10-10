/* BBDD/SPs/Administracion.sql
 * Fecha: 9/10/2026
 * Integrantes: Lista, Matías Josué. Maldonado Medrano, Milagros.
 * Descripción: Crea todos los store procedures, funciones, y vistas del schema [Administracion].
 **/

USE GestionDelMundial;
GO


CREATE OR ALTER PROCEDURE Administracion.sp_registrar_regla 
	@AñoMundial INT,
	@Codigo VARCHAR(100),
	@Valor VARCHAR(100)
AS
BEGIN
	DECLARE @errores NVARCHAR(500) = '';

	IF NOT EXISTS (SELECT 1 FROM Mundial.Mundiales WHERE año = @AñoMundial)
		SET @errores = @errores + 'El mundial no existe. ';

	IF EXISTS (SELECT 1 FROM Administracion.Reglas WHERE mundial_id = @AñoMundial AND codigo = @Codigo)
		SET @errores = @errores + 'La regla ya está registrada para ese mundial.';

	IF (@errores <> '')
		THROW 50001, @errores, 1;
	-- Acá tendría que hacer un intento de casteo para ver que el @Valor sea apropiado segun el código. POr ejemplo, si es "MAX CONVOCADOS" tiene que ser un int
	-- O podría manejarse en sp_crear_mundial, tiene más sentido porque ahí van ciertas reglas definidas

	INSERT INTO Administracion.Reglas (mundial_id, codigo, valor) VALUES (@AñoMundial, @codigo, @valor);

END
GO

CREATE OR ALTER PROCEDURE Administracion.sp_obtener_regla
	@AñoMundial INT,
	@Codigo VARCHAR(100),
	@Valor VARCHAR(100) OUTPUT
AS
BEGIN
	 -- Si la regla está definida para ese mundial, la carga en @Valor,
	 -- si no, queda en NULL

	SELECT @Valor = valor 
	FROM Administracion.Reglas 
	WHERE mundial_id = @AñoMundial 
	  AND codigo = @Codigo;
END
GO



CREATE OR ALTER PROCEDURE Administracion.sp_crear_confederacion 
	@Nombre VARCHAR(100),
	@siglas VARCHAR(8),
	@FFundacion DATE = NULL
AS
BEGIN
DECLARE @errores NVARCHAR(500) = '';

	IF (@Nombre IS NULL OR TRIM(@Nombre) = '')
		SET @errores = @errores + 'Debe indicar el nombre de la confederación. ';

	IF EXISTS (SELECT 1 FROM Administracion.Confederaciones WHERE nombre = @Nombre)
		SET @errores = @errores + 'Ya existe una confederación con ese nombre. ';

	IF EXISTS (SELECT 1 FROM Administracion.Confederaciones WHERE siglas = @Siglas)
		SET @errores = @errores + 'Ya existe una confederación con esas siglas. ';

	IF (@FFundacion > CAST(GETDATE() AS DATE))
		SET @errores = @errores + 'La fecha de fundación no puede ser futura.';

	IF (@errores <> '')
		THROW 50001, @errores, 1;
	INSERT INTO Administracion.Confederaciones
		(nombre, siglas, f_fundacion)
		VALUES
		(@Nombre, @Siglas, @FFundacion);
END
GO

CREATE OR ALTER PROCEDURE Administracion.sp_modificar_confederacion 
	@ID INT,
	@Nombre VARCHAR(100),
	@siglas VARCHAR(8),
	@FFundacion DATE = NULL
AS
BEGIN
	DECLARE @errores NVARCHAR(500) = '';

	IF NOT EXISTS (SELECT 1 FROM Administracion.Confederaciones WHERE id = @ID)
		SET @errores = @errores + 'No existe una confederación con ese ID. ';

	IF (@Nombre IS NULL OR TRIM(@Nombre) = '')
		SET @errores = @errores + 'Debe indicar el nombre de la confederación. ';

	IF EXISTS (SELECT 1 FROM Administracion.Confederaciones WHERE nombre = @Nombre AND id <> @ID)
		SET @errores = @errores + 'Otra confederación ya usa ese nombre. ';

	IF EXISTS (SELECT 1 FROM Administracion.Confederaciones WHERE siglas = @Siglas AND id <> @ID)
		SET @errores = @errores + 'Otra confederación ya usa esas siglas. ';

	IF (@FFundacion > CAST(GETDATE() AS DATE))
		SET @errores = @errores + 'La fecha de fundación no puede ser futura. ';

	IF (@errores <> '')
		THROW 50001, @errores, 1;
	UPDATE Administracion.Confederaciones
		SET nombre = @Nombre, siglas = @siglas, f_fundacion = @FFundacion
		WHERE id = @ID;
END
GO

CREATE OR ALTER PROCEDURE Administracion.sp_crear_pais 
	@Nombre VARCHAR(100),
	@Codigo VARCHAR(3),
	@ConfederacionID INT
AS
BEGIN
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
	DECLARE @errores NVARCHAR(500) = '';

	IF (@Codigo IS NULL OR @Codigo NOT LIKE '[A-Z][A-Z][A-Z]')
		SET @errores = @errores + 'El código del país debe tener 3 letras (ISO). ';

	IF NOT EXISTS (SELECT 1 FROM Administracion.Paises WHERE codigo = @Codigo)
		SET @errores = @errores + 'No existe un país con ese código. ';

	IF (@Nombre IS NULL OR TRIM(@Nombre) = '')
		SET @errores = @errores + 'Debe indicar el nombre del país. ';

	IF (@ConfederacionID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Administracion.Confederaciones WHERE id = @ConfederacionID))
		SET @errores = @errores + 'La confederación no existe. ';

	IF (@errores <> '')
		THROW 50001, @errores, 1;
	UPDATE Administracion.Paises
		SET nombre = @Nombre, confederacion_id = @ConfederacionID
		WHERE codigo = @Codigo;
END
GO


---------------------------------------------------------------------------------------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE Administracion.sp_crear_idioma
	@Codigo CHAR(2),
	@Label VARCHAR(100)
AS
BEGIN
	DECLARE @errores NVARCHAR(500) = '';

    IF (@Codigo IS NULL OR LTRIM(RTRIM(@Codigo)) = '') --valido que no sea null o que no sean espacion vacíos!
        SET @errores = @errores + 'Debe ingresar el código del idioma. ';

    IF EXISTS (SELECT 1 FROM Administracion.Idiomas WHERE codigo = @Codigo)
        SET @errores = @errores + 'Ya existe un idioma con ese código. ';

    IF (@errores <> '')
        THROW 50001, @errores, 1;

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
	DECLARE @errores NVARCHAR(500) = '';

    IF NOT EXISTS (SELECT 1 FROM Administracion.Idiomas WHERE codigo = @Codigo)
        SET @errores = @errores + 'No existe un idioma con ese código. ';


    IF (@errores <> '')
        THROW 50001, @errores, 1;


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
        SET @errores = @errores + 'Debe indicar el código del país. ';

    IF (@IdiomaID IS NULL)
        SET @errores = @errores + 'Debe indicar el código del idioma. ';

    IF NOT EXISTS (SELECT 1 FROM Administracion.Paises WHERE codigo = @CodigoPais)
        SET @errores = @errores + 'El país no existe. ';

    IF NOT EXISTS (SELECT 1 FROM Administracion.Idiomas WHERE codigo = @IdiomaID)
        SET @errores = @errores + 'El idioma no existe. ';

    IF EXISTS (SELECT 1 FROM Administracion.Pais_Habla WHERE pais_id = @CodigoPais AND idioma_id = @IdiomaID)
        SET @errores = @errores + 'El país ya tiene asociado ese idioma. ';

    IF (@errores <> '')
        THROW 50001, @errores, 1;
	
	INSERT INTO Administracion.Pais_Habla
	(pais_id,idioma_id)
	VALUES
	(@CodigoPais,@IdiomaID)
END 
GO


CREATE OR ALTER PROCEDURE Administracion.sp_crear_club
	@Nombre VARCHAR(100)
AS
BEGIN
	DECLARE @errores NVARCHAR(500) = '';

	IF (@Nombre IS NULL)
		SET @errores = @errores + 'Debe ingresar el nombre del club. ';

	IF EXISTS (SELECT 1 FROM Administracion.Clubes WHERE nombre = @Nombre)
		SET @errores = @errores + 'Ya existe un club con ese nombre.';

	IF (@errores <> '')
		THROW 50001, @errores, 1;

	INSERT INTO Administracion.Clubes
	(nombre)
	VALUES
	(@Nombre)
END 
GO

CREATE OR ALTER PROCEDURE Administracion.sp_modificar_club
	@Id INT,
	@Nombre VARCHAR(100)
AS
BEGIN
	DECLARE @errores NVARCHAR(500) = '';

	IF NOT EXISTS (SELECT 1 FROM Administracion.Clubes WHERE id = @Id)
		SET @errores = @errores + 'No existe un club con ese ID.';

	IF (@errores <> '')
		THROW 50001, @errores, 1;

	UPDATE Administracion.Clubes
		SET nombre=@Nombre WHERE id=@Id;
END
GO





---------Los SP de eliminacion/desasociar--------------------------------------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE Administracion.sp_eliminar_idioma
	@Codigo CHAR(2)
AS
BEGIN
	DECLARE @errores NVARCHAR(500) = '';

	IF (@Codigo IS NULL)
		SET @errores = @errores + 'Debe indicar el código del idioma. ';

	IF NOT EXISTS (SELECT 1 FROM Administracion.Idiomas WHERE codigo = @Codigo)
		SET @errores = @errores + 'El idioma no existe.';

	IF EXISTS (SELECT 1 FROM Administracion.Pais_Habla WHERE idioma_id = @Codigo)
		SET @errores = @errores + 'El idioma está asociado a uno o más países. ';

	IF EXISTS (SELECT 1 FROM Arbitraje.Arbitro_Habla WHERE idioma_id = @Codigo)
		SET @errores = @errores + 'El idioma está asociado a uno o más árbitros.';

	IF (@errores <> '')
		THROW 50001, @errores, 1;

	DELETE FROM Administracion.Idiomas
		WHERE codigo = @Codigo;
END
GO


CREATE OR ALTER PROCEDURE Administracion.sp_desasociar_idioma_de_pais
	@CodigoPais CHAR(3),
	@CodigoIdioma CHAR(2)
AS
BEGIN
	DECLARE @errores NVARCHAR(500) = '';

	IF (@CodigoPais IS NULL)
		SET @errores = @errores + 'Debe indicar el código del país. ';

	IF (@CodigoIdioma IS NULL)
		SET @errores = @errores + 'Debe indicar el código del idioma. ';

	IF NOT EXISTS (SELECT 1 FROM Administracion.Pais_Habla 
				   WHERE pais_id = @CodigoPais AND idioma_id = @CodigoIdioma)
		SET @errores = @errores + 'El país no tiene asociado ese idioma.';

	IF (@errores <> '')
		THROW 50001, @errores, 1;

	DELETE FROM Administracion.Pais_Habla
		WHERE pais_id = @CodigoPais AND idioma_id = @CodigoIdioma;
END
GO


CREATE OR ALTER PROCEDURE Administracion.sp_eliminar_club
	@ID INT
AS
BEGIN
	DECLARE @errores NVARCHAR(500) = '';

	IF (@ID IS NULL)
		SET @errores = @errores + 'Debe indicar el id del club. ';

	IF NOT EXISTS (SELECT 1 FROM Administracion.Clubes WHERE id = @ID)
		SET @errores = @errores + 'El club no existe. ';

	IF EXISTS (SELECT 1 FROM Equipos.ConvocacionEnSeleccion WHERE club_id = @ID)
		SET @errores = @errores + 'El club tiene jugadores convocados asociados.';

	IF (@errores <> '')
		THROW 50001, @errores, 1;

	DELETE FROM Administracion.Clubes
		WHERE id = @ID;
END
GO