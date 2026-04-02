<?php
define('AUTH_REQUIRED', true);
require 'core/FactusConfig.php';

function getAccessToken()
{
    $url = FACTUS_API_URL . '/oauth/token';
    $payload = [
        'grant_type' => 'password',
        'client_id' => FACTUS_CLIENT_ID,
        'client_secret' => FACTUS_CLIENT_SECRET,
        'username' => FACTUS_USERNAME,
        'password' => FACTUS_PASSWORD
    ];

    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query($payload));
    curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/x-www-form-urlencoded']);

    $response = curl_exec($ch);
    curl_close($ch);

    $res = json_decode($response, true);
    return $res['access_token'] ?? null;
}

try {
    $token = getAccessToken();
    if (!$token)
        die("Error obteniendo token\n");

    $targetRef = 'OT-GRP-1771797034';
    $found = false;

    for ($page = 1; $page <= 20; $page++) {
        echo "Buscando en página $page...\n";
        $url = FACTUS_API_URL . "/v1/bills?page=$page&per_page=50";

        $ch = curl_init($url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Authorization: Bearer ' . $token,
            'Accept: application/json'
        ]);

        $response = curl_exec($ch);
        curl_close($ch);

        $data = json_decode($response, true);

        if (isset($data['data']['data'])) {
            foreach ($data['data']['data'] as $bill) {
                if (($bill['reference_code'] ?? '') == $targetRef) {
                    echo "--- FACTURA ENCONTRADA ---\n";
                    print_r($bill);
                    $found = true;
                    break 2;
                }
            }
        } else {
            break;
        }
    }

    if (!$found)
        echo "No se encontró la factura con referencia $targetRef en las primeras 20 páginas.\n";

} catch (Exception $e) {
    echo "ERROR: " . $e->getMessage() . "\n";
}
