<?php
define('AUTH_REQUIRED', true);
require __DIR__ . '/backend/core/FactusService.php';
$ranges = FactusService::getNumberingRanges();
if (empty($ranges)) {
    echo "NO_RANGES_FOUND";
} else {
    foreach ($ranges as $index => $r) {
        printf(
            "ID: %d | Prefix: %s | Document: %s | Active: %s\n",
            $r['id'] ?? 0,
            $r['prefix'] ?? 'N/A',
            $r['document'] ?? 'N/A',
            ($r['is_active'] ?? false) ? 'YES' : 'NO'
        );
    }
}
echo "END_LIST\n";
