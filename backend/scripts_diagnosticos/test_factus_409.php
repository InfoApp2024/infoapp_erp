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

    // Payload minimalista pero válido para prueba
    $data = [
        'numbering_range_id' => 8,
        'reference_code' => 'OT-TEST-' . time(),
        'customer' => [
            'identification' => '890101234',
            'dv' => 1,
            'company' => 'EMPRESA TEST',
            'trade_name' => 'EMPRESA TEST',
            'names' => 'EMPRESA TEST',
            'address' => 'Cl 1 # 1-1',
            'email' => 'test@example.com',
            'phone' => '3000000000',
            'legal_organization_id' => 2,
            'tribute_id' => 18,
            'identification_document_id' => 6,
            'municipality_id' => 982
        ],
        'items' => [
            [
                'standard_code_id' => 1,
                'is_excluded' => 0,
                'tribute_id' => 1,
                'tax_rate' => '19.00',
                'unit_measure_id' => 70,
                'code_reference' => 'TEST-001',
                'name' => 'Servicio de Prueba',
                'quantity' => 1,
                'discount_rate' => '0.00',
                'price' => 100000,
            ]
        ],
        'observation' => 'Prueba de diagnóstico error 409',
        'payment_form' => '1',
        'payment_method_code' => '10',
        'is_asynchronous' => false
    ];

    $url = FACTUS_API_URL . '/v1/bills/validate';

    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_CUSTOMREQUEST, "POST");
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Authorization: Bearer ' . $token,
        'Content-Type: application/json',
        'Accept: application/json'
    ]);

    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    echo "HTTP CODE: $httpCode\n";
    echo "RESPONSE: " . $response . "\n";

} catch (Exception $e) {
    echo "ERROR: " . $e->getMessage() . "\n";
}
