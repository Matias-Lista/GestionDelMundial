/* BBDD/SPs/Eventos.sql
 * Fecha: 18/10/2026
 * Lista, Matías Josué.
 * Descripción: Contiene todos los store procedures necesarios para generar reportes.
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
CREATE OR ALTER PROCEDURE Reportes.sp_resultados_de_encuentros
	@AñoMundial INT
AS
BEGIN
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
	WHERE P.mundial_id = @AñoMundial
	order by fecha_y_hora DESC
END
GO

------Selecciones y plantillas: listado de selecciones con un vector anidado de convocados (nombre, posición, club,
-----dorsal).

CREATE OR ALTER PROCEDURE Reportes.sp_selecciones
	@AñoMundial INT
AS
BEGIN


	SELECT @AñoMundial as '@año',
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
			WHERE PP.mundial_id = @AñoMundial
			FOR XML PATH('Seleccion'), TYPE
		)
	FOR XML PATH('Mundial')

END
--- Entiendo que esta es la opción ideal para XML por la parte de "anidado"
GO


-- Ocupación publicitaria por sede y partido: anunciantes exhibidos en los cuatro espacios, e ingresos generados.
CREATE OR ALTER PROCEDURE Reportes.sp_ingresos_publicitarios
	@AñoMundial INT
AS
BEGIN
	SET NOCOUNT ON;

	-- Obtener la fecha de inicio del Mundial consultado
	DECLARE @fechaInicio DATE;
	SELECT @fechaInicio = f_inicio
	FROM Mundial.Mundiales
	WHERE año = @AñoMundial;

	IF @fechaInicio IS NULL
	BEGIN
		THROW 50001, 'No existe un mundial registrado para el año indicado.', 1;
	END

	DECLARE @fechaStr       VARCHAR(10)    = CONVERT(VARCHAR(10), @fechaInicio, 23);
	DECLARE @cotizacionARS  DECIMAL(18, 6) = NULL;
	DECLARE @tipoCotizacion VARCHAR(30)    = 'HISTORICA_INICIO_MUNDIAL';
	DECLARE @obj            INT;
	DECLARE @hr             INT;
	DECLARE @status         INT;
	DECLARE @url            NVARCHAR(300);
	DECLARE @response       NVARCHAR(MAX);
	DECLARE @errSrc         NVARCHAR(255);
	DECLARE @errDesc        NVARCHAR(255);
	DECLARE @RespTable      TABLE (respuesta NVARCHAR(MAX));

	-- Consultar cotización histórica USD -> ARS al día de inicio del Mundial
	SET @url = N'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@' + @fechaStr + N'/v1/currencies/usd.json';

	EXEC @hr = sp_OACreate 'MSXML2.ServerXMLHTTP.6.0', @obj OUT;
	IF @hr = 0
	BEGIN
		EXEC @hr = sp_OAMethod @obj, 'open', NULL, 'GET', @url, 'false';
		IF @hr = 0 EXEC @hr = sp_OAMethod @obj, 'send';
		IF @hr = 0 EXEC @hr = sp_OAGetProperty @obj, 'status', @status OUT;
		IF @hr = 0 AND @status = 200
		BEGIN
			INSERT INTO @RespTable (respuesta)
			EXEC @hr = sp_OAGetProperty @obj, 'responseText';
		END
		IF @hr <> 0
			EXEC sp_OAGetErrorInfo @obj, @errSrc OUT, @errDesc OUT;

		EXEC sp_OADestroy @obj;
	END

	SELECT TOP 1 @response = respuesta FROM @RespTable;
	IF ISJSON(@response) = 1
	BEGIN
		SET @cotizacionARS = TRY_CAST(JSON_VALUE(@response, '$.usd.ars') AS DECIMAL(18, 6));
	END

	-- Fallback a última cotización disponible si la fecha no está en el histórico de la API (ej. 2022)
	IF @cotizacionARS IS NULL
	BEGIN
		DELETE FROM @RespTable;
		SET @response       = NULL;
		SET @errDesc        = NULL;
		SET @status         = NULL;
		SET @tipoCotizacion = 'ULTIMA_DISPONIBLE';
		SET @url            = N'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json';

		EXEC @hr = sp_OACreate 'MSXML2.ServerXMLHTTP.6.0', @obj OUT;
		IF @hr = 0
		BEGIN
			EXEC @hr = sp_OAMethod @obj, 'open', NULL, 'GET', @url, 'false';
			IF @hr = 0 EXEC @hr = sp_OAMethod @obj, 'send';
			IF @hr = 0 EXEC @hr = sp_OAGetProperty @obj, 'status', @status OUT;
			IF @hr = 0 AND @status = 200
			BEGIN
				INSERT INTO @RespTable (respuesta)
				EXEC @hr = sp_OAGetProperty @obj, 'responseText';
			END
			IF @hr <> 0
				EXEC sp_OAGetErrorInfo @obj, @errSrc OUT, @errDesc OUT;

			EXEC sp_OADestroy @obj;
		END

		SELECT TOP 1 @response = respuesta FROM @RespTable;
		IF ISJSON(@response) = 1
		BEGIN
			SET @cotizacionARS = TRY_CAST(JSON_VALUE(@response, '$.usd.ars') AS DECIMAL(18, 6));
			SET @fechaStr      = ISNULL(JSON_VALUE(@response, '$.date'), @fechaStr);
		END
	END

	IF @cotizacionARS IS NULL OR @cotizacionARS <= 0
	BEGIN
		DECLARE @mensajeError NVARCHAR(500) = N'No se pudo obtener la cotización USD/ARS desde la API externa.' 
			+ ISNULL(N' Detalle: ' + @errDesc, N'');
		THROW 50001, @mensajeError, 1;
	END

	-- Generar reporte XML con costos individuales y sumados en ARS y USD
	SELECT 
		@AñoMundial     AS [@Mundial],
		@fechaStr       AS [@fecha_cotizacion],
		@tipoCotizacion AS [@tipo_cotizacion],
		@cotizacionARS  AS [@cotizacion_usd_ars],
		(
			SELECT 
				CONCAT(ISNULL(Pais_A.nombre, 'A definir'), ' vs ', ISNULL(Pais_B.nombre, 'A definir')) AS [@nombre],
				P.fase                    AS [@fase],
				S.nombre                  AS [sede/@nombre],
				S.ciudad                  AS [sede/@ciudad],
				Pais_Sede.nombre          AS [sede/@pais],
				Totales.espacios_ocupados AS [piezas/@espacios_ocupados],
				Totales.costo_total_ars   AS [piezas/@costo_total_ars],
				Totales.costo_total_usd   AS [piezas/@costo_total_usd],
				(
					SELECT 
						A.razon_social                                     AS [@anunciante],
						C.nombre                                           AS [@campaña],
						PDC.nombre                                         AS [@nombre],
						CAST(RPE.costo AS DECIMAL(12, 2))                  AS [@costo_ars],
						CAST(RPE.costo / @cotizacionARS AS DECIMAL(12, 2)) AS [@costo_usd]
					FROM Publicidad.RegistroDePiezasEmitidas RPE
					INNER JOIN Publicidad.PiezasDeContenido PDC ON PDC.id = RPE.pieza_de_contenido_id
					INNER JOIN Publicidad.Campañas C           ON C.id = PDC.campaña_id
					INNER JOIN Publicidad.Anunciantes A        ON A.id = C.anunciante_id
					WHERE RPE.partido_id = P.id
					ORDER BY RPE.id ASC
					FOR XML PATH('pieza'), TYPE
				)                         AS [piezas]
			FROM Partidos.Partidos P
			INNER JOIN Administracion.Sedes S          ON S.id = P.sede_id
			INNER JOIN Administracion.Paises Pais_Sede ON Pais_Sede.codigo = S.pais_id
			LEFT JOIN Mundial.Paises_Participes PP_A   ON PP_A.seleccion_id = P.seleccion_A_id AND PP_A.mundial_id = P.mundial_id
			LEFT JOIN Mundial.Paises_Participes PP_B   ON PP_B.seleccion_id = P.seleccion_B_id AND PP_B.mundial_id = P.mundial_id
			LEFT JOIN Administracion.Paises Pais_A     ON Pais_A.codigo = PP_A.pais_id
			LEFT JOIN Administracion.Paises Pais_B     ON Pais_B.codigo = PP_B.pais_id
			OUTER APPLY (
				SELECT 
					COUNT(*)                                                               AS espacios_ocupados,
					CAST(ISNULL(SUM(RPE_Tot.costo), 0) AS DECIMAL(12, 2))                  AS costo_total_ars,
					CAST(ISNULL(SUM(RPE_Tot.costo), 0) / @cotizacionARS AS DECIMAL(12, 2)) AS costo_total_usd
				FROM Publicidad.RegistroDePiezasEmitidas RPE_Tot
				WHERE RPE_Tot.partido_id = P.id
			) Totales
			WHERE P.mundial_id = @AñoMundial
			ORDER BY P.fecha_y_hora ASC
			FOR XML PATH('Partido'), TYPE
		)
	FOR XML PATH('OcupacionPublicitaria'), TYPE;
END
GO

-- EXEC Reportes.sp_ingresos_publicitarios @AñoMundial = 2022

GO
-- • Matriz de prime time: tabla cruzada (pivot) que muestre, para cada partido, en qué mercados/países su horario
-- cae en prime time
 
 ---- Como el exec dinamico rompe el "ownership chaining, agrego "WITH EXECUTE AS OWNER"
CREATE OR ALTER PROCEDURE Reportes.sp_matriz_prime_time
	@AñoMundial INT
WITH EXECUTE AS OWNER
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @columnas NVARCHAR(MAX);
	DECLARE @sql NVARCHAR(MAX);

	-- Obtener dinámicamente las columnas de los países/mercados del mundial
	SELECT @columnas = STRING_AGG(QUOTENAME(codigo), ', ') WITHIN GROUP (ORDER BY codigo)
	FROM (
		SELECT DISTINCT Pais.codigo
		FROM Mundial.Paises_Participes PP
		INNER JOIN Administracion.Paises Pais ON Pais.codigo = PP.pais_id
		WHERE PP.mundial_id = @AñoMundial
	) Paises;

	IF @columnas IS NULL
	BEGIN
		THROW 50001, 'No existen países partícipes registrados para el mundial indicado.', 1;
	END

	-- Armar y ejecutar la consulta cruzada (PIVOT)
	SET @sql = N'
	SELECT 
		partido_id,
		fase,
		partido,
		fecha_hora_utc0,
		' + @columnas + N'
	FROM (
		SELECT 
			P.id AS partido_id,
			P.fase,
			CONCAT(ISNULL(Pais_A.nombre, ''A definir''), '' vs '', ISNULL(Pais_B.nombre, ''A definir'')) AS partido,
			P.fecha_y_hora AS fecha_hora_utc0,
			Mercado.codigo AS pais_mercado,
			CASE 
				WHEN Mercado.zona_horaria IS NULL THEN ''Sin ZH''
				WHEN DATEPART(HOUR, CAST((P.fecha_y_hora AT TIME ZONE ''UTC'' AT TIME ZONE Mercado.zona_horaria) AS DATETIME)) BETWEEN 19 AND 23 
					THEN ''Sí''
				ELSE ''No''
			END AS es_prime_time
		FROM Partidos.Partidos P
		LEFT JOIN Mundial.Paises_Participes PP_A ON PP_A.seleccion_id = P.seleccion_A_id AND PP_A.mundial_id = P.mundial_id
		LEFT JOIN Mundial.Paises_Participes PP_B ON PP_B.seleccion_id = P.seleccion_B_id AND PP_B.mundial_id = P.mundial_id
		LEFT JOIN Administracion.Paises Pais_A   ON Pais_A.codigo = PP_A.pais_id
		LEFT JOIN Administracion.Paises Pais_B   ON Pais_B.codigo = PP_B.pais_id
		CROSS JOIN (
			SELECT DISTINCT Pais.codigo, Pais.zona_horaria
			FROM Mundial.Paises_Participes PP
			INNER JOIN Administracion.Paises Pais ON Pais.codigo = PP.pais_id
			WHERE PP.mundial_id = @AñoMundial
		) Mercado
		WHERE P.mundial_id = @AñoMundial
	) Fuente
	PIVOT (
		MAX(es_prime_time)
		FOR pais_mercado IN (' + @columnas + N')
	) Matriz
	ORDER BY fecha_hora_utc0 ASC, partido_id ASC;';

	EXEC sp_executesql 
		@stmt = @sql, 
		@params = N'@AñoMundial INT', 
		@AñoMundial = @AñoMundial;
END
GO

--EXEC Reportes.sp_matriz_prime_time @AñoMundial = 2022;

 /*
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
	@ArbitroID = 295;
GO

EXEC Reportes.sp_resultados_de_encuentros @AñoMundial = 2022
GO

EXEC Reportes.sp_selecciones @AñoMundial = 2022
GO

EXEC Reportes.sp_ingresos_publicitarios @AñoMundial = 2022
GO

EXEC Reportes.sp_matriz_prime_time @AñoMundial = 2022;
GO

*/


--- idea: cantidad de partidos perdidos por seleccion?
--- idea: top expulsiones más tempranas
--- Países que ganaron más mundiales
