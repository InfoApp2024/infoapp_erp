<?php
// jwt_config.php
// ✅ Configuración para JSON Web Tokens (JWT)

// 🔐 CLAVE SECRETA - ¡MUY IMPORTANTE!
// Esta clave debe ser ÚNICA y SECRETA para tu aplicación
// En producción, cámbiala por una más compleja y guárdala en variables de entorno
define('JWT_SECRET_KEY', 'InfoApp_2025_$ecur3_K3y_#789!');

// ⏰ CONFIGURACIÓN DE TIEMPO
define('JWT_EXPIRATION_TIME', 24 * 60 * 60); // 24 horas en segundos (86400 segundos)
// Otras opciones:
// define('JWT_EXPIRATION_TIME', 60 * 60);     // 1 hora
// define('JWT_EXPIRATION_TIME', 8 * 60 * 60); // 8 horas

// 🔐 ALGORITMO DE ENCRIPTACIÓN
define('JWT_ALGORITHM', 'HS256');

// 🏢 INFORMACIÓN DEL EMISOR
define('JWT_ISSUER', 'InfoApp'); // Nombre de tu aplicación
define('JWT_AUDIENCE', 'InfoApp-Users'); // Quién puede usar este token

// 🌐 DOMINIO (opcional - para mayor seguridad)
define('JWT_DOMAIN', 'localhost'); // Cambia por tu dominio real en producción

// 📝 CONFIGURACIÓN ADICIONAL
define('JWT_REFRESH_TIME', 2 * 60 * 60); // 2 horas antes de expirar, permite refresh

// ✅ FUNCIÓN AUXILIAR - Obtener configuración completa
function getJwtConfig() {
    return [
        'secret_key' => JWT_SECRET_KEY,
        'algorithm' => JWT_ALGORITHM,
        'expiration_time' => JWT_EXPIRATION_TIME,
        'issuer' => JWT_ISSUER,
        'audience' => JWT_AUDIENCE,
        'domain' => JWT_DOMAIN,
        'refresh_time' => JWT_REFRESH_TIME
    ];
}

// ✅ FUNCIÓN AUXILIAR - Validar que la configuración está correcta
function validateJwtConfig() {
    $errors = [];
    
    if (strlen(JWT_SECRET_KEY) < 20) {
        $errors[] = "La clave secreta debe tener al menos 20 caracteres";
    }
    
    if (JWT_EXPIRATION_TIME < 60) {
        $errors[] = "El tiempo de expiración debe ser al menos 60 segundos";
    }
    
    if (empty(JWT_ISSUER)) {
        $errors[] = "El emisor no puede estar vacío";
    }
    
    return $errors;
}

// MENSAJE DE ADVERTENCIA PARA DESARROLLO
if ($_SERVER['SERVER_NAME'] === 'localhost' || $_SERVER['SERVER_NAME'] === '127.0.0.1') {
    // Solo mostrar en desarrollo
    $config_errors = validateJwtConfig();
    if (!empty($config_errors)) {
        error_log("⚠️  ADVERTENCIAS JWT CONFIG: " . implode(", ", $config_errors));
    }
}

// CONSTANTES ADICIONALES ÚTILES
define('JWT_HEADER_NAME', 'Authorization'); // Nombre del header HTTP
define('JWT_TOKEN_PREFIX', 'Bearer '); // Prefijo del token en el header

// NOTAS IMPORTANTES:
/*
1.  SEGURIDAD:
   - Cambia JWT_SECRET_KEY por algo único y complejo
   - Nunca subas este archivo a repositorios públicos
   - En producción, usa variables de entorno

2. TIEMPO DE EXPIRACIÓN:
   - 1 hora: Para máxima seguridad
   - 8 horas: Para aplicaciones de trabajo
   - 24 horas: Para aplicaciones móviles
   - 7 días: Solo si implementas refresh tokens

3. REFRESH TOKENS:
   - JWT_REFRESH_TIME: Tiempo antes de expirar para permitir renovación
   - Implementa refresh tokens para sesiones largas

4. PRODUCCIÓN:
   - Cambia JWT_DOMAIN por tu dominio real
   - Usa HTTPS siempre
   - Considera usar tokens más cortos (1-8 horas)

5. LOGS:
   - Los errores de configuración se registran en error_log
   - Solo en desarrollo se muestran advertencias
*/

?>