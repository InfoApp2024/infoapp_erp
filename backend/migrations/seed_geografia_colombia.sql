-- seed_geografia_colombia.sql
-- Inserción de departamentos y municipios (DIVIPOLA Colombia)

-- 1. Departamentos
INSERT IGNORE INTO departamentos (id, nombre) VALUES
(5, 'Antioquia'),
(8, 'Atlántico'),
(11, 'Bogotá, D.C.'),
(13, 'Bolívar'),
(15, 'Boyacá'),
(17, 'Caldas'),
(18, 'Caquetá'),
(19, 'Cauca'),
(20, 'Cesar'),
(23, 'Córdoba'),
(25, 'Cundinamarca'),
(27, 'Chocó'),
(41, 'Huila'),
(44, 'La Guajira'),
(47, 'Magdalena'),
(50, 'Meta'),
(52, 'Nariño'),
(54, 'Norte de Santander'),
(63, 'Quindío'),
(66, 'Risaralda'),
(68, 'Santander'),
(70, 'Sucre'),
(73, 'Tolima'),
(76, 'Valle del Cauca'),
(81, 'Arauca'),
(85, 'Casanare'),
(86, 'Putumayo'),
(88, 'Archipiélago de San Andrés, Providencia y Santa Catalina'),
(91, 'Amazonas'),
(94, 'Guainía'),
(95, 'Guaviare'),
(97, 'Vaupés'),
(99, 'Vichada');

-- 2. Municipios (Muestra representativa, se recomienda usar el archivo completo)
-- ATLÁNTICO (ID: 8)
INSERT IGNORE INTO ciudades (nombre, departamento, departamento_id) VALUES
('BARRANQUILLA', 'Atlántico', 8),
('BARANOA', 'Atlántico', 8),
('CAMPO DE LA CRUZ', 'Atlántico', 8),
('CANDELARIA', 'Atlántico', 8),
('GALAPA', 'Atlántico', 8),
('JUAN DE ACOSTA', 'Atlántico', 8),
('LURUACO', 'Atlántico', 8),
('MALAMBO', 'Atlántico', 8),
('MANATÍ', 'Atlántico', 8),
('PALMAR DE VARELA', 'Atlántico', 8),
('PIOJÓ', 'Atlántico', 8),
('POLONUEVO', 'Atlántico', 8),
('PONEDERA', 'Atlántico', 8),
('PUERTO COLOMBIA', 'Atlántico', 8),
('REPELÓN', 'Atlántico', 8),
('SABANAGRANDE', 'Atlántico', 8),
('SABANALARGA', 'Atlántico', 8),
('SANTA LUCÍA', 'Atlántico', 8),
('SANTO TOMÁS', 'Atlántico', 8),
('SOLEDAD', 'Atlántico', 8),
('SUAN', 'Atlántico', 8),
('TUBARÁ', 'Atlántico', 8),
('USIACURÍ', 'Atlántico', 8);

-- BOGOTÁ (ID: 11)
INSERT IGNORE INTO ciudades (nombre, departamento, departamento_id) VALUES
('BOGOTÁ, D.C.', 'Bogotá, D.C.', 11);

-- ANTIOQUIA (ID: 5)
INSERT IGNORE INTO ciudades (nombre, departamento, departamento_id) VALUES
('MEDELLÍN', 'Antioquia', 5),
('BELLO', 'Antioquia', 5),
('ENVIGADO', 'Antioquia', 5),
('ITAGÜÍ', 'Antioquia', 5),
('RIONEGRO', 'Antioquia', 5);

-- VALLE DEL CAUCA (ID: 76)
INSERT IGNORE INTO ciudades (nombre, departamento, departamento_id) VALUES
('CALI', 'Valle del Cauca', 76),
('BUENAVENTURA', 'Valle del Cauca', 76),
('PALMIRA', 'Valle del Cauca', 76),
('TULUÁ', 'Valle del Cauca', 76);
