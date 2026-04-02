<?php
// ======================================================
// NUEVO ARCHIVO: guardar_valores_campos_adicionales.php
// ======================================================

require_once '../../login/auth_middleware.php';

// header('Access-Control-Allow-Methods: ...');  <-- Removed
// header('Access-Control-Allow-Headers: ...');  <-- Removed
// header('Content-Type: ...');                   <-- Removed
// if OPTIONS exit                                <-- Removed

try {
    $currentUser = requireAuth();
} catch (Exception $e) {
    http_response_code(401);
    echo json_encode(['error' => 'Unauthorized']);
    exit;
}

require '../../conexion.php';

// Función de logging
function logMessage($message)
{
    $logFile = "guardar_valores_" . date('Y-m-d') . ".log";
    error_log(date('Y-m-d H:i:s') . " - " . $message . "\n", 3, $logFile);
}

// Mostrar información de debug si se solicita
if (isset($_GET['debug'])) {
    header('Content-Type: text/html; charset=utf-8');
    echo "<h2>🐛 DEBUG MODE - guardar_valores_campos_adicionales.php</h2>";
    echo "<p><strong>Timestamp:</strong> " . date('Y-m-d H:i:s') . "</p>";
    echo "<p><strong>Request Method:</strong> " . $_SERVER['REQUEST_METHOD'] . "</p>";
    echo "<p><strong>Content-Type:</strong> " . ($_SERVER['CONTENT_TYPE'] ?? 'no definido') . "</p>";
    echo "<p><strong>Query String:</strong> " . ($_SERVER['QUERY_STRING'] ?? 'vacío') . "</p>";
    echo "<p><strong>POST Data (raw):</strong> " . file_get_contents('php://input') . "</p>";
    echo "<p><strong>GET Data:</strong> " . json_encode($_GET) . "</p>";
    echo "<p><strong>PHP Version:</strong> " . phpversion() . "</p>";
    echo "<hr>";
    echo "<h3>Probando conexión a BD...</h3>";

    // ✅ EJEMPLO: Conexión con manejo de errores
    try {
        $pdo = new PDO("mysql:host=localhost;dbname=u342171239_InfoApp_Test;charset=utf8mb4", "u342171239_Test", "Test_2025/-*");
        $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        logMessage("Conexión BD establecida exitosamente");

        echo "<p style='color: green;'>✅ Conexión a BD exitosa</p>";

        $stmt = $pdo->query("SHOW TABLES LIKE 'valores_campos_adicionales'");
        if ($stmt->rowCount() > 0) {
            echo "<p style='color: green;'>✅ Tabla 'valores_campos_adicionales' existe</p>";
        } else {
            echo "<p style='color: red;'>❌ Tabla 'valores_campos_adicionales' NO existe</p>";
        }
    } catch (Exception $e) {
        logMessage("ERROR DE BD EN DEBUG: " . $e->getMessage());
        echo "<p style='color: red;'>❌ Error BD: " . $e->getMessage() . "</p>";
    }

    exit();
}

try {
    logMessage("=== INICIO NUEVO SCRIPT ===");
    logMessage("Method: " . $_SERVER['REQUEST_METHOD']);
    logMessage("Content-Type: " . ($_SERVER['CONTENT_TYPE'] ?? 'no definido'));

    // ✅ PERMITIR TANTO GET COMO POST
    $data = null;

    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        // Modo GET - obtener campos reales de la BD para pruebas
        $servicio_id = isset($_GET['servicio_id']) ? intval($_GET['servicio_id']) : 1;

        // Obtener campos reales de la BD
        // ✅ EJEMPLO: Conexión con manejo de errores
        try {
            $pdo = new PDO("mysql:host=localhost;dbname=u342171239_InfoApp_Test;charset=utf8mb4", "u342171239_Test", "Test_2025/-*");
            $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
            logMessage("Conexión BD establecida exitosamente");
        } catch (PDOException $e) {
            logMessage("ERROR DE CONEXIÓN BD: " . $e->getMessage());
            throw new Exception("Error conectando a base de datos: " . $e->getMessage());
        }
        $stmt_temp = $pdo->query("SELECT id, nombre_campo, tipo_campo FROM campos_adicionales ORDER BY id LIMIT 3");
        $campos_reales = $stmt_temp->fetchAll(PDO::FETCH_ASSOC);

        if (empty($campos_reales)) {
            throw new Exception('No hay campos adicionales creados en la BD. Crea campos primero.');
        }

        // Generar datos de prueba con campos reales
        $campos_prueba = [];
        foreach ($campos_reales as $index => $campo_real) {
            $valor_prueba = '';

            // Generar valor según el tipo de campo
            switch (strtolower($campo_real['tipo_campo'])) {
                case 'texto':
                case 'párrafo':
                    $valor_prueba = 'Texto de prueba para ' . $campo_real['nombre_campo'] . ' - ' . date('H:i:s');
                    break;
                case 'entero':
                    $valor_prueba = rand(1, 100);
                    break;
                case 'decimal':
                case 'moneda':
                    $valor_prueba = round(rand(100, 9999) / 100, 2);
                    break;
                case 'fecha':
                    $valor_prueba = date('Y-m-d');
                    break;
                case 'hora':
                    $valor_prueba = date('H:i:s');
                    break;
                default:
                    $valor_prueba = 'Valor de prueba ' . $index;
                    break;
            }

            $campos_prueba[] = [
                'campo_id' => $campo_real['id'],
                'valor' => $valor_prueba
            ];
        }

        $data = [
            'servicio_id' => $servicio_id,
            'modulo' => 'Servicios',
            'campos' => $campos_prueba
        ];

        logMessage("Datos GET con campos reales: " . json_encode($data));
        logMessage("Campos disponibles en BD: " . json_encode($campos_reales));

    } elseif ($_SERVER['REQUEST_METHOD'] === 'POST') {
        // Modo POST - datos reales
        $input = file_get_contents('php://input');
        logMessage("POST input: " . $input);

        if (empty($input)) {
            throw new Exception('No se recibieron datos POST');
        }

        $data = json_decode($input, true);
        if (json_last_error() !== JSON_ERROR_NONE) {
            throw new Exception('Error JSON: ' . json_last_error_msg());
        }
        logMessage("Datos POST decodificados: " . json_encode($data));

    } else {
        throw new Exception('Método no soportado: ' . $_SERVER['REQUEST_METHOD']);
    }

    // Validar datos básicos
    if (!isset($data['servicio_id'])) {
        throw new Exception('servicio_id es requerido');
    }

    // Detectar formato de campos
    $campos = [];
    if (isset($data['campos']) && is_array($data['campos'])) {
        $campos = $data['campos'];
        logMessage("Formato detectado: campos (Flutter nuevo)");
    } elseif (isset($data['valores']) && is_array($data['valores'])) {
        $campos = $data['valores'];
        logMessage("Formato detectado: valores (formato anterior)");
    } else {
        throw new Exception('Se requiere array "campos" o "valores". Recibido: ' . json_encode(array_keys($data)));
    }

    if (empty($campos)) {
        throw new Exception('Array de campos está vacío');
    }

    $servicio_id = intval($data['servicio_id']);
    $modulo = isset($data['modulo']) ? trim($data['modulo']) : 'Servicios';

    logMessage("Procesando: servicio_id=$servicio_id, modulo=$modulo, campos=" . count($campos));

    // Conexión a BD
    // ✅ EJEMPLO: Conexión con manejo de errores
    try {
        $pdo = new PDO("mysql:host=localhost;dbname=u342171239_InfoApp_Test;charset=utf8mb4", "u342171239_Test", "Test_2025/-*");
        $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        logMessage("Conexión BD establecida exitosamente");
    } catch (PDOException $e) {
        logMessage("ERROR DE CONEXIÓN BD: " . $e->getMessage());
        throw new Exception("Error conectando a base de datos: " . $e->getMessage());
    }
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    logMessage("Conexión BD establecida");

    // Verificar que la tabla existe
    $stmt = $pdo->query("SHOW TABLES LIKE 'valores_campos_adicionales'");
    if ($stmt->rowCount() === 0) {
        throw new Exception('La tabla valores_campos_adicionales no existe');
    }

    // Iniciar transacción
    $pdo->beginTransaction();
    logMessage("Transacción iniciada");

    $procesados = 0;
    $errores = [];

    // Procesar cada campo
    foreach ($campos as $index => $campo) {
        try {
            if (!isset($campo['campo_id']) || !isset($campo['valor'])) {
                $errores[] = "Campo $index: faltan campo_id o valor";
                continue;
            }

            $campo_id = intval($campo['campo_id']);
            $valor = $campo['valor'];

            logMessage("Procesando campo_id=$campo_id, valor=" . json_encode($valor));

            // Determinar tipo y valor final
            $valorTexto = null;
            $valorNumero = null;
            $valorFecha = null;
            $valorHora = null;
            $tipoCampo = 'Texto';

            if (is_numeric($valor)) {
                $valorNumero = floatval($valor);
                $tipoCampo = 'Numero';
            } elseif (preg_match('/^\d{4}-\d{2}-\d{2}$/', $valor)) {
                $valorFecha = $valor;
                $tipoCampo = 'Fecha';
            } elseif (preg_match('/^\d{2}:\d{2}/', $valor)) {
                $valorHora = $valor;
                $tipoCampo = 'Hora';
            } else {
                $valorTexto = strval($valor);
                $tipoCampo = 'Texto';
            }

            // Verificar si existe
            $stmt = $pdo->prepare("SELECT id FROM valores_campos_adicionales WHERE servicio_id = ? AND campo_id = ?");
            $stmt->execute([$servicio_id, $campo_id]);
            $existente = $stmt->fetch();

            if ($existente) {
                // Actualizar
                $stmt = $pdo->prepare("
                    UPDATE valores_campos_adicionales 
                    SET valor_texto = ?, valor_numero = ?, valor_fecha = ?, valor_hora = ?, 
                        tipo_campo = ?, fecha_actualizacion = NOW()
                    WHERE id = ?
                ");
                $stmt->execute([$valorTexto, $valorNumero, $valorFecha, $valorHora, $tipoCampo, $existente['id']]);
                logMessage("Campo $campo_id actualizado");
            } else {
                // Insertar nuevo
                $stmt = $pdo->prepare("
                    INSERT INTO valores_campos_adicionales 
                    (servicio_id, campo_id, valor_texto, valor_numero, valor_fecha, valor_hora, tipo_campo, fecha_creacion, fecha_actualizacion)
                    VALUES (?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
                ");
                $stmt->execute([$servicio_id, $campo_id, $valorTexto, $valorNumero, $valorFecha, $valorHora, $tipoCampo]);
                logMessage("Campo $campo_id insertado con ID: " . $pdo->lastInsertId());
            }

            $procesados++;

        } catch (Exception $e) {
            $error = "Error en campo $index (campo_id={$campo['campo_id']}): " . $e->getMessage();
            $errores[] = $error;
            logMessage("ERROR: $error");
        }
    }

    // Confirmar transacción
    $pdo->commit();
    logMessage("Transacción confirmada. Procesados: $procesados");

    // Respuesta
    $response = [
        'success' => true,
        'message' => "Procesados $procesados campos exitosamente",
        'datos' => [
            'servicio_id' => $servicio_id,
            'modulo' => $modulo,
            'campos_procesados' => $procesados,
            'total_enviados' => count($campos),
            'errores' => $errores
        ]
    ];

    echo json_encode($response);
    logMessage("Respuesta enviada: " . json_encode($response));

} catch (Exception $e) {
    // Rollback si hay transacción activa
    if (isset($pdo) && $pdo->inTransaction()) {
        $pdo->rollback();
        logMessage("Transacción revertida");
    }

    $errorMsg = 'Error: ' . $e->getMessage();
    logMessage("ERROR FATAL: $errorMsg");
    logMessage("Stack: " . $e->getTraceAsString());

    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $errorMsg,
        'error_details' => [
            'file' => $e->getFile(),
            'line' => $e->getLine(),
            'method' => $_SERVER['REQUEST_METHOD'],
            'timestamp' => date('Y-m-d H:i:s')
        ]
    ]);
}

logMessage("=== FIN SCRIPT ===\n");
?>