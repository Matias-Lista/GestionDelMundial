/* BBDD/SCHEMA/Tablas.sql
 * Fecha: 24/10/2026
 * Lista, Matías Josué.
 * Descripción: Contiene todos los archivos necesarios para crear la base de datos, sus schemas, sus tablas, y sus restricciones.
 **/

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

IF SCHEMA_ID('Importacion') IS NULL
BEGIN
    EXEC('CREATE SCHEMA Importacion;');
END
GO

--- TABLAS!!!!!

IF OBJECT_ID('Mundial.Mundiales', 'U') IS NULL
BEGIN
CREATE TABLE Mundial.Mundiales (
    año AS (CAST(YEAR(f_inicio) AS SMALLINT)) PERSISTED,
    f_inicio DATE UNIQUE CHECK (YEAR(f_inicio) >= 1930), -- 1930 => Primer mundial de futbol masculino
    f_fin    DATE UNIQUE CHECK (YEAR(f_fin) >= 1930),
    
    CONSTRAINT CK_Mundiales_Fin_Despues_Inicio CHECK (f_fin >= f_inicio),
    CONSTRAINT PK_Un_Mundial_Por_Año PRIMARY KEY (año)
);
END

IF OBJECT_ID('Administracion.Clubes', 'U') IS NULL
BEGIN
CREATE TABLE Administracion.Clubes (
    id     INT          IDENTITY (1,1),
    nombre VARCHAR(100) UNIQUE NOT NULL,
    
    CONSTRAINT PK_Clubes PRIMARY KEY (id)
);
END
GO

IF OBJECT_ID('Administracion.Confederaciones', 'U') IS NULL
BEGIN
CREATE TABLE Administracion.Confederaciones (
    id          INT          IDENTITY (1,1),
    nombre      VARCHAR(100) UNIQUE,
    siglas      VARCHAR(8)   UNIQUE,
    f_fundacion DATE,

    CONSTRAINT PK_Confederaciones PRIMARY KEY (id)
);
END
GO

IF OBJECT_ID('Administracion.Reglas', 'U') IS NULL
BEGIN
CREATE TABLE Administracion.Reglas (
    id         INT           IDENTITY (1,1),
    mundial_id SMALLINT      NOT NULL,
    codigo     VARCHAR(100),
    valor      VARCHAR(100),

    CONSTRAINT PK_Reglas PRIMARY KEY (id),
    CONSTRAINT FK_Reglas_Mundial FOREIGN KEY (mundial_id) REFERENCES Mundial.Mundiales(año),
    CONSTRAINT UQ_Un_Valor_Por_regla_Por_Mundial UNIQUE(mundial_id, codigo) -- Solo una valor de cada regla por mundial
);
END
GO

IF OBJECT_ID('Administracion.Idiomas', 'U') IS NULL
BEGIN
CREATE TABLE Administracion.Idiomas (
    codigo CHAR(2),
    label  VARCHAR(100),

    CONSTRAINT PK_Idiomas PRIMARY KEY (codigo),
    CONSTRAINT UQ_Label_Idioma UNIQUE(label),
    CONSTRAINT CK_Codigo_Idioma_ISO CHECK(codigo LIKE '[A-Z][A-Z]')
);
END
GO

IF OBJECT_ID('Administracion.Paises', 'U') IS NULL
BEGIN
CREATE TABLE Administracion.Paises (
    codigo           CHAR(3)      ,
    confederacion_id INT          ,
    nombre           VARCHAR(100) NOT NULL UNIQUE,

    CONSTRAINT PK_Paises             PRIMARY KEY (codigo),
    CONSTRAINT FK_Pais_Confederacion FOREIGN KEY (confederacion_id) REFERENCES Administracion.Confederaciones(id),
    CONSTRAINT CK_Codigo_Pais_ISO    CHECK(codigo LIKE '[A-Z][A-Z][A-Z]')

    -- TODO: HAY QUE SUMAR HUSO HORARIO AL PAIS TAMBIEN. la gestion de la publicidad requiere saber el 
    -- uso horario de un país, no solo de la sede del partido
);
END
GO

IF OBJECT_ID('Administracion.Pais_Habla', 'U') IS NULL
BEGIN
CREATE TABLE Administracion.Pais_Habla (
    id        INT     IDENTITY(1,1),
    pais_id   CHAR(3),
    idioma_id CHAR(2),

    CONSTRAINT PK_Pais_Habla         PRIMARY KEY (id),
    CONSTRAINT FK_Pais_Habla_Pais    FOREIGN KEY (pais_id) REFERENCES Administracion.Paises(codigo),
    CONSTRAINT FK_Pais_Habla_Idioma  FOREIGN KEY (idioma_id) REFERENCES Administracion.Idiomas(codigo)
);
END
GO

IF OBJECT_ID('Mundial.Selecciones', 'U') IS NULL
BEGIN
CREATE TABLE Mundial.Selecciones (
    id      INT      IDENTITY(1,1),
    pais_id CHAR(3),

    CONSTRAINT PK_Selecciones      PRIMARY KEY (id),
    CONSTRAINT FK_Selecciones_Pais FOREIGN KEY (pais_id) REFERENCES Administracion.Paises(codigo)
);
END
GO

-- TODO: añadir Foreign Key
IF OBJECT_ID('Mundial.Paises_Participes', 'U') IS NULL
BEGIN
CREATE TABLE Mundial.Paises_Participes (
    id             INT      IDENTITY(1,1),
    pais_id        CHAR(3)  NOT NULL,
    mundial_id     SMALLINT NOT NULL,
    seleccion_id   INT      , -- No pongo not null acá para poder asociar un pais al mundial sin haber creado la seleccion aun
    esta_eliminado BIT      DEFAULT 0,
    grupo          CHAR(1)  ,

    CONSTRAINT PK_Paises_Participes                   PRIMARY KEY (id),
    CONSTRAINT FK_Paises_Participes_Pais              FOREIGN KEY (pais_id)      REFERENCES Administracion.Paises(codigo),
    CONSTRAINT FK_Paises_Participes_Mundial           FOREIGN KEY (mundial_id)   REFERENCES Mundial.Mundiales(año),
    CONSTRAINT FK_Paises_Participes_Seleccion         FOREIGN KEY (seleccion_id) REFERENCES Mundial.Selecciones(id),
    CONSTRAINT CK_Paises_Participes_Grupo_Solo_Letras CHECK (grupo LIKE '[A-Z]')
);
END
GO

IF OBJECT_ID('Arbitraje.Arbitros', 'U') IS NULL
BEGIN
CREATE TABLE Arbitraje.Arbitros (
    id               INT          IDENTITY(1,1),
    pais_id          CHAR(3)      NOT NULL,
    nombre           VARCHAR(100) NOT NULL,
    apellido         VARCHAR(100) NOT NULL,
    es_mujer         BIT,
    confederacion_id INT,

    CONSTRAINT PK_Arbitros PRIMARY KEY (id),
    CONSTRAINT FK_Arbitros_Pais FOREIGN KEY (pais_id)      REFERENCES Administracion.Paises(codigo),
    CONSTRAINT FK_Arbitros_Confederacion FOREIGN KEY (confederacion_id)       REFERENCES Administracion.Confederaciones(id),
    CONSTRAINT UQ_Nombre_Apellido_Pais_Arbitro UNIQUE (pais_id, nombre, apellido)
);
END
GO

IF OBJECT_ID('Arbitraje.Arbitro_Habla', 'U') IS NULL
BEGIN
CREATE TABLE Arbitraje.Arbitro_Habla (
    id         INT     IDENTITY(1,1),
    idioma_id  CHAR(2) NOT NULL,
    arbitro_id INT     NOT NULL,

    CONSTRAINT PK_Arbitro_Habla         PRIMARY KEY (id),
    CONSTRAINT FK_Arbitro_Habla_Idioma  FOREIGN KEY (idioma_id)  REFERENCES Administracion.Idiomas(codigo),
    CONSTRAINT FK_Arbitro_Habla_Arbitro FOREIGN KEY (arbitro_id) REFERENCES Arbitraje.Arbitros(id)
);
END
GO

IF OBJECT_ID('Mundial.Habilitacion_Arbitro', 'U') IS NULL
BEGIN
CREATE TABLE Mundial.Habilitacion_Arbitro (
    id         INT      IDENTITY(1,1),
    mundial_id SMALLINT NOT NULL,
    arbitro_id INT      NOT NULL,
    
    CONSTRAINT PK_Habilitacion_Arbitro                 PRIMARY KEY (id),
    CONSTRAINT FK_Habilitacion_Arbitro_Arbitro         FOREIGN KEY (arbitro_id) REFERENCES Arbitraje.Arbitros(id),
    CONSTRAINT FK_Habilitacion_Arbitro_Mundial         FOREIGN KEY (mundial_id) REFERENCES Mundial.Mundiales(año),
    CONSTRAINT UQ_Una_Asignacion_Por_Arbitro_y_Mundial UNIQUE(mundial_id, arbitro_id)
);
END
GO

IF OBJECT_ID('Administracion.Sedes', 'U') IS NULL
BEGIN
CREATE TABLE Administracion.Sedes (
    id        INT           IDENTITY(1,1),
    pais_id   char(3)       NOT NULL,
    nombre    VARCHAR(100)  NOT NULL,
    ciudad    VARCHAR(100)  NOT NULL,
    capacidad INT           CHECK (capacidad > 0) NOT NULL,

    CONSTRAINT PK_Sedes                           PRIMARY KEY (id),
    CONSTRAINT FK_Sedes_Pais                      FOREIGN KEY (pais_id) REFERENCES Administracion.Paises(codigo),
	CONSTRAINT UQ_Pais_Nombre_Ciudad_Irrepetibles UNIQUE (pais_id, nombre, ciudad, capacidad)
);
END
GO

IF OBJECT_ID('Equipos.IntegranteSeleccion', 'U') IS NULL
BEGIN
CREATE TABLE Equipos.IntegranteSeleccion (
    id           INT           IDENTITY(1,1),
    pais_id      char(3)       NOT NULL,
    nombre       VARCHAR(100)  NOT NULL,
    apellido     VARCHAR(100)  NOT NULL,
    f_nacimiento DATE, -- Para diferenciar jugadores con el mismo nombre y país.
    
    CONSTRAINT PK_Integrante_Seleccion      PRIMARY KEY (id),
    CONSTRAINT FK_Integrante_Seleccion_Pais FOREIGN KEY (pais_id) REFERENCES Administracion.Paises(codigo),
    CONSTRAINT CK_Pais_NyA_Nacimiento_Unico UNIQUE (pais_id, nombre, apellido, f_nacimiento)
);
END
GO

IF OBJECT_ID('Equipos.ConvocacionEnSeleccion', 'U') IS NULL
BEGIN
CREATE TABLE Equipos.ConvocacionEnSeleccion (
    id            INT           IDENTITY(1,1),
    seleccion_id  INT           NOT NULL,
    miembro_id    INT           NOT NULL,
    tipo          CHAR(10)      CHECK (tipo in ('DT', 'Asistente', 'Jugador')) NOT NULL,
    f_convocacion DATE          NOT NULL,
    f_fin         DATE,
    motivo        VARCHAR(200),
    dorsal        TINYINT       CHECK (dorsal between 1 and 26), -- TODO: Vi que el 26 es el máximo, no sé si siempre fue así, sino, sería una REGLA gestionada en su store procedure.
    club_id       INT,
    
    CONSTRAINT PK_Convocacion_En_Seleccion           PRIMARY KEY (id),

    CONSTRAINT FK_Convocacion_En_Seleccion_Seleccion FOREIGN KEY (seleccion_id) REFERENCES Mundial.Selecciones(id),
    CONSTRAINT FK_Convocacion_En_Seleccion_Miembro   FOREIGN KEY (miembro_id)   REFERENCES Equipos.IntegranteSeleccion(id),
    CONSTRAINT FK_Convocacion_En_Seleccion_Club      FOREIGN KEY (club_id)      REFERENCES Administracion.Clubes(id),

    CONSTRAINT CK_Convocaciones_Fin_Despues_Inicio   CHECK (f_fin >= f_convocacion),
    CONSTRAINT CK_Solo_Jugadores_Tienen_Dorsal       CHECK ((tipo = 'Jugador' and dorsal is not NULL) or (tipo <> 'Jugador' and dorsal is NULL))
);
END
GO


IF OBJECT_ID('Partidos.Partidos', 'U') IS NULL
BEGIN
CREATE TABLE Partidos.Partidos (
    id                        INT         IDENTITY(1,1),
    seleccion_A_id            INT,
    seleccion_B_id            INT,
    seleccion_ganadora_id     INT,
    mundial_id                SMALLINT    NOT NULL,
    sede_id                   INT         NOT NULL,
    fecha_y_hora              DATETIME    NOT NULL, --TODO: Podemos guardar "fecha_y_hora" en utc 0 y usar AT TIME ZONE para mostrar el horario q queramos
    fase                      VARCHAR(15) CHECK (fase in ('GRUPOS', 'DIECISEISAVOS', 'OCTAVOS', 'CUARTOS', 'SEMIFINAL', 'TERCER_PUESTO', 'FINAL')) NOT NULL,
    siguiente_partido_id      INT,
    tiempo_adicional_1        TINYINT,
    tiempo_adicional_2        TINYINT,
    tiempo_adicional_3        TINYINT,
    tiempo_adicional_4        TINYINT,
    hubo_tiempo_suplementario BIT,

    CONSTRAINT PK_Partidos                    PRIMARY KEY (id),

    CONSTRAINT FK_Partidos_Seleccion_A        FOREIGN KEY (seleccion_A_id)        REFERENCES Mundial.Selecciones(id),
    CONSTRAINT FK_Partidos_Seleccion_B        FOREIGN KEY (seleccion_B_id)        REFERENCES Mundial.Selecciones(id),
    CONSTRAINT FK_Partidos_Seleccion_Ganadora FOREIGN KEY (seleccion_ganadora_id) REFERENCES Mundial.Selecciones(id),
    CONSTRAINT FK_Partidos_Mundial            FOREIGN KEY (mundial_id)            REFERENCES Mundial.Mundiales(año),
    CONSTRAINT FK_Partidos_Sedes              FOREIGN KEY (sede_id)               REFERENCES Administracion.Sedes(id),
    CONSTRAINT FK_Partidos_Siguiente_Partido  FOREIGN KEY (siguiente_partido_id)  REFERENCES Partidos.Partidos(id),


    CONSTRAINT CK_Selecciones_Enfrentadas_Distintas CHECK (seleccion_A_id <> seleccion_B_id),
    CONSTRAINT CK_Seleccion_Ganadora_Jugo_El_Partido CHECK (seleccion_ganadora_id in (seleccion_A_id, seleccion_B_id))
);
END
GO

IF OBJECT_ID('Arbitraje.ArbitroAsignadoPartido', 'U') IS NULL
BEGIN
CREATE TABLE Arbitraje.ArbitroAsignadoPartido (
    id         INT      IDENTITY(1,1),
    arbitro_id INT      NOT NULL,
    partido_id INT      NOT NULL,
    rol        CHAR(50) CHECK (rol in ('PRINCIPAL', 'ASISTENTE1', 'ASISTENTE2', 'CUARTO', 'VAR')) NOT NULL,

    CONSTRAINT PK_ArbitroAsignadoPartido             PRIMARY KEY (id),

    CONSTRAINT FK_ArbitroAsignadoPartido_Partido     FOREIGN KEY (partido_id) REFERENCES Partidos.Partidos(id),
    CONSTRAINT FK_ArbitroAsignadoPartido_Arbitro     FOREIGN KEY (arbitro_id) REFERENCES Arbitraje.Arbitros(id),

    CONSTRAINT UQ_Arbitro_Y_Partido_Unicos           UNIQUE (arbitro_id, partido_id),
    CONSTRAINT UQ_Un_Arbitro_Por_Rol_En_Cada_Partido UNIQUE (partido_id, rol)
);
END
GO

IF OBJECT_ID('Arbitraje.InformesArbitros', 'U') IS NULL
BEGIN
CREATE TABLE Arbitraje.InformesArbitros (
    id         INT          IDENTITY(1,1),
    arbitro_id INT          NOT NULL,
    partido_id INT,
    f_reporte  DATE         NOT NULL,
    motivo     VARCHAR(250) NOT NULL

    CONSTRAINT PK_InformesArbitros         PRIMARY KEY (id),
    CONSTRAINT FK_InformesArbitros_Partido FOREIGN KEY (partido_id) REFERENCES Partidos.Partidos(id),
    CONSTRAINT FK_InformesArbitros_Arbitro FOREIGN KEY (arbitro_id) REFERENCES Arbitraje.Arbitros(id)
);
END
GO


IF OBJECT_ID('Partidos.JugadorPosicionInicial', 'U') IS NULL
BEGIN
CREATE TABLE Partidos.JugadorPosicionInicial (
    id               INT     IDENTITY(1,1),
    comienza_jugando BIT     NOT NULL,
    posicion         CHAR(2) NOT NULL,  -- TODO: Check con las posiciones válidas (extraídas del dataset de datahub)
    partido_id       INT     NOT NULL,
    jugador_id       INT     NOT NULL,
    seleccion_id     INT     NOT NULL,

    CONSTRAINT PK_JugadorPosicionInicial           PRIMARY KEY (id),

    CONSTRAINT FK_Jugador_Posicion_Inicial_Partido   FOREIGN KEY (partido_id)   REFERENCES Partidos.Partidos(id),
    CONSTRAINT FK_Jugador_Posicion_Inicial_Jugador   FOREIGN KEY (jugador_id)   REFERENCES Equipos.IntegranteSeleccion(id),
    CONSTRAINT FK_Jugador_Posicion_Inicial_Seleccion FOREIGN KEY (seleccion_id) REFERENCES Mundial.Selecciones(id)
);
END
GO


IF OBJECT_ID('Eventos.Impedimentos', 'U') IS NULL
BEGIN
CREATE TABLE Eventos.Impedimentos (
    id                   INT      IDENTITY(1,1),
    jugador_id           INT      NOT NULL,
    partido_origen_id    INT      NOT NULL,
    cantidad_de_partidos TINYINT  CHECK (cantidad_de_partidos > 0) NOT NULL,
    cantidad_restante    TINYINT ,

    CONSTRAINT PK_Impedimentos           PRIMARY KEY (id),

    CONSTRAINT FK_Impedimentos_Jugador   FOREIGN KEY (jugador_id)        REFERENCES Equipos.IntegranteSeleccion(id),
    CONSTRAINT FK_Impedimentos_Partido   FOREIGN KEY (partido_origen_id) REFERENCES Partidos.Partidos(id)
);
END
GO

IF OBJECT_ID('Eventos.Amonestaciones', 'U') IS NULL
BEGIN
CREATE TABLE Eventos.Amonestaciones (
    id                            INT          IDENTITY(1,1),
    partido_id                    INT          NOT NULL,
    jugador_id                    INT          NOT NULL,
    tarjeta                       CHAR(1)      CHECK (tarjeta IN ('A', 'R')) NOT NULL, -- Amarilla, Roja
    
    alcanza_acumulacion_amarillas BIT          DEFAULT 0, -- Doble Amarilla (o la cantidad parametrizada)
    
    motivo                        VARCHAR(200) ,

    minuto                        SMALLINT     NOT NULL CHECK (minuto between 0 and 45),
    extra                         SMALLINT     NOT NULL DEFAULT 0,
    tiempo                        SMALLINT     NOT NULL CHECK (tiempo between 1 and 4),
    
    CONSTRAINT PK_Amonestaciones           PRIMARY KEY (id),

    CONSTRAINT FK_Amonestaciones_Partido   FOREIGN KEY (partido_id) REFERENCES Partidos.Partidos(id),
    CONSTRAINT FK_Amonestaciones_Jugador   FOREIGN KEY (jugador_id)        REFERENCES Equipos.IntegranteSeleccion(id)
    -- TODO: Se puede sumar chequeos como si minuto != maximo => extra = 0. (tiempo 1 y 2 max 45, 3 y 4 max 15)
);
END
GO

IF OBJECT_ID('Eventos.Cambios', 'U') IS NULL
BEGIN
CREATE TABLE Eventos.Cambios (
    id                 INT         IDENTITY(1,1),
    partido_id         INT         NOT NULL,
    jugador_entra_id   INT ,
    jugador_sale_id    INT ,
    motivo             VARCHAR(10) CHECK (motivo IN ('TACTICO', 'LESION', 'PRECAUCION', 'EXPULSION')) NOT NULL,

    minuto             SMALLINT    NOT NULL CHECK (minuto between 0 and 45),
    extra              SMALLINT    NOT NULL DEFAULT 0,
    tiempo             SMALLINT    NOT NULL CHECK (tiempo between 1 and 4),

    CONSTRAINT PK_Cambios                 PRIMARY KEY (id),

    CONSTRAINT FK_Cambios_Partido         FOREIGN KEY (partido_id)       REFERENCES Partidos.Partidos(id),
    CONSTRAINT FK_Cambios_Jugador_Entra   FOREIGN KEY (jugador_entra_id) REFERENCES Equipos.IntegranteSeleccion(id),
    CONSTRAINT FJ_Cambios_jugador_Sale_id FOREIGN KEY (jugador_sale_id)  REFERENCES Equipos.IntegranteSeleccion(id),

    CONSTRAINT CK_Cambio_Jugadores_Distintos       CHECK (jugador_entra_id <> jugador_sale_id),
    CONSTRAINT CK_Al_Menos_Un_Jugador_En_Un_Cambio CHECK (jugador_entra_id is not null OR jugador_sale_id is not null)
    -- TODO: Se puede sumar chequeos como si minuto != maximo => extra = 0. (tiempo 1 y 2 max 45, 3 y 4 max 15)
);
END
GO

IF OBJECT_ID('Eventos.Goles', 'U') IS NULL
BEGIN
CREATE TABLE Eventos.Goles (
    id                   INT      IDENTITY(1,1),
    partido_id           INT      NOT NULL,
    jugador_autor_id     INT      NOT NULL,
    jugador_asistente_id INT       ,
    tipo                 CHAR(1)  CHECK(tipo in ('T', 'N', 'C', 'P', 'E')) NOT NULL, -- Tiro libre, normal, cabeza, Penal (por falta en el area), En Contra

    minuto               SMALLINT NOT NULL CHECK (minuto between 0 and 45),
    extra                SMALLINT NOT NULL DEFAULT 0,
    tiempo               SMALLINT NOT NULL CHECK (tiempo between 1 and 4),

    CONSTRAINT PK_Goles                   PRIMARY KEY (id),

    CONSTRAINT FK_Goles_Partido           FOREIGN KEY (partido_id)           REFERENCES Partidos.Partidos(id),
    CONSTRAINT FK_Goles_Jugador_Autor     FOREIGN KEY (jugador_autor_id)     REFERENCES Equipos.IntegranteSeleccion(id),
    CONSTRAINT FJ_Goles_jugador_Asistente FOREIGN KEY (jugador_asistente_id) REFERENCES Equipos.IntegranteSeleccion(id),

    CONSTRAINT CK_Gol_Asistente_Distinto_Del_Autor CHECK (jugador_asistente_id IS NULL OR jugador_asistente_id <> jugador_autor_id)
    -- TODO: Se puede sumar chequeos como si minuto != maximo => extra = 0. (tiempo 1 y 2 max 45, 3 y 4 max 15)
);
END
GO

IF OBJECT_ID('Eventos.PenalesDeTanda', 'U') IS NULL
BEGIN
CREATE TABLE Eventos.PenalesDeTanda (
    id         INT IDENTITY(1,1),
    partido_id INT NOT NULL,
    jugador_id INT NOT NULL,
    convirtio  BIT NOT NULL,

    CONSTRAINT PK_PenalesDeTanda               PRIMARY KEY (id),

    CONSTRAINT FK_PenalesDeTanda_Partido       FOREIGN KEY (partido_id) REFERENCES Partidos.Partidos(id),
    CONSTRAINT FK_PenalesDeTanda_Jugador_Autor FOREIGN KEY (jugador_id) REFERENCES Equipos.IntegranteSeleccion(id),

    -- NOTA: Las reglas preveen la siguiente situación:
    -- Si patearon todos los jugadores, recién ahí, se puede volver a patear.
    -- JAMÁS ocurrió en un mundial. Por eso simplifico esa regla.
    CONSTRAINT UQ_Un_Penal_Por_Jugador UNIQUE (partido_id, jugador_id)
);
END
GO


IF OBJECT_ID('Publicidad.Anunciantes', 'U') IS NULL
BEGIN
CREATE TABLE Publicidad.Anunciantes (
    id           INT          IDENTITY(1,1),
    razon_social VARCHAR(150) UNIQUE NOT NULL,
    
    CONSTRAINT PK_Anunciantes PRIMARY KEY (id)
);
END
GO

IF OBJECT_ID('Publicidad.Campañas', 'U') IS NULL
BEGIN
CREATE TABLE Publicidad.Campañas (
    id             INT          IDENTITY(1,1),
    anunciante_id  INT          NOT NULL,
    mundial_id     SMALLINT     NOT NULL,
    nombre         VARCHAR(150) NOT NULL,
    descripcion    VARCHAR(300) ,
    horario_minimo TINYINT      CHECK(horario_minimo between 0 AND 24),
    horario_maximo TINYINT      CHECK(horario_maximo between 0 AND 24),

    CONSTRAINT PK_Campañas            PRIMARY KEY (id),

    CONSTRAINT FK_Campañas_Anunciante FOREIGN KEY (anunciante_id) REFERENCES Publicidad.Anunciantes(id),
    CONSTRAINT FK_Campañas_Mundial    FOREIGN KEY (mundial_id) REFERENCES Mundial.Mundiales(año),


    CONSTRAINT UQ_Un_Nombre_Por_Mundial UNIQUE (mundial_id, nombre)
);
END
GO

IF OBJECT_ID('Publicidad.PiezasDeContenido', 'U') IS NULL
BEGIN
CREATE TABLE Publicidad.PiezasDeContenido (
    id          INT          IDENTITY(1,1),
    campaña_id  INT          NOT NULL,
    nombre      VARCHAR(300) NOT NULL,
    descripcion VARCHAR(300),

    CONSTRAINT PK_Piezas_De_Contenido         PRIMARY KEY (id),

    CONSTRAINT FK_Piezas_De_Contenido_Campaña FOREIGN KEY (campaña_id) REFERENCES Publicidad.Campañas(id),

    CONSTRAINT UQ_Nombres_Unicos_Por_Campaña  UNIQUE(campaña_id, nombre)
);
END
GO

IF OBJECT_ID('Publicidad.PaisesInteresados', 'U') IS NULL
BEGIN
CREATE TABLE Publicidad.PaisesInteresados (
    id                    INT     IDENTITY(1,1),
    pieza_de_contenido_id INT     NOT NULL,
    pais_id               CHAR(3) NOT NULL,

    CONSTRAINT PK_Paises_Interesados                    PRIMARY KEY (id),

    CONSTRAINT FK_Paises_Interesados_Pieza_De_Contenido FOREIGN KEY (pieza_de_contenido_id) REFERENCES Publicidad.PiezasDeContenido(id),
    CONSTRAINT FK_Paises_Interesados_Pais               FOREIGN KEY (pais_id)               REFERENCES Administracion.Paises(codigo)
);
END
GO


IF OBJECT_ID('Publicidad.Tarifas', 'U') IS NULL
BEGIN
CREATE TABLE Publicidad.Tarifas (
    id         INT           IDENTITY(1,1),
    franja     CHAR(1)       CHECK (franja in ('P', 'N')) NOT NULL, -- Prime Time, Normal
    fase       CHAR(25)      CHECK (fase in ('GRUPOS', 'DIECISEISAVOS', 'OCTAVOS', 'CUARTOS', 'SEMIFINAL', 'TERCER_PUESTO', 'FINAL')) NOT NULL,
    costo      DECIMAL(10,2) NOT NULL,
    mundial_id SMALLINT      NOT NULL,

    CONSTRAINT PK_Tarifas         PRIMARY KEY (id),

    CONSTRAINT FK_Tarifas_Mundial FOREIGN KEY (mundial_id) REFERENCES Mundial.Mundiales(año),

    CONSTRAINT UQ_Tarifa_Unica_Para_Cada_Franja_Y_Fase_En_un_Mundial UNIQUE(franja, fase, mundial_id)
);
END
GO

IF OBJECT_ID('Publicidad.RegistroDePiezasEmitidas', 'U') IS NULL
BEGIN
CREATE TABLE Publicidad.RegistroDePiezasEmitidas (
    id                    INT           IDENTITY(1,1),
    pieza_de_contenido_id INT           NOT NULL,
    descripcion           VARCHAR(200)  , 
    costo                 DECIMAL(10,2) NOT NULL,
    partido_id            INT           NOT NULL,

    CONSTRAINT PK_Registro_De_Piezas_Emitidas         PRIMARY KEY (id),
    CONSTRAINT FK_Registro_De_Piezas_Emitidas_Pieza_De_Contenido FOREIGN KEY (pieza_de_contenido_id) REFERENCES Publicidad.PiezasDeContenido(id),
    CONSTRAINT FK_Registro_De_Piezas_Emitidas_Partido FOREIGN KEY (partido_id) REFERENCES Partidos.Partidos(id)
);
END
GO


