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

    // El último ID conocido fue 31435. Probamos los siguientes.
    $startId = 31430;
    $endId = 31450;

    for ($id = $startId; $id <= $endId; $id++) {
        $url = FACTUS_API_URL . "/v1/bills/$id";

        $ch = curl_init($url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Authorization: Bearer ' . $token,
            'Accept: application/json'
        ]);

        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($httpCode === 200) {
            $bill = json_decode($response, true)['data'] ?? [];
            echo "ID: $id | Status: " . ($bill['status'] ?? '?') . " | Valid: " . ($bill['is_valid'] ?? '?') . " | Ref: " . ($bill['reference_code'] ?? '?') . "\n";
            if (($bill['status'] ?? 0) == 0 || ($bill['is_valid'] ?? 1) == 0) {
                echo ">>> POSIBLE BLOQUEO ENCONTRADO EN ID $id <<<\n";
            }
        } else {
            echo "ID: $id | HTTP CODE: $httpCode\n";
        }
    }

} catch (Exception $e) {
    echo "ERROR: " . $e->getMessage() . "\n";
}
