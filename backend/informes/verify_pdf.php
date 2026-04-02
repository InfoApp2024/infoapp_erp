<?php
require_once __DIR__ . '/../core/PDFGeneratorFactory.php';
require_once __DIR__ . '/../vendor/autoload.php';

use Core\PDFGeneratorFactory;

function test_engine($engine, $html)
{
    echo "--- Testing Engine: $engine ---\n";
    try {
        $factory = new PDFGeneratorFactory($engine);
        $destDir = __DIR__ . '/../uploads/informes';
        if (!is_dir($destDir))
            mkdir($destDir, 0775, true);

        $filename = "test_{$engine}_" . time() . ".pdf";
        $fullPath = $destDir . '/' . $filename;

        $factory->generate($html, '', $fullPath, 'F');
        echo "✅ Success: $fullPath created.\n";
    } catch (Exception $e) {
        echo "❌ Error: " . $e->getMessage() . "\n";
    }
}

$html_simple = "<h1>Hola Mundo</h1><p>Test standard</p>";
$html_utf8 = "<h1>Caracteres Especiales</h1><p>Español: Ñandú, Acción. Special: ☺, ☃, ☘. Arabic: مرحبا. Chinese: 你好.</p>";

test_engine('legacy', $html_simple);
test_engine('modern', $html_utf8);
