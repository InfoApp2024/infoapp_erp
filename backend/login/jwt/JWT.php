<?php
// jwt/JWT.php
// ✅ Versión simplificada de Firebase JWT sin namespaces

class JWT {
    
    /**
     * Codifica un payload en un token JWT
     */
    public static function encode($payload, $key, $alg = 'HS256') {
        $header = ['typ' => 'JWT', 'alg' => $alg];
        
        $segments = [];
        $segments[] = self::urlsafeB64Encode(json_encode($header));
        $segments[] = self::urlsafeB64Encode(json_encode($payload));
        
        $signing_input = implode('.', $segments);
        $signature = self::sign($signing_input, $key, $alg);
        $segments[] = self::urlsafeB64Encode($signature);
        
        return implode('.', $segments);
    }
    
    /**
     * Decodifica un token JWT
     */
    public static function decode($jwt, $key, $allowed_algs = ['HS256']) {
        $segments = explode('.', $jwt);
        
        if (count($segments) != 3) {
            throw new Exception('JWT debe tener 3 segmentos');
        }
        
        list($headb64, $bodyb64, $cryptob64) = $segments;
        
        if (null === ($header = json_decode(self::urlsafeB64Decode($headb64)))) {
            throw new Exception('Header JSON inválido');
        }
        
        if (null === $payload = json_decode(self::urlsafeB64Decode($bodyb64))) {
            throw new Exception('Payload JSON inválido');
        }
        
        if (!property_exists($header, 'alg')) {
            throw new Exception('Algoritmo no especificado');
        }
        
        if (!in_array($header->alg, $allowed_algs)) {
            throw new Exception('Algoritmo no permitido');
        }
        
        $sig = self::urlsafeB64Decode($cryptob64);
        
        // Verificar la firma
        if (!self::verify("$headb64.$bodyb64", $sig, $key, $header->alg)) {
            throw new SignatureInvalidException('Firma inválida');
        }
        
        // Verificar timestamps
        if (isset($payload->nbf) && $payload->nbf > time()) {
            throw new BeforeValidException('Token no es válido todavía');
        }
        
        if (isset($payload->exp) && $payload->exp < time()) {
            throw new ExpiredException('Token expirado');
        }
        
        return $payload;
    }
    
    /**
     * Firmar datos con una clave
     */
    private static function sign($msg, $key, $method = 'HS256') {
        switch ($method) {
            case 'HS256':
                return hash_hmac('sha256', $msg, $key, true);
            default:
                throw new Exception('Algoritmo no soportado');
        }
    }
    
    /**
     * Verificar firma
     */
    private static function verify($msg, $signature, $key, $method = 'HS256') {
        switch ($method) {
            case 'HS256':
                $hash = hash_hmac('sha256', $msg, $key, true);
                return hash_equals($signature, $hash);
            default:
                throw new Exception('Algoritmo no soportado');
        }
    }
    
    /**
     * Codificar en base64 URL-safe
     */
    private static function urlsafeB64Encode($input) {
        return str_replace('=', '', strtr(base64_encode($input), '+/', '-_'));
    }
    
    /**
     * Decodificar desde base64 URL-safe
     */
    private static function urlsafeB64Decode($input) {
        $remainder = strlen($input) % 4;
        if ($remainder) {
            $padlen = 4 - $remainder;
            $input .= str_repeat('=', $padlen);
        }
        return base64_decode(strtr($input, '-_', '+/'));
    }
}
?>