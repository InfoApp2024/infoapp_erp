<?php
define('AUTH_REQUIRED', true);
require __DIR__ . '/backend/core/FactusService.php';

$factusPayload = [
    'numbering_range_id' => 8,
    'reference_code' => "T" . time(),
    'customer' => [
        'identification' => "123",
        'dv' => null,
        'company' => null,
        'trade_name' => "PRUEBA",
        'names' => "PRUEBA",
        'address' => "Dir",
        'email' => "p@g.com",
        'phone' => "300",
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
            'code_reference' => "C1",
            'name' => "S1",
            'quantity' => 1,
            'discount_rate' => "0.00",
            'price' => 1000,
            'withholding_taxes' => []
        ]
    ],
    'payment_form' => "1",
    'payment_method_code' => "10",
    'is_asynchronous' => false
];

$token = FactusService::getAccessToken();
$url = rtrim(FACTUS_API_URL, '/') . '/v1/bills/validate';
$ch = curl_init($url);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_CUSTOMREQUEST, "POST");
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($factusPayload));
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Authorization: Bearer ' . $token,
    'Content-Type: application/json',
    'Accept: application/json',
    'User-Agent: InfoApp-ERP/1.0'
]);

$res = curl_exec($ch);
echo "RES_START:" . $res . ":RES_END";
curl_close($ch);
