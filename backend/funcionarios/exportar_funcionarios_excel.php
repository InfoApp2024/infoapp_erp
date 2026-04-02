<?php
require_once '../login/auth_middleware.php';
require_once '../vendor/autoload.php';

use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;
use PhpOffice\PhpSpreadsheet\Style\Fill;
use PhpOffice\PhpSpreadsheet\Style\Border;
use PhpOffice\PhpSpreadsheet\Style\Alignment;

try {
    // PASO 1: Requerir autenticación JWT
    $currentUser = requireAuth();
    
    // PASO 2: Log de acceso
    logAccess($currentUser, '/exportar_funcionarios_excel.php', 'export_funcionarios_excel');
    
    // PASO 3: Validar método HTTP
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }
    
    // PASO 4: Conexión a BD
    require '../conexion.php';
    
    // PASO 5: Obtener parámetros opcionales
    $incluir_inactivos = isset($_GET['incluir_inactivos']) && $_GET['incluir_inactivos'] === 'true';
    
    // PASO 6: Consultar funcionarios (SIN JOIN - simplificado)
    $sql = "
        SELECT 
            id,
            nombre,
            cargo,
            empresa,
            activo,
            fecha_creacion
        FROM funcionario
    ";
    
    if (!$incluir_inactivos) {
        $sql .= " WHERE activo = 1";
    }
    
    $sql .= " ORDER BY nombre ASC";
    
    $result = $conn->query($sql);
    
    if (!$result) {
        throw new Exception('Error al consultar funcionarios: ' . $conn->error);
    }
    
    // PASO 7: Crear archivo Excel
    $spreadsheet = new Spreadsheet();
    $sheet = $spreadsheet->getActiveSheet();
    
    // Configurar propiedades del documento
    $spreadsheet->getProperties()
        ->setCreator($currentUser['usuario'])
        ->setTitle('Funcionarios')
        ->setSubject('Exportación de Funcionarios')
        ->setDescription('Lista de funcionarios exportada desde el sistema')
        ->setCategory('Reportes');
    
    // PASO 8: Configurar encabezados
    $sheet->setTitle('Funcionarios');
    
    // Encabezados de columnas (sin Usuario Creador)
    $headers = ['ID', 'Nombre', 'Cargo', 'Empresa', 'Activo', 'Fecha Creación'];
    $column = 'A';
    
    foreach ($headers as $header) {
        $sheet->setCellValue($column . '1', $header);
        $column++;
    }
    
    // Estilo para encabezados
    $headerStyle = [
        'font' => [
            'bold' => true,
            'color' => ['rgb' => 'FFFFFF'],
            'size' => 12
        ],
        'fill' => [
            'fillType' => Fill::FILL_SOLID,
            'startColor' => ['rgb' => '4472C4']
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
    
    $sheet->getStyle('A1:F1')->applyFromArray($headerStyle);
    
    // PASO 9: Llenar datos
    $row = 2;
    while ($funcionario = $result->fetch_assoc()) {
        $sheet->setCellValue('A' . $row, $funcionario['id']);
        $sheet->setCellValue('B' . $row, $funcionario['nombre']);
        $sheet->setCellValue('C' . $row, $funcionario['cargo'] ?? '');
        $sheet->setCellValue('D' . $row, $funcionario['empresa'] ?? '');
        $sheet->setCellValue('E' . $row, $funcionario['activo'] ? 'Sí' : 'No');
        $sheet->setCellValue('F' . $row, $funcionario['fecha_creacion']);
        
        // Estilo alternado para filas
        if ($row % 2 == 0) {
            $sheet->getStyle('A' . $row . ':F' . $row)->applyFromArray([
                'fill' => [
                    'fillType' => Fill::FILL_SOLID,
                    'startColor' => ['rgb' => 'F2F2F2']
                ]
            ]);
        }
        
        $row++;
    }
    
    // PASO 10: Ajustar ancho de columnas
    foreach (range('A', 'F') as $col) {
        $sheet->getColumnDimension($col)->setAutoSize(true);
    }
    
    // Agregar bordes a todas las celdas con datos
    $lastRow = $row - 1;
    if ($lastRow >= 2) {
        $sheet->getStyle('A1:F' . $lastRow)->applyFromArray([
            'borders' => [
                'allBorders' => [
                    'borderStyle' => Border::BORDER_THIN,
                    'color' => ['rgb' => 'CCCCCC']
                ]
            ]
        ]);
    }
    
    // PASO 11: Agregar hoja de instrucciones
    $instructionsSheet = $spreadsheet->createSheet();
    $instructionsSheet->setTitle('Instrucciones');
    
    $instructionsSheet->setCellValue('A1', 'INSTRUCCIONES PARA IMPORTAR FUNCIONARIOS');
    $instructionsSheet->getStyle('A1')->applyFromArray([
        'font' => ['bold' => true, 'size' => 14, 'color' => ['rgb' => '0000FF']]
    ]);
    
    $instructionsSheet->setCellValue('A3', '1. Los campos obligatorios son:');
    $instructionsSheet->setCellValue('A4', '   - Nombre (mínimo 2 caracteres, máximo 100)');
    $instructionsSheet->setCellValue('A6', '2. Los campos opcionales son:');
    $instructionsSheet->setCellValue('A7', '   - Cargo (máximo 100 caracteres)');
    $instructionsSheet->setCellValue('A8', '   - Empresa (máximo 100 caracteres)');
    $instructionsSheet->setCellValue('A9', '   - Activo (Sí/No, por defecto Sí)');
    $instructionsSheet->setCellValue('A11', '3. Para CREAR nuevos funcionarios:');
    $instructionsSheet->setCellValue('A12', '   - Deje la columna ID vacía o elimínela');
    $instructionsSheet->setCellValue('A13', '   - El sistema generará automáticamente los IDs');
    $instructionsSheet->setCellValue('A15', '4. Para ACTUALIZAR funcionarios existentes:');
    $instructionsSheet->setCellValue('A16', '   - Mantenga el ID del funcionario');
    $instructionsSheet->setCellValue('A17', '   - El sistema actualizará el registro correspondiente');
    $instructionsSheet->setCellValue('A19', '5. No modifique la columna "Fecha Creación"');
    $instructionsSheet->setCellValue('A20', '   - Esta se ignorará durante la importación');
    
    $instructionsSheet->getColumnDimension('A')->setWidth(80);
    
    // PASO 12: Generar y descargar archivo
    $filename = 'funcionarios_' . date('Y-m-d_His') . '.xlsx';
    
    // Configurar headers para descarga
    header('Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    header('Content-Disposition: attachment; filename="' . $filename . '"');
    header('Cache-Control: max-age=0');
    header('Cache-Control: max-age=1');
    header('Expires: Mon, 26 Jul 1997 05:00:00 GMT');
    header('Last-Modified: ' . gmdate('D, d M Y H:i:s') . ' GMT');
    header('Cache-Control: cache, must-revalidate');
    header('Pragma: public');
    
    $writer = new Xlsx($spreadsheet);
    $writer->save('php://output');
    
    // Liberar memoria
    $spreadsheet->disconnectWorksheets();
    unset($spreadsheet);
    
    exit;
    
} catch (Exception $e) {
    error_log('Error exportando Excel: ' . $e->getMessage());
    
    // Si ya se enviaron headers de Excel, no podemos enviar JSON
    if (!headers_sent()) {
        sendJsonResponse(errorResponse('Error al exportar Excel: ' . $e->getMessage()), 500);
    } else {
        // Si ya se enviaron headers, registrar el error
        error_log('No se puede enviar respuesta JSON, headers ya enviados');
        exit;
    }
}

// Cerrar conexión
if (isset($conn) && $conn !== null) {
    $conn->close();
}
?>