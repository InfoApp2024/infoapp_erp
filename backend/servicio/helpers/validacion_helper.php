<?php
// backend/servicio/helpers/validacion_helper.php

/**
 * Valida que todos los campos adicionales obligatorios de un servicio para su estado actual estén diligenciados.
 * 
 * @param mysqli $conn Conexión a la base de datos
 * @param int $servicio_id ID del servicio
 * @param int $estado_id ID del estado a validar (generalmente el estado actual)
 * @param string $modulo Nombre del módulo (default 'Servicios')
 * @return array ['valido' => bool, 'campos_faltantes' => array]
 */
function validarCamposObligatorios($conn, $servicio_id, $estado_id, $modulo = 'Servicios')
{
    error_log("VALIDACION DEBUG: Iniciando validación para servicio #$servicio_id en estado #$estado_id (Módulo: $modulo)");

    // 1. Obtener campos adicionales obligatorios para el estado dado
    // Nota: Quitamos el filtro de módulo para ser más tolerantes, o lo dejamos opcional
    $sql_campos = "
        SELECT id, nombre_campo, tipo_campo
        FROM campos_adicionales
        WHERE estado_mostrar = ? 
        AND obligatorio = 1
    ";

    $stmt = $conn->prepare($sql_campos);
    $stmt->bind_param("i", $estado_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $campos_obligatorios = [];

    while ($row = $result->fetch_assoc()) {
        $campos_obligatorios[] = $row;
    }
    $stmt->close();

    error_log("VALIDACION DEBUG: Se encontraron " . count($campos_obligatorios) . " campos obligatorios configurados.");

    if (empty($campos_obligatorios)) {
        return ['valido' => true, 'campos_faltantes' => []];
    }

    // 2. Verificar que cada campo obligatorio tenga un valor
    $campos_faltantes = [];

    foreach ($campos_obligatorios as $campo) {
        $stmt_valor = $conn->prepare("
            SELECT valor_texto, valor_numero, valor_fecha, valor_hora, valor_datetime, valor_archivo, valor_booleano
            FROM valores_campos_adicionales
            WHERE campo_id = ? 
            AND servicio_id = ?
        ");
        $stmt_valor->bind_param("ii", $campo['id'], $servicio_id);
        $stmt_valor->execute();
        $result_valor = $stmt_valor->get_result();
        $valor = $result_valor->fetch_assoc();
        $stmt_valor->close();

        // Verificar si el valor existe y al menos una de las columnas tiene algo
        $esta_vacio = true;
        if ($valor) {
            // Un valor booleano (0 o 1) se considera LLENO si no es NULL
            // Un valor numérico (incluyendo 0) se considera LLENO si no es NULL
            if (
                ($valor['valor_texto'] !== null && trim($valor['valor_texto']) !== '') ||
                ($valor['valor_numero'] !== null) ||
                ($valor['valor_fecha'] !== null) ||
                ($valor['valor_hora'] !== null) ||
                ($valor['valor_datetime'] !== null) ||
                ($valor['valor_archivo'] !== null && trim($valor['valor_archivo']) !== '') ||
                ($valor['valor_booleano'] !== null)
            ) {
                $esta_vacio = false;
            }
        }

        if ($esta_vacio) {
            error_log("VALIDACION DEBUG: Campo faltante: " . $campo['nombre_campo'] . " (ID: " . $campo['id'] . ")");
            $campos_faltantes[] = $campo['nombre_campo'];
        }
    }

    return [
        'valido' => empty($campos_faltantes),
        'campos_faltantes' => $campos_faltantes
    ];
}

/**
 * Lanza una excepción si hay campos obligatorios faltantes.
 * 
 * @throws Exception si la validación falla
 */
function checkRequiredFields($conn, $servicio_id, $estado_id, $mensaje_prefijo = "No se puede continuar.")
{
    $resultado = validarCamposObligatorios($conn, $servicio_id, $estado_id);

    if (!$resultado['valido']) {
        $mensaje = $mensaje_prefijo . " Los siguientes campos adicionales deben ser diligenciados: ";
        $mensaje .= implode(", ", $resultado['campos_faltantes']);
        throw new Exception($mensaje);
    }
}
