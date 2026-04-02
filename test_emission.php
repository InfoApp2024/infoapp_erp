<?php
define('AUTH_REQUIRED', true);
require __DIR__ . '/backend/core/FactusService.php';

$factusPayload = [
    'numbering_range_id' => 8, // SETP - Factura de Venta
    'reference_code' => "TEST-EMIT-" . time(),
    'customer' => [
        'identification' => "123",
        'dv' => null,
        'company' => null,
        'trade_name' => "CLIENTE PRUEBA",
        'names' => "CLIENTE PRUEBA",
        'address' => "Calle 123",
        'email' => "pruebas@gmail.com",
        'phone' => "3000000000",
        'legal_organization_id' => 2,
        'tribute_id' => 18,
        'identification_document_id' => 3,
        'municipality_id' => 982
    ],
    'items' => [
        [
            'standard_code_id' => 1,
            'is_excluded' => 0,
            'tribute_id' => 1,
            'tax_rate' => "19.00",
            'unit_measure_id' => 70,
            'code_reference' => "TEST-01",
            'name' => "Servicio de Prueba Emisión",
            'quantity' => 1,
            'discount_rate' => "0.00",
            'price' => 100000,
            'withholding_taxes' => [
                [
                    'code' => '06',
                    'withholding_tax_rate' => '4.00',
                    'amount' => 4000
                ]
            ]
        ]
    ],
    'payment_form' => "1",
    'payment_method_code' => "10",
    'is_asynchronous' => false
];

$token = FactusService::getAccessToken();
$payloads = [
    'NUMERIC_8' => array_merge($factusPayload, ['numbering_range_id' => 8]),
    'STRING_8' => array_merge($factusPayload, ['numbering_range_id' => "8"]),
    'PREFIX_SETP' => array_merge($factusPayload, ['numbering_range_id' => "SETP"])
];

foreach ($payloads as $label => $p) {
    echo "--- TESTING $label ---\n";
    $ch = curl_init(rtrim(FACTUS_API_URL, '/') . '/v1/bills/validate');
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_CUSTOMREQUEST, "POST");
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($p));
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Authorization: Bearer ' . $token,
        'Content-Type: application/json',
        'Accept: application/json',
        'User-Agent: InfoApp-ERP/1.0'
    ]);
    $res = curl_exec($ch);
    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    echo "HTTP CODE: $code\n";
    echo "RES: $res\n\n";
    curl_close($ch);
}
