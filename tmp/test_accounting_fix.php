<?php
require 'backend/conexion.php';
require 'backend/core/AccountingEngine.php';

// Simular el error: extraDetalle con código pero sin PK
$extraDetalles = [
    [
        'codigo' => '135515',
        'nombre' => 'ReteFuente Test',
        'tipo' => 'DEBITO',
        'valor' => 1000
    ]
];

$montos = ['TOTAL' => 1000];

try {
    // Intentamos generar un asiento. 
    // Usamos un evento que sepamos que existe o forzamos uno vacío.
    $asiento = AccountingEngine::generateEntry($conn, 'GENERAR_FACTURA', $montos, 'TEST-FIX', $extraDetalles);
    
    $found = false;
    foreach ($asiento['detalles'] as $det) {
        if ($det['codigo'] === '135515') {
            echo "SUCCESS: Cuenta 135515 resuelta a ID: " . ($det['cuenta_id'] ?? 'NULL') . "\n";
            if ($det['cuenta_id'] !== null) {
                $found = true;
            }
        }
    }
    
    if (!$found) {
        echo "FAILURE: El campo cuenta_id sigue siendo NULL para 135515\n";
    }
} catch (Exception $e) {
    echo "ERROR: " . $e->getMessage() . "\n";
}
