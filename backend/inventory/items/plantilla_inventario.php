<?php
require_once '../../login/auth_middleware.php';
$currentUser = requireAuth();
// logAccess($currentUser, '/inventory/items/plantilla_inventario.php', 'download_inventory_template');

header("Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
header("Content-Disposition: attachment; filename=plantilla_inventario.xlsx");

require_once '../../vendor/autoload.php';
require '../../conexion.php'; // Incluir conexión para listas dinámicas

use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;
use PhpOffice\PhpSpreadsheet\Style\Color;
use PhpOffice\PhpSpreadsheet\Style\Fill;
use PhpOffice\PhpSpreadsheet\Cell\DataValidation;
use PhpOffice\PhpSpreadsheet\NamedRange;

try {
    // 1. OBTENER DATOS PARA LISTAS DESPLEGABLES

    // Categorías
    $categories = [];
    $resCat = $conn->query("SELECT name FROM inventory_categories ORDER BY name ASC");
    if ($resCat) {
        while ($row = $resCat->fetch_assoc()) {
            $categories[] = $row['name'];
        }
    }

    // Proveedores
    $suppliers = [];
    $resSup = $conn->query("SELECT name FROM suppliers ORDER BY name ASC");
    if ($resSup) {
        while ($row = $resSup->fetch_assoc()) {
            $suppliers[] = $row['name'];
        }
    }

    // Tipos y Unidades (Listas estáticas robustas)
    $types = ['Repuesto', 'Insumo', 'Herramienta', 'Consumible', 'Activo Fijo', 'Material', 'Fluido', 'Servicio', 'Otro'];
    $units = [
        'UND - UNIDAD', 'PZA - PIEZA', 'KIT - KIT', 'JGO - JUEGO', 'PAR - PAR',
        'M - METRO', 'CM - CENTÍMETRO', 'MM - MILÍMETRO', 'KM - KILÓMETRO',
        'KG - KILOGRAMO', 'G - GRAMO', 'LB - LIBRA',
        'L - LITRO', 'ML - MILILITRO', 'GAL - GALÓN',
        'CAJ - CAJA', 'PAQ - PAQUETE', 'BL - BLISTER', 'ROL - ROLLO', 'SAC - SACO',
        'HR - HORA', 'DIA - DÍA', 'SERV - SERVICIO'
    ];

    // 2. CREAR SPREADSHEET
    $spreadsheet = new Spreadsheet();
    $sheet = $spreadsheet->getActiveSheet();
    $sheet->setTitle('Inventario');

    // Headers de la plantilla
    $headers = [
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

    $sheet->fromArray($headers, NULL, 'A1');

    // Estilos Header
    $headerStyle = [
        'font' => ['bold' => true, 'color' => ['rgb' => 'FFFFFF']],
        'fill' => [
            'fillType' => Fill::FILL_SOLID,
            'startColor' => ['rgb' => '2E7D32']
        ],
        'alignment' => ['horizontal' => 'center'],
    ];
    $lastColumn = \PhpOffice\PhpSpreadsheet\Cell\Coordinate::stringFromColumnIndex(count($headers));
    $sheet->getStyle('A1:' . $lastColumn . '1')->applyFromArray($headerStyle);

    // 3. HOJA OCULTA DE DATOS (Para validaciones)
    $dataSheet = $spreadsheet->createSheet();
    $dataSheet->setTitle('DataReference');
    $dataSheet->setSheetState(\PhpOffice\PhpSpreadsheet\Worksheet\Worksheet::SHEETSTATE_HIDDEN);

    // Escribir listas en columnas
    function writeListStatus($sheet, $col, $data)
    {
        $row = 1;
        foreach ($data as $item) {
            $sheet->setCellValue($col . $row, $item);
            $row++;
        }
        return $row - 1; // Última fila con datos
    }

    $maxRowCat = writeListStatus($dataSheet, 'A', $categories);
    $maxRowSup = writeListStatus($dataSheet, 'B', $suppliers);
    $maxRowTyp = writeListStatus($dataSheet, 'C', $types);
    $maxRowUnt = writeListStatus($dataSheet, 'D', $units);

    // Definir Rangos Nombrados
    // Cuidado: Si la lista está vacía, el rango será inválido.
    if ($maxRowCat > 0)
        $spreadsheet->addNamedRange(new NamedRange('ListCategories', $dataSheet, '$A$1:$A$' . $maxRowCat));
    if ($maxRowSup > 0)
        $spreadsheet->addNamedRange(new NamedRange('ListSuppliers', $dataSheet, '$B$1:$B$' . $maxRowSup));
    if ($maxRowTyp > 0)
        $spreadsheet->addNamedRange(new NamedRange('ListTypes', $dataSheet, '$C$1:$C$' . $maxRowTyp));
    if ($maxRowUnt > 0)
        $spreadsheet->addNamedRange(new NamedRange('ListUnits', $dataSheet, '$D$1:$D$' . $maxRowUnt));

    // 4. APLICAR VALIDACIÓN DE DATOS
    // Columnas según Headers: 
    // E (5) = Categoría, F (6) = Proveedor, G (7) = Tipo, H (8) = Unidad

    $validationRange = 1000; // Aplicar hasta la fila 1000

    // Helper function
    function applyValidation($sheet, $columnChar, $namedRange, $rows)
    {
        if (!$namedRange)
            return; // Si no hay datos, no aplicar validación

        $validation = $sheet->getCell($columnChar . '2')->getDataValidation();
        $validation->setType(DataValidation::TYPE_LIST);
        $validation->setErrorStyle(DataValidation::STYLE_INFORMATION);
        $validation->setAllowBlank(true);
        $validation->setShowInputMessage(true);
        $validation->setShowErrorMessage(true);
        $validation->setShowDropDown(true);
        $validation->setFormula1("=$namedRange"); // Referencia al Rango Nombrado

        // Clonar para el resto de filas
        for ($i = 3; $i <= $rows; $i++) {
            $sheet->getCell($columnChar . $i)->setDataValidation(clone $validation);
        }
    }

    if ($maxRowCat > 0)
        applyValidation($sheet, 'E', 'ListCategories', $validationRange);
    if ($maxRowSup > 0)
        applyValidation($sheet, 'F', 'ListSuppliers', $validationRange);
    if ($maxRowTyp > 0)
        applyValidation($sheet, 'G', 'ListTypes', $validationRange);
    if ($maxRowUnt > 0)
        applyValidation($sheet, 'H', 'ListUnits', $validationRange);

    // 5. EJEMPLOS
    $ejemplos = [
        [
            '',
            'INV001',
            'Tornillo hexagonal M8x20',
            'Tornillo hexagonal de acero inoxidable',
            $categories[0] ?? 'Ferretería',
            $suppliers[0] ?? 'Tornillos SA',
            'Material',
            'UND - UNIDAD',
            'ACME',
            'M8x20',
            'TH-M8-20',
            '10.50',
            '15.00',
            '100',
            '20',
            '500',
            'A-01',
            'A',
            '01',
            '7891234567890',
            '',
            'true',
            '',
            ''
        ],
        [
            '',
            'INV002',
            'Aceite motor 20W-50',
            'Aceite lubricante para motores diesel',
            $categories[1] ?? 'Lubricantes',
            $suppliers[1] ?? 'Lubricantes XYZ',
            'Fluido',
            'L - LITRO',
            'Shell',
            'Rimula R4',
            'SH-R4-20W50',
            '120.00',
            '150.00',
            '50',
            '10',
            '100',
            'B-02',
            'B',
            '02',
            '7891234567891',
            '',
            'true',
            '',
            ''
        ]
    ];

    $row = 2;
    foreach ($ejemplos as $ejemplo) {
        $sheet->fromArray($ejemplo, NULL, 'A' . $row);
        $row++;
    }

    // Auto-size columns
    for ($i = 1; $i <= count($headers); $i++) {
        $col = \PhpOffice\PhpSpreadsheet\Cell\Coordinate::stringFromColumnIndex($i);
        $sheet->getColumnDimension($col)->setAutoSize(true);
    }

    // 6. INSTRUCCIONES
    $instructionsSheet = $spreadsheet->createSheet();
    $instructionsSheet->setTitle('Instrucciones');

    $instructions = [
        ['INSTRUCCIONES PARA IMPORTAR INVENTARIO'],
        [''],
        ['TIPOS DE DATOS:'],
        ['• Las columnas Categoría, Proveedor, Tipo y Unidad tienen listas desplegables.'],
        ['• Puede seleccionar una opción de la lista o escribir un valor nuevo.'],
        ['• Si escribe un valor nuevo para Categoría o Proveedor, se creará al importar.'],
        [''],
        ['CAMPOS OBLIGATORIOS (*):'],
        ['• SKU, Nombre, Tipo, Unidad de Medida, Costo Inicial, Precio de Venta, Stock Actual, Stock Mínimo'],
        [''],
        ['CAMPOS OPCIONALES:'],
        ['• ID, Descripción, Categoría, Proveedor, Marca, Modelo, Stock Máximo, etc.'],
        [''],
        ['NOTAS:'],
        ['• No elimine la fila de encabezados.'],
        ['• No elimine la hoja "DataReference" (está oculta).']
    ];

    $instructionsSheet->fromArray($instructions, NULL, 'A1');
    $instructionsSheet->getColumnDimension('A')->setAutoSize(true);
    $instructionsSheet->getStyle('A1')->getFont()->setBold(true)->setSize(14)->setColor(new Color(Color::COLOR_DARKGREEN));

    // Volver a la hoja principal
    $spreadsheet->setActiveSheetIndex(0);

    // Generar
    $writer = new Xlsx($spreadsheet);
    $writer->save('php://output');

    if (isset($conn))
        $conn->close();

} catch (Exception $e) {
    header("Content-Type: application/json");
    echo json_encode(['error' => 'Error al generar plantilla de inventario: ' . $e->getMessage()]);
}
?>