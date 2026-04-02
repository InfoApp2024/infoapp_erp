<?php
/**
 * FactusService.php
 * Servicio para integración con la API de Factus (Facturación Electrónica).
 */

if (!defined('AUTH_REQUIRED')) {
    header('HTTP/1.0 403 Forbidden');
    exit('Acceso directo no permitido');
}
require_once 'FactusConfig.php';

class FactusService
{
    private static $token = null;

    /**
     * Obtiene el token de acceso OAuth2 usando credenciales dinámicas.
     */
    public static function getAccessToken($conn)
    {
        if (self::$token)
            return self::$token;

        $url = FactusConfig::getApiUrl() . '/oauth/token';
        $payload = [
            'grant_type' => 'password',
            'client_id' => FactusConfig::getClientId($conn),
            'client_secret' => FactusConfig::getClientSecret($conn),
            'username' => FactusConfig::getUsername($conn),
            'password' => FactusConfig::getPassword($conn)
        ];

        // Validación preventiva de credenciales
        if (empty($payload['client_id']) || empty($payload['client_secret'])) {
            throw new Exception("Error Factus: Credenciales OAuth2 no configuradas en app_settings.");
        }

        $ch = curl_init($url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query($payload));
        curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/x-www-form-urlencoded']);

        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        $res = json_decode($response, true);
        if ($httpCode === 200 && isset($res['access_token'])) {
            self::$token = $res['access_token'];
            return self::$token;
        }

        throw new Exception("Error de Autenticación Factus: " . ($res['message'] ?? 'Token no recibido. Verifique credenciales en app_settings.'));
    }

    /**
     * Envía una factura a la API de Factus.
     */
    public static function sendInvoice($conn, $data)
    {
        $token = self::getAccessToken($conn);
        $url = rtrim(FactusConfig::getApiUrl(), '/') . '/v1/bills/validate';

        $ch = curl_init($url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_CUSTOMREQUEST, "POST");
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));

        curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
        curl_setopt($ch, CURLOPT_POSTREDIR, 3);

        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Authorization: Bearer ' . $token,
            'Content-Type: application/json',
            'Accept: application/json',
            'User-Agent: InfoApp-ERP/1.0'
        ]);

        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);

        if (curl_errno($ch)) {
            throw new Exception("Error de conexión cURL: " . curl_error($ch));
        }

        curl_close($ch);

        $res = json_decode($response, true);

        if ($httpCode === 201 || $httpCode === 200) {
            $bill = $res['data']['bill'] ?? null;
            $range = $res['data']['numbering_range'] ?? null;

            if (!$bill) {
                throw new Exception("Factus OK ($httpCode) pero falta el objeto 'bill' en data.");
            }

            if (empty($bill['prefix']) && !empty($range['prefix'])) {
                $res['data']['bill']['prefix'] = $range['prefix'];
                $bill = $res['data']['bill'];
            }

            // Inyectar QR si viene en campo alternativo
            if (empty($bill['qr']) && !empty($bill['qr_image'])) {
                $res['data']['bill']['qr'] = $bill['qr_image'];
            }

            return $res;
        }

        $errorDetail = $res['message'] ?? "Error de validación desconocido";
        if (isset($res['errors'])) {
            $formattedErrors = [];
            foreach ($res['errors'] as $field => $messages) {
                $fieldLabel = ucwords(str_replace(['.', '_'], ' ', $field));
                $msg = is_array($messages) ? implode(', ', $messages) : $messages;
                $formattedErrors[] = "[$fieldLabel]: $msg";
            }
            $errorDetail .= "\nDetalles:\n" . implode("\n", $formattedErrors);
        }

        // Para la limpieza atómica (Status 0), inyectamos el JSON de respuesta en el mensaje
        // para que el controlador pueda extraer el bill_id si existe.
        $payload = [
            'http_code' => $httpCode,
            'message' => $errorDetail,
            'original_res' => $res
        ];

        throw new Exception("FACTUS_API_ERROR:" . json_encode($payload));
    }

    /**
     * Elimina un borrador o factura de Factus (Limpieza Atómica).
     */
    public static function deleteBill($conn, $billId)
    {
        if (!$billId)
            return false;

        $token = self::getAccessToken($conn);
        $url = rtrim(FactusConfig::getApiUrl(), '/') . '/v1/bills/' . $billId;

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

        return ($httpCode === 200 || $httpCode === 204);
    }

    /**
     * Busca facturas que no han sido validadas.
     */
    public static function getPendingInvoices($conn)
    {
        $token = self::getAccessToken($conn);
        $url = rtrim(FactusConfig::getApiUrl(), '/') . '/v1/bills?per_page=20';

        $ch = curl_init($url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Authorization: Bearer ' . $token,
            'Accept: application/json'
        ]);

        $response = curl_exec($ch);
        curl_close($ch);

        $res = json_decode($response, true);
        $pending = [];

        if (isset($res['data']['data'])) {
            foreach ($res['data']['data'] as $bill) {
                if (($bill['status'] ?? 0) != 1) {
                    $pending[] = $bill;
                }
            }
        }

        return $pending;
    }

    /**
     * Obtiene los rangos de numeración activos.
     */
    public static function getNumberingRanges($conn)
    {
        $token = self::getAccessToken($conn);
        $url = rtrim(FactusConfig::getApiUrl(), '/') . '/v1/numbering-ranges';

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
        if ($httpCode === 200) {
            return $res['data']['data'] ?? $res['data'] ?? [];
        }
        return [];
    }

    /**
     * Obtiene dinámicamente el ID del rango de numeración activo.
     */
    public static function getActiveRangeId($conn)
    {
        $ranges = self::getNumberingRanges($conn);

        foreach ($ranges as $range) {
            $docType = strtolower($range['document'] ?? '');
            $prefix = strtoupper($range['prefix'] ?? '');

            if (strpos($docType, 'factura') !== false || in_array($prefix, ['SETP', 'SETT', 'FE'])) {
                if ($range['is_active'] ?? false) {
                    return $range['id'];
                }
            }
        }

        // Si no se detecta dinámicamente, usar el de app_settings
        return FactusConfig::getNumberingRangeId($conn) ?? '1';
    }

    /**
     * Busca configuraciones dinámicas de impuestos.
     */
    public static function getTaxConfigs($conn, $tipo, $ciiu = null)
    {
        $sql = "SELECT nombre_impuesto, porcentaje, base_minima_pesos 
                FROM impuestos_config 
                WHERE tipo_impuesto = ? AND estado = 1";

        if ($ciiu !== null) {
            $sql .= " AND (codigo_ciiu = ? OR codigo_ciiu IS NULL)";
        } else {
            $sql .= " AND codigo_ciiu IS NULL";
        }

        $stmt = $conn->prepare($sql);
        if ($ciiu !== null) {
            $stmt->bind_param("ss", $tipo, $ciiu);
        } else {
            $stmt->bind_param("s", $tipo);
        }

        $stmt->execute();
        $res = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
        $stmt->close();

        return $res;
    }

    /**
     * Mapea los datos del cliente al formato de Factus.
     */
    public static function mapCustomer($cliente)
    {
        $nit = trim($cliente['documento_nit']);
        $dv = isset($cliente['dv']) && !is_null($cliente['dv']) ? trim($cliente['dv']) : self::calcularDV($nit);
        $email = !empty($cliente['email_facturacion']) ? $cliente['email_facturacion'] :
            (!empty($cliente['email']) ? $cliente['email'] : null);

        if (empty($email)) {
            throw new Exception("Error Legal: El cliente no tiene un correo electrónico definido para la recepción de facturas. Por favor, actualice los datos del cliente antes de continuar.");
        }

        $tipo_persona = trim($cliente['tipo_persona']);
        $is_juridica = (mb_stripos($tipo_persona, 'juridica') !== false);

        return [
            'identification' => $nit,
            'dv' => $dv,
            'company' => $is_juridica ? $cliente['nombre_completo'] : null,
            'trade_name' => $cliente['nombre_completo'],
            'names' => $cliente['nombre_completo'],
            'address' => (!empty($cliente['direccion'])) ? $cliente['direccion'] : 'Cr 1 # 1-1',
            'email' => $email,
            'phone' => (!empty($cliente['telefono_principal'])) ? $cliente['telefono_principal'] : '3000000000',
            'legal_organization_id' => $is_juridica ? 2 : 1,
            'tribute_id' => ($cliente['regimen_tributario'] === 'Responsable de IVA' || $cliente['es_gran_contribuyente'] == 1) ? 21 : 18,
            'identification_document_id' => $is_juridica ? 6 : ((strlen($nit) >= 9) ? 6 : 3),
            'municipality_id' => 982
        ];
    }

    private static function calcularDV($nit)
    {
        if (!is_numeric($nit))
            return null;
        $arr = [3, 7, 13, 17, 19, 23, 29, 37, 41, 43, 47, 53, 59, 67, 71];
        $x = 0;
        $y = 0;
        $z = strlen($nit);
        for ($i = 0; $i < $z; $i++) {
            $y = substr($nit, $z - 1 - $i, 1);
            $x += ($y * $arr[$i]);
        }
        $y = $x % 11;
        return ($y > 1) ? (11 - $y) : $y;
    }

    public static function mapItems($servicios, $cliente, $tax_engine_data = [])
    {
        $mapped = [];
        // IVA puede venir como lista de configuraciones, tomamos la primera
        $iva_rate = $tax_engine_data['IVA'][0]['porcentaje'] ?? 19.00;

        foreach ($servicios as $s) {
            $ot = $s['numero_orden'] ?? $s['servicio_id'];
            $items_count_before = count($mapped);

            if ((float) ($s['total_repuestos'] ?? 0) > 0) {
                $base = (float) $s['total_repuestos'];
                $mapped[] = [
                    'standard_code_id' => 1,
                    'is_excluded' => 0,
                    'tribute_id' => 1,
                    'tax_rate' => number_format($iva_rate, 2, '.', ''),
                    'unit_measure_id' => 70,
                    'code_reference' => "REP-$ot",
                    'name' => "Repuestos de: " . ($s['nombre_servicio'] ?? "Servicio OT $ot"),
                    'quantity' => 1,
                    'discount_rate' => "0.00",
                    'price' => $base,
                    'withholding_taxes' => self::calculateWithholdings($base, $cliente, $tax_engine_data)
                ];
            }

            if ((float) ($s['total_mano_obra'] ?? 0) > 0) {
                $base = (float) $s['total_mano_obra'];
                $mapped[] = [
                    'standard_code_id' => 1,
                    'is_excluded' => 0,
                    'tribute_id' => 1,
                    'tax_rate' => number_format($iva_rate, 2, '.', ''),
                    'unit_measure_id' => 70,
                    'code_reference' => "MO-$ot",
                    'name' => ($s['nombre_servicio'] ?? "Mano de Obra") . " (OT $ot)",
                    'quantity' => 1,
                    'discount_rate' => "0.00",
                    'price' => $base,
                    'withholding_taxes' => self::calculateWithholdings($base, $cliente, $tax_engine_data)
                ];
            }

            // [ROBUSTEZ]: Si el total es > 0 pero no clasificó en Repuestos ni M.O., agregar como Servicio General
            if (count($mapped) === $items_count_before && (float) ($s['valor_snapshot'] ?? 0) > 0) {
                $base = (float) $s['valor_snapshot'];
                $mapped[] = [
                    'standard_code_id' => 1,
                    'is_excluded' => 0,
                    'tribute_id' => 1,
                    'tax_rate' => number_format($iva_rate, 2, '.', ''),
                    'unit_measure_id' => 70,
                    'code_reference' => "SERV-$ot",
                    'name' => ($s['nombre_servicio'] ?? "Servicio Técnico") . " (OT $ot)",
                    'quantity' => 1,
                    'discount_rate' => "0.00",
                    'price' => $base,
                    'withholding_taxes' => self::calculateWithholdings($base, $cliente, $tax_engine_data)
                ];
            }
        }
        return $mapped;
    }

    public static function calculateWithholdings($base, $cliente, $tax_engine_data)
    {
        $iva_rate = ($tax_engine_data['IVA'][0]['porcentaje'] ?? 19.00) / 100;
        $tax_iva = $base * $iva_rate;
        $retenciones = [];

        $es_o13 = ($cliente['responsabilidad_fiscal_id'] ?? '') === 'O-13';
        $switch_reteiva = ($cliente['es_gran_contribuyente'] ?? 0) == 1;

        if ($es_o13 || $switch_reteiva) {
            $retenciones[] = [
                'code' => '05',
                'name' => 'ReteIVA 15%',
                'withholding_tax_rate' => '15.000',
                'amount' => round($tax_iva * 0.15, 2)
            ];
        }

        $es_agente = ($cliente['es_agente_retenedor'] ?? 0) == 1;
        $es_auto = ($cliente['es_autorretenedor'] ?? 0) == 1;

        if ($es_agente && !$es_auto) {
            $configs_rf = $tax_engine_data['RETEFUENTE'] ?? [];
            foreach ($configs_rf as $rf_cfg) {
                $base_min = (float) $rf_cfg['base_minima_pesos'];
                $pct = (float) $rf_cfg['porcentaje'];
                if ($base >= $base_min && $pct > 0) {
                    $retenciones[] = [
                        'code' => '06',
                        'name' => $rf_cfg['nombre_impuesto'] ?? 'ReteFuente',
                        'withholding_tax_rate' => number_format($pct, 3, '.', ''),
                        'amount' => round($base * ($pct / 100), 2)
                    ];
                }
            }
        }

        $configs_ica = $tax_engine_data['RETEICA'] ?? [];
        foreach ($configs_ica as $ica_cfg) {
            $tarifa = (float) $ica_cfg['tarifa_x_mil'];
            $base_min = (float) $ica_cfg['base_minima_pesos'];
            if ($base >= $base_min && $tarifa > 0) {
                $retenciones[] = [
                    'code' => '07',
                    'name' => $ica_cfg['nombre_impuesto'] ?? 'ReteICA',
                    'withholding_tax_rate' => number_format($tarifa, 3, '.', ''),
                    'amount' => round($base * ($tarifa / 1000), 2)
                ];
            }
        }

        return $retenciones;
    }
}
