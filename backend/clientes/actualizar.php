<?php
// actualizar.php - Actualizar cliente
// Protegido con JWT

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    logAccess($currentUser, 'clientes/actualizar.php', 'update_client');

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    require '../conexion.php';

    $input = json_decode(file_get_contents('php://input'), true);

    if (!$input || !isset($input['id'])) {
        throw new Exception('ID de cliente requerido');
    }

    $id = (int) $input['id'];

    // Validar existencia
    $stmtCheck = $conn->prepare("SELECT id FROM clientes WHERE id = ?");
    $stmtCheck->bind_param("i", $id);
    $stmtCheck->execute();
    if ($stmtCheck->get_result()->num_rows === 0) {
        throw new Exception('Cliente no encontrado');
    }

    // Campos permitidos para actualizar
    // Nota: created_at y id_user (creador) no se actualizan
    $fieldsToUpdate = [];
    $params = [];
    $types = "";

    // Mapeo de campos input -> db
    $fieldMap = [
        'tipo_persona' => 's',
        'documento_nit' => 's',
        'dv' => 's',
        'nombre_completo' => 's',
        'email' => 's',
        'email_facturacion' => 's',
        'telefono_principal' => 's',
        'telefono_secundario' => 's',
        'direccion' => 's',
        'ciudad_id' => 'i',
        'limite_credito' => 'd',
        'perfil' => 's',
        'regimen_tributario' => 's',
        'responsabilidad_fiscal_id' => 's',
        'codigo_ciiu' => 's',
        'es_agente_retenedor' => 'i',
        'es_autorretenedor' => 'i',
        'es_gran_contribuyente' => 'i',
        'estado' => 'i'
    ];

    foreach ($fieldMap as $field => $type) {
        if (isset($input[$field])) {
            $fieldsToUpdate[] = "$field = ?";
            $params[] = $input[$field];
            $types .= $type;
        }
    }

    // Si se enviaron perfiles, manejarlos
    $actualizarPerfiles = isset($input['perfiles']) && is_array($input['perfiles']);

    if (empty($fieldsToUpdate) && !$actualizarPerfiles) {
        throw new Exception('No se enviaron datos para actualizar');
    }

    // Verificar unicidad de NIT si se está cambiando
    if (isset($input['documento_nit'])) {
        $stmtNit = $conn->prepare("SELECT id FROM clientes WHERE documento_nit = ? AND id != ?");
        $stmtNit->bind_param("si", $input['documento_nit'], $id);
        $stmtNit->execute();
        if ($stmtNit->get_result()->num_rows > 0) {
            throw new Exception("El documento/NIT ya está registrado en otro cliente");
        }
    }

    $conn->begin_transaction();

    try {
        // Actualizar campos principales si hay
        if (!empty($fieldsToUpdate)) {
            $sql = "UPDATE clientes SET " . implode(", ", $fieldsToUpdate) . " WHERE id = ?";
            $params[] = $id;
            $types .= "i";

            $stmt = $conn->prepare($sql);
            $stmt->bind_param($types, ...$params);

            if (!$stmt->execute()) {
                throw new Exception("Error al actualizar cliente: " . $stmt->error);
            }
        }

        // Actualizar Perfiles (Tarifas)
        if ($actualizarPerfiles) {
            // Eliminar anteriores
            $conn->query("DELETE FROM cliente_perfiles WHERE cliente_id = $id");

            // Insertar nuevos
            if (!empty($input['perfiles'])) {
                $stmtPerfil = $conn->prepare("INSERT INTO cliente_perfiles (cliente_id, especialidad_id, valor) VALUES (?, ?, ?)");
                foreach ($input['perfiles'] as $p) {
                    $esp_id = (int) $p['especialidad_id'];
                    $valor = (float) $p['valor'];
                    $stmtPerfil->bind_param("iid", $id, $esp_id, $valor);
                    if (!$stmtPerfil->execute()) {
                        throw new Exception("Error al guardar tarifa: " . $stmtPerfil->error);
                    }
                }
            }
        }

        $conn->commit();
        sendJsonResponse(successResponse(null, 'Cliente actualizado exitosamente'));

    } catch (Exception $e) {
        $conn->rollback();
        throw $e;
    }

} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
}
