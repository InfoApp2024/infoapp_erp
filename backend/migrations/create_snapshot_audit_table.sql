-- 
-- Tabla para auditoría de ajustes manuales en snapshots financieros
--

CREATE TABLE IF NOT EXISTS `fac_snapshot_ajustes` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `servicio_id` INT NOT NULL,
  `usuario_id` INT NOT NULL,
  `campo` ENUM('MANO_OBRA', 'REPUESTOS') NOT NULL,
  `valor_anterior` DECIMAL(15, 2) NOT NULL,
  `valor_nuevo` DECIMAL(15, 2) NOT NULL,
  `motivo` TEXT NOT NULL,
  `fecha` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_ajuste_servicio` FOREIGN KEY (`servicio_id`) REFERENCES `servicios` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_ajuste_usuario` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Índice para mejorar velocidad de consulta por servicio
CREATE INDEX `idx_ajuste_servicio` ON `fac_snapshot_ajustes` (`servicio_id`);
