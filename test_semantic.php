<?php
define('AUTH_REQUIRED', true);
require __DIR__ . '/backend/core/FactusService.php';

$token = FactusService::getAccessToken();
$variants = [
    '/v1/bills',
    '/v1/bills/store',
    '/v1/bills/create',
    '/v1/invoices',
    '/v1/invoices/store',
    '/v1/invoices/create',
    '/v2/bills'
];

foreach ($variants as $v) {
    $url = rtrim(FACTUS_API_URL, '/') . $v;
    echo "Testing $url ... ";
    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_CUSTOMREQUEST, "POST");
    curl_setopt($ch, CURLOPT_POSTFIELDS, "{}");
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Authorization: Bearer ' . $token,
        'Accept: application/json',
        'Content-Type: application/json',
        'User-Agent: InfoApp-ERP/1.0'
    ]);
    curl_exec($ch);
    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    echo "CODE: $code\n";
    curl_close($ch);
}
