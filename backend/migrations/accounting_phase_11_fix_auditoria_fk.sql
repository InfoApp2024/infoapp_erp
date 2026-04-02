-- ============================================================
-- Migración: Corrección de FK en Auditoría
-- Fecha: 2026-03-07
-- ============================================================

-- 1. Eliminar la restricción incorrecta si existe
ALTER TABLE fac_auditorias_servicio
DROP FOREIGN KEY IF EXISTS fk_auditoria_servicio;

-- 2. Asegurar que los datos actuales (si los hay) sean consistentes o limpiar si son basura de pruebas
-- (Normalmente no se borra, pero aquí estamos en fase de fix y el error FK impedía inserciones exitosas anyway)

-- 3. Crear la restricción correcta apuntando a servicios(id)
ALTER TABLE fac_auditorias_servicio
ADD CONSTRAINT fk_auditoria_servicio
FOREIGN KEY (servicio_id)
REFERENCES servicios(id)
ON DELETE CASCADE ON UPDATE CASCADE;

-- 4. Verificar auditor_id (por si acaso también fallara, aunque este sí apuntaba a usuarios)
-- ALTER TABLE fac_auditorias_servicio DROP FOREIGN KEY IF EXISTS fk_auditoria_auditor;
-- ALTER TABLE fac_auditorias_servicio ADD CONSTRAINT fk_auditoria_auditor FOREIGN KEY (auditor_id) REFERENCES usuarios(id) ON DELETE RESTRICT ON UPDATE CASCADE;
