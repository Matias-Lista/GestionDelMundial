USE GestionDelMundial;
GO

CREATE OR ALTER PROCEDURE Importacion.sp_simular_mundial 
	@FechaDeInicio DATE,
	@FechaDeFin    DATE
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @AñoMundial INT = YEAR(@FechaDeInicio);
	IF @AñoMundial is not null and exists (SELECT 1 FROM Mundial.Mundiales WHERE año = @AñoMundial)
		throw 50001, 'Ya existe un mundial en ese año.', 1;

	PRINT CONCAT('Generando mundial ', @AñoMundial, '...');
	
	EXEC Mundial.sp_crear_mundial @FInicio = @FechaDeInicio, @FFin = @FechaDeFin, @LimiteJugadoresConvocados = 26, 
			@LimiteStaffConvocados = 10, @ArbitroDeVarRequerido = 1, @CantidadDeEquipos = 32;
	
    IF OBJECT_ID('tempdb..#Paises') IS NOT NULL DROP TABLE #Paises;
	CREATE TABLE #Paises (id INT PRIMARY KEY IDENTITY(1,1), codigo CHAR(3) UNIQUE);

    IF OBJECT_ID('tempdb..#Integrantes') IS NOT NULL DROP TABLE #Integrantes;
	CREATE TABLE #Integrantes (id INT PRIMARY KEY IDENTITY(1,1), jugador_id INT UNIQUE);
	
	INSERT INTO #Paises (codigo)
	SELECT TOP 32 P.codigo
		FROM Administracion.Paises P
		INNER JOIN Equipos.IntegranteSeleccion I ON I.pais_id = P.codigo
		GROUP BY P.codigo
		HAVING COUNT(*) >= 26 -- Solo tomo países al azar que tengan al menos 26 jugadores registrados.
	ORDER BY CASE when codigo = 'ARG' THEN 0 else 1 end, NEWID();

	DECLARE @codigo CHAR(3) = NULL;
	DECLARE @i INT = 1;
	
	WHILE @i < 33 BEGIN -- Cargar países 
		SELECT @codigo = codigo FROM #Paises WHERE id = @i;
		
		EXEC Mundial.sp_incluir_pais @CodigoPais = @codigo, @AñoMundial = @AñoMundial;

		TRUNCATE TABLE #Integrantes;

		INSERT INTO #Integrantes (jugador_id)
		SELECT TOP 26 id
		FROM Equipos.IntegranteSeleccion
		WHERE pais_id = @codigo
		ORDER BY NEWID();

		DECLARE @j         INT = 1;
		DECLARE @jugadorID INT = NULL;

		WHILE @j < 27 BEGIN -- Cargar Convocados 
		DECLARE @cantidad INT =(SELECT count(*) FROM #Integrantes)
			
			SELECT @jugadorID = jugador_id FROM #Integrantes WHERE id = @j;
			DECLARE @fechaDeConvocacion DATE;

			SET @fechaDeConvocacion = DATEADD(
				DAY,
				-(ABS(CHECKSUM(NEWID())) % 30),
				@FechaDeInicio
			);
			
			EXEC Equipos.sp_convocar_jugador
					@AñoMundial   = @AñoMundial,
					@MiembroID    = @jugadorID,
					@FConvocacion = @fechaDeConvocacion,
					@Dorsal = @j;
			
			SET @j = @j + 1;
		END -- END Cargar Convocados 

		SET @i = @i + 1;
	END -- END Cargar países 
	
	
	-- En este punto: Cargados países y convocados.

	EXEC Partidos.sp_generar_partidos
		 @AñoMundial = @AñoMundial;

	SELECT * FROM Partidos.Partidos WHERE mundial_id = @AñoMundial
	
	-- Asignación de Arbitros aleatorios. (170)
	
    IF OBJECT_ID('tempdb..#Arbitros') IS NOT NULL DROP TABLE #Arbitros;
	CREATE TABLE #Arbitros (id INT PRIMARY KEY IDENTITY(1,1), arbitro_id INT UNIQUE);
	
	INSERT INTO #Arbitros (arbitro_id)
	SELECT TOP 170 A.id
	FROM Arbitraje.Arbitros A
	ORDER BY NEWID();

	DECLARE @arbitroID INT = NULL;
	SET @i = 1;
	WHILE @i < 171 BEGIN

		SELECT @arbitroID = arbitro_id FROM #Arbitros WHERE id = @i;

		EXEC Mundial.sp_habilitar_arbitro
			@AñoMundial = @AñoMundial,
			@ArbitroID  = @arbitroID;

		SET @i = @i + 1;
	END

	

	

END
GO
/*
BEGIN TRANSACTION

EXEC Importacion.sp_simular_mundial 
	  @FechaDeInicio = '2040-09-01',
	  @FechaDeFin    = '2040-10-01';

ROLLBACK TRANSACTION;*/
