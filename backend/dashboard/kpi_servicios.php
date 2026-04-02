<?php

/**
 * GET /backend/dashboard/kpi_servicios.php
 * 
 * Endpoint modular para obtener KPIs específicos del módulo de SERVICIOS.
 * Diseñado para alimentar gráficas de dashboard gerencial.
 */

// Configuración de cabeceras y errores
error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);
header('Content-Type: application/json; charset=utf-8');

// Dependencias
require_once '../conexion.php';
require_once '../login/auth_middleware.php';

try {
    // 1. Autenticación y Autorización
    $currentUser = requireAuth();

    // Opcional: Validar que sea rol administrativo/gerencial
    $rolesPermitidos = ['admin', 'administrador', 'gerente'];
    if (!in_array(strtolower($currentUser['rol']), $rolesPermitidos)) {
        // Por ahora permitimos acceso, pero idealmente se restringe aquí
        // throw new Exception("Acceso no autorizado a reportes gerenciales", 403);
    }

    // 2. Parámetros de Filtro (Rango de Fechas)
    // Por defecto: Últimos 30 días o Mes Actual
    $fechaInicio = isset($_GET['fecha_inicio']) ? $_GET['fecha_inicio'] : date('Y-m-01'); // Primer día del mes actual
    $fechaFin = isset($_GET['fecha_fin']) ? $_GET['fecha_fin'] : date('Y-m-d'); // Hoy

    // Validar formato de fecha básico
    if (!strtotime($fechaInicio) || !strtotime($fechaFin)) {
        throw new Exception("Formato de fecha inválido");
    }

    $response = [
        'periodo' => [
            'inicio' => $fechaInicio,
            'fin' => $fechaFin
        ],
        'generado_el' => date('Y-m-d H:i:s')
    ];

    // 3. KPI: Distribución por Estado (Pie Chart)
    // Usamos el nombre del estado para la etiqueta
    $sqlEstados = "SELECT 
                    e.nombre_estado as label, 
                    e.color as color,
                    COUNT(s.id) as value
                   FROM servicios s
                   JOIN estados_proceso e ON s.estado = e.id
                   WHERE DATE(s.fecha_registro) BETWEEN ? AND ?
                   GROUP BY s.estado, e.nombre_estado, e.color";

    $stmt = $conn->prepare($sqlEstados);
    $stmt->bind_param("ss", $fechaInicio, $fechaFin);
    $stmt->execute();
    $result = $stmt->get_result();
    $response['distribucion_estados'] = $result->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    // 4. KPI: Distribución por Tipo de Mantenimiento (Doughnut Chart)
    $sqlTipos = "SELECT 
                    tipo_mantenimiento as label, 
                    COUNT(id) as value
                 FROM servicios 
                 WHERE DATE(fecha_registro) BETWEEN ? AND ?
                 GROUP BY tipo_mantenimiento";

    $stmt = $conn->prepare($sqlTipos);
    $stmt->bind_param("ss", $fechaInicio, $fechaFin);
    $stmt->execute();
    $result = $stmt->get_result();
    $response['tipos_mantenimiento'] = $result->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    // 5. KPI: Carga de Trabajo por Técnico (Bar Chart)
    // Top 10 técnicos con más servicios asignados en el periodo
    $sqlTecnicos = "SELECT 
                        u.NOMBRE_USER as label,
                        COUNT(s.id) as value
                    FROM servicios s
                    LEFT JOIN usuarios u ON s.responsable_id = u.id
                    WHERE DATE(s.fecha_registro) BETWEEN ? AND ?
                    AND s.responsable_id IS NOT NULL
                    GROUP BY s.responsable_id, u.NOMBRE_USER
                    ORDER BY value DESC
                    LIMIT 10";

    $stmt = $conn->prepare($sqlTecnicos);
    $stmt->bind_param("ss", $fechaInicio, $fechaFin);
    $stmt->execute();
    $result = $stmt->get_result();
    $response['carga_tecnicos'] = $result->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    // 6. Resumen General (Cards)
    $sqlResumen = "SELECT 
                    COUNT(*) as total_servicios,
                    SUM(CASE WHEN e.nombre_estado LIKE '%Finalizado%' OR e.nombre_estado LIKE '%Cerrado%' THEN 1 ELSE 0 END) as finalizados,
                    SUM(CASE WHEN e.nombre_estado NOT LIKE '%Finalizado%' AND e.nombre_estado NOT LIKE '%Cerrado%' AND s.anular_servicio != 1 THEN 1 ELSE 0 END) as activos,
                    SUM(CASE WHEN s.anular_servicio = 1 THEN 1 ELSE 0 END) as anulados
                   FROM servicios s
                   LEFT JOIN estados_proceso e ON s.estado = e.id
                   WHERE DATE(s.fecha_registro) BETWEEN ? AND ?";

    $stmt = $conn->prepare($sqlResumen);
    $stmt->bind_param("ss", $fechaInicio, $fechaFin);
    $stmt->execute();
    $result = $stmt->get_result();
    $response['resumen'] = $result->fetch_assoc();
    $stmt->close();

    // 7. Listado de Servicios Anulados (Razones)
    $sqlAnulados = "SELECT 
                        s.id,
                        s.o_servicio,
                        s.razon as motivo,
                        s.fecha_actualizacion as fecha,
                        u.NOMBRE_USER as usuario
                    FROM servicios s
                    LEFT JOIN usuarios u ON s.usuario_ultima_actualizacion = u.id
                    WHERE s.anular_servicio = 1 
                    AND DATE(s.fecha_registro) BETWEEN ? AND ?
                    ORDER BY s.fecha_actualizacion DESC
                    LIMIT 20";

    $stmt = $conn->prepare($sqlAnulados);
    $stmt->bind_param("ss", $fechaInicio, $fechaFin);
    $stmt->execute();
    $result = $stmt->get_result();
    $response['servicios_anulados'] = $result->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    // 8. KPI: Top Equipos con Mayor Costo en Repuestos
    $sqlTopEquipos = "SELECT 
                        e.nombre as label,
                        SUM(sr.cantidad * sr.costo_unitario) as value
                      FROM servicio_repuestos sr
                      JOIN servicios s ON sr.servicio_id = s.id
                      JOIN equipos e ON s.id_equipo = e.id
                      WHERE DATE(s.fecha_registro) BETWEEN ? AND ?
                      GROUP BY e.id, e.nombre
                      ORDER BY value DESC
                      LIMIT 5";

    $stmt = $conn->prepare($sqlTopEquipos);
    $stmt->bind_param("ss", $fechaInicio, $fechaFin);
    $stmt->execute();
    $result = $stmt->get_result();
    $response['top_equipos_costo'] = $result->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    // 8. KPI: Top Repuestos Más Utilizados (Cantidad)
    $sqlTopRepuestos = "SELECT 
                        i.name as label,
                        SUM(sr.cantidad) as value
                        FROM servicio_repuestos sr
                        JOIN inventory_items i ON sr.inventory_item_id = i.id
                        JOIN servicios s ON sr.servicio_id = s.id
                        WHERE DATE(s.fecha_registro) BETWEEN ? AND ?
                        GROUP BY i.id, i.name
                        ORDER BY value DESC
                        LIMIT 5";

    $stmt = $conn->prepare($sqlTopRepuestos);
    $stmt->bind_param("ss", $fechaInicio, $fechaFin);
    $stmt->execute();
    $result = $stmt->get_result();
    $response['top_repuestos_uso'] = $result->fetch_all(MYSQLI_ASSOC);
    $stmt->close();


    // Enviar respuesta
    echo json_encode([
        'success' => true,
        'data' => $response
    ]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
