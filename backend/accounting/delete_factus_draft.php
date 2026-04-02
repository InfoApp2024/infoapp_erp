<?php
/**
 * delete_factus_draft.php
 * Herramienta de emergencia para eliminar borradores bloqueantes en Factus.
 * Uso: Enviar ?bill_id=XXXXX vía GET o POST.
 */
define('AUTH_REQUIRED', true);
require_once '../login/auth_middleware.php';
require_once '../core/FactusService.php';
require_once '../core/FactusConfig.php'; // Added for FactusConfig

try {
    $currentUser = requireAuth();
    require '../conexion.php';

    $bill_id = $_REQUEST['bill_id'] ?? null;
    $action = $_REQUEST['action'] ?? 'delete';

    if ($action === 'list') {
        $token = FactusService::getAccessToken($conn);
        $apiUrl = rtrim(FactusConfig::getApiUrl(), '/');
        $url = "$apiUrl/v1/bills?per_page=50";

        $ch = curl_init($url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Authorization: Bearer ' . $token,
            'Accept: application/json'
        ]);

        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        $res = json_decode($response, true);

        echo json_encode([
            'success' => true,
            'http_code' => $httpCode,
            'token_preview' => substr($token, 0, 10) . '...',
            'original_response' => $res
        ]);
        exit;
    }

    if (!$bill_id) {
        throw new Exception("Se requiere el bill_id de Factus para proceder. Ejemplo: ?bill_id=XXXXX");
    }

    $token = FactusService::getAccessToken($conn);
    $apiUrl = rtrim(FactusConfig::getApiUrl(), '/');
    $ref_code = 'test75'; // Visto en el listado previo del usuario

    // Matriz de Nivel 3: Hail Mary
    $attempts = [
        ['method' => 'GET', 'url' => "$apiUrl/v1/bills/$bill_id", 'label' => 'GET Standard bills/{id}'],
        ['method' => 'DELETE', 'url' => "$apiUrl/v1/bills/$ref_code", 'label' => 'DELETE via reference_code'],
        ['method' => 'DELETE', 'url' => "$apiUrl/v1/bills/id/$bill_id", 'label' => 'DELETE via v1/bills/id/{id}'],
        ['method' => 'DELETE', 'url' => "$apiUrl/v1/bills?id=$bill_id", 'label' => 'DELETE with query param id'],
        ['method' => 'DELETE', 'url' => "$apiUrl/v1/bills?reference_code=$ref_code", 'label' => 'DELETE with query param ref'],
        ['method' => 'POST', 'url' => "$apiUrl/v1/bills/$bill_id/cancel", 'label' => 'POST bills/{id}/cancel'],
        ['method' => 'POST', 'url' => "$apiUrl/v1/bills/$bill_id/delete", 'label' => 'POST bills/{id}/delete'],
        ['method' => 'DELETE', 'url' => "$apiUrl/v1/invoices/$bill_id", 'label' => 'DELETE v1/invoices/{id}'],
        ['method' => 'GET', 'url' => "$apiUrl/v1/bills/reference/$ref_code", 'label' => 'GET via reference path']
    ];

    $results = [];
    $found_success = false;

    foreach ($attempts as $attempt) {
        $ch = curl_init($attempt['url']);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_CUSTOMREQUEST, $attempt['method']);

        $headers = [
            'Authorization: Bearer ' . $token,
            'Accept: application/json',
            'Content-Type: application/json'
        ];
        if (isset($attempt['headers'])) {
            $headers = array_merge($headers, $attempt['headers']);
        }

        curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);

        if ($attempt['method'] === 'POST') {
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode(['id' => $bill_id, 'reference_code' => $ref_code]));
        }

        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        $resObj = json_decode($response, true);
        $is_ok = ($httpCode === 200 || $httpCode === 204);

        $results[] = [
            'label' => $attempt['label'],
            'method' => $attempt['method'],
            'url' => $attempt['url'],
            'code' => $httpCode,
            'success' => $is_ok,
            'response' => $resObj ?? $response
        ];

        if ($is_ok && $attempt['method'] !== 'GET') {
            $found_success = true;
        }
    }

    echo json_encode([
        'success' => $found_success,
        'message' => $found_success ? "Se logró eliminar el borrador." : "Escaneo Nivel 3 fallido. El recurso parece inalcanzable individualmente.",
        'scan_results' => $results,
        'hint' => "Intenta con action=list para ver si el ID sigue ahí."
    ]);

} catch (Exception $e) {
    header('Content-Type: application/json');
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
