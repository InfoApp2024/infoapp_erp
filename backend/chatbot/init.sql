-- =============================================================================
-- MÓDULO: Chatbot (IA / Gemini)
-- PROPÓSITO: Inicializar tablas para el módulo de chat inteligente.
-- =============================================================================

SET NAMES utf8mb4;

-- 1. Historial de mensajes del chatbot
CREATE TABLE IF NOT EXISTS chat_messages (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    message TEXT NOT NULL,
    is_user BOOLEAN DEFAULT 1 COMMENT '1=mensaje del usuario, 0=respuesta del bot',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. Tokens temporales para descarga de PDF desde el chatbot
CREATE TABLE IF NOT EXISTS pdf_temp_links (
    id INT AUTO_INCREMENT PRIMARY KEY,
    token VARCHAR(64) NOT NULL UNIQUE,
    jwt TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_token (token)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
