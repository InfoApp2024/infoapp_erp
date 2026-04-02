-- Agregar columnas tributarias a la tabla clientes
ALTER TABLE clientes
ADD COLUMN regimen_tributario VARCHAR(50) DEFAULT 'No Responsable de IVA' COMMENT 'Responsable de IVA, No Responsable, Gran Contribuyente, etc.' AFTER perfil,
ADD COLUMN codigo_ciiu VARCHAR(20) DEFAULT NULL COMMENT 'Código actividad económica principal' AFTER regimen_tributario,
ADD COLUMN es_agente_retenedor TINYINT(1) DEFAULT 0 COMMENT '1=Sí, 0=No' AFTER codigo_ciiu;
