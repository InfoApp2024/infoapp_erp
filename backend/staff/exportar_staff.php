<?php
// Headers CORS
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

// Manejar preflight requests
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}

// Headers para descarga de Excel
header("Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
header("Content-Disposition: attachment; filename=empleados_" . date('Y-m-d_H-i-s') . ".xlsx");

// Incluir dependencias
require_once '../../vendor/autoload.php';

use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;
use PhpOffice\PhpSpreadsheet\Style\Color;
use PhpOffice\PhpSpreadsheet\Style\Fill;
use PhpOffice\PhpSpreadsheet\Style\Border;
use PhpOffice\PhpSpreadsheet\Style\Alignment;

try {
    // Incluir conexión para obtener datos reales
    require '../../conexion.php';
    
    // Obtener datos del POST o usar datos de ejemplo
    $input = [];
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $input = json_decode(file_get_contents('php://input'), true);
        if (json_last_error() !== JSON_ERROR_NONE) {
            $input = [];
        }
    }
    
    $staff = [];
    
    // Si hay empleados en el request, usarlos
    if (isset($input['staff']) && !empty($input['staff'])) {
        $staff = $input['staff'];
        error_log("Usando empleados del request: " . count($staff));
    } else {
        // Intentar obtener de la base de datos
        try {
            // Verificar si la tabla existe
            $check_table = $conn->query("SHOW TABLES LIKE 'staff'");
            
            if ($check_table && $check_table->num_rows > 0) {
                // La tabla existe, consultar datos reales
                $sql = "SELECT 
                            s.id, s.staff_code, s.first_name, s.last_name, s.email, s.phone,
                            s.department_id, d.name as department_name,
                            s.position_id, p.title as position_title,
                            s.hire_date, s.identification_type, s.identification_number,
                            s.salary, s.birth_date, s.address,
                            s.emergency_contact_name, s.emergency_contact_phone,
                            s.photo_url, s.is_active, s.created_at, s.updated_at,
                            CONCAT(s.first_name, ' ', s.last_name) as full_name,
                            CASE 
                                WHEN s.birth_date IS NOT NULL THEN TIMESTAMPDIFF(YEAR, s.birth_date, CURDATE())
                                ELSE NULL 
                            END as age,
                            TIMESTAMPDIFF(YEAR, s.hire_date, CURDATE()) as years_employed,
                            TIMESTAMPDIFF(MONTH, s.hire_date, CURDATE()) as months_employed
                        FROM staff s
                        LEFT JOIN departments d ON s.department_id = d.id
                        LEFT JOIN positions p ON s.position_id = p.id
                        ORDER BY s.first_name, s.last_name 
                        LIMIT 10000";
                
                $result = $conn->query($sql);
                
                if ($result && $result->num_rows > 0) {
                    while ($row = $result->fetch_assoc()) {
                        $staff[] = $row;
                    }
                    error_log("Empleados obtenidos de BD: " . count($staff));
                } else {
                    error_log("No hay empleados en la BD, usando datos de ejemplo");
                }
            } else {
                error_log("Tabla staff no existe, usando datos de ejemplo");
            }
        } catch (Exception $e) {
            error_log("Error consultando BD: " . $e->getMessage());
        }
        
        // Si no hay empleados de BD, usar datos de ejemplo
        if (empty($staff)) {
            $staff = [
                [
                    'id' => 1,
                    'staff_code' => 'STF001001',
                    'first_name' => 'Juan Carlos',
                    'last_name' => 'Pérez García',
                    'full_name' => 'Juan Carlos Pérez García',
                    'email' => 'juan.perez@empresa.com',
                    'phone' => '+57 300 123 4567',
                    'department_id' => 1,
                    'department_name' => 'Desarrollo de Software',
                    'position_id' => 1,
                    'position_title' => 'Desarrollador Senior',
                    'hire_date' => '2023-01-15',
                    'identification_type' => 'cedula',
                    'identification_number' => '12345678901',
                    'salary' => 4500000.00,
                    'birth_date' => '1990-03-20',
                    'age' => 34,
                    'address' => 'Calle 123 #45-67, Bogotá',
                    'emergency_contact_name' => 'María Pérez',
                    'emergency_contact_phone' => '+57 310 987 6543',
                    'photo_url' => null,
                    'is_active' => 1,
                    'years_employed' => 2,
                    'months_employed' => 24,
                    'created_at' => '2023-01-15 09:00:00',
                    'updated_at' => '2025-01-15 10:30:00'
                ],
                [
                    'id' => 2,
                    'staff_code' => 'STF001002',
                    'first_name' => 'Ana María',
                    'last_name' => 'González López',
                    'full_name' => 'Ana María González López',
                    'email' => 'ana.gonzalez@empresa.com',
                    'phone' => '+57 301 456 7890',
                    'department_id' => 2,
                    'department_name' => 'Recursos Humanos',
                    'position_id' => 2,
                    'position_title' => 'Coordinadora de RRHH',
                    'hire_date' => '2022-06-01',
                    'identification_type' => 'cedula',
                    'identification_number' => '98765432109',
                    'salary' => 3800000.00,
                    'birth_date' => '1988-08-15',
                    'age' => 36,
                    'address' => 'Carrera 45 #78-90, Medellín',
                    'emergency_contact_name' => 'Carlos González',
                    'emergency_contact_phone' => '+57 302 123 4567',
                    'photo_url' => 'https://ejemplo.com/fotos/ana.jpg',
                    'is_active' => 1,
                    'years_employed' => 2,
                    'months_employed' => 31,
                    'created_at' => '2022-06-01 08:30:00',
                    'updated_at' => '2025-01-15 11:15:00'
                ],
                [
                    'id' => 3,
                    'staff_code' => 'STF001003',
                    'first_name' => 'Carlos Eduardo',
                    'last_name' => 'Rodríguez Silva',
                    'full_name' => 'Carlos Eduardo Rodríguez Silva',
                    'email' => 'carlos.rodriguez@empresa.com',
                    'phone' => '+57 305 789 0123',
                    'department_id' => 3,
                    'department_name' => 'Administración',
                    'position_id' => 3,
                    'position_title' => 'Contador',
                    'hire_date' => '2021-03-10',
                    'identification_type' => 'cedula',
                    'identification_number' => '11223344556',
                    'salary' => 3200000.00,
                    'birth_date' => '1985-12-03',
                    'age' => 39,
                    'address' => 'Avenida 30 #12-34, Cali',
                    'emergency_contact_name' => 'Lucía Rodríguez',
                    'emergency_contact_phone' => '+57 304 567 8901',
                    'photo_url' => null,
                    'is_active' => 0,
                    'years_employed' => 3,
                    'months_employed' => 46,
                    'created_at' => '2021-03-10 14:20:00',
                    'updated_at' => '2024-12-15 16:45:00'
                ]
            ];
            error_log("Usando datos de ejemplo: " . count($staff));
        }
    }
    
    // Crear spreadsheet
    $spreadsheet = new Spreadsheet();
    $sheet = $spreadsheet->getActiveSheet();
    $sheet->setTitle('Personal');
    
    // Headers principales
    $headers = [
        'ID', 'Código', 'Nombres', 'Apellidos', 'Nombre Completo', 'Email', 'Teléfono',
        'ID Departamento', 'Departamento', 'ID Posición', 'Posición', 'Fecha Ingreso',
        'Tipo Identificación', 'Número Identificación', 'Salario', 'Fecha Nacimiento',
        'Edad', 'Dirección', 'Contacto Emergencia', 'Teléfono Emergencia',
        'Foto URL', 'Estado', 'Años Empleado', 'Meses Empleado', 'Fecha Creación', 'Fecha Actualización'
    ];
    
    $sheet->fromArray($headers, NULL, 'A1');
    
    // Estilo para headers
    $headerStyle = [
        'font' => [
            'bold' => true, 
            'color' => ['rgb' => 'FFFFFF'],
            'size' => 11
        ],
        'fill' => [
            'fillType' => Fill::FILL_SOLID,
            'startColor' => ['rgb' => '1976D2'] // Azul más profesional para RRHH
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
    
    $sheet->getStyle('A1:Z1')->applyFromArray($headerStyle);
    
    // Agregar datos
    $row = 2;
    foreach ($staff as $employee) {
        $rowData = [
            $employee['id'] ?? '',
            $employee['staff_code'] ?? '',
            $employee['first_name'] ?? '',
            $employee['last_name'] ?? '',
            $employee['full_name'] ?? ($employee['first_name'] . ' ' . $employee['last_name']),
            $employee['email'] ?? '',
            $employee['phone'] ?? '',
            $employee['department_id'] ?? '',
            $employee['department_name'] ?? '',
            $employee['position_id'] ?? '',
            $employee['position_title'] ?? '',
            $employee['hire_date'] ?? '',
            $employee['identification_type'] ?? '',
            $employee['identification_number'] ?? '',
            $employee['salary'] ?? 0,
            $employee['birth_date'] ?? '',
            $employee['age'] ?? '',
            $employee['address'] ?? '',
            $employee['emergency_contact_name'] ?? '',
            $employee['emergency_contact_phone'] ?? '',
            $employee['photo_url'] ?? '',
            ($employee['is_active'] ?? 1) ? 'Activo' : 'Inactivo',
            $employee['years_employed'] ?? 0,
            $employee['months_employed'] ?? 0,
            $employee['created_at'] ?? '',
            $employee['updated_at'] ?? ''
        ];
        
        $sheet->fromArray($rowData, NULL, 'A' . $row);
        
        // Aplicar estilo alternado en filas
        if ($row % 2 == 0) {
            $sheet->getStyle('A' . $row . ':Z' . $row)->applyFromArray([
                'fill' => [
                    'fillType' => Fill::FILL_SOLID,
                    'startColor' => ['rgb' => 'F8F9FA']
                ]
            ]);
        }
        
        // Estilo especial para empleados inactivos
        if (!($employee['is_active'] ?? 1)) {
            $sheet->getStyle('A' . $row . ':Z' . $row)->applyFromArray([
                'font' => ['color' => ['rgb' => '6C757D']],
                'fill' => [
                    'fillType' => Fill::FILL_SOLID,
                    'startColor' => ['rgb' => 'FFF3CD']
                ]
            ]);
        }
        
        // Formato para columna de salario
        if (!empty($employee['salary'])) {
            $sheet->getStyle('O' . $row)->getNumberFormat()->setFormatCode('#,##0.00');
        }
        
        $row++;
    }
    
    // Auto-size columns
    foreach (range('A', 'Z') as $col) {
        $sheet->getColumnDimension($col)->setAutoSize(true);
    }
    
    // Establecer altura mínima para las filas
    $sheet->getDefaultRowDimension()->setRowHeight(18);
    
    // Agregar filtros a los headers
    $sheet->setAutoFilter('A1:Z' . ($row - 1));
    
    // Congelar primera fila
    $sheet->freezePane('A2');
    
    // Crear hoja de resumen
    $summarySheet = $spreadsheet->createSheet();
    $summarySheet->setTitle('Resumen');
    
    // Calcular estadísticas
    $totalStaff = count($staff);
    $activeStaff = count(array_filter($staff, function($emp) { return $emp['is_active'] ?? 1; }));
    $inactiveStaff = $totalStaff - $activeStaff;
    
    $departments = [];
    $positions = [];
    $totalSalary = 0;
    $staffWithSalary = 0;
    
    foreach ($staff as $emp) {
        if (!empty($emp['department_name'])) {
            $departments[$emp['department_name']] = ($departments[$emp['department_name']] ?? 0) + 1;
        }
        if (!empty($emp['position_title'])) {
            $positions[$emp['position_title']] = ($positions[$emp['position_title']] ?? 0) + 1;
        }
        if (!empty($emp['salary']) && $emp['salary'] > 0) {
            $totalSalary += $emp['salary'];
            $staffWithSalary++;
        }
    }
    
    $averageSalary = $staffWithSalary > 0 ? $totalSalary / $staffWithSalary : 0;
    
    // Agregar resumen
    $summaryData = [
        ['RESUMEN DE PERSONAL', ''],
        ['Generado el:', date('Y-m-d H:i:s')],
        ['', ''],
        ['ESTADÍSTICAS GENERALES', ''],
        ['Total de empleados:', $totalStaff],
        ['Empleados activos:', $activeStaff],
        ['Empleados inactivos:', $inactiveStaff],
        ['Promedio salarial:', $averageSalary > 0 ? '$' . number_format($averageSalary, 2) : 'N/A'],
        ['', ''],
        ['EMPLEADOS POR DEPARTAMENTO', ''],
    ];
    
    foreach ($departments as $dept => $count) {
        $summaryData[] = [$dept, $count];
    }
    
    $summaryData[] = ['', ''];
    $summaryData[] = ['EMPLEADOS POR POSICIÓN', ''];
    
    foreach ($positions as $pos => $count) {
        $summaryData[] = [$pos, $count];
    }
    
    $summarySheet->fromArray($summaryData, NULL, 'A1');
    
    // Estilo para la hoja de resumen
    $summarySheet->getStyle('A1')->applyFromArray([
        'font' => ['bold' => true, 'size' => 16, 'color' => ['rgb' => '1976D2']],
    ]);
    
    $summarySheet->getStyle('A4')->applyFromArray([
        'font' => ['bold' => true, 'size' => 12, 'color' => ['rgb' => '1976D2']],
    ]);
    
    $summarySheet->getStyle('A10')->applyFromArray([
        'font' => ['bold' => true, 'size' => 12, 'color' => ['rgb' => '1976D2']],
    ]);
    
    $summarySheet->getStyle('A' . (10 + count($departments) + 2))->applyFromArray([
        'font' => ['bold' => true, 'size' => 12, 'color' => ['rgb' => '1976D2']],
    ]);
    
    // Auto-size columns en resumen
    $summarySheet->getColumnDimension('A')->setAutoSize(true);
    $summarySheet->getColumnDimension('B')->setAutoSize(true);
    
    // Seleccionar la hoja principal
    $spreadsheet->setActiveSheetIndex(0);
    
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
        'error' => 'Error al exportar empleados: ' . $e->getMessage(),
        'details' => $e->getTraceAsString()
    ]);
}
?>