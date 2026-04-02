<?php
// Configuraciones globales de InfoApp
// Controla el motor por defecto para generar PDFs.
// Valores permitidos: 'browser' (Chromium/Browsershot) o 'tcpdf'
if (!defined('PDF_RENDERER_DEFAULT')) {
    define('PDF_RENDERER_DEFAULT', 'browser');
}

// Puedes cambiar este valor a true si quieres que por defecto
// se intente abrir el PDF en el navegador (inline). El cliente
// aún puede sobrescribirlo enviando {"inline": true/false}.
if (!defined('PDF_INLINE_DEFAULT')) {
    define('PDF_INLINE_DEFAULT', false);
}

?>