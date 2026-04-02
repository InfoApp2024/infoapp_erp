<?php
require_once '../../login/auth_middleware.php';
$currentUser = requireAuth();
// logAccess($currentUser, '/inventory/items/exportar_inventario.php', 'export_inventory');

// Headers CORS
header("Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
header("Content-Disposition: attachment; filename=inventario_" . date('Y-m-d_H-i-s') . ".xlsx");

// Incluir dependencias
require_once '../../vendor/autoload.php';

use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;
use PhpOffice\PhpSpreadsheet\Style\Color;
use PhpOffice\PhpSpreadsheet\Style\Fill;
use PhpOffice\PhpSpreadsheet\Cell\DataValidation;
use PhpOffice\PhpSpreadsheet\NamedRange;

try {
    require '../../conexion.php';

    // Obtener datos del POST
    $input = [];
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $input = json_decode(file_get_contents('php://input'), true);
        if (json_last_error() !== JSON_ERROR_NONE) {
            $input = [];
        }
    }

    // Parámetros de configuración
    $selectedFields = $input['selected_fields'] ?? [];
    $includeHeaders = isset($input['include_headers']) ? filter_var($input['include_headers'], FILTER_VALIDATE_BOOLEAN) : true;

    // Mapeo detallado
    $fieldMap = [
        'id' => ['header' => 'ID', 'key' => 'id'],
        'sku' => ['header' => 'SKU*', 'key' => 'sku'],
        'name' => ['header' => 'Nombre*', 'key' => 'name'],
        'description' => ['header' => 'Descripción', 'key' => 'description'],
        'categoryName' => ['header' => 'Nombre Categoría', 'key' => 'category_name'],
        'supplierName' => ['header' => 'Nombre Proveedor', 'key' => 'supplier_name'],
        'itemType' => ['header' => 'Tipo*', 'key' => 'item_type'],
        'unitOfMeasure' => ['header' => 'Unidad de Medida*', 'key' => 'unit_of_measure'],
        'brand' => ['header' => 'Marca', 'key' => 'brand'],
        'model' => ['header' => 'Modelo', 'key' => 'model'],
        'partNumber' => ['header' => 'Número de Parte', 'key' => 'part_number'],
        'initialCost' => ['header' => 'Costo Inicial*', 'key' => 'initial_cost'],
        'unitCost' => ['header' => 'Precio de Venta*', 'key' => 'unit_cost'],
        'currentStock' => ['header' => 'Stock Actual*', 'key' => 'current_stock'],
        'minimumStock' => ['header' => 'Stock Mínimo*', 'key' => 'minimum_stock'],
        'maximumStock' => ['header' => 'Stock Máximo', 'key' => 'maximum_stock'],
        'location' => ['header' => 'Ubicación', 'key' => 'location'],
        'shelf' => ['header' => 'Estante', 'key' => 'shelf'],
        'bin' => ['header' => 'Compartimiento', 'key' => 'bin'],
        'barcode' => ['header' => 'Código de Barras', 'key' => 'barcode'],
        'qrCode' => ['header' => 'Código QR', 'key' => 'qr_code'],
        'isActive' => ['header' => 'Activo', 'key' => 'is_active'],
        'createdAt' => ['header' => 'Fecha Creación', 'key' => 'created_at'],
        'updatedAt' => ['header' => 'Fecha Actualización', 'key' => 'updated_at'],
    ];

    // OMITIMOS ID CATEGORIA Y ID PROVEEDOR EN EXPORTACION TAMBIEN PARA CONSISTENCIA
    // Aunque el usuario no los pidió explicitamente en la exportación, si la plantilla no los tiene, el export tampoco debería si es para "round-trip".
    // Pero el usuario elige los campos en el frontend. Si el frontend ya no manda 'categoryId' ni 'supplierId', entonces esto está bien.

    // Si no hay campos seleccionados, usar todos
    if (empty($selectedFields)) {
        $activeKeys = array_keys($fieldMap);
    } else {
        $activeKeys = array_filter($selectedFields, function ($key) use ($fieldMap) {
            return isset($fieldMap[$key]);
        });
        if (empty($activeKeys))
            $activeKeys = array_keys($fieldMap);
    }

    // OBTENER ITEMS
    $items = [];
    if (isset($input['items']) && !empty($input['items'])) {
        $items = $input['items'];
    } else {
        // Consultar DB
        $sql = "SELECT 
                    i.id, i.sku, i.name, i.description, 
                    i.category_id, ic.name as category_name,
                    i.supplier_id, s.name as supplier_name,
                    i.item_type, i.unit_of_measure, i.brand, i.model, i.part_number,
                    i.initial_cost, i.unit_cost,
                    i.current_stock, i.minimum_stock, i.maximum_stock,
                    i.location, i.shelf, i.bin,
                    i.barcode, i.qr_code, i.is_active,
                    i.created_at, i.updated_at
                FROM inventory_items i
                LEFT JOIN inventory_categories ic ON i.category_id = ic.id
                LEFT JOIN suppliers s ON i.supplier_id = s.id
                WHERE i.is_active = 1 
                ORDER BY i.name";

        $result = $conn->query($sql);
        if ($result) {
            while ($row = $result->fetch_assoc()) {
                $items[] = $row;
            }
        }
    }

    // CREAR SPREADSHEET
    $spreadsheet = new Spreadsheet();
    $sheet = $spreadsheet->getActiveSheet();
    $sheet->setTitle('Inventario');

    $currentRow = 1;

    // --- PREPARAR DATOS PARA DROPDOWNS ---
    $categories = [];
    $resCat = $conn->query("SELECT name FROM inventory_categories ORDER BY name ASC");
    if ($resCat) {
        while ($row = $resCat->fetch_assoc())
            $categories[] = $row['name'];
    }

    $suppliers = [];
    $resSup = $conn->query("SELECT name FROM suppliers ORDER BY name ASC");
    if ($resSup) {
        while ($row = $resSup->fetch_assoc())
            $suppliers[] = $row['name'];
    }

    $types = ['Repuesto', 'Insumo', 'Herramienta', 'Consumible', 'Activo Fijo', 'Material', 'Fluido', 'Servicio', 'Otro'];
    $units = [
        'UND - UNIDAD', 'PZA - PIEZA', 'KIT - KIT', 'JGO - JUEGO', 'PAR - PAR',
        'M - METRO', 'CM - CENTÍMETRO', 'MM - MILÍMETRO', 'KM - KILÓMETRO',
        'KG - KILOGRAMO', 'G - GRAMO', 'LB - LIBRA',
        'L - LITRO', 'ML - MILILITRO', 'GAL - GALÓN',
        'CAJ - CAJA', 'PAQ - PAQUETE', 'BL - BLISTER', 'ROL - ROLLO', 'SAC - SACO',
        'HR - HORA', 'DIA - DÍA', 'SERV - SERVICIO'
    ];


    // --- HOJA OCULTA ---
    $dataSheet = $spreadsheet->createSheet();
    $dataSheet->setTitle('DataReference');
    $dataSheet->setSheetState(\PhpOffice\PhpSpreadsheet\Worksheet\Worksheet::SHEETSTATE_HIDDEN);

    function writeList($sheet, $col, $data)
    {
        $row = 1;
        foreach ($data as $item) {
            $sheet->setCellValue($col . $row, $item);
            $row++;
        }
        return $row - 1;
    }

    $mrCat = writeList($dataSheet, 'A', $categories);
    $mrSup = writeList($dataSheet, 'B', $suppliers);
    $mrTyp = writeList($dataSheet, 'C', $types);
    $mrUnt = writeList($dataSheet, 'D', $units);

    if ($mrCat > 0)
        $spreadsheet->addNamedRange(new NamedRange('ListCategories', $dataSheet, '$A$1:$A$' . $mrCat));
    if ($mrSup > 0)
        $spreadsheet->addNamedRange(new NamedRange('ListSuppliers', $dataSheet, '$B$1:$B$' . $mrSup));
    if ($mrTyp > 0)
        $spreadsheet->addNamedRange(new NamedRange('ListTypes', $dataSheet, '$C$1:$C$' . $mrTyp));
    if ($mrUnt > 0)
        $spreadsheet->addNamedRange(new NamedRange('ListUnits', $dataSheet, '$D$1:$D$' . $mrUnt));

    // --- ESCRIBIR HEADERS ---
    if ($includeHeaders) {
        $colIndex = 1;
        foreach ($activeKeys as $fieldKey) {
            $mappedHeader = $fieldMap[$fieldKey]['header'];
            $colLetter = \PhpOffice\PhpSpreadsheet\Cell\Coordinate::stringFromColumnIndex($colIndex);
            $sheet->setCellValue($colLetter . $currentRow, $mappedHeader);
            $colIndex++;
        }
        $lastCol = \PhpOffice\PhpSpreadsheet\Cell\Coordinate::stringFromColumnIndex(count($activeKeys));
        $headerStyle = [
            'font' => ['bold' => true, 'color' => ['rgb' => 'FFFFFF']],
            'fill' => ['fillType' => Fill::FILL_SOLID, 'startColor' => ['rgb' => '2E7D32']],
            'alignment' => ['horizontal' => 'center'],
        ];
        if (count($activeKeys) > 0)
            $sheet->getStyle('A1:' . $lastCol . '1')->applyFromArray($headerStyle);
        $currentRow++;
    }

    // --- ESCRIBIR DATOS ---
    foreach ($items as $item) {
        $colIndex = 1;
        foreach ($activeKeys as $fieldKey) {
            $colLetter = \PhpOffice\PhpSpreadsheet\Cell\Coordinate::stringFromColumnIndex($colIndex);
            $dataKey = $fieldMap[$fieldKey]['key'];
            $value = $item[$dataKey] ?? '';

            if ($fieldKey === 'isActive') {
                $value = ($value === 1 || $value === '1' || $value === true || $value === 'true') ? 'true' : 'false';
            }

            $sheet->setCellValue($colLetter . $currentRow, $value);
            $colIndex++;
        }
        $currentRow++;
    }

    // --- APLICAR VALIDACION ---
    // Recorremos las columnas activas para ver si alguna corresponde a nuestros campos validados
    $colIndex = 1;
    $totalRows = max($currentRow, 100); // Al menos hasta 100 o hasta donde haya datos para permitir agregar más

    foreach ($activeKeys as $fieldKey) {
        $colLetter = \PhpOffice\PhpSpreadsheet\Cell\Coordinate::stringFromColumnIndex($colIndex);
        $namedRange = null;

        if ($fieldKey === 'categoryName')
            $namedRange = 'ListCategories';
        elseif ($fieldKey === 'supplierName')
            $namedRange = 'ListSuppliers';
        elseif ($fieldKey === 'itemType')
            $namedRange = 'ListTypes';
        elseif ($fieldKey === 'unitOfMeasure')
            $namedRange = 'ListUnits';

        if ($namedRange) {
            // Aplicar validación a toda la columna (desde fila 2 hasta 5000 para edición futura)
            $validation = $sheet->getCell($colLetter . '2')->getDataValidation();
            $validation->setType(DataValidation::TYPE_LIST);
            $validation->setErrorStyle(DataValidation::STYLE_INFORMATION);
            $validation->setAllowBlank(true);
            $validation->setShowInputMessage(true);
            $validation->setShowErrorMessage(true);
            $validation->setShowDropDown(true);
            $validation->setFormula1("=$namedRange");

            // Clonar para el rango
            for ($r = 3; $r <= 5000; $r++) {
                $sheet->getCell($colLetter . $r)->setDataValidation(clone $validation);
            }
        }
        $colIndex++;
    }

    // Auto-size
    for ($i = 1; $i <= count($activeKeys); $i++) {
        $colLetter = \PhpOffice\PhpSpreadsheet\Cell\Coordinate::stringFromColumnIndex($i);
        $sheet->getColumnDimension($colLetter)->setAutoSize(true);
    }

    // Generar archivo
    $spreadsheet->setActiveSheetIndex(0);
    $writer = new Xlsx($spreadsheet);
    $writer->save('php://output');

    if (isset($conn))
        $conn->close();

} catch (Exception $e) {
    header("Content-Type: application/json");
    echo json_encode(['error' => 'Error al exportar inventario: ' . $e->getMessage()]);
}
?>