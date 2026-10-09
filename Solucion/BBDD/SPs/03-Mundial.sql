/* BBDD/SPs/Mundial.sql
 * Fecha: 9/10/2026
 * Integrantes: Lista, Matías Josué. Maldonado Medrano, Milagros.
 * Descripción: Crea todos los store procedures, funciones, y vistas del schema [Mundial].
 **/
 
USE GestionDelMundial;
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
	exec Administracion.sp_registrar_regla @AñoMundial = @añoMundial, @Codigo = 'ARBITRO_DE_VAR', @Valor = @ArbitroDeVarRequerido;
	exec Administracion.sp_registrar_regla @AñoMundial = @añoMundial, @Codigo = 'MAX_CONVOCADOS', @Valor = @LimiteJugadoresConvocados;
	exec Administracion.sp_registrar_regla @AñoMundial = @añoMundial, @Codigo = 'CANTIDAD_EQUIPOS', @Valor = @CantidadDeEquipos;

END
GO 
-- exec Administracion.sp_registrar_reglas @AñoMundial = 1930, @Codigo = 'ARBITRO_DE_VAR', @Valor = 1
--exec Mundial.sp_crear_mundial @FInicio = '1935-10-06', @FFin = '1935-10-08', @LimiteJugadoresConvocados = 23, @ArbitroDeVarRequerido = 1, @CantidadDeEquipos=32
--SELECT * FROM Mundial.Mundiales
--SELECT * FROM Administracion.Reglas

GO
CREATE OR ALTER PROCEDURE Mundial.sp_incluir_pais
	 @CodigoPais CHAR(3),
	 @AñoMundial INT,
	 @Grupo char(1) = NULL
AS
BEGIN
	-- Comprueba que el país no esté ya incluído.
	-- Crea una selección para ese país
	-- Crea el registro países_participes asociando todo lo necesario

	-- Lógica real: se arman distintos bombos, se van seleccionando y tienen reglas como " no más de x de cada continente, excepto europa que puede tener 2 ..."
	-- Esos bombos se arman teniendo en cuenta cosas como el ranking fifa. Me parece excesivamente complicado para el tp
	-- asíque propongo esta lógica más amena y qeu nos sirve igual para la importación:

	-- Grupos: O se pasa por parámetro, o se asigna automáticamente a la primer posicion disponible (por ejemplo, si hay dos equipos, le da el grupo A posicion 3)

	INSERT INTO Mundial.Selecciones (pais_id) VALUES (@CodigoPais)
	DECLARE @seleccionId INT = (SELECT SCOPE_IDENTITY());

	IF (@Grupo is null)
	BEGIN
		DECLARE @cantidadEquipos VARCHAR(100); 
		exec Administracion.sp_obtener_regla 
			 @AñoMundial = @AñoMundial, 
			 @Codigo = 'SELECCIONES', 
			 @Valor = @cantidadEquipos

		-- La cantidad de grupos siempre es cantidadDeEquipos / 4.

		-- con este código puedo obtener el primer grupo disponible
		-- Se puede mover más arriba grupo disponible para saber si el parametro ingresado es válido
		-- Convertir WITH a # temproal para poder usarla varias veces
		/* 
		WITH GruposPosibles AS (
		    -- Caso base: Empezamos con la letra 'A' (Código ASCII 65)
		    SELECT 1 AS Indice, CHAR(65) AS Letra
		    UNION ALL
		    -- Paso recursivo: Generamos las siguientes letras hasta llegar a @cantidadGrupos
		    SELECT Indice + 1, CHAR(65 + Indice)
		    FROM GruposPosibles
		    WHERE Indice < @cantidadGrupos
			)
			-- 2. Buscamos el primer grupo con menos de 4 equipos
			SELECT TOP 1 
			    G.Letra AS GrupoDisponible
			FROM GruposPosibles G
			-- LEFT JOIN permite incluir los grupos que todavía tienen 0 equipos asignados
			LEFT JOIN Mundial.Paises_Participes P 
			    ON G.Letra = P.grupo 
			    AND P.mundial_id = @mundial_id 
			GROUP BY 
			    G.Letra
			HAVING 
			    COUNT(P.id) < 4 -- Exige que haya al menos 1 lugar disponible (máximo 4 por grupo)
			ORDER BY 
			    G.Letra ASC;
		 */
	END

	INSERT INTO Mundial.Paises_Participes 
		(pais_id, mundial_id, seleccion_id, esta_eliminado, grupo)
		VALUES
		(@CodigoPais, @AñoMundial, @seleccionId, 0, @Grupo);

END
GO

CREATE OR ALTER PROCEDURE Mundial.sp_habilitar_arbitro
	@AñoMundial INT,
	@ArbitroID INT,
	@Confederacion varchar(8) = NULL
AS
BEGIN

	-- Que el Arbitro no esté asignado a ese mundial, 
	-- que la confederacion exista.
	-- que el mundial exista
	-- que el arbitro exista

	DECLARE @confederacionId INT = IIF(@Confederacion is not NULL,
		(SELECT id FROM Administracion.Confederaciones WHERE siglas = @Confederacion),
		(NULL)
	);


	INSERT INTO Mundial.Habilitacion_Arbitro 
		(mundial_id, arbitro_id, confederacion_id)
		VALUES
		(@AñoMundial, @ArbitroID, @confederacionId);
END
GO