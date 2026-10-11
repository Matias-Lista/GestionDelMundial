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
	
	DECLARE @añoMundial INT = YEAR(@FInicio);

	DECLARE @errores VARCHAR(500) = '';

	IF EXISTS (SELECT 1 FROM Mundial.Mundiales WHERE año = @añoMundial) 
		SET @errores = @errores + '- Ya existe un mundial en ese año. '+ CHAR(13) + CHAR(10);

	IF (@FInicio >= @FFin) SET @errores = @errores + '- La fecho de inicio debe ser anterior a la fecha de fin.' + CHAR(13) + CHAR(10);

	IF (@LimiteJugadoresConvocados <= 0) SET @errores = @errores + '- El límite de jugadores convocados debe ser un número positivo.' + CHAR(13) + CHAR(10);
	
	IF (@CantidadDeEquipos < 16 OR @CantidadDeEquipos % 4 <> 0) SET @errores = @errores + '- La cantidad de Equipos convocados debe ser al menos 16 y múltiplo de 4.' + CHAR(13) + CHAR(10);

	IF (@errores <> '')
		throw 50001, @errores, 1;

	BEGIN TRY
		BEGIN TRANSACTION
			INSERT INTO Mundial.Mundiales (f_inicio, f_fin) VALUES (@FInicio, @FFin);

			exec Administracion.sp_registrar_regla @AñoMundial = @añoMundial, @Codigo = 'ARBITRO_DE_VAR', @Valor = @ArbitroDeVarRequerido;
			exec Administracion.sp_registrar_regla @AñoMundial = @añoMundial, @Codigo = 'MAX_CONVOCADOS', @Valor = @LimiteJugadoresConvocados;
			exec Administracion.sp_registrar_regla @AñoMundial = @añoMundial, @Codigo = 'CANTIDAD_EQUIPOS', @Valor = @CantidadDeEquipos;
		COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0
			ROLLBACK TRANSACTION;

			throw;
	END CATCH;
END
GO 

-- exec Administracion.sp_registrar_reglas @AñoMundial = 1930, @Codigo = 'ARBITRO_DE_VAR', @Valor = 1
-- exec Mundial.sp_crear_mundial @FInicio = '1935-10-06', @FFin = '1935-10-01', @LimiteJugadoresConvocados = 0, @ArbitroDeVarRequerido = 1, @CantidadDeEquipos=32
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
	-- asíque propongo esta lógica más amena y que nos sirve igual para la importación:

	-- Grupos: O se pasa por parámetro, o se asigna automáticamente a la primer posicion disponible (por ejemplo, si hay dos equipos, le da el grupo A posicion 3)

	DECLARE @errores VARCHAR(500) = '';

	IF NOT EXISTS (SELECT 1 FROM Mundial.Mundiales WHERE año = @AñoMundial)
		SET @errores = @errores + '- No hay mundial registrado para ese país mundial.' + CHAR(13) + CHAR(10);
		
	IF NOT EXISTS (SELECT 1 FROM Administracion.Paises WHERE codigo = @CodigoPais)
		SET @errores = @errores + '- El país no se encuentra registrado.' + CHAR(13) + CHAR(10);

	IF EXISTS (SELECT 1 FROM Mundial.Paises_Participes WHERE mundial_id = @AñoMundial AND pais_id = @CodigoPais)
		SET @errores = @errores + '- El equipo ya está participando de ese mundial.' + CHAR(13) + CHAR(10);

	-- NOTA: en los primeros mundiales hubieron equipos de 3.
	DECLARE @cantidadEquipos INT; 
	exec Administracion.sp_obtener_regla @AñoMundial = @AñoMundial, @Codigo = 'CANTIDAD_EQUIPOS', @Valor = @cantidadEquipos OUTPUT;
	
	DECLARE @cantidadDeGrupos INT = @cantidadEquipos / 4;

	IF ((SELECT COUNT(*) FROM Mundial.Paises_Participes WHERE mundial_id = @AñoMundial) = @cantidadEquipos)
		SET @errores = @errores + '- Este mundial alcanzo su cupo de participantes.' + CHAR(13) + CHAR(10);

	DECLARE @TablaGruposPosibles TABLE (letra CHAR(1));

	--TODO: Me quede aca
	WITH TodasLasLetras AS (
		-- caso base: A
		SELECT 1 AS indice, CHAR(65) AS letra
		UNION ALL
		-- Paso recursivo: Generamos las siguientes letras hasta llegar a @cantidadGrupos
		SELECT indice + 1, CHAR(65 + indice)
		FROM TodasLasLetras
		WHERE indice < @cantidadDeGrupos
	)
	INSERT INTO @TablaGruposPosibles (Letra)
	SELECT G.Letra
	FROM TodasLasLetras G
	LEFT JOIN Mundial.Paises_Participes P 
		ON G.Letra = P.grupo 
		AND P.mundial_id = @AñoMundial 
	GROUP BY G.Letra
	HAVING COUNT(P.id) < 4; -- Esto me da warning aunque  funciona, no sé si es relevante

	IF (@Grupo IS NOT NULL AND ASCII(@Grupo) not between 65 and (65 + @cantidadDeGrupos)) 
		SET @errores = @errores + '- Si se define un grupo, debe ser válido.' + CHAR(13) + CHAR(10);
	ELSE IF (@Grupo is not null and (NOT EXISTS (SELECT 1 FROM @TablaGruposPosibles WHERE Letra = @Grupo)))
		SET @errores = @errores + '- El grupo indicado está lleno.' + CHAR(13) + CHAR(10);

	IF (@errores <> '')
		throw 50001, @errores, 1;

	INSERT INTO Mundial.Selecciones (pais_id) VALUES (@CodigoPais)
	DECLARE @seleccionId INT = (SELECT SCOPE_IDENTITY());

	IF (@Grupo is null)
		SET @Grupo = (SELECT TOP 1 Letra FROM @TablaGruposPosibles); -- El primer grupo disponible, en orden

	INSERT INTO Mundial.Paises_Participes 
		(pais_id, mundial_id, seleccion_id, esta_eliminado, grupo)
		VALUES
		(@CodigoPais, @AñoMundial, @seleccionId, 0, @Grupo);

END
GO

--exec Mundial.sp_crear_mundial @FInicio = '2026-10-06', @FFin = '2026-10-09', @LimiteJugadoresConvocados = 10, @ArbitroDeVarRequerido = 1, @CantidadDeEquipos=32
/*exec Mundial.sp_incluir_pais 'ARG', 2026, 'A'
exec Mundial.sp_incluir_pais 'ESP', 2026, 'A'
exec Mundial.sp_incluir_pais 'USA', 2026, 'A'
exec Mundial.sp_incluir_pais 'PRY', 2026, 'A'
exec Mundial.sp_incluir_pais 'RUS', 2026, 'A' -- FALLA POR GRUPO LLENO! CORRECTO
exec Mundial.sp_incluir_pais 'RUS', 2026      -- ASIGNA AUTOMATICAMENTE EL GRUPO B! CORRECTO
select * from Mundial.Paises_Participes
GO*/

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