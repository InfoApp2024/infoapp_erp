<?php
require_once '../login/auth_middleware.php';
require_once '../vendor/autoload.php';

use PhpOffice\PhpSpreadsheet\IOFactory;

try {
    // PASO 1: Requerir autenticación JWT
    $currentUser = requireAuth();
    
    // PASO 2: Log de acceso
    logAccess($currentUser, '/importar_funcionarios_excel.php', 'import_funcionarios_excel');
    
    // PASO 3: Validar método HTTP
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }
    
    // PASO 4: Leer datos del request
    $rawInput = file_get_contents("php://input");
    
    if (empty($rawInput)) {
        throw new Exception('No se recibieron datos en el request');
    }
    
    $input = json_decode($rawInput, true);
    
    if (json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('Error decodificando JSON: ' . json_last_error_msg());
    }
    
    if (!isset($input['archivo_base64'])) {
        throw new Exception('No se recibió el archivo Excel en formato base64');
    }
    
    $modo = isset($input['modo']) ? $input['modo'] : 'crear_o_actualizar';
    $sobrescribir_existentes = isset($input['sobrescribir_existentes']) ? (bool)$input['sobrescribir_existentes'] : false;
    
    // PASO 5: Decodificar y guardar temporalmente el archivo
    $archivoBase64 = $input['archivo_base64'];
    $archivoBytes = base64_decode($archivoBase64);
    
    if ($archivoBytes === false) {
        throw new Exception('Error decodificando el archivo base64');
    }
    
    // Validar que tenga contenido
    if (strlen($archivoBytes) === 0) {
        throw new Exception('El archivo decodificado está vacío');
    }
    
    // Crear archivo temporal
    $tempFile = tempnam(sys_get_temp_dir(), 'funcionarios_import_') . '.xlsx';
    $bytesWritten = file_put_contents($tempFile, $archivoBytes);
    
    if ($bytesWritten === false) {
        throw new Exception('Error guardando el archivo temporal');
    }
    
    // PASO 6: Leer archivo Excel
    try {
        $spreadsheet = IOFactory::load($tempFile);
        $sheet = $spreadsheet->getSheet(0); // Primera hoja (Funcionarios)
        $highestRow = $sheet->getHighestRow();
        
        // Validar que tenga datos
        if ($highestRow < 2) {
            throw new Exception('El archivo Excel está vacío o no tiene datos válidos');
        }
        
        // PASO 7: Leer encabezados (fila 1)
        $headers = [];
        $highestColumn = $sheet->getHighestColumn();
        $highestColumnIndex = \PhpOffice\PhpSpreadsheet\Cell\Coordinate::columnIndexFromString($highestColumn);
        
        for ($col = 1; $col <= $highestColumnIndex; $col++) {
            $cellValue = $sheet->getCellByColumnAndRow($col, 1)->getValue();
            $headers[$col] = strtolower(trim($cellValue ?? ''));
        }
        
        // Mapear columnas
        $colID = array_search('id', $headers);
        $colNombre = array_search('nombre', $headers);
        $colCargo = array_search('cargo', $headers);
        $colEmpresa = array_search('empresa', $headers);
        $colActivo = array_search('activo', $headers);
        
        if ($colNombre === false) {
            throw new Exception('No se encontró la columna "Nombre" en el archivo Excel');
        }
        
        // PASO 8: Conexión a BD
        require '../conexion.php';
        
        // PASO 9: Procesar cada fila
        $resultados = [
            'insertados' => 0,
            'actualizados' => 0,
            'omitidos' => 0,
            'errores' => []
        ];
        
        // Iniciar transacción
        $conn->begin_transaction();
        
        try {
            for ($row = 2; $row <= $highestRow; $row++) {
                try {
                    // Leer valores
                    $id = $colID !== false ? $sheet->getCellByColumnAndRow($colID, $row)->getValue() : null;
                    $nombre = $sheet->getCellByColumnAndRow($colNombre, $row)->getValue();
                    $cargo = $colCargo !== false ? $sheet->getCellByColumnAndRow($colCargo, $row)->getValue() : '';
                    $empresa = $colEmpresa !== false ? $sheet->getCellByColumnAndRow($colEmpresa, $row)->getValue() : '';
                    $activo = $colActivo !== false ? $sheet->getCellByColumnAndRow($colActivo, $row)->getValue() : 'Sí';
                    
                    // Limpiar valores
                    $nombre = trim($nombre ?? '');
                    $cargo = trim($cargo ?? '');
                    $empresa = trim($empresa ?? '');
                    
                    // Validar nombre obligatorio
                    if (empty($nombre)) {
                        $resultados['errores'][] = "Fila $row: Nombre es obligatorio";
                        $resultados['omitidos']++;
                        continue;
                    }
                    
                    // Validar longitud
                    if (strlen($nombre) < 2 || strlen($nombre) > 100) {
                        $resultados['errores'][] = "Fila $row: Nombre debe tener entre 2 y 100 caracteres";
                        $resultados['omitidos']++;
                        continue;
                    }
                    
                    if (strlen($cargo) > 100) {
                        $resultados['errores'][] = "Fila $row: Cargo no puede exceder 100 caracteres";
                        $resultados['omitidos']++;
                        continue;
                    }
                    
                    if (strlen($empresa) > 100) {
                        $resultados['errores'][] = "Fila $row: Empresa no puede exceder 100 caracteres";
                        $resultados['omitidos']++;
                        continue;
                    }
                    
                    // Convertir activo a booleano
                    $activoValue = strtolower(trim($activo));
                    $activoBool = ($activoValue === 'sí' || $activoValue === 'si' || $activoValue === 'yes' || $activoValue === '1' || $activoValue === 'true');
                    
                    // Determinar si es inserción o actualización
                    $esActualizacion = false;
                    $idExistente = null;
                    
                    // Si tiene ID, intentar actualizar por ID
                    if (!empty($id) && is_numeric($id)) {
                        $stmt_check = $conn->prepare("SELECT id FROM funcionario WHERE id = ?");
                        $stmt_check->bind_param("i", $id);
                        $stmt_check->execute();
                        $result_check = $stmt_check->get_result();
                        
                        if ($result_check->num_rows > 0) {
                            $esActualizacion = true;
                            $idExistente = $id;
                        }
                        $stmt_check->close();
                    }
                    
                    // Si no tiene ID o no existe, verificar por nombre
                    if (!$esActualizacion) {
                        $stmt_check = $conn->prepare("SELECT id FROM funcionario WHERE nombre = ?");
                        $stmt_check->bind_param("s", $nombre);
                        $stmt_check->execute();
                        $result_check = $stmt_check->get_result();
                        
                        if ($result_check->num_rows > 0) {
                            $existente = $result_check->fetch_assoc();
                            $idExistente = $existente['id'];
                            $esActualizacion = true;
                        }
                        $stmt_check->close();
                    }
                    
                    // Ejecutar operación según el modo
                    if ($esActualizacion) {
                        if ($modo === 'crear') {
                            if ($sobrescribir_existentes) {
                                // Actualizar
                                $stmt_update = $conn->prepare("
                                    UPDATE funcionario 
                                    SET nombre = ?, cargo = ?, empresa = ?, activo = ?, 
                                        usuario_modificacion = ?, fecha_modificacion = NOW()
                                    WHERE id = ?
                                ");
                                $stmt_update->bind_param("sssiii", $nombre, $cargo, $empresa, $activoBool, $currentUser['id'], $idExistente);
                                
                                if ($stmt_update->execute()) {
                                    $resultados['actualizados']++;
                                } else {
                                    $resultados['errores'][] = "Fila $row: Error actualizando - " . $stmt_update->error;
                                    $resultados['omitidos']++;
                                }
                                $stmt_update->close();
                            } else {
                                $resultados['errores'][] = "Fila $row: '$nombre' ya existe (omitido)";
                                $resultados['omitidos']++;
                            }
                        } else {
                            // Actualizar
                            $stmt_update = $conn->prepare("
                                UPDATE funcionario 
                                SET nombre = ?, cargo = ?, empresa = ?, activo = ?, 
                                    usuario_modificacion = ?, fecha_modificacion = NOW()
                                WHERE id = ?
                            ");
                            $stmt_update->bind_param("sssiii", $nombre, $cargo, $empresa, $activoBool, $currentUser['id'], $idExistente);
                            
                            if ($stmt_update->execute()) {
                                $resultados['actualizados']++;
                            } else {
                                $resultados['errores'][] = "Fila $row: Error actualizando - " . $stmt_update->error;
                                $resultados['omitidos']++;
                            }
                            $stmt_update->close();
                        }
                    } else {
                        // Insertar nuevo
                        if ($modo === 'actualizar') {
                            $resultados['errores'][] = "Fila $row: '$nombre' no existe para actualizar (omitido)";
                            $resultados['omitidos']++;
                        } else {
                            $stmt_insert = $conn->prepare("
                                INSERT INTO funcionario (nombre, cargo, empresa, activo, fecha_creacion, usuario_creacion)
                                VALUES (?, ?, ?, ?, NOW(), ?)
                            ");
                            $stmt_insert->bind_param("sssii", $nombre, $cargo, $empresa, $activoBool, $currentUser['id']);
                            
                            if ($stmt_insert->execute()) {
                                $resultados['insertados']++;
                            } else {
                                $resultados['errores'][] = "Fila $row: Error insertando - " . $stmt_insert->error;
                                $resultados['omitidos']++;
                            }
                            $stmt_insert->close();
                        }
                    }
                    
                } catch (Exception $e) {
                    $resultados['errores'][] = "Fila $row: " . $e->getMessage();
                    $resultados['omitidos']++;
                }
            }
            
            // Confirmar transacción
            if ($resultados['insertados'] > 0 || $resultados['actualizados'] > 0) {
                $conn->commit();
            } else {
                $conn->rollback();
                throw new Exception('No se realizaron cambios. Verifica los datos e intenta nuevamente.');
            }
            
            // Liberar recursos
            $spreadsheet->disconnectWorksheets();
            unset($spreadsheet);
            
            // Eliminar archivo temporal
            @unlink($tempFile);
            
            // PASO 10: Respuesta exitosa
            $mensaje = "Importación completada: {$resultados['insertados']} insertados, {$resultados['actualizados']} actualizados, {$resultados['omitidos']} omitidos";
            
            sendJsonResponse([
                'success' => true,
                'message' => $mensaje,
                'data' => [
                    'resultados' => $resultados,
                    'total_filas' => $highestRow - 1,
                    'modo' => $modo,
                    'importado_por' => $currentUser['usuario'],
                    'fecha_importacion' => date('Y-m-d H:i:s')
                ]
            ], 200);
            
        } catch (Exception $e) {
            $conn->rollback();
            throw $e;
        }
        
    } finally {
        // Asegurar limpieza de archivos temporales
        if (isset($tempFile) && file_exists($tempFile)) {
            @unlink($tempFile);
        }
    }
    
} catch (Exception $e) {
    if (isset($conn)) {
        $conn->rollback();
    }
    
    // Limpiar archivo temporal en caso de error
    if (isset($tempFile) && file_exists($tempFile)) {
        @unlink($tempFile);
    }
    
    error_log('Error importando Excel: ' . $e->getMessage());
    sendJsonResponse(errorResponse('Error en importación: ' . $e->getMessage()), 500);
}

// Cerrar conexión
if (isset($conn) && $conn !== null) {
    $conn->close();
}
?>