-- Migration: Add can_edit_closed_ops permission to usuarios table
-- Date: 2026-03-16

ALTER TABLE usuarios ADD COLUMN can_edit_closed_ops TINYINT(1) DEFAULT 0 AFTER es_auditor;
