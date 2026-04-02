<?php
// Script para probar la robustez de la salida en vista_previa_pdf.php

function test_download()
{
    echo "--- Testing Download Robustness: vista_previa_pdf.php ---\n";

    // Necesitamos simular el entorno para que no muera por falta de Auth o POST
    // El script real lee de php://input. 
    // Usaremos un truco para ejecutarlo y capturar su salida.

    $payload = json_encode([
        'servicio_id' => 170,
        'generar_pdf' => true,
        'contenido_html' => '<h1>Test Robustness</h1>'
    ]);

    // Crear un archivo auto_prepend para el test
    file_put_contents('test_env_mock.php', "<?php \$_SERVER['REQUEST_METHOD'] = 'POST'; ?>");

    // Ejecutar via CLI y capturar salida
    // Nota: Necesitamos que auth_middleware no aborte. 
    // Como estamos en CLI, quizÃ¡s falle auth, pero queremos ver si HAY SALIDA antes del JSON de error.

    $descriptorspec = array(
        0 => array("pipe", "r"),  // stdin
        1 => array("pipe", "w"),  // stdout
        2 => array("pipe", "w")   // stderr
    );

    $process = proc_open('php -d auto_prepend_file=test_env_mock.php vista_previa_pdf.php', $descriptorspec, $pipes);

    if (is_resource($process)) {
        fwrite($pipes[0], $payload);
        fclose($pipes[0]);

        $stdout = stream_get_contents($pipes[1]);
        fclose($pipes[1]);

        $stderr = stream_get_contents($pipes[2]);
        fclose($pipes[2]);

        proc_close($process);

        echo "STDOUT length: " . strlen($stdout) . "\n";
        if (strlen($stdout) > 0) {
            echo "First 50 chars of STDOUT: [" . substr($stdout, 0, 50) . "]\n";

            // Verificar si hay algo ANTES del primer '{'
            $firstBrace = strpos($stdout, '{');
            if ($firstBrace !== false && $firstBrace > 0) {
                echo "âŒ ERROR: Detected output BEFORE JSON brace at position $firstBrace: [" . substr($stdout, 0, $firstBrace) . "]\n";
            } else if ($firstBrace === 0) {
                echo "âœ… SUCCESS: Output starts with JSON brace.\n";
            } else {
                echo "âŒ ERROR: No JSON brace found in output.\n";
                echo "Full output: $stdout\n";
            }
        } else {
            echo "âŒ ERROR: No output produced by script.\n";
            echo "STDERR: $stderr\n";
        }
    }
}

test_download();
?>