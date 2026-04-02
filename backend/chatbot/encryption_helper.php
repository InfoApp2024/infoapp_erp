<?php
// backend/chatbot/encryption_helper.php

// Esta clave debe mantenerse SECRETA. 
// En producción, debería estar en variables de entorno, pero para este caso la definimos aquí o en config.
define('ENCRYPTION_KEY', 'v9Kx3B8nL2pQ5rZ7wX1jM4tY6hF0cD3g'); // 32 chars for AES-256
define('ENCRYPTION_METHOD', 'aes-256-cbc');

function encryptData($data)
{
  $ivLength = openssl_cipher_iv_length(ENCRYPTION_METHOD);
  $iv = openssl_random_pseudo_bytes($ivLength);
  $encrypted = openssl_encrypt($data, ENCRYPTION_METHOD, ENCRYPTION_KEY, 0, $iv);
  // Devolvemos IV + Data encriptada codificada en base64 para almacenamiento seguro
  return base64_encode($iv . $encrypted);
}

function decryptData($encryptedData)
{
  $data = base64_decode($encryptedData);
  $ivLength = openssl_cipher_iv_length(ENCRYPTION_METHOD);

  // Extraer IV y texto cifrado
  $iv = substr($data, 0, $ivLength);
  $encryptedText = substr($data, $ivLength);

  return openssl_decrypt($encryptedText, ENCRYPTION_METHOD, ENCRYPTION_KEY, 0, $iv);
}
