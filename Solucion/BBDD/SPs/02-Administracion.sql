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
	UPDATE Administracion.Paises
		SET nombre = @Nombre, confederacion_id = @ConfederacionID
		WHERE codigo = @Codigo;
END
GO
