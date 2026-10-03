
USE GestionDelMundial;
GO

CREATE OR ALTER PROCEDURE Administracion.sp_registrar_regla 
	@AñoMundial INT,
	@Codigo VARCHAR(100),
	@Valor VARCHAR(100)
AS
BEGIN

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


CREATE OR ALTER PROCEDURE Mundial.sp_crear_mundial
	 @FInicio DATE,
	 @FFin DATE,
	 --- TODAS LAS CONFIGURACIONES NECESARIAS. Por ejemplo, Abritro de var requerido, o, equipos
	 @LimiteJugadoresConvocados INT,
	 @ArbitroDeVarRequerido BIT,
	 @CantidadDeEquipos INT
AS
BEGIN
	-- Registrar Mundial
	INSERT INTO Mundial.Mundiales (f_inicio, f_fin) VALUES (@FInicio, @FFin);

	DECLARE @añoMundial INT = YEAR(@FInicio);

	-- Registrar Reglas.
	exec Administracion.sp_registrar_reglas @AñoMundial = @añoMundial, @Codigo = 'ARBITRO_DE_VAR', @Valor = @ArbitroDeVarRequerido;
	exec Administracion.sp_registrar_reglas @AñoMundial = @añoMundial, @Codigo = 'MAX_CONVOCADOS', @Valor = @LimiteJugadoresConvocados;
	exec Administracion.sp_registrar_reglas @AñoMundial = @añoMundial, @Codigo = 'CANTIDAD_EQUIPOS', @Valor = @CantidadDeEquipos;

END
GO 
-- exec Administracion.sp_registrar_reglas @AñoMundial = 1930, @Codigo = 'ARBITRO_DE_VAR', @Valor = 1
exec Mundial.sp_crear_mundial @FInicio = '1935-10-06', @FFin = '1935-10-08', @LimiteJugadoresConvocados = 23, @ArbitroDeVarRequerido = 1, @CantidadDeEquipos=32
SELECT * FROM Mundial.Mundiales
SELECT * FROM Administracion.Reglas

