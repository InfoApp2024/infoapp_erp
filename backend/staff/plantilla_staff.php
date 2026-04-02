<?php
// Headers CORS
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

// Manejar preflight requests
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}

// Headers para descarga de Excel
header("Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
header("Content-Disposition: attachment; filename=plantilla_empleados_" . date('Y-m-d') . ".xlsx");

// Incluir dependencias
require_once '../../vendor/autoload.php';

use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;
use PhpOffice\PhpSpreadsheet\Style\Color;
use PhpOffice\PhpSpreadsheet\Style\Fill;
use PhpOffice\PhpSpreadsheet\Style\Border;
use PhpOffice\PhpSpreadsheet\Style\Alignment;
use PhpOffice\PhpSpreadsheet\Cell\DataValidation;
use PhpOffice\PhpSpreadsheet\Style\Protection;

try {
    // Incluir conexión para obtener datos de referencia
    require '../../conexion.php';
    
    // Crear spreadsheet
    $spreadsheet = new Spreadsheet();
    
    // === HOJA 1: PLANTILLA PRINCIPAL ===
    $sheet = $spreadsheet->getActiveSheet();
    $sheet->setTitle('Plantilla Empleados');
    
    // Headers de la plantilla
    $headers = [
        'nombres',                    // A - REQUERIDO
        'apellidos',                  // B - REQUERIDO  
        'email',                      // C - REQUERIDO
        'telefono',                   // D - Opcional
        'departamento',               // E - REQUERIDO
        'cargo',                      // F - REQUERIDO
        'fecha_ingreso',              // G - Opcional (formato YYYY-MM-DD)
        'tipo_documento',             // H - Opcional (cedula, dni, passport)
        'numero_documento',           // I - REQUERIDO
        'salario',                    // J - Opcional
        'fecha_nacimiento',           // K - Opcional (formato YYYY-MM-DD)
        'direccion',                  // L - Opcional
        'contacto_emergencia',        // M - Opcional
        'telefono_emergencia'         // N - Opcional
    ];
    
    $sheet->fromArray($headers, NULL, 'A1');
    
    // === APLICAR ESTILOS A HEADERS ===
    $headerStyle = [
        'font' => [
            'bold' => true,
            'color' => ['rgb' => 'FFFFFF'],
            'size' => 12
        ],
        'fill' => [
            'fillType' => Fill::FILL_SOLID,
            'startColor' => ['rgb' => '1976D2']
        ],
        'alignment' => [
            'horizontal' => Alignment::HORIZONTAL_CENTER,
            'vertical' => Alignment::VERTICAL_CENTER
        ],
        'borders' => [
            'allBorders' => [
                'borderStyle' => Border::BORDER_THIN,
                'color' => ['rgb' => '000000']
            ]
        ]
    ];
    
    $sheet->getStyle('A1:N1')->applyFromArray($headerStyle);
    
    // === AGREGAR FILA DE EJEMPLO ===
    $example_data = [
        'Juan Carlos',                 // nombres
        'Pérez García',               // apellidos
        'juan.perez@empresa.com',     // email
        '+57 300 123 4567',           // telefono
        'Desarrollo',                 // departamento
        'Desarrollador Senior',       // cargo
        '2023-01-15',                 // fecha_ingreso
        'cedula',                     // tipo_documento
        '12345678901',                // numero_documento
        '4500000',                    // salario
        '1990-03-20',                 // fecha_nacimiento
        'Calle 123 #45-67, Bogotá',  // direccion
        'María Pérez',                // contacto_emergencia
        '+57 310 987 6543'            // telefono_emergencia
    ];
    
    $sheet->fromArray($example_data, NULL, 'A2');
    
    // Estilo para fila de ejemplo
    $exampleStyle = [
        'fill' => [
            'fillType' => Fill::FILL_SOLID,
            'startColor' => ['rgb' => 'E3F2FD']
        ],
        'font' => [
            'italic' => true,
            'color' => ['rgb' => '1565C0']
        ]
    ];
    
    $sheet->getStyle('A2:N2')->applyFromArray($exampleStyle);
    
    // === AGREGAR VALIDACIONES ===
    
    // Validación para tipo_documento (columna H)
    $validation_tipo_doc = $sheet->getCell('H3')->getDataValidation();
    $validation_tipo_doc->setType(DataValidation::TYPE_LIST);
    $validation_tipo_doc->setErrorStyle(DataValidation::STYLE_INFORMATION);
    $validation_tipo_doc->setAllowBlank(true);
    $validation_tipo_doc->setShowInputMessage(true);
    $validation_tipo_doc->setShowErrorMessage(true);
    $validation_tipo_doc->setErrorTitle('Valor inválido');
    $validation_tipo_doc->setError('Debe seleccionar un tipo de documento válido');
    $validation_tipo_doc->setPromptTitle('Tipo de Documento');
    $validation_tipo_doc->setPrompt('Seleccione: cedula, dni, o passport');
    $validation_tipo_doc->setFormula1('"cedula,dni,passport"');
    
    // Aplicar validación a rango de filas (ejemplo: hasta fila 1000)
    $sheet->getStyle('H3:H1000')->getDataValidation()->setType(DataValidation::TYPE_LIST);
    $sheet->getStyle('H3:H1000')->getDataValidation()->setFormula1('"cedula,dni,passport"');
    $sheet->getStyle('H3:H1000')->getDataValidation()->setAllowBlank(true);
    
    // === OBTENER DATOS DE REFERENCIA DE LA BD ===
    $departments = [];
    $positions = [];
    
    if (isset($conn) && !$conn->connect_error) {
        // Obtener departamentos activos
        $dept_sql = "SELECT name FROM departments WHERE is_active = 1 ORDER BY name";
        $dept_result = $conn->query($dept_sql);
        if ($dept_result) {
            while ($row = $dept_result->fetch_assoc()) {
                $departments[] = $row['name'];
            }
        }
        
        // Obtener posiciones activas
        $pos_sql = "SELECT DISTINCT title FROM positions WHERE is_active = 1 ORDER BY title";
        $pos_result = $conn->query($pos_sql);
        if ($pos_result) {
            while ($row = $pos_result->fetch_assoc()) {
                $positions[] = $row['title'];
            }
        }
    }
    
    // Si no hay datos de BD, usar ejemplos
    if (empty($departments)) {
        $departments = [
            'Administración',
            'Desarrollo',
            'Recursos Humanos',
            'Ventas',
            'Marketing',
            'Contabilidad',
            'Soporte Técnico',
            'Gerencia'
        ];
    }
    
    if (empty($positions)) {
        $positions = [
            'Gerente',
            'Coordinador',
            'Analista',
            'Desarrollador Junior',
            'Desarrollador Senior',
            'Contador',
            'Asistente Administrativo',
            'Vendedor',
            'Soporte Técnico'
        ];
    }
    
    // === CREAR HOJA DE DEPARTAMENTOS ===
    $deptSheet = $spreadsheet->createSheet();
    $deptSheet->setTitle('Departamentos');
    
    $deptSheet->setCellValue('A1', 'Departamentos Disponibles');
    $deptSheet->getStyle('A1')->applyFromArray([
        'font' => ['bold' => true, 'size' => 14, 'color' => ['rgb' => '1976D2']],
    ]);
    
    $row = 2;
    foreach ($departments as $dept) {
        $deptSheet->setCellValue('A' . $row, $dept);
        $row++;
    }
    
    $deptSheet->getColumnDimension('A')->setAutoSize(true);
    
    // === CREAR HOJA DE POSICIONES ===
    $posSheet = $spreadsheet->createSheet();
    $posSheet->setTitle('Posiciones');
    
    $posSheet->setCellValue('A1', 'Posiciones Disponibles');
    $posSheet->getStyle('A1')->applyFromArray([
        'font' => ['bold' => true, 'size' => 14, 'color' => ['rgb' => '1976D2']],
    ]);
    
    $row = 2;
    foreach ($positions as $pos) {
        $posSheet->setCellValue('A' . $row, $pos);
        $row++;
    }
    
    $posSheet->getColumnDimension('A')->setAutoSize(true);
    
    // === CREAR HOJA DE INSTRUCCIONES ===
    $instructionsSheet = $spreadsheet->createSheet();
    $instructionsSheet->setTitle('Instrucciones');
    
    $instructions = [
        ['INSTRUCCIONES PARA IMPORTAR EMPLEADOS', ''],
        ['', ''],
        ['1. CAMPOS REQUERIDOS (obligatorios):', ''],
        ['   • nombres', 'Nombre del empleado'],
        ['   • apellidos', 'Apellidos del empleado'],
        ['   • email', 'Correo electrónico único'],
        ['   • departamento', 'Nombre del departamento'],
        ['   • cargo', 'Nombre del cargo/posición'],
        ['   • numero_documento', 'Número de identificación único'],
        ['', ''],
        ['2. CAMPOS OPCIONALES:', ''],
        ['   • telefono', 'Número de teléfono'],
        ['   • fecha_ingreso', 'Formato: YYYY-MM-DD (ej: 2023-01-15)'],
        ['   • tipo_documento', 'cedula, dni, o passport'],
        ['   • salario', 'Valor numérico sin puntos ni comas'],
        ['   • fecha_nacimiento', 'Formato: YYYY-MM-DD'],
        ['   • direccion', 'Dirección completa'],
        ['   • contacto_emergencia', 'Nombre del contacto'],
        ['   • telefono_emergencia', 'Teléfono del contacto'],
        ['', ''],
        ['3. REGLAS IMPORTANTES:', ''],
        ['   • Los emails deben ser únicos en el sistema'],
        ['   • Los números de documento deben ser únicos'],
        ['   • Las fechas deben usar formato YYYY-MM-DD'],
        ['   • Los departamentos y cargos se crearán automáticamente si no existen'],
        ['   • La edad mínima es 16 años'],
        ['   • El salario debe ser un número positivo'],
        ['', ''],
        ['4. DEPARTAMENTOS DISPONIBLES:', ''],
        ['   Consulte la hoja "Departamentos" para ver la lista actual'],
        ['', ''],
        ['5. POSICIONES DISPONIBLES:', ''],
        ['   Consulte la hoja "Posiciones" para ver la lista actual'],
        ['', ''],
        ['6. PROCESO DE IMPORTACIÓN:', ''],
        ['   • Complete los datos en la hoja "Plantilla Empleados"'],
        ['   • Elimine la fila de ejemplo (fila 2) antes de importar'],
        ['   • Guarde el archivo en formato Excel (.xlsx)'],
        ['   • Use la función de importar en el sistema'],
        ['', ''],
        ['7. ERRORES COMUNES:', ''],
        ['   • Email duplicado: Cada empleado debe tener un email único'],
        ['   • Documento duplicado: Cada empleado debe tener un número único'],
        ['   • Formato de fecha incorrecto: Use YYYY-MM-DD'],
        ['   • Departamento/cargo vacío: Son campos obligatorios'],
        ['   • Edad insuficiente: Mínimo 16 años']
    ];
    
    $instructionsSheet->fromArray($instructions, NULL, 'A1');
    
    // Estilos para instrucciones
    $instructionsSheet->getStyle('A1')->applyFromArray([
        'font' => ['bold' => true, 'size' => 16, 'color' => ['rgb' => '1976D2']],
    ]);
    
    // Estilo para títulos de sección
    foreach ([3, 11, 20, 27, 30, 33, 40] as $row) {
        $instructionsSheet->getStyle('A' . $row)->applyFromArray([
            'font' => ['bold' => true, 'size' => 12, 'color' => ['rgb' => '1976D2']],
        ]);
    }
    
    $instructionsSheet->getColumnDimension('A')->setWidth(50);
    $instructionsSheet->getColumnDimension('B')->setWidth(40);
    
    // === VOLVER A LA HOJA PRINCIPAL ===
    $spreadsheet->setActiveSheetIndex(0);
    
    // === CONFIGURAR HOJA PRINCIPAL ===
    
    // Auto-size para todas las columnas
    foreach (range('A', 'N') as $col) {
        $sheet->getColumnDimension($col)->setAutoSize(true);
    }
    
    // Establecer altura de fila
    $sheet->getDefaultRowDimension()->setRowHeight(20);
    $sheet->getRowDimension(1)->setRowHeight(25);
    
    // Congelar primera fila
    $sheet->freezePane('A2');
    
    // Agregar comentarios a celdas importantes
    $sheet->getComment('A1')->getText()->createTextRun('CAMPO REQUERIDO: Nombre del empleado');
    $sheet->getComment('B1')->getText()->createTextRun('CAMPO REQUERIDO: Apellidos del empleado');
    $sheet->getComment('C1')->getText()->createTextRun('CAMPO REQUERIDO: Email único del empleado');
    $sheet->getComment('E1')->getText()->createTextRun('CAMPO REQUERIDO: Departamento (se creará si no existe)');
    $sheet->getComment('F1')->getText()->createTextRun('CAMPO REQUERIDO: Cargo/posición (se creará si no existe)');
    $sheet->getComment('G1')->getText()->createTextRun('OPCIONAL: Formato YYYY-MM-DD (ej: 2023-01-15)');
    $sheet->getComment('H1')->getText()->createTextRun('OPCIONAL: cedula, dni, o passport');
    $sheet->getComment('I1')->getText()->createTextRun('CAMPO REQUERIDO: Número de identificación único');
    $sheet->getComment('J1')->getText()->createTextRun('OPCIONAL: Salario en números (sin puntos ni comas)');
    $sheet->getComment('K1')->getText()->createTextRun('OPCIONAL: Formato YYYY-MM-DD, mínimo 16 años');
    
    // Proteger hojas de referencia contra edición
    $deptSheet->getProtection()->setSheet(true);
    $posSheet->getProtection()->setSheet(true);
    $instructionsSheet->getProtection()->setSheet(true);
    
    // Agregar nota en la hoja principal
    $sheet->setCellValue('A50', 'NOTA: Esta es una fila de ejemplo. Elimínela antes de importar sus datos.');
    $sheet->mergeCells('A50:N50');
    $sheet->getStyle('A50')->applyFromArray([
        'font' => ['bold' => true, 'color' => ['rgb' => 'D32F2F']],
        'alignment' => ['horizontal' => Alignment::HORIZONTAL_CENTER],
        'fill' => [
            'fillType' => Fill::FILL_SOLID,
            'startColor' => ['rgb' => 'FFEBEE']
        ]
    ]);
    
    // Generar archivo
    $writer = new Xlsx($spreadsheet);
    $writer->save('php://output');
    
    // Cerrar conexión
    if (isset($conn)) {
        $conn->close();
    }
    
} catch (Exception $e) {
    // En caso de error
    header("Content-Type: application/json");
    echo json_encode([
        'error' => 'Error al generar plantilla: ' . $e->getMessage(),
        'details' => $e->getTraceAsString()
    ]);
}
?>