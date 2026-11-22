/* BBDD/Testeos/16-Testing-Rol-Administrador.sql
 * Fecha: 21/11/2026
 * Lista, Matías Josué.
 * Descripción: Verifica los permisos otorgados y denegados para el usuario
 *              [usr_administracion] asociado al rol [rol_administrador].
 **/

USE GestionDelMundial;
GO
SET NOCOUNT ON;

DECLARE @ErrorRecibido VARCHAR(MAX);
DECLARE @NumeroError   INT;
DECLARE @NombreTesteo  VARCHAR(200);

BEGIN TRY
BEGIN TRANSACTION ComienzoTesteo;

	---------------------------------------------------------
	-- SETUP: crear datos ficticios
	---------------------------------------------------------
	
	DECLARE @añoMundialTest INT = 9999;
	INSERT INTO Mundial.Mundiales (f_inicio, f_fin) 
	VALUES ('9999-01-01', '9999-02-02');

	DECLARE @confederacionIDTest INT;
	EXEC Administracion.sp_crear_confederacion 
		@Nombre = 'Confederacion Test Rol',
		@siglas = 'CTR',
		@FFundacion = '2000-01-01',
		@ID = @confederacionIDTest OUTPUT;

	DECLARE @clubBaseID INT;
	EXEC Administracion.sp_crear_club 
		@Nombre = 'Club Base Rol Admin',
		@ID = @clubBaseID OUTPUT;

	---------------------------------------------------------
	-- 2. CAMBIO DE CONTEXTO AL USUARIO A TESTEAR
	---------------------------------------------------------
	EXECUTE AS USER = 'usr_administracion';

	PRINT '====================================================';
	PRINT 'INICIO TESTEOS ROL: rol_administrador (usr_administracion)';
	PRINT '====================================================';

	---------------------------------------------------------
	-- CASOS POSITIVOS (Lo que SÍ puede hacer)
	---------------------------------------------------------

	SET @NombreTesteo = '[PERMITIDO] Ejecutar SP de Administracion (Crear y Modificar País)';
	BEGIN TRY
		EXEC Administracion.sp_crear_pais 
			@Nombre = 'Pais X',
			@Codigo = 'XXX',
			@ConfederacionID = @confederacionIDTest;

		EXEC Administracion.sp_modificar_pais 
			@Codigo = 'XXX',
			@Nombre = 'Pais X Modificado',
			@ConfederacionID = @confederacionIDTest;

		PRINT 'Testeo exitoso: ' + @NombreTesteo;
	END TRY
	BEGIN CATCH
		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;
	END CATCH

	---------------------------------------------------------

	SET @NombreTesteo = '[PERMITIDO] Ejecutar SP de Administracion (Crear Club) y hacer SELECT en el esquema';
	BEGIN TRY
		DECLARE @nuevoClubID INT;
		EXEC Administracion.sp_crear_club 
			@Nombre = 'Club X Test Admin',
			@ID = @nuevoClubID OUTPUT;

		IF NOT EXISTS (SELECT 1 FROM Administracion.Paises WHERE codigo = 'XXX')
			THROW 50001, 'No pudo consultar el país recién creado.', 1;

		PRINT 'Testeo exitoso: ' + @NombreTesteo;
	END TRY
	BEGIN CATCH
		SET @ErrorRecibido = ERROR_MESSAGE();
		THROW 50001, @ErrorRecibido, 1;
	END CATCH

	---------------------------------------------------------
	-- CASOS NEGATIVOS (Lo que NO puede hacer)
	---------------------------------------------------------

	SET @NombreTesteo = '[DENEGADO] Ejecutar SP con DENY explícito (Administracion.sp_registrar_regla)';
	BEGIN TRY
		EXEC Administracion.sp_registrar_regla 
			@AñoMundial = @añoMundialTest,
			@Codigo = 'REGLA_PROHIBIDA',
			@Valor = '1';

		THROW 50001, 'ERROR DE SEGURIDAD: El administrador pudo registrar una regla.', 1;
	END TRY
	BEGIN CATCH
		IF ERROR_NUMBER() = 229
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
		BEGIN
			SET @ErrorRecibido = ERROR_MESSAGE();
			THROW 50001, @ErrorRecibido, 1;
		END
	END CATCH

	---------------------------------------------------------

	SET @NombreTesteo = '[DENEGADO] Ejecutar SP de otro esquema (Mundial.sp_crear_mundial)';
	BEGIN TRY
		EXEC Mundial.sp_crear_mundial 
			@FInicio = '9998-01-01',
			@FFin = '9998-02-01',
			@LimiteJugadoresConvocados = 26,
			@LimiteStaffConvocados = 10,
			@ArbitroDeVarRequerido = 1,
			@CantidadDeEquipos = 32;

		THROW 50001, 'ERROR DE SEGURIDAD: El administrador pudo crear un mundial.', 1;
	END TRY
	BEGIN CATCH
		IF ERROR_NUMBER() = 229
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
		BEGIN
			SET @ErrorRecibido = ERROR_MESSAGE();
			THROW 50001, @ErrorRecibido, 1;
		END
	END CATCH

	---------------------------------------------------------

	SET @NombreTesteo = '[DENEGADO] Ejecutar SP de otro esquema (Publicidad.sp_crear_anunciante)';
	BEGIN TRY
		EXEC Publicidad.sp_crear_anunciante 
			@RazonSocial = 'Anunciante Prohibido SA';

		THROW 50001, 'ERROR DE SEGURIDAD: El administrador pudo crear un anunciante.', 1;
	END TRY
	BEGIN CATCH
		IF ERROR_NUMBER() = 229
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
		BEGIN
			SET @ErrorRecibido = ERROR_MESSAGE();
			THROW 50001, @ErrorRecibido, 1;
		END
	END CATCH

	---------------------------------------------------------

	SET @NombreTesteo = '[DENEGADO] INSERT directo en tabla de su propio esquema (Administracion.Clubes)';
	BEGIN TRY
		INSERT INTO Administracion.Clubes (nombre) 
		VALUES ('Club Insertado Directo');

		THROW 50001, 'ERROR DE SEGURIDAD: Se permitió INSERT directo en Administracion.Clubes.', 1;
	END TRY
	BEGIN CATCH
		IF ERROR_NUMBER() = 229
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
		BEGIN
			SET @ErrorRecibido = ERROR_MESSAGE();
			THROW 50001, @ErrorRecibido, 1;
		END
	END CATCH

	---------------------------------------------------------

	SET @NombreTesteo = '[DENEGADO] UPDATE directo en tabla de su propio esquema (Administracion.Clubes)';
	BEGIN TRY
		UPDATE Administracion.Clubes 
		SET nombre = 'Club Modificado Directo' 
		WHERE id = @clubBaseID;

		THROW 50001, 'ERROR DE SEGURIDAD: Se permitió UPDATE directo en Administracion.Clubes.', 1;
	END TRY
	BEGIN CATCH
		IF ERROR_NUMBER() = 229
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
		BEGIN
			SET @ErrorRecibido = ERROR_MESSAGE();
			THROW 50001, @ErrorRecibido, 1;
		END
	END CATCH

	---------------------------------------------------------

	SET @NombreTesteo = '[DENEGADO] DELETE directo en tabla de su propio esquema (Administracion.Clubes)';
	BEGIN TRY
		DELETE FROM Administracion.Clubes 
		WHERE id = @clubBaseID;

		THROW 50001, 'ERROR DE SEGURIDAD: Se permitió DELETE directo en Administracion.Clubes.', 1;
	END TRY
	BEGIN CATCH
		IF ERROR_NUMBER() = 229
			PRINT 'Testeo exitoso: ' + @NombreTesteo;
		ELSE
		BEGIN
			SET @ErrorRecibido = ERROR_MESSAGE();
			THROW 50001, @ErrorRecibido, 1;
		END
	END CATCH

	---------------------------------------------------------
	-- 3. RESTAURAR CONTEXTO Y REVERTIR CAMBIOS
	---------------------------------------------------------
	REVERT;
	ROLLBACK TRANSACTION;

	PRINT '====================================================';
	PRINT 'TODOS LOS TESTEOS DE [usr_administracion] PASARON OK';
	PRINT '====================================================';

END TRY
BEGIN CATCH
	IF USER_NAME() = 'usr_administracion'
		REVERT;

	IF @@TRANCOUNT > 0
		ROLLBACK TRANSACTION;

	PRINT '';
	PRINT 'Testeo fallido: ' + ISNULL(@NombreTesteo, 'Setup inicial');
	THROW;
END CATCH;
GO