<?php
require_once '../../login/auth_middleware.php';
$currentUser = requireAuth();
// logAccess($currentUser, '/inventory/items/importar_inventario.php', 'import_inventory');

header("Content-Type: application/json");

// Solo procesar POST requests
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Método no permitido']);
    exit;
}

require '../../conexion.php';
require_once '../../vendor/autoload.php';

use PhpOffice\PhpSpreadsheet\IOFactory;

try {
    // Verificar conexión a la base de datos
    if (!isset($conn) || $conn->connect_error) {
        throw new Exception('Error de conexión a la base de datos');
    }

    // Obtener datos del request
    $input = json_decode(file_get_contents('php://input'), true);

    if (!isset($input['archivo_base64']) || empty($input['archivo_base64'])) {
        throw new Exception('No se recibió archivo');
    }

    // Obtener opciones
    $options = $input['options'] ?? [];
    $updateExisting = isset($options['update_existing']) ? filter_var($options['update_existing'], FILTER_VALIDATE_BOOLEAN) : true;
    $createCategories = isset($options['create_categories']) ? filter_var($options['create_categories'], FILTER_VALIDATE_BOOLEAN) : true;
    $createSuppliers = isset($options['create_suppliers']) ? filter_var($options['create_suppliers'], FILTER_VALIDATE_BOOLEAN) : true;
    $skipFirstRow = isset($options['skip_first_row']) ? filter_var($options['skip_first_row'], FILTER_VALIDATE_BOOLEAN) : true;

    // Decodificar el archivo base64
    $archivoData = base64_decode($input['archivo_base64']);
    if ($archivoData === false) {
        throw new Exception('Error al decodificar archivo');
    }

    // Crear archivo temporal
    $tempFile = tempnam(sys_get_temp_dir(), 'import_inventario_');
    if (file_put_contents($tempFile, $archivoData) === false) {
        throw new Exception('Error al crear archivo temporal');
    }

    // Verificar que PhpSpreadsheet esté disponible
    if (!class_exists('PhpOffice\PhpSpreadsheet\IOFactory')) {
        throw new Exception('PhpSpreadsheet no está instalado');
    }

    // Cargar el archivo Excel
    $spreadsheet = IOFactory::load($tempFile);
    $sheet = $spreadsheet->getActiveSheet();
    $data = $sheet->toArray();

    // Limpiar archivo temporal
    unlink($tempFile);

    // NUEVO FORMATO DE HEADERS (Sin IDs explícitos)
    $expectedHeaders = [
        'ID',
        'SKU*',
        'Nombre*',
        'Descripción',
        'Nombre Categoría',
        'Nombre Proveedor',
        'Tipo*',
        'Unidad de Medida*',
        'Marca',
        'Modelo',
        'Número de Parte',
        'Costo Inicial*',
        'Precio de Venta*',
        'Stock Actual*',
        'Stock Mínimo*',
        'Stock Máximo',
        'Ubicación',
        'Estante',
        'Compartimiento',
        'Código de Barras',
        'Código QR',
        'Activo',
        'Fecha Creación',
        'Fecha Actualización'
    ];

    if (empty($data) || count($data[0]) < 3) {
        throw new Exception('Formato de archivo inválido. Asegúrese de usar la plantilla correcta.');
    }

    // Headers básicos requeridos para validación (SKU, Nombre)
    // No somos tan estrictos con todo el header para permitir cierta flexibilidad,
    // pero verificamos columna 1 (SKU) y 2 (Nombre) como mínimo.
    $headersEncontrados = array_slice($data[0], 1, 2);
    $headersEsperados = array_slice($expectedHeaders, 1, 2);

    /* 
       Validación laxa de headers para no bloquear por diferencias menores de texto,
       pero si el usuario usa la plantilla vieja (con IDs), los índices fallarán.
       Podríamos detectar formato viejo contando columnas, pero asumiremos formato nuevo.
    */

    $conn->autocommit(FALSE); // Iniciar transacción

    $insertados = 0;
    $actualizados = 0;
    $omitidos = 0;
    $errores = 0;
    $erroresDetalle = [];

    // Determinar desde dónde empezar
    $startIndex = $skipFirstRow ? 1 : 0;

    // Procesar datos
    for ($i = $startIndex; $i < count($data); $i++) {
        $row = $data[$i];
        $numeroFila = $i + 1;

        // Validar datos mínimos requeridos (SKU, Nombre, Tipo, Unidad, Costo Inicial, Precio Venta, Stock Actual, Stock Mínimo)
        if (empty($row[1]) || empty($row[2]) || empty($row[6]) || empty($row[7]) || 
            empty($row[11]) || empty($row[12]) || empty($row[13]) || empty($row[14])) {
            $errores++;
            $erroresDetalle[] = "FILA $numeroFila: FALTAN CAMPOS OBLIGATORIOS (SKU, NOMBRE, TIPO, UNIDAD, COSTOS O STOCKS)";
            continue;
        }

        // Extraer datos de la fila con NUEVOS INDICES
        $sku = trim($row[1]);
        $nombre = trim($row[2]);
        $descripcion = trim($row[3] ?? '');

        // Categoría y Proveedor por nombre solamente
        $categoryName = trim($row[4] ?? '');
        $supplierName = trim($row[5] ?? '');

        $itemType = trim($row[6]);
        $unitOfMeasure = trim($row[7]);
        // Extraer código si viene en formato "CODE - NAME"
        if (strpos($unitOfMeasure, ' - ') !== false) {
            $parts = explode(' - ', $unitOfMeasure);
            $unitOfMeasure = trim($parts[0]);
        }
        $brand = trim($row[8] ?? '');
        $model = trim($row[9] ?? '');
        $partNumber = trim($row[10] ?? '');

        $initialCost = !empty($row[11]) ? floatval($row[11]) : 0.0;
        $unitCost = !empty($row[12]) ? floatval($row[12]) : 0.0;
        
        // Validación de valores mayores a 0 para campos obligatorios
        if ($initialCost <= 0 || $unitCost <= 0) {
            $errores++;
            $erroresDetalle[] = "FILA $numeroFila: EL COSTO INICIAL Y PRECIO DE VENTA DEBEN SER MAYORES A 0";
            continue;
        }

        $currentStock = !empty($row[13]) ? floatval($row[13]) : 0.0;
        $minimumStock = !empty($row[14]) ? floatval($row[14]) : 0.0;
        
        if ($currentStock <= 0 || $minimumStock <= 0) {
            $errores++;
            $erroresDetalle[] = "FILA $numeroFila: EL STOCK ACTUAL Y STOCK MÍNIMO DEBEN SER MAYORES A 0";
            continue;
        }

        $maximumStock = !empty($row[15]) ? floatval($row[15]) : 0.0;
        $location = trim($row[16] ?? '');
        $shelf = trim($row[17] ?? '');
        $bin = trim($row[18] ?? '');
        $barcode = trim($row[19] ?? '');
        $qrCode = trim($row[20] ?? '');
        $isActive = empty($row[21]) || strtolower($row[21]) === 'true' ? 1 : 0;

        // Validar longitudes
        if (strlen($sku) > 50 || strlen($nombre) > 255 || strlen($itemType) > 50) {
            $errores++;
            $erroresDetalle[] = "Fila $numeroFila: Algunos campos exceden la longitud máxima";
            continue;
        }

        try {
            // RESOLVER ID CATEGORÍA
            $categoryId = null;
            if ($categoryName) {
                // Buscar por nombre
                $stmt = $conn->prepare("SELECT id FROM inventory_categories WHERE name = ?");
                $stmt->bind_param("s", $categoryName);
                $stmt->execute();
                $res = $stmt->get_result();

                if ($res->num_rows > 0) {
                    $categoryId = $res->fetch_assoc()['id'];
                } elseif ($createCategories) {
                    // Crear
                    $stmt = $conn->prepare("INSERT INTO inventory_categories (name, description, created_at) VALUES (?, ?, NOW())");
                    $stmt->bind_param("ss", $categoryName, $categoryName);
                    if ($stmt->execute()) {
                        $categoryId = $conn->insert_id;
                    }
                }
            }

            // RESOLVER ID PROVEEDOR
            $supplierId = null;
            if ($supplierName) {
                // Buscar por nombre
                $stmt = $conn->prepare("SELECT id FROM suppliers WHERE name = ?");
                $stmt->bind_param("s", $supplierName);
                $stmt->execute();
                $res = $stmt->get_result();

                if ($res->num_rows > 0) {
                    $supplierId = $res->fetch_assoc()['id'];
                } elseif ($createSuppliers) {
                    // Crear
                    $stmt = $conn->prepare("INSERT INTO suppliers (name, created_at) VALUES (?, NOW())");
                    $stmt->bind_param("s", $supplierName);
                    if ($stmt->execute()) {
                        $supplierId = $conn->insert_id;
                    }
                }
            }

            // Verificar si item existe por SKU
            $stmt = $conn->prepare("SELECT id FROM inventory_items WHERE sku = ? AND is_active = 1");
            $stmt->bind_param("s", $sku);
            $stmt->execute();
            $result = $stmt->get_result();

            if ($result->num_rows > 0) {
                // UPDATE
                if ($updateExisting) {
                    $item = $result->fetch_assoc();
                    $stmt = $conn->prepare("
                        UPDATE inventory_items SET 
                            name = ?, description = ?, category_id = ?, supplier_id = ?,
                            item_type = ?, unit_of_measure = ?, brand = ?, model = ?, part_number = ?,
                            initial_cost = ?, unit_cost = ?, current_stock = ?,
                            minimum_stock = ?, maximum_stock = ?, location = ?, shelf = ?, bin = ?,
                            barcode = ?, qr_code = ?, is_active = ?, updated_at = NOW()
                        WHERE id = ?
                    ");

                    $stmt->bind_param(
                        "ssiisssssddiiisssssii",
                        $nombre,
                        $descripcion,
                        $categoryId,
                        $supplierId,
                        $itemType,
                        $unitOfMeasure,
                        $brand,
                        $model,
                        $partNumber,
                        $initialCost,
                        $unitCost,
                        $currentStock,
                        $minimumStock,
                        $maximumStock,
                        $location,
                        $shelf,
                        $bin,
                        $barcode,
                        $qrCode,
                        $isActive,
                        $item['id']
                    );

                    if ($stmt->execute()) {
                        $actualizados++;
                    } else {
                        throw new Exception("Error al actualizar: " . $stmt->error);
                    }
                } else {
                    $omitidos++;
                }
            } else {
                // INSERT
                $stmt = $conn->prepare("
                    INSERT INTO inventory_items (
                        sku, name, description, category_id, supplier_id,
                        item_type, unit_of_measure, brand, model, part_number,
                        initial_cost, unit_cost, current_stock,
                        minimum_stock, maximum_stock, location, shelf, bin,
                        barcode, qr_code, is_active, created_at, updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
                ");

                $stmt->bind_param(
                    "sssiisssssddiiisssssi",
                    $sku,
                    $nombre,
                    $descripcion,
                    $categoryId,
                    $supplierId,
                    $itemType,
                    $unitOfMeasure,
                    $brand,
                    $model,
                    $partNumber,
                    $initialCost,
                    $unitCost,
                    $currentStock,
                    $minimumStock,
                    $maximumStock,
                    $location,
                    $shelf,
                    $bin,
                    $barcode,
                    $qrCode,
                    $isActive
                );

                if ($stmt->execute()) {
                    $insertados++;
                } else {
                    throw new Exception("Error al insertar: " . $stmt->error);
                }
            }
        } catch (Exception $rowError) {
            $errores++;
            $msg = $rowError->getMessage();

            // Traducción de errores (manteniendo lo que arreglamos antes)
            if (strpos($msg, "doesn't exist") !== false && strpos($msg, "Table") !== false) {
                $friendlyMsg = "Error interno: Configuración de base de datos incorrecta.";
            } elseif (strpos($msg, "Duplicate entry") !== false) {
                $friendlyMsg = "Error de datos: El registro/SKU ya existe duplicado.";
            } elseif (strpos($msg, "Data too long") !== false) {
                $friendlyMsg = "Error de datos: Un campo excede la longitud permitida.";
            } else {
                $friendlyMsg = $msg;
            }

            $erroresDetalle[] = "Fila $numeroFila: " . $friendlyMsg;
        }
    }

    $conn->commit();

    $mensaje = "Importación completada: $insertados nuevos, $actualizados actualizados";
    if ($errores > 0) {
        $mensaje .= ", $errores errores";
    }

    $response = [
        'success' => true,
        'message' => $mensaje,
        'insertados' => $insertados,
        'actualizados' => $actualizados,
        'omitidos' => $omitidos,
        'errores' => $errores
    ];

    if ($errores > 0) {
        $response['errores_detalle'] = $erroresDetalle;
    }

    echo json_encode($response);

} catch (Exception $e) {
    if (isset($conn))
        $conn->rollback();
    if (isset($tempFile) && file_exists($tempFile))
        unlink($tempFile);

    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}

if (isset($conn))
    $conn->close();
?>