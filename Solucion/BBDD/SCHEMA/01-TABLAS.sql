/* BBDD/SCHEMA/Tablas.sql
 * Fecha: 9/10/2026
 * Integrantes: Lista, Matías Josué. Maldonado Medrano, Milagros.
 * Descripción: Contiene todos los archivos necesarios para crear la base de datos, sus schemas, sus tablas, y sus restricciones.
 **/


--TODO: Hay que poner las FKs semánticas!
--TODO: Hay que sumar la tabla de penal
--TODO: Hay que confirmar qué hacemos con los husos horarios (Me parece que lo mejor es usar una API)

--CREACION BASE DE DATOS
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'GestionDelMundial')
BEGIN
	CREATE DATABASE GestionDelMundial
	COLLATE Latin1_General_100_CI_AS_SC_UTF8;
    
    ALTER DATABASE [GestionDelMundial]
    SET MULTI_USER 
    WITH ROLLBACK IMMEDIATE;
END
GO

USE GestionDelMundial;
GO

--CREACION ESQUEMAS

IF SCHEMA_ID('Mundial') IS NULL
BEGIN
    EXEC('CREATE SCHEMA Mundial;');
END
GO

IF SCHEMA_ID('Administracion') IS NULL
BEGIN
    EXEC('CREATE SCHEMA Administracion;');
END
GO

IF SCHEMA_ID('Equipos') IS NULL
BEGIN
    EXEC('CREATE SCHEMA Equipos;');
END
GO

IF SCHEMA_ID('Eventos') IS NULL
BEGIN
    EXEC('CREATE SCHEMA Eventos;');
END
GO

IF SCHEMA_ID('Partidos') IS NULL
BEGIN
    EXEC('CREATE SCHEMA Partidos;');
END
GO

IF SCHEMA_ID('Eventos') IS NULL
BEGIN
    EXEC('CREATE SCHEMA Eventos;');
END
GO

IF SCHEMA_ID('Arbitraje') IS NULL
BEGIN
    EXEC('CREATE SCHEMA Arbitraje;');
END
GO

IF SCHEMA_ID('Publicidad') IS NULL
BEGIN
    EXEC('CREATE SCHEMA Publicidad;');
END
GO

--- TABLAS!!!!!

IF OBJECT_ID('Mundial.Mundiales', 'U') IS NULL
BEGIN
CREATE TABLE Mundial.Mundiales (
    año AS (CAST(YEAR(f_inicio) AS SMALLINT)) PERSISTED,
    f_inicio DATE UNIQUE CHECK (YEAR(f_inicio) >= 1930), -- 1930 => Primer mundial de futbol masculino
    f_fin DATE UNIQUE CHECK (YEAR(f_fin) >= 1930),
    
    CONSTRAINT CK_Mundiales_Fin_Despues_Inicio CHECK (f_fin >= f_inicio),
    CONSTRAINT PK_Un_Mundial_Por_Año PRIMARY KEY (año)
);
END

IF OBJECT_ID('Administracion.Clubes', 'U') IS NULL
BEGIN
CREATE TABLE Administracion.Clubes (
    id INT IDENTITY (1,1),
    nombre VARCHAR(100) UNIQUE NOT NULL,
    
    CONSTRAINT PK_Clubes PRIMARY KEY (id)
);
END
GO

IF OBJECT_ID('Administracion.Confederaciones', 'U') IS NULL
BEGIN
CREATE TABLE Administracion.Confederaciones (
    id INT IDENTITY (1,1),
    nombre VARCHAR(100) UNIQUE,
    siglas VARCHAR(8) UNIQUE,
    f_fundacion DATE,

    CONSTRAINT FK_Confederaciones PRIMARY KEY (id)
);
END
GO

IF OBJECT_ID('Administracion.Reglas', 'U') IS NULL
BEGIN
CREATE TABLE Administracion.Reglas (
    id INT PRIMARY KEY IDENTITY (1,1),
    mundial_id SMALLINT NOT NULL REFERENCES Mundial.Mundiales(año),
    codigo VARCHAR(100),
    valor varchar(100),

    CONSTRAINT UQ_MomentoEvento UNIQUE(mundial_id, codigo) -- Solo una valor de cada regla por mundial
);
END
GO

IF OBJECT_ID('Administracion.Idiomas', 'U') IS NULL
BEGIN
CREATE TABLE Administracion.Idiomas (
    codigo char(2) PRIMARY KEY,
    label varchar(100)
);
END
GO

IF OBJECT_ID('Administracion.Paises', 'U') IS NULL
BEGIN
CREATE TABLE Administracion.Paises (
    codigo char(3) PRIMARY KEY, -- La versión de tres letras de ISO
    confederacion_id INT REFERENCES Administracion.Confederaciones(id),
    nombre varchar(100)
    -- TODO: HAY QUE SUMAR HUSO HORARIO AL PAIS TAMBIEN. la gestion de la publicidad requiere saber el 
    -- uso horario de un país, no solo de la sede del partido
);
END
GO

IF OBJECT_ID('Administracion.Pais_Habla', 'U') IS NULL
BEGIN
CREATE TABLE Administracion.Pais_Habla (
    id        INT     PRIMARY KEY IDENTITY(1,1),
    pais_id   char(3) REFERENCES Administracion.Paises(codigo),
    idioma_id char(2) REFERENCES Administracion.Idiomas(codigo)
);
END
GO

IF OBJECT_ID('Mundial.Selecciones', 'U') IS NULL
BEGIN
CREATE TABLE Mundial.Selecciones (
    id        INT     PRIMARY KEY IDENTITY(1,1),
    pais_id   char(3) REFERENCES Administracion.Paises(codigo)
);
END
GO

IF OBJECT_ID('Mundial.Paises_Participes', 'U') IS NULL
BEGIN
CREATE TABLE Mundial.Paises_Participes (
    id             INT     PRIMARY KEY IDENTITY(1,1),
    pais_id        char(3) REFERENCES Administracion.Paises(codigo) NOT NULL,
    mundial_id     SMALLINT     REFERENCES Mundial.Mundiales(año) NOT NULL,
    seleccion_id   INT     REFERENCES Mundial.Selecciones(id), -- No pongo not null acá para poder asociar un pais al mundial sin haber creado la seleccion aun
    esta_eliminado BIT DEFAULT 0,
    grupo          char(1) CHECK (grupo LIKE '[A-Z]')
);
END
GO

IF OBJECT_ID('Arbitraje.Arbitros', 'U') IS NULL
BEGIN
CREATE TABLE Arbitraje.Arbitros (
    id             INT          PRIMARY KEY IDENTITY(1,1),
    pais_id        char(3)      REFERENCES Administracion.Paises(codigo) NOT NULL,
    nombre         VARCHAR(100),
    apellido       VARCHAR(100)
);
END
GO

IF OBJECT_ID('Arbitraje.Arbitro_Habla', 'U') IS NULL
BEGIN
CREATE TABLE Arbitraje.Arbitro_Habla (
    id         INT     PRIMARY KEY IDENTITY(1,1),
    idioma_id  char(2) REFERENCES Administracion.Idiomas(codigo) NOT NULL,
    arbitro_id INT     REFERENCES Arbitraje.Arbitros(id) NOT NULL
);
END
GO

IF OBJECT_ID('Mundial.Habilitacion_Arbitro', 'U') IS NULL
BEGIN
CREATE TABLE Mundial.Habilitacion_Arbitro (
    id               INT PRIMARY KEY IDENTITY(1,1),
    mundial_id       SMALLINT REFERENCES Mundial.Mundiales(año) NOT NULL,
    arbitro_id       INT REFERENCES Arbitraje.Arbitros(id) NOT NULL,
    confederacion_id INT REFERENCES Administracion.Confederaciones(id) NOT NULL
);
END
GO

IF OBJECT_ID('Administracion.Sedes', 'U') IS NULL
BEGIN
CREATE TABLE Administracion.Sedes (
    id           INT           PRIMARY KEY IDENTITY(1,1),
    pais_id      char(3)       REFERENCES Administracion.Paises(codigo) NOT NULL,
    nombre       VARCHAR(100)  UNIQUE NOT NULL,
    ciudad       VARCHAR(100)  NOT NULL,
    capacidad    INT           CHECK (capacidad > 0) NOT NULL,
    huso_horario SMALLINT      CHECK (huso_horario BETWEEN -12 and 12) NOT NULL
);
END
GO

IF OBJECT_ID('Equipos.IntegranteSeleccion', 'U') IS NULL
BEGIN
CREATE TABLE Equipos.IntegranteSeleccion (
    id       INT           PRIMARY KEY IDENTITY(1,1),
    pais_id  char(3)       REFERENCES Administracion.Paises(codigo) NOT NULL,
    nombre   VARCHAR(100)  NOT NULL,
    apellido VARCHAR(100)  NOT NULL,
    f_nacimiento DATE, -- Para diferenciar jugadores con el mismo nombre y país.
    
    CONSTRAINT CK_Pais_NyA_Nacimiento_Unico UNIQUE (pais_id, nombre, apellido, f_nacimiento)
);
END
GO

IF OBJECT_ID('Equipos.ConvocacionEnSeleccion', 'U') IS NULL
BEGIN
CREATE TABLE Equipos.ConvocacionEnSeleccion (
    id       INT           PRIMARY KEY IDENTITY(1,1),
    seleccion_id  INT       REFERENCES Mundial.Selecciones(id) NOT NULL,
    miembro_id  INT       REFERENCES Equipos.IntegranteSeleccion(id) NOT NULL,
    tipo CHAR(10) CHECK (tipo in ('DT', 'Asistente', 'Jugador')) NOT NULL,
    f_convocacion DATE NOT NULL,
    f_fin DATE,
    motivo VARCHAR(200),
    dorsal tinyint CHECK (dorsal between 0 and 26), -- TODO: Vi que el 26 es el máximo, no sé si siempre fue así, sino, sería una REGLA gestionada en su store procedure.
    club_id INT REFERENCES Administracion.Clubes(id),
    
    CONSTRAINT CK_Convocaciones_Fin_Despues_Inicio CHECK (f_fin >= f_convocacion),
    CONSTRAINT CK_Solo_Jugadores_Tienen_Dorsal CHECK ((tipo = 'Jugador' and dorsal is not NULL) or (tipo <> 'Jugador' and dorsal is NULL))
);
END
GO


IF OBJECT_ID('Partidos.Partidos', 'U') IS NULL
BEGIN
CREATE TABLE Partidos.Partidos (
    id       INT              PRIMARY KEY IDENTITY(1,1),
    seleccion_A_id INT        REFERENCES Mundial.Selecciones(id) NOT NULL,
    seleccion_B_id INT        REFERENCES Mundial.Selecciones(id) NOT NULL,
    seleccion_ganadora_id INT       REFERENCES Mundial.Selecciones(id),
    mundial_id SMALLINT        REFERENCES Mundial.Mundiales(año) NOT NULL,
    sede_id INT        REFERENCES Administracion.Sedes(id) NOT NULL,
    fecha_y_hora DATETIME NOT NULL, --TODO: Podemos guardar "fecha_y_hora" en utc 0 y usar AT TIME ZONE para mostrar el horario q queramos
    fase VARCHAR(15) CHECK (fase in ('GRUPOS', 'DIECISEISAVOS', 'OCTAVOS', 'CUARTOS', 'SEMIFINAL', 'TERCER_PUESTO', 'FINAL')) NOT NULL,
    siguiente_partid_id INT REFERENCES Partidos.Partidos(id),
    tiempo_adicional_1 SMALLINT,
    tiempo_adicional_2 SMALLINT,
    tiempo_adicional_3 SMALLINT,
    tiempo_adicional_4 SMALLINT,
    hubo_tiempo_suplementario BIT,
    -- TODO: EN vez de usar una tabla "Penales" que nos diga si hubieron penales, o un flag "hubieron penales",
    -- Podemos simplemente consultar "Penal_pateado" con el id de partido. Si es null, no habian, no si no es null, habian penales.

    CONSTRAINT CK_Selecciones_Enfrentadas_Distintas CHECK (seleccion_A_id <> seleccion_B_id),
    CONSTRAINT CK_Seleccion_Ganadora_Jugo_El_Partido CHECK (seleccion_ganadora_id in (seleccion_A_id, seleccion_B_id))
);
END
GO

IF OBJECT_ID('Arbitraje.ArbitroAsignadoPartido', 'U') IS NULL
BEGIN
CREATE TABLE Arbitraje.ArbitroAsignadoPartido (
    id         INT              PRIMARY KEY IDENTITY(1,1),
    arbitro_id INT        REFERENCES Arbitraje.Arbitros(id) NOT NULL,
    partido_id INT REFERENCES Partidos.Partidos(id) NOT NULL,
    rol CHAR(50) CHECK (rol in ('PRINCIPAL', 'ASISTENTE', 'CUARTO', 'VAR')) NOT NULL --TODO: ver nombres correctos
);
END
GO


IF OBJECT_ID('Arbitraje.InformesArbitros', 'U') IS NULL
BEGIN
CREATE TABLE Arbitraje.InformesArbitros (
    id         INT              PRIMARY KEY IDENTITY(1,1),
    arbitro_id INT        REFERENCES Arbitraje.Arbitros(id) NOT NULL,
    partido_id INT REFERENCES Partidos.Partidos(id),
    f_reporte  DATE NOT NULL,
    motivo VARCHAR(250) NOT NULL
);
END
GO


IF OBJECT_ID('Partidos.JugadorPosicionInicial', 'U') IS NULL
BEGIN
CREATE TABLE Partidos.JugadorPosicionInicial (
    id         INT PRIMARY KEY IDENTITY(1,1),
    comienza_jugando BIT NOT NULL,
    --posicion SMALLINT NOT NULL, -- TODO: Poner un check con los numeros validos, o poner texto como posicion
    posicion CHAR(2) NOT NULL, 
    partido_id INT REFERENCES Partidos.Partidos(id) NOT NULL,
    jugador_id INT REFERENCES Equipos.IntegranteSeleccion(id) NOT NULL,
    seleccion_id INT REFERENCES Mundial.Selecciones(id) NOT NULL
);
END
GO


IF OBJECT_ID('Eventos.Impedimentos', 'U') IS NULL
BEGIN
CREATE TABLE Eventos.Impedimentos (
    id         INT PRIMARY KEY IDENTITY(1,1),
    jugador_id INT REFERENCES Equipos.IntegranteSeleccion(id) NOT NULL,
    partidos_restantes SMALLINT CHECK (partidos_restantes >= 0) NOT NULL
);
END
GO



IF OBJECT_ID('Eventos.MomentoEvento', 'U') IS NULL
BEGIN
CREATE TABLE Eventos.MomentoEvento (
    id         INT PRIMARY KEY IDENTITY(1,1),
    minuto SMALLINT CHECK (minuto >= 0) NOT NULL,
    tiempo char(1) CHECK (tiempo in ('1', '2', '3', '4')) NOT NULL,
    
    CONSTRAINT UQ_MomentoEvento UNIQUE(minuto, tiempo)
);
END
GO

IF OBJECT_ID('Eventos.Amonestaciones', 'U') IS NULL
BEGIN
CREATE TABLE Eventos.Amonestaciones (
    id         INT PRIMARY KEY IDENTITY(1,1),
    partido_id INT REFERENCES Partidos.Partidos(id) NOT NULL,
    jugador_id INT REFERENCES Equipos.IntegranteSeleccion(id) NOT NULL,
    momento_id INT REFERENCES Eventos.MomentoEvento(id) NOT NULL
);

END
GO

IF OBJECT_ID('Eventos.Cambios', 'U') IS NULL
BEGIN
CREATE TABLE Eventos.Cambios (
    id         INT PRIMARY KEY IDENTITY(1,1),
    partido_id INT REFERENCES Partidos.Partidos(id) NOT NULL,
    jugador_entra_id INT REFERENCES Equipos.IntegranteSeleccion(id) NOT NULL,
    jugador_sale_id INT REFERENCES Equipos.IntegranteSeleccion(id) NOT NULL,
    momento_id INT REFERENCES Eventos.MomentoEvento(id) NOT NULL
);
END
GO

IF OBJECT_ID('Eventos.Goles', 'U') IS NULL
BEGIN
CREATE TABLE Eventos.Goles (
    id         INT PRIMARY KEY IDENTITY(1,1),
    partido_id INT REFERENCES Partidos.Partidos(id) NOT NULL,
    jugador_autor_id INT REFERENCES Equipos.IntegranteSeleccion(id) NOT NULL,
    jugador_asistente_id INT REFERENCES Equipos.IntegranteSeleccion(id),
    momento_id INT REFERENCES Eventos.MomentoEvento(id) NOT NULL,
    tipo CHAR(1) CHECK(tipo in ('T', 'N', 'C', 'P', 'E')) NOT NULL -- Tiro libre, normal, cabeza, Penal (por falta en el area), En Contra
);
END
GO

-- TODO: La parte de penales no la entendí

IF OBJECT_ID('Publicidad.Anunciantes', 'U') IS NULL
BEGIN
CREATE TABLE Publicidad.Anunciantes (
    id         INT PRIMARY KEY IDENTITY(1,1),
    razon_social VARCHAR(150) UNIQUE NOT NULL
);
END
GO

IF OBJECT_ID('Publicidad.Campañas', 'U') IS NULL
BEGIN
CREATE TABLE Publicidad.Campañas (
    id         INT PRIMARY KEY IDENTITY(1,1),
    anunciante_id INT REFERENCES Publicidad.Anunciantes(id) NOT NULL,
    mundial_id SMALLINT REFERENCES Mundial.Mundiales(año) NOT NULL,
    nombre VARCHAR(150) NOT NULL UNIQUE,
    descripcion VARCHAR(300),
    horario_minimo SMALLINT check(horario_minimo between 0 AND 24),
    horario_maximo SMALLINT check(horario_maximo between 0 AND 24)
);
END
GO

IF OBJECT_ID('Publicidad.PiezasDeContenido', 'U') IS NULL
BEGIN
CREATE TABLE Publicidad.PiezasDeContenido (
    id         INT PRIMARY KEY IDENTITY(1,1),
    campaña_id INT REFERENCES Publicidad.Campañas(id) NOT NULL,
    descripcion VARCHAR(300)
);
END
GO

IF OBJECT_ID('Publicidad.PaisesInteresados', 'U') IS NULL
BEGIN
CREATE TABLE Publicidad.PaisesInteresados (
    id         INT PRIMARY KEY IDENTITY(1,1),
    pieza_de_contenido_id INT REFERENCES Publicidad.PiezasDeContenido(id) NOT NULL,
    pais_id CHAR(3) REFERENCES Administracion.Paises(codigo) NOT NULL
);
END
GO


IF OBJECT_ID('Publicidad.Tarifa', 'U') IS NULL
BEGIN
CREATE TABLE Publicidad.Tarifa (
    id         INT PRIMARY KEY IDENTITY(1,1),
    franja CHAR(1) CHECK (franja in ('P', 'N')) NOT NULL, -- Primer Time, Normal
    fase CHAR(25) CHECK (fase in ('GRUPOS', 'DIECISEISAVOS', 'OCTAVOS', 'CUARTOS', 'SEMIFINAL', 'TERCER_PUESTO', 'FINAL')) NOT NULL,
    costo DECIMAL(10,2) NOT NULL,
    mundial_id SMALLINT  REFERENCES Mundial.Mundiales(año) NOT NULL,

    CONSTRAINT UQ_Tarifa_Unica_Para_Cada_Franja_Y_Fase_En_un_Mundial UNIQUE(franja, fase, mundial_id)
);
END
GO

IF OBJECT_ID('Publicidad.RegistroDePiezasEmitidas', 'U') IS NULL
BEGIN
CREATE TABLE Publicidad.RegistroDePiezasEmitidas (
    id         INT PRIMARY KEY IDENTITY(1,1),
    pieza_de_contenido_id INT REFERENCES Publicidad.PiezasDeContenido(id) NOT NULL,
    descripcion VARCHAR(200), 
    costo DECIMAL(10,2) NOT NULL,
    partido_id INT REFERENCES Partidos.Partidos(id) NOT NULL

);
END
GO


