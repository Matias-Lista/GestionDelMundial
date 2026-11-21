/* BBDD/Seguridad/Cifrado.sql
 * Fecha: 9/10/2026
 * Lista, Matías Josué.
 * Descripción: Este script se encarga de cifrar el campo "apellido" de la tabla arbitro, modificando todos 
 				los objetos que utilizan el campo.
 **/

USE GestionDelMundial;
GO


IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Arbitraje.Arbitros') AND name = 'apellido_cifrado')
BEGIN

	-- Agregamos un campo para los datos cifrados
	ALTER TABLE Arbitraje.Arbitros
	ADD apellido_cifrado VARBINARY(256);

END;
GO



IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Arbitraje.Arbitros') AND name = 'apellido_cifrado')
	and EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Arbitraje.Arbitros') AND name = 'apellido')
BEGIN

	DECLARE @claveDeCifrado VARCHAR(128) = 'QuieroMiPanDanes';
	
	UPDATE Arbitraje.Arbitros
	SET apellido_cifrado = EncryptByPassPhrase(@claveDeCifrado, 
							apellido, 1, CONVERT(varbinary, id));

	ALTER TABLE Arbitraje.Arbitros DROP CONSTRAINT UQ_Nombre_Apellido_Pais_Arbitro;
	ALTER TABLE Arbitraje.Arbitros DROP COLUMN apellido;

END;
GO

SELECT 
    id, nombre, apellido_cifrado,
    CONVERT(varchar(100), DecryptByPassPhrase('QuieroMiPanDanes', 
        apellido_cifrado, 1, CONVERT(varbinary, id))) AS apellido_descifrado
FROM Arbitraje.Arbitros;
