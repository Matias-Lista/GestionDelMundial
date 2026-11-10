/* BBDD/SPs/Eventos.sql
 * Fecha: 18/10/2026
 * Lista, Matías Josué.
 * Descripción: 
 **/

USE GestionDelMundial;
GO
-- Goleadores por selección, fase y torneo


CREATE OR ALTER PROCEDURE Reportes.sp_goleadores_por_torneo 
	@AñoMundial INT
AS
BEGIN
	-- Goleadores por torneo
	-- Por lo que investigue, para evitar empates (para la bota de oro) se miran cosas como asistencias y minutos jugados.
	-- En este caso solo me importan los goles asique, que compartan el podio!

	SELECT J.nombre, J.apellido, J.pais_id, 
		   count(*) as goles,
		   RANK() OVER (ORDER BY count(*) DESC) as posicion
		FROM Eventos.Goles G
		INNER JOIN Partidos.Partidos P ON P.id = G.partido_id
		INNER JOIN Equipos.IntegranteSeleccion J ON J.id = G.jugador_autor_id
		WHERE P.mundial_id = @AñoMundial AND tipo <> 'E'
		GROUP BY J.nombre, J.apellido, J.pais_id
		ORDER BY goles DESC;

END
GO


CREATE OR ALTER PROCEDURE Reportes.sp_goleadores_por_fase 
	@AñoMundial INT
AS
BEGIN

	-- GOLEADORES POR FASE
	SELECT J.nombre, J.apellido, J.pais_id, P.fase,
		   count(*) as goles,
		   RANK() OVER (PARTITION BY P.fase ORDER BY count(*) DESC) as posicion
		FROM Eventos.Goles G
		INNER JOIN Partidos.Partidos P ON P.id = G.partido_id
		INNER JOIN Equipos.IntegranteSeleccion J ON J.id = G.jugador_autor_id
		WHERE P.mundial_id = @AñoMundial AND tipo <> 'E'
		GROUP BY J.nombre, J.apellido, J.pais_id, P.fase
		ORDER BY Eventos.fn_mapear_fase(P.fase), goles DESC;

END
GO


CREATE OR ALTER PROCEDURE Reportes.sp_goleadores_por_seleccion 
	@AñoMundial INT
AS
BEGIN
	
	-- GOLEADORES POR SELECCIÓN
	-- Creo que la consigna se refiere a goles por selección de un mundial específico. Pero como mi bbdd maneja varios mundiales, 
	-- voy a hacer por mundial e histórico

	-- x mundial:
	SELECT J.nombre, J.apellido, J.pais_id, ---- En vez de usar selección ID, puedo determinar una seleccion con pais y mundial.
		   count(*) as goles,
		   RANK() OVER (PARTITION BY J.pais_id ORDER BY count(*) DESC) as posicion
		FROM Eventos.Goles G
		INNER JOIN Partidos.Partidos P ON P.id = G.partido_id
		INNER JOIN Equipos.IntegranteSeleccion J ON J.id = G.jugador_autor_id
		WHERE P.mundial_id = @AñoMundial AND tipo <> 'E'
		GROUP BY J.nombre, J.apellido, J.pais_id
		ORDER BY pais_id, goles DESC;

END
GO


CREATE OR ALTER PROCEDURE Reportes.sp_goleadores_por_seleccion_historico 
	@AñoMundial INT
AS
BEGIN
	
	-- histórico

	SELECT J.nombre, J.apellido, J.pais_id, ---- En vez de usar selección ID, puedo determinar una seleccion con pais y mundial.
		   count(*) as goles,
		   RANK() OVER (PARTITION BY J.pais_id ORDER BY count(*) DESC) as posicion
		FROM Eventos.Goles G
		INNER JOIN Partidos.Partidos P ON P.id = G.partido_id
		INNER JOIN Equipos.IntegranteSeleccion J ON J.id = G.jugador_autor_id
		WHERE tipo <> 'E'
		GROUP BY J.nombre, J.apellido, J.pais_id
		ORDER BY pais_id, goles DESC;

END
GO




/******************/
/* AMONESTACIONES */
/******************/

-- Tarjetas (amarillas y rojas) por selección y jugador, 
-- con detalle de suspensiones activas por acumulación.

CREATE OR ALTER PROCEDURE Reportes.sp_jugadores_amonestados_historico 
AS
BEGIN
	-- histórico
	SELECT J.nombre, J.apellido, J.pais_id,
		SUM (CASE WHEN A.tarjeta = 'R' THEN 1 ELSE 0 END) as rojas,
		SUM (CASE WHEN A.alcanza_acumulacion_amarillas = 1 THEN 1 ELSE 0 END) as roja_por_limite_de_amarillas,
		SUM (CASE WHEN A.tarjeta = 'A' THEN 1 ELSE 0 END) as amarillas
		
		FROM Eventos.Amonestaciones A
		INNER JOIN Equipos.IntegranteSeleccion J ON J.id = A.jugador_id
		GROUP BY J.nombre, J.apellido, J.pais_id
		ORDER BY rojas DESC, roja_por_limite_de_amarillas DESC, amarillas DESC
END
GO


CREATE OR ALTER PROCEDURE Reportes.sp_jugadores_amonestados_por_mundial 
	@AñoMundial INT
AS
BEGIN

	-- por mundial
	SELECT J.nombre, J.apellido, J.pais_id,
		SUM (CASE WHEN A.tarjeta = 'R' THEN 1 ELSE 0 END) as rojas_directas,
		SUM (CASE WHEN A.alcanza_acumulacion_amarillas = 1 THEN 1 ELSE 0 END) as roja_por_limite_de_amarillas,
		SUM (CASE WHEN A.tarjeta = 'A' THEN 1 ELSE 0 END) as amarillas
		
		FROM Eventos.Amonestaciones A
		INNER JOIN Equipos.IntegranteSeleccion J ON J.id = A.jugador_id
		INNER JOIN Partidos.Partidos P ON P.id = A.partido_id
		WHERE P.mundial_id = @AñoMundial
		GROUP BY J.nombre, J.apellido, J.pais_id
		ORDER BY rojas_directas DESC, roja_por_limite_de_amarillas DESC, amarillas DESC

END
GO

--- AMONESTACIONES DE TODOS LOS JUGADORES DE UNA SELECCION EN UN MUNDIAL

CREATE OR ALTER PROCEDURE Reportes.sp_jugadores_amonestados_por_seleccion_en_un_mundial 
	@AñoMundial SMALLINT,
	@CodigoPais CHAR(3)
AS
BEGIN
	SELECT concat(J.nombre, ' ', J.apellido) as Jugador,
		SUM (CASE WHEN A.tarjeta = 'R' THEN 1 ELSE 0 END) as rojas_directas,
		SUM (CASE WHEN A.alcanza_acumulacion_amarillas = 1 THEN 1 ELSE 0 END) as roja_por_limite_de_amarillas,
		SUM (CASE WHEN A.tarjeta = 'A' THEN 1 ELSE 0 END) as amarillas
		
		FROM Eventos.Amonestaciones A
		INNER JOIN Equipos.IntegranteSeleccion J ON J.id = A.jugador_id
		INNER JOIN Partidos.Partidos P ON P.id = A.partido_id
		WHERE P.mundial_id = @AñoMundial and J.pais_id = @CodigoPais
		GROUP BY J.nombre, J.apellido, J.pais_id
		ORDER BY rojas_directas DESC, roja_por_limite_de_amarillas DESC, amarillas DESC

END
GO

/******************/
/*    ARBITRAJE   */
/******************/

-- Designaciones arbitrales: partidos dirigidos por cada árbitro, 
--                   con las amonestaciones/expulsiones que señaló.
-------- Acá considero que una amonestación la dan todos los arbitros asignados ... es decir, seas principal, 
-------- asistente, o VAR, si estuviste en un partido asignado y dieron una amarilla, cuenta como que la entregaste vos


CREATE OR ALTER PROCEDURE Reportes.sp_resumen_de_arbitro 
	@ArbitroID INT
AS
BEGIN
	SELECT A.nombre, A.apellido, A.pais_id, CONCAT(PP_A.pais_id, ' vs ',PP_B.pais_id) as partido, P.mundial_id,
		SUM (CASE WHEN AMO.tarjeta = 'R' THEN 1 ELSE 0 END) as rojas_directas,
		SUM (CASE WHEN AMO.alcanza_acumulacion_amarillas = 1 THEN 1 ELSE 0 END) as roja_por_limite_de_amarillas,
		SUM (CASE WHEN AMO.tarjeta = 'A' THEN 1 ELSE 0 END) as amarillas
		FROM Arbitraje.ArbitroAsignadoPartido AAP
		INNER JOIN Partidos.Partidos P ON P.id = AAP.partido_id
		LEFT  JOIN Eventos.Amonestaciones AMO ON AMO.partido_id = AAP.partido_id
		INNER JOIN Arbitraje.Arbitros A ON A.id = AAP.arbitro_id
		INNER JOIN Mundial.Paises_Participes PP_A ON PP_A.seleccion_id = P.seleccion_A_id
		INNER JOIN Mundial.Paises_Participes PP_B ON PP_B.seleccion_id = P.seleccion_B_id
		WHERE AAP.arbitro_id = @ArbitroID
		GROUP BY A.nombre, A.apellido, A.pais_id, P.id, AAP.partido_id, PP_A.pais_id, PP_B.pais_id, P.mundial_id
END
GO
--- Resultados de los encuentros (en la forma que vean más ilustrativa).

SELECT 
	P.mundial_id,
	 CONCAT(Pais_A.nombre, ' vs ',Pais_B.nombre) as partido,
	 (CASE 
		WHEN P.seleccion_ganadora_id is NULL THEN 'EMPATE'
		WHEN P.seleccion_ganadora_id = seleccion_A_id THEN Pais_A.nombre
		WHEN P.seleccion_ganadora_id = seleccion_B_id THEN Pais_B.nombre 
	END) as ganador,
	P.fase,
	P.fecha_y_hora,
	P.goles_A,
	P.goles_B,
	P.goles_tanda_de_penales_A,
	P.goles_tanda_de_penales_B
FROM Partidos.vw_resumen_partido P
INNER JOIN Mundial.Paises_Participes PP_A ON PP_A.seleccion_id = P.seleccion_A_id
INNER JOIN Mundial.Paises_Participes PP_B ON PP_B.seleccion_id = P.seleccion_B_id
INNER JOIN Administracion.Paises Pais_A ON Pais_A.codigo = PP_A.pais_id
INNER JOIN Administracion.Paises Pais_B ON Pais_B.codigo = PP_B.pais_id
-- INNER JOIN Administracion.Sedes S ON S.id = P.sede_id
WHERE P.mundial_id = 2002
order by fecha_y_hora DESC


------Selecciones y plantillas: listado de selecciones con un vector anidado de convocados (nombre, posición, club,
-----dorsal).

SELECT 2022 as '@año',
	(
		SELECT P.nombre as '@Pais',
			(
				SELECT C.dorsal, trim(c.tipo) as 'Tipo', I.nombre, I.apellido
					FROM Equipos.ConvocacionEnSeleccion C
					INNER JOIN Equipos.IntegranteSeleccion I ON I.id = C.miembro_id
					WHERE C.seleccion_id = PP.seleccion_id and f_fin is Null -- o sea, que no lo cambiaron
			
				FOR XML Path('Jugador'), TYPE
			) as 'Convocados'
		FROM Mundial.Selecciones S
		INNER JOIN Mundial.Paises_Participes PP ON PP.seleccion_id = S.id

		INNER JOIN Administracion.Paises P ON P.codigo = PP.pais_id
		WHERE PP.mundial_id = 2022
		FOR XML PATH('Seleccion'), TYPE
	)
FOR XML PATH('Mundial')

--- Entiendo que esta es la opción ideal para XML por la parte de "anidado"

 

EXEC Reportes.sp_goleadores_por_torneo @AñoMundial = 2022
GO

EXEC Reportes.sp_goleadores_por_fase @AñoMundial = 2022
go

EXEC Reportes.sp_goleadores_por_seleccion @AñoMundial = 2022
GO

EXEC Reportes.sp_goleadores_por_seleccion_historico @AñoMundial = 2022
GO

EXEC Reportes.sp_jugadores_amonestados_historico
GO

EXEC Reportes.sp_jugadores_amonestados_por_mundial @AñoMundial = 2022
GO

EXEC Reportes.sp_jugadores_amonestados_por_seleccion_en_un_mundial 
	@AñoMundial = 2022,
	@CodigoPais = 'ARG'
GO

EXEC Reportes.sp_resumen_de_arbitro 
	@ArbitroID = 193;
GO



--- idea: cantidad de partidos perdidos por seleccion?
--- idea: top expulsiones más tempranas
--- Países que ganaron más mundiales
