<?php
// Reportar errores (para debug)
ini_set('display_errors', 0);
error_reporting(E_ALL);

header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

// Manejo de Preflight (OPTIONS)
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit();
}

$response = array();

try {
    // 1. Usar conexion.php (Base de datos de la App: u342171239_InfoApp_Test)
    $connPath = __DIR__ . '/../conexion.php';
    if (!file_exists($connPath)) {
        throw new Exception("Archivo de conexión no encontrado: conexion.php");
    }

    // 2. Incluir conexión
    require_once $connPath;

    // 3. Verificar variable $conn
    if (!isset($conn)) {
        throw new Exception("Error de configuración: \$conn no definida.");
    }

    if ($conn->connect_error) {
        throw new Exception("Error de conexión BD: " . $conn->connect_error);
    }

    // 4. Leer Input
    $data = json_decode(file_get_contents("php://input"));

    // 5. Validar datos requeridos
    if (
        !isset(
        $data->ID_REGISTRO,
        $data->NOMBRE_CLIENTE,
        $data->NIT,
        $data->CORREO,
        $data->NOMBRE_USER,
        $data->CONTRASEÑA
    )
    ) {
        throw new Exception("Datos incompletos. Faltan campos obligatorios.");
    }

    $id_registro = $data->ID_REGISTRO;
    $correo = $data->CORREO;
    $nombre_user = $data->NOMBRE_USER;

    // 6. Verificar duplicados (Usuario check)
    // Nota: Usamos UPPERCASE columns basado en create_full_admin.sql
    $sqlCheck = "SELECT id FROM usuarios WHERE ID_REGISTRO = ? AND NOMBRE_USER = ?";
    $stmtCheck = $conn->prepare($sqlCheck);
    if (!$stmtCheck) {
        throw new Exception("Error prepare check: " . $conn->error);
    }
    $stmtCheck->bind_param("ss", $id_registro, $nombre_user);
    $stmtCheck->execute();
    $resultCheck = $stmtCheck->get_result();

    if ($resultCheck->num_rows > 0) {
        echo json_encode(["success" => false, "message" => "El usuario '$nombre_user' ya existe para este registro."]);
        exit;
    }

    // 7. Preparar Insert
    $nombre_cliente = $data->NOMBRE_CLIENTE;
    $nit = $data->NIT;
    $rol = $data->TIPO_ROL ?? 'colaborador';
    $password_raw = $data->CONTRASEÑA;
    $estado = 'activo';

    // --- MEJORA: Fetch data from Admin DB if possible (under the hood) ---
    $direccion = '';
    $telefono = '';
    $regimen = '';
    $sitio_web = '';
    $resolucion = '';
    $instagram = '';
    $facebook = '';
    $whatsapp = '';
    $contacto = '';
    $ciudad = '';

    $admin_conn_path = __DIR__ . '/../conexion_admin.php';
    if (file_exists($admin_conn_path)) {
        require_once $admin_conn_path;
        if (isset($conn_admin) && !$conn_admin->connect_error) {
            $id_reg_esc = $conn_admin->real_escape_string($id_registro);
            $sqlAdmin = "SELECT nombre_cliente, nit, direccion, telefono, correo, url_web, contacto_principal, ciudad, regimen_tributario, resolucion_dian, instagram, facebook, whatsapp 
                         FROM clientes WHERE id_registro = '$id_reg_esc' LIMIT 1";
            $resA = $conn_admin->query($sqlAdmin);
            if ($rowA = $resA->fetch_assoc()) {
                $nombre_cliente = $rowA['nombre_cliente'] ?? $nombre_cliente;
                $nit = $rowA['nit'] ?? $nit;
                $direccion = $rowA['direccion'] ?? '';
                $telefono = $rowA['telefono'] ?? '';
                $regimen = $rowA['regimen_tributario'] ?? '';
                $sitio_web = $rowA['url_web'] ?? '';
                $resolucion = $rowA['resolucion_dian'] ?? '';
                $instagram = $rowA['instagram'] ?? '';
                $facebook = $rowA['facebook'] ?? '';
                $whatsapp = $rowA['whatsapp'] ?? '';
                $contacto = $rowA['contacto_principal'] ?? '';
                $ciudad = $rowA['ciudad'] ?? '';
            }
        }
    }

    // Hash password
    $password_hash = password_hash($password_raw, PASSWORD_BCRYPT);

    $sql = "INSERT INTO usuarios 
            (ID_REGISTRO, NOMBRE_CLIENTE, NIT, CORREO, NOMBRE_USER, TIPO_ROL, CONTRASEÑA, ESTADO_USER,
             DIRECCION, TELEFONO, regimen_tributario, SITIO_WEB, RESOLUCION_DIAN, INSTAGRAM, FACEBOOK, WHATSAPP, NOMBRE_CONTACTO, CIUDAD)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";

    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        throw new Exception("Error prepare insert: " . $conn->error);
    }

    $stmt->bind_param(
        "ssssssssssssssssss",
        $id_registro,
        $nombre_cliente,
        $nit,
        $correo,
        $nombre_user,
        $rol,
        $password_hash,
        $estado,
        $direccion,
        $telefono,
        $regimen,
        $sitio_web,
        $resolucion,
        $instagram,
        $facebook,
        $whatsapp,
        $contacto,
        $ciudad
    );

    if ($stmt->execute()) {
        echo json_encode(["success" => true, "message" => "Usuario registrado exitosamente."]);
    } else {
        throw new Exception("Error al registrar: " . $stmt->error);
    }

} catch (Exception $e) {
    http_response_code(200);
    echo json_encode(["success" => false, "message" => "Error del Servidor: " . $e->getMessage()]);
}
?>