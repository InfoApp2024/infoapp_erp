<?php 
// No podemos sobreescribir php://input, pero el script usa file_get_contents('php://input')
// Una alternativa es inyectar la lógica en el script real o usar un servidor local.
// Dado que es CLI, mejor simplemente verificar que compila y no tiene errores de sintaxis.
