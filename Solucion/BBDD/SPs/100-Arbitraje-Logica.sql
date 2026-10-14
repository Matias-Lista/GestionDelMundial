/* BBDD/SPs/Arbitraje-Logica.sql
 * Fecha: 10/10/2026
 * Integrantes: Lista, Matías Josué. Maldonado Medrano, Milagros.
 * Descripción: Store procedures de lógica de negocio del schema [Arbitraje]: designación de árbitros por partido.
 **/

USE GestionDelMundial;                  
GO

CREATE OR ALTER PROCEDURE Arbitraje.sp_designar_arbitro
    @PartidoID INT,
    @ArbitroID INT,
    @Rol VARCHAR(15)
AS
BEGIN
    DECLARE @errores NVARCHAR(1000) = '';

    DECLARE @mundialId SMALLINT;
    DECLARE @fase VARCHAR(15);
    DECLARE @fechaPartido DATE;
    DECLARE @paisA CHAR(3);
    DECLARE @paisB CHAR(3);

    -- Obtengo info del partido
    SELECT @mundialId = P.mundial_id,
           @fase = P.fase,
           @fechaPartido = CAST(P.fecha_y_hora AS DATE),
           @paisA = SA.pais_id,
           @paisB = SB.pais_id
        FROM Partidos.Partidos P
        INNER JOIN Mundial.Selecciones SA ON SA.id = P.seleccion_A_id
        INNER JOIN Mundial.Selecciones SB ON SB.id = P.seleccion_B_id
        WHERE P.id = @PartidoID;

    -- pais del árbitro
    DECLARE @paisArbitro CHAR(3) = (SELECT pais_id FROM Arbitraje.Arbitros WHERE id = @ArbitroID);

    -- cupo máx por rol
    DECLARE @cupoRol INT;

    IF (@Rol = 'ASISTENTE')
        BEGIN
            SET @cupoRol = 2;   -- si el rol es ASISTENTE, se permiten 2 árbitros
        END
    ELSE
        BEGIN
            SET @cupoRol = 1;   -- paar PRINCIPAL, CUARTO o VAR, solo se permite 1 árbitr
        END

  
    IF (@mundialId IS NULL)
        SET @errores = @errores + 'El partido no existe. ';

    IF (@paisArbitro IS NULL)
		SET @errores = @errores + 'El árbitro no existe. ';

    IF (@Rol IS NULL OR @Rol NOT IN ('PRINCIPAL', 'ASISTENTE', 'CUARTO', 'VAR'))
        SET @errores = @errores + 'El rol debe ser PRINCIPAL, ASISTENTE, CUARTO o VAR. ';

    IF (@mundialId IS NOT NULL AND @paisArbitro IS NOT NULL
        AND NOT EXISTS (SELECT 1 FROM Mundial.Habilitacion_Arbitro WHERE arbitro_id = @ArbitroID AND mundial_id = @mundialId))
        SET @errores = @errores + 'El árbitro no está habilitado para este mundial. ';

    IF (@paisArbitro IN (@paisA, @paisB))
        SET @errores = @errores + 'Conflicto de nacionalidad: el árbitro es del mismo país que una de las selecciones. ';

    IF EXISTS (SELECT 1 FROM Arbitraje.ArbitroAsignadoPartido WHERE partido_id = @PartidoID AND arbitro_id = @ArbitroID)
        SET @errores = @errores + 'El árbitro ya está designado en este partido. ';

    IF ((SELECT COUNT(*) FROM Arbitraje.ArbitroAsignadoPartido WHERE partido_id = @PartidoID AND rol = @Rol) >= @cupoRol)
        SET @errores = @errores + 'El partido ya tiene cubierto el cupo para ese rol. ';


    IF EXISTS (SELECT 1
                FROM Arbitraje.ArbitroAsignadoPartido A
                INNER JOIN Partidos.Partidos P ON P.id = A.partido_id
                WHERE A.arbitro_id = @ArbitroID
                  AND A.partido_id <> @PartidoID
                  AND CAST(P.fecha_y_hora AS DATE) = @fechaPartido)
        SET @errores = @errores + 'El árbitro ya tiene otro partido designado ese día. ';

    -- Validación especial para árbitro VAR: solo si el mundial lo permite
    IF (@Rol = 'VAR' AND @mundialId IS NOT NULL)
    BEGIN
        DECLARE @usaVar VARCHAR(100);
        EXEC Administracion.sp_obtener_regla @AñoMundial = @mundialId, @Codigo = 'ARBITRO_DE_VAR', @Valor = @usaVar OUTPUT;

        IF (ISNULL(@usaVar, '0') <> '1')
            SET @errores = @errores + 'El mundial de este partido no utiliza árbitro de VAR. ';
    END

    IF (@errores <> '')
        THROW 50001, @errores, 1;

    IF (@fase <> 'GRUPOS'
        AND EXISTS (SELECT 1 FROM Mundial.Paises_Participes WHERE mundial_id = @mundialId AND pais_id = @paisArbitro AND esta_eliminado = 0))
        RAISERROR('Advertencia: el país del árbitro sigue en competencia y podría cruzarse con las selecciones de este partido.', 10, 1);

    INSERT INTO Arbitraje.ArbitroAsignadoPartido
        (partido_id, arbitro_id, rol)
        VALUES
        (@PartidoID, @ArbitroID, @Rol);
END
GO








CREATE OR ALTER PROCEDURE Arbitraje.sp_designar_terna_completa
	@PartidoID INT,
	@PrincipalID INT,
	@Asistente1ID INT,
	@Asistente2ID INT,
	@CuartoID INT,
	@VarID INT = NULL
AS
BEGIN
	DECLARE @errores NVARCHAR(500) = '';

	DECLARE @mundialId SMALLINT = (SELECT mundial_id FROM Partidos.Partidos WHERE id = @PartidoID);
	DECLARE @usaVar VARCHAR(100);
	EXEC Administracion.sp_obtener_regla @AñoMundial = @mundialId, @Codigo = 'ARBITRO_DE_VAR', @Valor = @usaVar OUTPUT;

	IF (@mundialId IS NULL)
		SET @errores = @errores + 'El partido no existe. ';

	IF (@PrincipalID IS NULL OR @Asistente1ID IS NULL OR @Asistente2ID IS NULL OR @CuartoID IS NULL)
		SET @errores = @errores + 'Debe indicar árbitro principal, dos asistentes y cuarto árbitro. ';

	IF (@usaVar = '1' AND @VarID IS NULL)
		SET @errores = @errores + 'Este mundial requiere árbitro de VAR. ';

	IF EXISTS (SELECT id
				FROM (VALUES (@PrincipalID), (@Asistente1ID), (@Asistente2ID), (@CuartoID), (@VarID)) AS Terna(id)
				WHERE id IS NOT NULL
				GROUP BY id
				HAVING COUNT(*) > 1)
		SET @errores = @errores + 'No se puede repetir un árbitro dentro de la terna. ';

	IF EXISTS (SELECT 1 FROM Arbitraje.ArbitroAsignadoPartido WHERE partido_id = @PartidoID)
		SET @errores = @errores + 'El partido ya tiene árbitros designados. ';

	IF (@errores <> '')
		THROW 50001, @errores, 1;

	-- O se designa la terna completa, o no se designa nadie.
	BEGIN TRY
		BEGIN TRANSACTION;

		EXEC Arbitraje.sp_designar_arbitro @PartidoID = @PartidoID, @ArbitroID = @PrincipalID,  @Rol = 'PRINCIPAL';
		EXEC Arbitraje.sp_designar_arbitro @PartidoID = @PartidoID, @ArbitroID = @Asistente1ID, @Rol = 'ASISTENTE';
		EXEC Arbitraje.sp_designar_arbitro @PartidoID = @PartidoID, @ArbitroID = @Asistente2ID, @Rol = 'ASISTENTE';
		EXEC Arbitraje.sp_designar_arbitro @PartidoID = @PartidoID, @ArbitroID = @CuartoID,     @Rol = 'CUARTO';

		IF (@VarID IS NOT NULL)
			EXEC Arbitraje.sp_designar_arbitro @PartidoID = @PartidoID, @ArbitroID = @VarID, @Rol = 'VAR';

		COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
		IF (@@TRANCOUNT > 0)
			ROLLBACK TRANSACTION;

		THROW;
	END CATCH
END
GO







CREATE OR ALTER PROCEDURE Arbitraje.sp_quitar_designacion
	@PartidoID INT,
	@ArbitroID INT
AS
BEGIN
	DECLARE @errores NVARCHAR(500) = '';

	IF NOT EXISTS (SELECT 1 FROM Arbitraje.ArbitroAsignadoPartido WHERE partido_id = @PartidoID AND arbitro_id = @ArbitroID)
		SET @errores = @errores + 'El árbitro no está designado en ese partido. ';

	IF EXISTS (SELECT 1 FROM Arbitraje.InformesArbitros WHERE partido_id = @PartidoID AND arbitro_id = @ArbitroID)
		SET @errores = @errores + 'El árbitro tiene informes registrados sobre ese partido. ';

	IF (@errores <> '')
		THROW 50001, @errores, 1;

	DELETE FROM Arbitraje.ArbitroAsignadoPartido
		WHERE partido_id = @PartidoID AND arbitro_id = @ArbitroID;
END
GO