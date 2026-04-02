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

    // Consultar facturas buscando cualquier estado que no sea validado
    for ($p = 1; $p <= 10; $p++) {
        $url = FACTUS_API_URL . "/v1/bills?page=$p&per_page=100";
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
                // Si el estatus es diferente de 1 (Validado) o si hay campos de error
                if (($bill['status'] ?? 0) != 1 || ($bill['is_valid'] ?? 1) == 0) {
                    echo "ENCONTRADA SOSPECHOSA: ID=" . $bill['id'] . " | Ref=" . ($bill['reference_code'] ?? 'N/A') . " | Status=" . ($bill['status'] ?? '?') . " | Valid=" . ($bill['is_valid'] ?? '?') . "\n";
                }
            }
        } else {
            break;
        }
    }

    echo "Búsqueda de sospechosas terminada.\n";

} catch (Exception $e) {
    echo "ERROR: " . $e->getMessage() . "\n";
}
