/* BBDD/SPs/Equipos.sql
 * Fecha: 9/10/2026
 * Integrantes: Lista, Matías Josué. Maldonado Medrano, Milagros.
 * Descripción: Crea todos los store procedures, funciones, y vistas del schema [Equipos].
 **/
 
USE GestionDelMundial;
GO


CREATE OR ALTER PROCEDURE Equipos.sp_crear_integrante_seleccion
	@CodigoPais CHAR(3),
	@Nombre VARCHAR(100),
	@Apellido VARCHAR(100),
	@FNacimiento DATE
AS
BEGIN

	-- País correcto, nombre y apellido no nulo, país nombre y apellido unico
	INSERT INTO Equipos.IntegranteSeleccion 
	(pais_id, nombre, apellido, f_nacimiento)
	VALUES
	(@CodigoPais, @Nombre, @Apellido, @FNacimiento);

END
GO

CREATE OR ALTER PROCEDURE Equipos.sp_modificar_integrante_seleccion
	@ID INT,
	@CodigoPais CHAR(3),
	@Nombre VARCHAR(100),
	@Apellido VARCHAR(100),
	@FNacimiento DATE
AS
BEGIN
	UPDATE Equipos.IntegranteSeleccion
		SET pais_id = @CodigoPais,
			nombre = @Nombre,
			apellido = @Apellido,
			f_nacimiento = @FNacimiento
		WHERE id = @ID;
END
GO

CREATE OR ALTER FUNCTION Equipos.fn_obtener_integrante_id (@Nombre VARCHAR(100), @Apellido VARCHAR(100), @FNacimiento DATE, @CodigoPais CHAR(3))
RETURNS INT
AS
BEGIN
	DECLARE @miembroId INT = (SELECT id
								FROM Equipos.IntegranteSeleccion
								WHERE nombre = @Nombre and apellido = @Apellido 
									  and (f_nacimiento = @FNacimiento OR (f_nacimiento is null and @FNacimiento is null) )
									  and pais_id = @CodigoPais);

	RETURN @miembroId;
END
GO

CREATE OR ALTER PROCEDURE Equipos.sp_convocar_jugador
	@AñoMundial INT,
	@CodigoPais CHAR(3),
	@Nombre VARCHAR(100),
	@Apellido VARCHAR(100),
	
	-- @Tipo VARCHAR(50),
	@FConvocacion DATE,
	@Dorsal SMALLINT,
	@ClubID INT = NULL	

AS
BEGIN 
	-- ACá hay un límite para STAFF y un límite para jugadores

	-- pseudocodigo:
	-- 1. Validar NyA, Año Mundial, País, Fechas.
	-- 2. Obtener el límite para jugadores (Regla)
	-- 3. (contar la cantidad de registros, 
	--    con ese mundial, para ese país, con el tipo jugador, sin fecha de fin)
	--	  Esto podría ser una vista o SP
	-- 4. Insertar solo sí no se superó el máximo.
	
	DECLARE @seleccionId INT = (SELECT seleccion_id FROM Mundial.Paises_Participes WHERE pais_id = @CodigoPais and mundial_id = @AñoMundial);

	DECLARE @maxConvocados INT;
	exec Administracion.sp_obtener_regla 
		 @AñoMundial = @AñoMundial, @Codigo = 'MAX_CONVOCADOS', @Valor = @maxConvocados;

	DECLARE @cantidadConvocadosActivos INT = (SELECT count(*) 
				FROM Equipos.ConvocacionEnSeleccion
				WHERE tipo = 'Jugador' AND f_fin is NULL AND seleccion_id = @seleccionId); 


	-- Obtenemos el miembro_id a partir del nombre, apellido y país
	-- TOASK: Cómo podemos manejar esto ? FIFA MEXICO 1986. Inglaterra tuvo dos Gary Stevens. Mismo país, mismo nombre y apellido
	-- https://datahub.io/football/worldcup tiene un Player ID , manager-id etc...
	-- Nos sirve para jugadores, pero no tiene un ID compartido entre player y manager.
	-- No hay casos de managers de un mismo pais con el mismo nombre que OTRO jugador.
	-- Podríamos usar el player id, y el manager identificarlo por nombre y apellido

	-- de momento para avanzar:
	DECLARE @miembroId INT = (SELECT id FROM Equipos.IntegranteSeleccion WHERE nombre = @Nombre and apellido = @Apellido and pais_id = @CodigoPais);

	if (@maxConvocados > @cantidadConvocadosActivos) BEGIN
		INSERT INTO Equipos.ConvocacionEnSeleccion
		(seleccion_id, miembro_id, tipo, f_convocacion, dorsal, club_id)
		VALUES
		(@seleccionId, @miembroId, 'Jugador', @FConvocacion, @Dorsal, @clubID);
	END
	ELSE 
	BEGIN
		print 'ERROR CONVOCADOS MAXIMO ALCANZADO' 
	END
END
GO


CREATE OR ALTER PROCEDURE Equipos.sp_convocar_staff
	@AñoMundial INT,
	@CodigoPais INT,
	@Nombre VARCHAR(100),
	@Apellido VARCHAR(100),
	@Tipo VARCHAR(50),
	@FConvocacion DATE
AS
BEGIN 
	-- ACá hay un límite para STAFF y un límite para jugadores

	-- pseudocodigo:
	-- 1. Validar NyA, Año Mundial, País, Fechas.
	-- 2. Obtener el límite para staff (Regla)
	-- 3. (contar la cantidad de registros, 
	--    con ese mundial, para ese país, con el tipo <> jugador, sin fecha de fin)
	--	  Esto podría ser una vista o SP
	-- 4. Insertar solo sí no se superó el máximo.
	
	DECLARE @seleccionId INT = (SELECT seleccion_id FROM Mundial.Paises_Participes WHERE pais_id = @CodigoPais and mundial_id = @AñoMundial);

	DECLARE @maxConvocados INT;
	exec Administracion.sp_obtener_regla 
		 @AñoMundial = @AñoMundial, @Codigo = 'MAX_CONVOCADOS_STAFF', @Valor = @maxConvocados;

	DECLARE @cantidadConvocadosActivos INT = (SELECT count(*) 
				FROM Equipos.ConvocacionEnSeleccion
				WHERE tipo <> 'Jugador' AND f_fin is NULL AND seleccion_id = @seleccionId); 

	-- de momento para avanzar:
	DECLARE @miembroId INT = (SELECT id FROM Equipos.IntegranteSeleccion WHERE nombre = @Nombre and apellido = @Apellido and pais_id = @CodigoPais);

	if (@maxConvocados > @cantidadConvocadosActivos) BEGIN
		INSERT INTO Equipos.ConvocacionEnSeleccion
		(seleccion_id, miembro_id, tipo, f_convocacion)
		VALUES
		(@seleccionId, @miembroId, @Tipo, @FConvocacion);
	END
	ELSE 
	BEGIN
		print 'ERROR CONVOCADOS STAFF MAXIMO ALCANZADO' 
	END
END
GO

CREATE OR ALTER PROCEDURE Equipos.sp_cancelar_convocacion
	@AñoMundial INT,
	@CodigoPais INT,
	@Nombre VARCHAR(100),
	@Apellido VARCHAR(100),
	@FFin DATE,
	@Motivo VARCHAR(300)
AS
BEGIN

	-- Acá se podría chequear con una regla "TIEMPO_LIMITE_RECONVOCAR"
	
	DECLARE @seleccionId INT = (SELECT seleccion_id FROM Mundial.Paises_Participes WHERE pais_id = @CodigoPais and mundial_id = @AñoMundial);

	DECLARE @miembroId INT = (SELECT id FROM Equipos.IntegranteSeleccion WHERE nombre = @Nombre and apellido = @Apellido and pais_id = @CodigoPais);

	UPDATE Equipos.ConvocacionEnSeleccion 
		SET f_fin = @FFin, motivo = @Motivo
		WHERE miembro_id = @miembroId and seleccion_id = @seleccionId;
END
GO


--TOASK: Deberíamos tener diferentes SPs para "el uso normal de la aplicación" y "el proceso de importacion" ?
--		 Porque, por ejemplo, en el dataset de partidos, te vienen todos los partidos juntos,
--       Si tengo que validar todo, (como en un uso normal), no puedo importar todos los partidos juntos. tengo que importar la info de un partido,
--		 Después, los goles, y recién ahí, puedo decir si ganó o perdió, y pasar al siguiente..
--		 Entonces, hago sps distintos? o tengo que cargar todos los datasets requeridos en tablas temporales diferentes, y gestioanr ese paso a paso?

CREATE OR ALTER FUNCTION Equipos.fn_obtener_jugadores_convocados (@SeleccionID INT)
RETURNS TABLE
AS
RETURN (
    SELECT *
    FROM Equipos.ConvocacionEnSeleccion
    WHERE seleccion_id = @SeleccionID and f_fin is null
);

GO
