<?php
/**
 * debug_factus_url.php
 * Script simple para verificar la URL exacta generada para Factus.
 */
define('AUTH_REQUIRED', true);
require 'FactusConfig.php';

$base = FACTUS_API_URL;
$full_url = rtrim($base, '/') . '/v1/bills/';

echo "--- DEBUG URL FACTUS ---<br>";
echo "URL BASE (Config): <b>" . $base . "</b><br>";
echo "URL FINAL (Generada): <b style='color:green;'>" . $full_url . "</b><br>";
echo "<br><i>Si esta URL no termina en <b>/v1/bills/</b> (con barra final), revisa el trailing slash.</i>";
