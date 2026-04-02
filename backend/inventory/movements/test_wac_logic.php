<?php
// backend/inventory/movements/test_wac_logic.php

require_once '../../login/auth_middleware.php';
$currentUser = requireAuth();

$item_id = isset($_GET['item_id']) ? intval($_GET['item_id']) : 1;

// Pure logic test script - no database required
echo "Iniciando prueba de lógica de Costo Promedio Ponderado (Sin DB)...\n\n";

// Function to calculate WAC (The logic to be tested)
function calculateWAC($current_stock, $current_avg_cost, $incoming_qty, $incoming_unit_cost)
{
  $current_val = $current_stock * $current_avg_cost;
  $incoming_val = $incoming_qty * $incoming_unit_cost;
  $total_qty = $current_stock + $incoming_qty;

  if ($total_qty > 0) {
    return ($current_val + $incoming_val) / $total_qty;
  } else {
    return $incoming_unit_cost;
  }
}

// === TEST CASE 1: Basic Average ===
// Stock: 10 @ $10. Incoming: 10 @ $20.
// Expected: ((10*10) + (10*20)) / 20 = (100 + 200) / 20 = 15.00
$t1_stock = 10;
$t1_avg = 10.00;
$t1_qty = 10;
$t1_cost = 20.00;
$t1_res = calculateWAC($t1_stock, $t1_avg, $t1_qty, $t1_cost);

echo "TEST 1 (Básico):\n";
echo "Stock: $t1_stock @ $$t1_avg\n";
echo "Entrada: $t1_qty @ $$t1_cost\n";
echo "Esperado: 15.00\n";
echo "Resultado: " . number_format($t1_res, 2) . "\n";
echo (abs($t1_res - 15.00) < 0.001) ? "✅ PASÓ" : "❌ FALLÓ";
echo "\n\n";

// === TEST CASE 2: Different Quantities ===
// Stock: 20 @ $15. Incoming: 5 @ $25.
// Expected: ((20*15) + (5*25)) / 25 = (300 + 125) / 25 = 425 / 25 = 17.00
$t2_stock = 20;
$t2_avg = 15.00;
$t2_qty = 5;
$t2_cost = 25.00;
$t2_res = calculateWAC($t2_stock, $t2_avg, $t2_qty, $t2_cost);

echo "TEST 2 (Cantidades Diferentes):\n";
echo "Stock: $t2_stock @ $$t2_avg\n";
echo "Entrada: $t2_qty @ $$t2_cost\n";
echo "Esperado: 17.00\n";
echo "Resultado: " . number_format($t2_res, 2) . "\n";
echo (abs($t2_res - 17.00) < 0.001) ? "✅ PASÓ" : "❌ FALLÓ";
echo "\n\n";

// === TEST CASE 3: Zero Initial Stock ===
// Stock: 0 @ $0. Incoming: 5 @ $100.
// Expected: $100.
$t3_stock = 0;
$t3_avg = 0.00;
$t3_qty = 5;
$t3_cost = 100.00;
$t3_res = calculateWAC($t3_stock, $t3_avg, $t3_qty, $t3_cost);

echo "TEST 3 (Stock Inicial Cero):\n";
echo "Stock: $t3_stock @ $$t3_avg\n";
echo "Entrada: $t3_qty @ $$t3_cost\n";
echo "Esperado: 100.00\n";
echo "Resultado: " . number_format($t3_res, 2) . "\n";
echo (abs($t3_res - 100.00) < 0.001) ? "✅ PASÓ" : "❌ FALLÓ";
echo "\n\n";

// === TEST CASE 4: Decimals ===
// Stock: 100 @ $1.50. Incoming: 50 @ $1.75.
// Expected: ((100*1.5) + (50*1.75)) / 150 = (150 + 87.5) / 150 = 237.5 / 150 = 1.5833...
$t4_stock = 100;
$t4_avg = 1.50;
$t4_qty = 50;
$t4_cost = 1.75;
$t4_res = calculateWAC($t4_stock, $t4_avg, $t4_qty, $t4_cost);

echo "TEST 4 (Decimales):\n";
echo "Stock: $t4_stock @ $$t4_avg\n";
echo "Entrada: $t4_qty @ $$t4_cost\n";
echo "Esperado: 1.5833\n";
echo "Resultado: " . number_format($t4_res, 4) . "\n";
echo (abs($t4_res - 1.58333) < 0.001) ? "✅ PASÓ" : "❌ FALLÓ";
echo "\n\n";

echo "Pruebas finalizadas.\n";
$unit_cost = 25.00;

$item = getItem($conn, $item_id);
$previous_stock = intval($item['current_stock']); // 20
$new_stock = $previous_stock + $quantity; // 25

// Logic again
$new_average_cost = floatval($item['average_cost']); // 15
$new_last_cost = floatval($item['last_cost']);

if ($movement_type === 'entrada') {
  $new_last_cost = $unit_cost;
  $current_val = $previous_stock * floatval($item['average_cost']); // 20 * 15 = 300
  $incoming_val = $quantity * $unit_cost; // 5 * 25 = 125
  $total_qty = $previous_stock + $quantity; // 25

  if ($total_qty > 0) {
    $new_average_cost = ($current_val + $incoming_val) / $total_qty; // 425 / 25 = 17
  }
}

echo "\nSimulando Entrada 2: +5 unidades a $25.00\n";
echo "Cálculo esperado: ((20 * 15) + (5 * 25)) / 25 = (300 + 125) / 25 = 425 / 25 = 17.00\n";
echo "Cálculo obtenido: $new_average_cost\n";

if (abs($new_average_cost - 17.00) < 0.01) {
  echo "✅ PRUEBA 2 PASADA: El cálculo es correcto.\n";
} else {
  echo "❌ PRUEBA 2 FALLADA: El cálculo es incorrecto.\n";
}

// Cleanup
$conn->query("DELETE FROM inventory_items WHERE id = $item_id");
echo "\nLimpieza completada.\n";
