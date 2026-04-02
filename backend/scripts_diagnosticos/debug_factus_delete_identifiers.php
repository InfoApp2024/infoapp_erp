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

    $identifiers = [
        "SETP990022792",
        "INV/2026/00003"
    ];

    foreach ($identifiers as $id) {
        $url = FACTUS_API_URL . "/v1/bills/" . urlencode($id);
        echo "probando DELETE en $url...\n";

        $ch = curl_init($url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_CUSTOMREQUEST, "DELETE");
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Authorization: Bearer ' . $token,
            'Accept: application/json'
        ]);

        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        echo "HTTP CODE: $httpCode | RESPONSE: $response\n\n";
    }

} catch (Exception $e) {
    echo "ERROR: " . $e->getMessage() . "\n";
}
