/* BBDD/SPs/Mundial.sql
 * Fecha: 9/10/2026
 * Lista, Matías Josué.
 * Descripción: Crea todos los store procedures, funciones, y vistas del schema [Mundial].
 **/
 
USE GestionDelMundial;
GO

CREATE OR ALTER PROCEDURE Mundial.sp_crear_mundial
	 @FInicio DATE,
	 @FFin DATE,
	 --- TODAS LAS CONFIGURACIONES NECESARIAS. Por ejemplo, Abritro de var requerido, o, equipos
	 @LimiteJugadoresConvocados INT,
	 @LimiteStaffConvocados INT,
	 @ArbitroDeVarRequerido BIT,
	 @CantidadDeEquipos INT,
	 @CantidadDeCambios INT = 5,
	 @AmarillasParaExpulsion INT = 2,
	 @ReiniciaAmarillasEnFaseDeGrupos BIT = 0,
	 @ReiniciaAmarillasEnSemifinal BIT = 1
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @errores VARCHAR(500) = '';
	
	DECLARE @añoMundial INT = NULL;

	IF @FInicio is NULL 
		SET @errores = @errores + '- Debe indicar una fecha de inicio. ' + CHAR(13) + CHAR(10);
	ELSE
		SET @añoMundial = YEAR(@FInicio);

	IF @FFin is NULL 
		SET @errores = @errores + '- Debe indicar una fecha de Fin. '+ CHAR(13) + CHAR(10);

	IF @LimiteJugadoresConvocados is NULL 
		SET @errores = @errores + '- Debe indicar un límite de jugadores convocados. '+ CHAR(13) + CHAR(10);

	IF @LimiteStaffConvocados is NULL 
		SET @errores = @errores + '- Debe indicar un límite de staff convocado. '+ CHAR(13) + CHAR(10);

	IF @ArbitroDeVarRequerido is NULL 
		SET @errores = @errores + '- Debe indicar si se requiere un arbitro de var. '+ CHAR(13) + CHAR(10);

	IF @CantidadDeEquipos is NULL 
		SET @errores = @errores + '- Debe indicar la cantidad de equipos que juegan. '+ CHAR(13) + CHAR(10);

	IF @añoMundial IS NOT NULL AND EXISTS (SELECT 1 FROM Mundial.Mundiales WHERE año = @añoMundial) 
		SET @errores = @errores + '- Ya existe un mundial en ese año. '+ CHAR(13) + CHAR(10);

	IF @FInicio IS NOT NULL AND @FFin IS NOT NULL AND @FInicio >= @FFin
	   SET @errores = @errores + '- La fecha de inicio debe ser anterior a la fecha de fin.' + CHAR(13) + CHAR(10);

	IF @LimiteJugadoresConvocados IS NOT NULL AND @LimiteJugadoresConvocados <= 0
		SET @errores = @errores + '- El límite de jugadores convocados debe ser un número positivo.' + CHAR(13) + CHAR(10);
	
	IF @LimiteStaffConvocados IS NOT NULL AND @LimiteStaffConvocados <= 0
		SET @errores = @errores + '- El límite de staff convocados debe ser un número positivo.' + CHAR(13) + CHAR(10);
	
	IF @CantidadDeEquipos IS NOT NULL AND (@CantidadDeEquipos < 16 OR @CantidadDeEquipos % 4 <> 0) 
		SET @errores = @errores + '- La cantidad de Equipos convocados debe ser al menos 16 y múltiplo de 4.' + CHAR(13) + CHAR(10);

	IF (@errores <> '') throw 50001, @errores, 1;

	BEGIN TRY
		BEGIN TRANSACTION
			INSERT INTO Mundial.Mundiales (f_inicio, f_fin) VALUES (@FInicio, @FFin);

			exec Administracion.sp_registrar_regla @AñoMundial = @añoMundial, @Codigo = 'ARBITRO_DE_VAR', @Valor = @ArbitroDeVarRequerido;
			exec Administracion.sp_registrar_regla @AñoMundial = @añoMundial, @Codigo = 'MAX_CONVOCADOS', @Valor = @LimiteJugadoresConvocados;
			exec Administracion.sp_registrar_regla @AñoMundial = @añoMundial, @Codigo = 'CANTIDAD_EQUIPOS', @Valor = @CantidadDeEquipos;
			exec Administracion.sp_registrar_regla @AñoMundial = @añoMundial, @Codigo = 'MAX_STAFF_CONVOCADOS', @Valor = @LimiteStaffConvocados;
			exec Administracion.sp_registrar_regla @AñoMundial = @añoMundial, @Codigo = 'CANTIDAD_DE_CAMBIOS', @Valor = @CantidadDeCambios;
			exec Administracion.sp_registrar_regla @AñoMundial = @añoMundial, @Codigo = 'AMARILLAS_PARA_EXPULSION', @Valor = @AmarillasParaExpulsion;
			exec Administracion.sp_registrar_regla @AñoMundial = @añoMundial, @Codigo = 'REINICIA_AMARILLAS_EN_FASE_DE_GRUPOS', @Valor = @ReiniciaAmarillasEnFaseDeGrupos;
			exec Administracion.sp_registrar_regla @AñoMundial = @añoMundial, @Codigo = 'REINICIA_AMARILLAS_EN_SEMIFINAL', @Valor = @ReiniciaAmarillasEnSemifinal;
		COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0
			ROLLBACK TRANSACTION;
		throw;
	END CATCH;
END
GO 

CREATE OR ALTER PROCEDURE Mundial.sp_eliminar_mundial
	@AñoMundial INT
AS
BEGIN 
	SET NOCOUNT ON
	DECLARE @errores VARCHAR(500) = '';


	IF @AñoMundial is NULL 
		SET @errores = @errores + '- Debe indicar un mundial. '+ CHAR(13) + CHAR(10);


	IF @AñoMundial IS NOT NULL BEGIN

	 	IF NOT EXISTS (SELECT 1 FROM Mundial.Mundiales WHERE año = @AñoMundial) 
			SET @errores = @errores + '- No existe un mundial en ese año. '+ CHAR(13) + CHAR(10);

		IF EXISTS (SELECT 1 FROM Partidos.Partidos WHERE mundial_id = @AñoMundial) 
			SET @errores = @errores + '- Este mundial tiene partidos asignados. '+ CHAR(13) + CHAR(10);
		
		IF EXISTS (SELECT 1 FROM Mundial.Paises_Participes WHERE mundial_id = @AñoMundial) 
			SET @errores = @errores + '- Este mundial tiene países asociados. '+ CHAR(13) + CHAR(10);

		IF EXISTS (SELECT 1 FROM Mundial.Habilitacion_Arbitro WHERE mundial_id = @AñoMundial) 
			SET @errores = @errores + '- Este mundial tiene arbitros asociados. '+ CHAR(13) + CHAR(10);

		IF EXISTS (SELECT 1 FROM Publicidad.Tarifas WHERE mundial_id = @AñoMundial) 
			SET @errores = @errores + '- Este mundial tiene tarifas asociadas. '+ CHAR(13) + CHAR(10);

	END

	IF (@errores <> '')
		throw 50001, @errores, 1;

	BEGIN TRANSACTION
	BEGIN TRY

		DELETE FROM Administracion.Reglas WHERE mundial_id = @AñoMundial;
		DELETE FROM Mundial.Mundiales WHERE año = @AñoMundial;

		COMMIT TRANSACTION
	END TRY
	BEGIN CATCH

		if @@TRANCOUNT > 0
			ROLLBACK TRANSACTION;
		throw

	END CATCH

END
GO

-- Sobre Mundial.sp_incluir_pais
-- En la realidad, se arman varios bombos con diferentes países y reglas, como, no más de x países de cada continente por grupo, excepto europa que puede tener 2.
-- Los bombos a partir de los cuales se hacen los sorteos se definen con datos como el ranking fifa.
--
-- En este SP, se pasa directamente el grupo al que se asigna un país, o se asigna el primero disponible. (Por ejemplo, si hay un equipo en el A, y uno en el B, el primero disponible es el A).
CREATE OR ALTER PROCEDURE Mundial.sp_incluir_pais
	 @CodigoPais CHAR(3),
	 @AñoMundial INT,
	 @Grupo char(1) = NULL 
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @errores VARCHAR(500) = '';

	IF @CodigoPais is NULL 
		SET @errores = @errores + '- Debe indicar un país.' + CHAR(13) + CHAR(10);

	IF @AñoMundial is NULL 
		SET @errores = @errores + '- Debe indicar un mundial.' + CHAR(13) + CHAR(10);

	IF @AñoMundial IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Mundial.Mundiales WHERE año = @AñoMundial)
		SET @errores = @errores + '- No hay mundial registrado en ese año.' + CHAR(13) + CHAR(10);
		
	IF @CodigoPais is NOT NULL AND NOT EXISTS (SELECT 1 FROM Administracion.Paises WHERE codigo = @CodigoPais)
		SET @errores = @errores + '- El país no se encuentra registrado.' + CHAR(13) + CHAR(10);

	IF @AñoMundial IS NOT NULL AND @CodigoPais is NOT NULL 
	   AND EXISTS (SELECT 1 FROM Mundial.Paises_Participes WHERE mundial_id = @AñoMundial AND pais_id = @CodigoPais)
		SET @errores = @errores + '- El equipo ya está participando de ese mundial.' + CHAR(13) + CHAR(10);
	
	IF (@errores <> '')
		throw 50001, @errores, 1;

	-- NOTA: en los primeros mundiales hubieron equipos de 3.
	DECLARE @cantidadEquipos INT; 
	exec Administracion.sp_obtener_regla @AñoMundial = @AñoMundial, @Codigo = 'CANTIDAD_EQUIPOS', @Valor = @cantidadEquipos OUTPUT;
	
	DECLARE @cantidadDeGrupos INT = @cantidadEquipos / 4;

	BEGIN TRY
	BEGIN TRANSACTION  -- Incluyo la validación del cupo y del grupo en una transacción con SERIALIZABLE.
	SAVE TRANSACTION sp_incluir_pais
		IF ((SELECT COUNT(*) FROM Mundial.Paises_Participes WITH (UPDLOCK, SERIALIZABLE) WHERE mundial_id = @AñoMundial) = @cantidadEquipos)
			SET @errores = @errores + '- Este mundial alcanzo su cupo de participantes.' + CHAR(13) + CHAR(10);

		DECLARE @TablaGruposPosibles TABLE (letra CHAR(1));

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
		LEFT JOIN Mundial.Paises_Participes P WITH (UPDLOCK, SERIALIZABLE)
			ON G.Letra = P.grupo 
			AND P.mundial_id = @AñoMundial 
		GROUP BY G.Letra
		HAVING COUNT(P.id) < 4; -- Esto me da warning aunque funciona, no sé si es relevante

		IF (@Grupo IS NOT NULL AND ASCII(@Grupo) not between 65 and (65 + @cantidadDeGrupos - 1)) 
			SET @errores = @errores + '- Si se define un grupo, debe ser válido.' + CHAR(13) + CHAR(10);
		ELSE IF (@Grupo is not null and (NOT EXISTS (SELECT 1 FROM @TablaGruposPosibles WHERE Letra = @Grupo)))
			SET @errores = @errores + '- El grupo indicado está lleno.' + CHAR(13) + CHAR(10);

		IF (@errores <> '')
			throw 50001, @errores, 1;

		
		IF (@Grupo is null)
			SET @Grupo = (SELECT TOP 1 Letra FROM @TablaGruposPosibles ORDER BY Letra ASC); -- El primer grupo disponible, en orden

		INSERT INTO Mundial.Selecciones (pais_id) VALUES (@CodigoPais)
		DECLARE @seleccionId INT = (SELECT SCOPE_IDENTITY());

		INSERT INTO Mundial.Paises_Participes 
			(pais_id, mundial_id, seleccion_id, esta_eliminado, grupo)
			VALUES
			(@CodigoPais, @AñoMundial, @seleccionId, 0, @Grupo);
	COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		if @@TRANCOUNT > 0
			ROLLBACK TRANSACTION sp_incluir_pais;
		throw
	END CATCH
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


CREATE OR ALTER PROCEDURE Mundial.sp_remover_pais
	 @CodigoPais CHAR(3),
	 @AñoMundial INT
AS
BEGIN

	SET NOCOUNT ON

	DECLARE @errores VARCHAR(500) = '';

	IF @CodigoPais is NULL 
		SET @errores = @errores + '- Debe indicar un país.' + CHAR(13) + CHAR(10);

	IF @AñoMundial is NULL 
		SET @errores = @errores + '- Debe indicar un mundial.' + CHAR(13) + CHAR(10);

	IF @AñoMundial IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Mundial.Mundiales WHERE año = @AñoMundial)
		SET @errores = @errores + '- No hay mundial registrado en ese año.' + CHAR(13) + CHAR(10);
		
	IF @CodigoPais is NOT NULL AND NOT EXISTS (SELECT 1 FROM Administracion.Paises WHERE codigo = @CodigoPais)
		SET @errores = @errores + '- El país no se encuentra registrado.' + CHAR(13) + CHAR(10);

	DECLARE @seleccionId INT = NULL;
	SELECT  @seleccionId = seleccion_id FROM Mundial.Paises_Participes WHERE mundial_id = @AñoMundial AND pais_id = @CodigoPais;
	
	IF (@errores <> '')
		throw 50001, @errores, 1;

	IF @AñoMundial IS NOT NULL AND @CodigoPais is NOT NULL AND @seleccionId is null
		SET @errores = @errores + '- El equipo NO está participando de ese mundial.' + CHAR(13) + CHAR(10);
	
	IF @seleccionId is not NULL and EXISTS (SELECT 1 FROM Partidos.Partidos WHERE seleccion_A_id = @seleccionId or seleccion_B_id = @seleccionId)
		SET @errores = @errores + '- El equipo está asignado a un partido de ese mundial.' + CHAR(13) + CHAR(10);

	IF @seleccionId is not NULL and EXISTS (SELECT 1 FROM Equipos.ConvocacionEnSeleccion WHERE seleccion_id = @seleccionId)
		SET @errores = @errores + '- El equipo tiene jugadores convocados.' + CHAR(13) + CHAR(10);

	IF (@errores <> '')
		throw 50001, @errores, 1;

	BEGIN TRY
	BEGIN TRANSACTION
	SAVE TRANSACTION sp_remover_pais
		

		DELETE FROM Mundial.Paises_Participes 
			WHERE pais_id = @CodigoPais and mundial_id = @AñoMundial;

		DELETE FROM Mundial.Selecciones WHERE id = @seleccionId;

	COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		if @@TRANCOUNT > 0
			ROLLBACK TRANSACTION sp_remover_pais;
		throw
	END CATCH
END
GO

CREATE OR ALTER PROCEDURE Mundial.sp_habilitar_arbitro
	@AñoMundial INT,
	@ArbitroID INT
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @errores VARCHAR(500) = '';

	IF (@AñoMundial is null)
		SET @errores = @errores + '- Debe indicar un mundial.' + CHAR(13) + CHAR(10)

	IF (@ArbitroID is null)
		SET @errores = @errores + '- Debe indicar un arbitro.' + CHAR(13) + CHAR(10)
	
	IF (@ArbitroID is not null and NOT EXISTS (SELECT 1 FROM Arbitraje.Arbitros WHERE id = @ArbitroID))
		SET @errores = @errores + '- El arbitro no existe.' + CHAR(13) + CHAR(10)
	
	IF (@AñoMundial is not null and NOT EXISTS (SELECT 1 FROM Mundial.Mundiales WHERE año = @AñoMundial))
		SET @errores = @errores + '- El Mundial no existe.' + CHAR(13) + CHAR(10)

	-- Duda: Deberíamos hacer transacciones acá? (para no habilitar dos veces al mismo arbitro, aunque la constraint UQ lo evitaría).

	IF EXISTS (SELECT 1 FROM Mundial.Habilitacion_Arbitro WHERE mundial_id = @AñoMundial and arbitro_id = @ArbitroID)
		SET @errores = @errores + '- El arbitro ya está habilitado para ese mundial.' + CHAR(13) + CHAR(10)
		
	IF (@errores <> '')
		throw 50001, @errores, 1;

	INSERT INTO Mundial.Habilitacion_Arbitro 
		(mundial_id, arbitro_id)
		VALUES
		(@AñoMundial, @ArbitroID);
END
GO

CREATE OR ALTER PROCEDURE Mundial.sp_remover_habilitacion_arbitro
	@AñoMundial INT,
	@ArbitroID INT
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @errores VARCHAR(500) = '';

	IF (@AñoMundial is null)
		SET @errores = @errores + '- Debe indicar un mundial.' + CHAR(13) + CHAR(10)

	IF (@ArbitroID is null)
		SET @errores = @errores + '- Debe indicar un arbitro.' + CHAR(13) + CHAR(10)
	
	IF (@ArbitroID is not null and NOT EXISTS (SELECT 1 FROM Arbitraje.Arbitros WHERE id = @ArbitroID))
		SET @errores = @errores + '- El arbitro no existe.' + CHAR(13) + CHAR(10)
	
	IF (@AñoMundial is not null and NOT EXISTS (SELECT 1 FROM Mundial.Mundiales WHERE año = @AñoMundial))
		SET @errores = @errores + '- El Mundial no existe.' + CHAR(13) + CHAR(10)

	IF (@errores <> '')
		throw 50001, @errores, 1;


	IF NOT EXISTS (SELECT 1 FROM Mundial.Habilitacion_Arbitro WHERE mundial_id = @AñoMundial and arbitro_id = @ArbitroID)
		SET @errores = @errores + '- El arbitro NO está habilitado para ese mundial.' + CHAR(13) + CHAR(10)
	ELSE IF EXISTS (SELECT 1 FROM Arbitraje.ArbitroAsignadoPartido AAP 
		JOIN Partidos.Partidos P ON P.id = AAP.partido_id
		WHERE AAP.arbitro_id = @ArbitroID and P.mundial_id = @AñoMundial)
		SET @errores = @errores + '- El arbitro está asignado en un partido de este mundial.' + CHAR(13) + CHAR(10)

	IF (@errores <> '')
		throw 50001, @errores, 1;

	DELETE FROM Mundial.Habilitacion_Arbitro WHERE mundial_id = @AñoMundial and arbitro_id = @ArbitroID;

END
GO