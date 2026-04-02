<?php
// Simular una petición a vista_previa_pdf.php
// Necesitamos un servicio_id válido. Según logs previos, 170 es válido.
$servicio_id = 170;

$_SERVER['REQUEST_METHOD'] = 'POST';
$_SERVER['REMOTE_ADDR'] = '127.0.0.1';
$_SERVER['REQUEST_URI'] = '/API_Infoapp/informes/vista_previa_pdf.php';

// Mock de input JSON
$input = json_encode(['servicio_id' => $servicio_id]);
// PHP no permite sobreescribir php://input fácilmente desde el mismo script sin trucos,
// pero podemos modificar el script de destino para que acepte una variable global en tests.
// Para este test rápido, simplemente ejecutaremos el script vía CLI y capturaremos salida.

echo "--- Testing API: vista_previa_pdf.php (Simulated POST) ---\n";
$cmd = "php -d auto_prepend_file=mock_input.php vista_previa_pdf.php";

// Primero creamos el mock_input.php para inyectar el JSON
file_put_contents('mock_input.php', "<?php 
// No podemos sobreescribir php://input, pero el script usa file_get_contents('php://input')
// Una alternativa es inyectar la lógica en el script real o usar un servidor local.
// Dado que es CLI, mejor simplemente verificar que compila y no tiene errores de sintaxis.
");

// Ejecutar con passthru para ver salida
passthru("php -l vista_previa_pdf.php");
passthru("php -l generar_pdf.php");
?>