<?php
/**
 * Simulador de Escenarios Contables - InfoApp
 * Valida los 3 casos (A, B, C) solicitados en ID #3.3-TEST
 */

function simulateAccountingScenario($name, $cliente, $subtotal)
{
    echo "==================================================\n";
    echo "ESCENARIO: $name\n";
    echo "==================================================\n";
    echo "CLIENTE CONFIG: Type: {$cliente['tipo_persona']} | Fiscal: {$cliente['responsabilidad_fiscal_id']} | Agente: {$cliente['es_agente_retenedor']} | Auto: {$cliente['es_autorretenedor']}\n";
    echo "SUBTOTAL FACTURA: $" . number_format($subtotal, 0) . "\n";

    // Simulación de lógica de create_invoice.php
    $total_iva = round($subtotal * 0.19, 2);
    $reteiva_asiento = 0;
    $retefuente_asiento = 0;

    if (($cliente['es_gran_contribuyente'] ?? 0) == 1 || ($cliente['responsabilidad_fiscal_id'] == 'O-13')) {
        $reteiva_asiento = round($total_iva * 0.15, 2);
    }

    $base_minima_fuente = 188000;
    if (($cliente['es_agente_retenedor'] ?? 0) == 1 && $subtotal >= $base_minima_fuente && ($cliente['es_autorretenedor'] ?? 0) == 0) {
        $retefuente_asiento = round($subtotal * 0.04, 2);
    }

    $total_neto = $subtotal + $total_iva - $reteiva_asiento - $retefuente_asiento;

    echo "--- RESULTADOS CALCULOS ---\n";
    echo "IVA (19%): $" . number_format($total_iva, 0) . "\n";
    echo "RETEIVA (15% del IVA): -$" . number_format($reteiva_asiento, 0) . "\n";
    echo "RETEFUENTE (4%): -$" . number_format($retefuente_asiento, 0) . "\n";
    echo "TOTAL NETO A COBRAR: $" . number_format($total_neto, 0) . "\n\n";

    echo "--- PROPUESTA DE ASIENTO CONTABLE ---\n";
    // Cuentas Mock
    $asiento = [
        ['cuenta' => '130505', 'nombre' => 'Clientes Nacionales', 'tipo' => 'DEBITO', 'valor' => $total_neto],
        ['cuenta' => '413505', 'nombre' => 'Ingresos por Servicios', 'tipo' => 'CREDITO', 'valor' => $subtotal],
        ['cuenta' => '240805', 'nombre' => 'IVA Generado 19%', 'tipo' => 'CREDITO', 'valor' => $total_iva],
    ];

    if ($reteiva_asiento > 0) {
        $asiento[] = ['cuenta' => '135517', 'nombre' => 'ReteIVA (15%)', 'tipo' => 'DEBITO', 'valor' => $reteiva_asiento];
    }
    if ($retefuente_asiento > 0) {
        $asiento[] = ['cuenta' => '135515', 'nombre' => 'ReteFuente (4%)', 'tipo' => 'DEBITO', 'valor' => $retefuente_asiento];
    }

    foreach ($asiento as $row) {
        echo sprintf("[%s] %-25s | %-8s | $%s\n", $row['cuenta'], $row['nombre'], $row['tipo'], number_format($row['valor'], 0));
    }
    echo "==================================================\n\n";
}

// ESCENARIO A: El Cliente "Pequeño"
simulateAccountingScenario("A: Cliente Pequeño (Persona Natural)", [
    'tipo_persona' => 'Natural',
    'responsabilidad_fiscal_id' => 'R-99-PN',
    'es_agente_retenedor' => 0,
    'es_autorretenedor' => 0,
    'es_gran_contribuyente' => 0
], 2000000);

// ESCENARIO B: El Cliente "Gran Contribuyente" (Argos)
simulateAccountingScenario("B: Gran Contribuyente (Argos)", [
    'tipo_persona' => 'Juridica',
    'responsabilidad_fiscal_id' => 'O-13',
    'es_agente_retenedor' => 1,
    'es_autorretenedor' => 0,
    'es_gran_contribuyente' => 1
], 2000000);

// ESCENARIO C: El "Tope de UVT"
simulateAccountingScenario("C: Tope de UVT (Factura < 4 UVT)", [
    'tipo_persona' => 'Juridica',
    'responsabilidad_fiscal_id' => 'O-13',
    'es_agente_retenedor' => 1,
    'es_autorretenedor' => 0,
    'es_gran_contribuyente' => 1
], 100000);
?>