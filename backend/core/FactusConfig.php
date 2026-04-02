<?php
/**
 * FactusConfig.php
 * Configuración dinámica para la API de Factus.
 * Lee valores de la tabla app_settings para permitir cambios sin editar código.
 */

if (!defined('AUTH_REQUIRED')) {
    header('HTTP/1.0 403 Forbidden');
    exit('Acceso no permitido');
}

class FactusConfig
{
    private static $settings = null;
    private static $apiUrl = 'https://api-sandbox.factus.com.co'; // Base URL suele ser fija por entorno

    /**
     * Carga las configuraciones desde la base de datos.
     */
    private static function loadSettings($conn)
    {
        if (self::$settings !== null)
            return;

        $selfKeys = [
            'factus_client_id',
            'factus_client_secret',
            'factus_username',
            'factus_password',
            'factus_numbering_range_id'
        ];

        self::$settings = [];
        $res = $conn->query("SELECT setting_key, setting_value FROM app_settings WHERE setting_key LIKE 'factus_%'");

        if ($res) {
            while ($row = $res->fetch_assoc()) {
                self::$settings[$row['setting_key']] = $row['setting_value'];
            }
        }
    }

    public static function getApiUrl()
    {
        return self::$apiUrl;
    }

    public static function getClientId($conn)
    {
        self::loadSettings($conn);
        return self::$settings['factus_client_id'] ?? null;
    }

    public static function getClientSecret($conn)
    {
        self::loadSettings($conn);
        return self::$settings['factus_client_secret'] ?? null;
    }

    public static function getUsername($conn)
    {
        self::loadSettings($conn);
        return self::$settings['factus_username'] ?? null;
    }

    public static function getPassword($conn)
    {
        self::loadSettings($conn);
        return self::$settings['factus_password'] ?? null;
    }

    public static function getNumberingRangeId($conn)
    {
        self::loadSettings($conn);
        return self::$settings['factus_numbering_range_id'] ?? null;
    }

    /**
     * Verifica si la configuración mínima necesaria está presente.
     */
    public static function isConfigured($conn)
    {
        self::loadSettings($conn);
        return !empty(self::$settings['factus_client_id']) &&
            !empty(self::$settings['factus_client_secret']) &&
            !empty(self::$settings['factus_username']) &&
            !empty(self::$settings['factus_password']);
    }
}