<?php

namespace Core;

/**
 * PDFGeneratorFactory
 * 
 * Clase encargada de gestionar la generación de PDFs utilizando diferentes motores.
 * Soporta 'modern' (Mpdf) para diseños complejos y 'legacy' (TCPPDF) para compatibilidad.
 */
class PDFGeneratorFactory
{
    private $engine;
    private $html;
    private $css;
    private $options;

    public function __construct(string $engine = 'legacy', array $options = [])
    {
        $this->engine = strtolower($engine);
        $this->options = $options;
        $this->loadDependencies();
    }

    /**
     * Registro de logs centralizado para el factory.
     */
    private function log($msg)
    {
        $logPath = dirname(__DIR__) . '/informes/debug_vista_previa_pdf.txt';
        $time = date('Y-m-d H:i:s');
        file_put_contents($logPath, "[$time][FACTORY] $msg\n", FILE_APPEND);
    }

    /**
     * Carga las dependencias necesarias de forma robusta.
     */
    private function loadDependencies()
    {
        // 1. Intentar autoloader de Composer
        $autoloadPath = dirname(__DIR__) . '/vendor/autoload.php';
        if (file_exists($autoloadPath)) {
            $this->log("✅ Autoloader encontrado en: $autoloadPath");
            require_once $autoloadPath;
        } else {
            $this->log("❌ Autoloader NO encontrado en: $autoloadPath");
        }

        // 2. Fallback manual para TCPDF
        if (!class_exists('\TCPDF')) {
            $tcpdfPath = dirname(__DIR__) . '/vendor/tecnickcom/tcpdf/tcpdf.php';
            if (file_exists($tcpdfPath)) {
                $this->log("✅ TCPDF encontrado manualmente en: $tcpdfPath");
                require_once $tcpdfPath;
            } else {
                $this->log("❌ TCPDF NO encontrado manualmente en: $tcpdfPath");
            }
        } else {
            $this->log("✅ TCPDF ya está cargado.");
        }

        // Check Mpdf
        if (class_exists('\Mpdf\Mpdf')) {
            $this->log("✅ Mpdf detectado correctamente.");
        } else {
            $this->log("❌ Mpdf NO detectado después de cargar autoloader.");
            // Intentar fallback para Mpdf si existe la carpeta
            $mpdfFallback = dirname(__DIR__) . '/vendor/mpdf/mpdf/src/Mpdf.php';
            if (file_exists($mpdfFallback)) {
                $this->log("⚠️ Intentando carga manual de Mpdf (Fallback): $mpdfFallback");
                // Mpdf v8 no se puede cargar con un solo archivo fácilmente debido a PSR-4
            }
        }
    }

    /**
     * Sanea el HTML para evitar inyecciones de scripts o acceso a archivos locales no autorizados.
     */
    public static function sanitizeHtml(string $html): string
    {
        $html = preg_replace('/<script\b[^>]*>(.*?)<\/script>/is', '', $html);
        $html = preg_replace('/on\w+\s*=\s*(["\'])(.*?)\1/is', '', $html);
        $html = str_replace('file://', '', $html);
        return $html;
    }

    /**
     * Genera el PDF y lo devuelve según el modo solicitado (I Por defecto).
     */
    public function generate(string $html, string $css = '', string $filename = 'documento.pdf', string $dest = 'I')
    {
        $this->html = self::sanitizeHtml($html);
        $this->css = $css;

        if ($this->engine === 'modern') {
            if (class_exists('\Mpdf\Mpdf')) {
                return $this->generateWithMpdf($filename, $dest);
            } else {
                // Fallback a legacy si modern (Mpdf) no está disponible en el servidor
                $this->log("⚠️ Fallback detectado: modern no disponible, usando legacy.");
                return $this->generateWithTCPDF($filename, $dest);
            }
        } else {
            return $this->generateWithTCPDF($filename, $dest);
        }
    }

    /**
     * Motor Moderno: Mpdf
     */
    private function generateWithMpdf(string $filename, string $dest)
    {
        ini_set("memory_limit", "256M");
        set_time_limit(60);

        $config = [
            'mode' => 'utf-8',
            'format' => $this->options['format'] ?? 'A4',
            'margin_left' => $this->options['margin_left'] ?? 10,
            'margin_right' => $this->options['margin_right'] ?? 10,
            'margin_top' => $this->options['margin_top'] ?? 10,
            'margin_bottom' => $this->options['margin_bottom'] ?? 10,
            'packTableData' => true,
            'tempDir' => dirname(__DIR__) . '/uploads/mpdf_temp',
            'allow_url_fopen' => true,
            'autoScriptToLang' => true,
            'autoLangToFont' => true,
            'shrink_tables_to_fit' => 1,
            'use_kwt' => true,
        ];

        if (!is_dir($config['tempDir'])) {
            mkdir($config['tempDir'], 0775, true);
        }
        $this->log("📁 Mpdf TempDir: " . $config['tempDir'] . (is_writable($config['tempDir']) ? " (Writable)" : " (NOT Writable)"));

        // Usar nombre completo global
        $mpdf = new \Mpdf\Mpdf($config);
        $mpdf->img_dpi = 96;
        $mpdf->showImageErrors = true; // Habilitar para diagnóstico

        $this->log("📊 Inyectando CSS y procesando HTML (len: " . strlen($this->html) . ")");
        $this->log("📊 HTML Prefix: " . substr($this->html, 0, 200));
        $this->log("📊 HTML Suffix: " . substr($this->html, -200));

        // CSS de compatibilidad para motores PDF (Mpdf no soporta Flexbox/Grid)
        $defaultCss = "
            tr, td, img { page-break-inside: avoid; }
            img { max-width: 100%; height: auto; }
            /* Correcciones para Mpdf */
            .flex, .d-flex, .grid, .d-grid { display: block !important; }
            .flex-row, .row { display: block !important; width: 100%; }
            .col, [class*='col-'] { display: block !important; width: 100% !important; float: none !important; }
            div { page-break-inside: auto; }
        ";

        // Cargar CSS base y extra como HEADER_CSS
        $mpdf->WriteHTML($defaultCss, \Mpdf\HTMLParserMode::HEADER_CSS);
        if (!empty($this->css)) {
            $mpdf->WriteHTML($this->css, \Mpdf\HTMLParserMode::HEADER_CSS);
        }

        // Para el HTML principal, NO usamos HTML_BODY (2) porque si el HTML
        // contiene etiquetas <style> o estructura completa, Mpdf las ignoraría y renderizaría como texto.
        // Usamos el modo por defecto (0) que procesa todo el documento.
        $mpdf->WriteHTML($this->html);

        $this->log("✅ Mpdf: WriteHTML completado.");
        return $mpdf->Output($filename, $dest);
    }

    /**
     * Motor Legacy: TCPDF
     */
    private function generateWithTCPDF(string $filename, string $dest)
    {
        if (!class_exists('\TCPDF')) {
            throw new \Exception("Error Crítico: Clase TCPDF no encontrada. Verifique la instalación en vendor.");
        }

        $pdf = new \TCPDF(
            $this->options['orientation'] ?? 'P',
            'mm',
            $this->options['format'] ?? 'A4',
            true,
            'UTF-8',
            false
        );

        $pdf->SetCreator('InfoApp');
        $pdf->SetAuthor('InfoApp');
        $pdf->SetTitle($filename);
        $pdf->setPrintHeader(false);
        $pdf->setPrintFooter(false);
        $pdf->SetMargins(
            $this->options['margin_left'] ?? 10,
            $this->options['margin_top'] ?? 10,
            $this->options['margin_right'] ?? 10
        );
        $pdf->SetAutoPageBreak(true, $this->options['margin_bottom'] ?? 10);
        $pdf->SetFont('helvetica', '', 10);
        $pdf->AddPage();

        if (!empty($this->css)) {
            $this->html = '<style>' . $this->css . '</style>' . $this->html;
        }

        $pdf->writeHTML($this->html, true, false, true, false, '');
        return $pdf->Output($filename, $dest);
    }
}
