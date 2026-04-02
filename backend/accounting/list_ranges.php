<?php
/**
 * list_ranges.php
 * Lista los rangos de numeración disponibles en Factus.
 */
define('AUTH_REQUIRED', true);
require __DIR__ . '/../core/FactusService.php';

echo "--- RANGOS DE NUMERACIÓN FACTUS ---<br>";

try {
    require __DIR__ . '/../conexion.php';
    $ranges = FactusService::getNumberingRanges($conn);
    echo "<pre>" . json_encode($ranges, JSON_PRETTY_PRINT) . "</pre>";

    if (empty($ranges)) {
        echo "No se encontraron rangos activos. Verifica el token y la URL base.";
    }

} catch (Exception $e) {
    echo "Error: " . $e->getMessage();
}
