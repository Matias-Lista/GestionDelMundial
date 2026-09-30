insert into Administracion.Clubes (nombre) values ('的')

SELECT * FROM Administracion.Clubes

-- 1. Ver la colación a nivel de Servidor (Instancia)
SELECT CONVERT(VARCHAR(100), SERVERPROPERTY('collation')) AS CollationServidor;

-- 2. Ver la colación de la Base de datos actual
SELECT 
    name AS BaseDeDatos, 
    collation_name AS CollationBaseDatos 
FROM sys.databases 
WHERE name = DB_NAME();

-- 3. Ver qué colación tiene exactamente tu tabla y columna creada
SELECT 
    t.name AS Tabla,
    c.name AS Columna,
    c.collation_name AS CollationColumna
FROM sys.columns c
JOIN sys.tables t ON c.object_id = t.object_id
WHERE t.name = 'Clubes';