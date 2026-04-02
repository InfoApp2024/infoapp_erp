<?php
// crear.php - Crear nuevo cliente
// Protegido con JWT

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    logAccess($currentUser, 'clientes/crear.php', 'create_client');

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    require '../conexion.php';

    $input = json_decode(file_get_contents('php://input'), true);

    if (!$input) {
        throw new Exception('Datos JSON inválidos');
    }

    // Validar campos obligatorios
    $requiredFields = ['documento_nit', 'nombre_completo', 'ciudad_id'];
    foreach ($requiredFields as $field) {
        if (empty($input[$field])) {
            throw new Exception("El campo $field es obligatorio");
        }
    }

    // Datos
    $tipo_persona = $input['tipo_persona'] ?? 'Natural';
    $documento_nit = trim($input['documento_nit']);
    $dv = $input['dv'] ?? null;
    $nombre_completo = trim($input['nombre_completo']);
    $email = $input['email'] ?? null;
    $email_facturacion = $input['email_facturacion'] ?? null;
    $telefono_principal = $input['telefono_principal'] ?? null;
    $telefono_secundario = $input['telefono_secundario'] ?? null;
    $direccion = $input['direccion'] ?? null;
    $ciudad_id = (int) $input['ciudad_id'];
    $limite_credito = isset($input['limite_credito']) ? (float) $input['limite_credito'] : 0.00;
    $perfil = isset($input['perfil']) ? trim($input['perfil']) : '';
    $regimen_tributario = $input['regimen_tributario'] ?? 'No Responsable de IVA';
    $responsabilidad_fiscal_id = $input['responsabilidad_fiscal_id'] ?? 'R-99-PN';
    $codigo_ciiu = $input['codigo_ciiu'] ?? null;
    $es_agente_retenedor = isset($input['es_agente_retenedor']) ? (int) $input['es_agente_retenedor'] : 0;
    $es_autorretenedor = isset($input['es_autorretenedor']) ? (int) $input['es_autorretenedor'] : 0;
    $es_gran_contribuyente = isset($input['es_gran_contribuyente']) ? (int) $input['es_gran_contribuyente'] : 0;
    $estado = 1;
    $id_user = $currentUser['id'];

    // Verificar duplicado por NIT
    $stmtCheck = $conn->prepare("SELECT id FROM clientes WHERE documento_nit = ?");
    $stmtCheck->bind_param("s", $documento_nit);
    $stmtCheck->execute();
    if ($stmtCheck->get_result()->num_rows > 0) {
        throw new Exception("Ya existe un cliente con el documento/NIT $documento_nit");
    }

    $conn->begin_transaction();

    try {
        $sql = "INSERT INTO clientes (
            tipo_persona, documento_nit, dv, nombre_completo, email, email_facturacion,
            telefono_principal, telefono_secundario, direccion, 
            ciudad_id, limite_credito, perfil, regimen_tributario, 
            responsabilidad_fiscal_id, codigo_ciiu, es_agente_retenedor, 
            es_autorretenedor, es_gran_contribuyente, estado, id_user
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";

        $stmt = $conn->prepare($sql);
        $stmt->bind_param(
            "sssssssssidssssiiiii",
            $tipo_persona,
            $documento_nit,
            $dv,
            $nombre_completo,
            $email,
            $email_facturacion,
            $telefono_principal,
            $telefono_secundario,
            $direccion,
            $ciudad_id,
            $limite_credito,
            $perfil,
            $regimen_tributario,
            $responsabilidad_fiscal_id,
            $codigo_ciiu,
            $es_agente_retenedor,
            $es_autorretenedor,
            $es_gran_contribuyente,
            $estado,
            $id_user
        );

        if (!$stmt->execute()) {
            throw new Exception("Error al crear cliente: " . $stmt->error);
        }

        $cliente_id = $stmt->insert_id;

        // Insertar Perfiles (Tarifas)
        if (!empty($input['perfiles']) && is_array($input['perfiles'])) {
            $stmtPerfil = $conn->prepare("INSERT INTO cliente_perfiles (cliente_id, especialidad_id, valor) VALUES (?, ?, ?)");
            foreach ($input['perfiles'] as $p) {
                $esp_id = (int) $p['especialidad_id'];
                $valor = (float) $p['valor'];
                $stmtPerfil->bind_param("iid", $cliente_id, $esp_id, $valor);
                if (!$stmtPerfil->execute()) {
                    throw new Exception("Error al guardar tarifa: " . $stmtPerfil->error);
                }
            }
        }

        // Insertar Funcionarios (Autorizado por)
        if (!empty($input['funcionarios']) && is_array($input['funcionarios'])) {
            $stmtFunc = $conn->prepare("INSERT INTO funcionario (nombre, cargo, empresa, telefono, correo, cliente_id, activo) VALUES (?, ?, ?, ?, ?, ?, 1)");
            foreach ($input['funcionarios'] as $f) {
                $nombre_func = trim($f['nombre']);
                if (empty($nombre_func))
                    continue;

                $cargo_func = $f['cargo'] ?? null;
                $empresa_func = $f['empresa'] ?? null;
                $telefono_func = $f['telefono'] ?? null;
                $correo_func = $f['correo'] ?? null;

                $stmtFunc->bind_param("sssssi", $nombre_func, $cargo_func, $empresa_func, $telefono_func, $correo_func, $cliente_id);
                if (!$stmtFunc->execute()) {
                    throw new Exception("Error al guardar funcionario: " . $stmtFunc->error);
                }
            }
        }

        $conn->commit();

        sendJsonResponse(successResponse([
            'id' => $cliente_id,
            'nombre_completo' => $nombre_completo
        ], 'Cliente creado exitosamente'));
    } catch (Exception $e) {
        $conn->rollback();
        throw $e;
    }
} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
}
