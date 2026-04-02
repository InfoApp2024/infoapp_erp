<?php
/**
 * master_setup.php - The "Single Source of Truth" for Database Initialization.
 * 
 * FEATURES:
 * - Full Orchestration: Core, Modules, Workflow, Migrations.
 * - Ultra-Robustness: Catches and reports mid-file SQL errors and self-healing failures.
 * - Self-Healing+: Automatically fixes PK and AUTO_INCREMENT issues on legacy tables.
 * - Diagnostic+: Precise query-level and path-level tracking.
 */

error_reporting(E_ALL);
ini_set('display_errors', 1);
set_time_limit(900); // 15 minutes max

header("Content-Type: application/json; charset=utf-8");

// Force mysqli to throw exceptions for easier catching in PHP 8.1+
mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);

$results = [
    "status" => "starting",
    "timestamp" => date('Y-m-d H:i:s'),
    "steps" => [],
    "errors" => [],
    "debug" => []
];

try {
    // 1. Connection
    $config_path = __DIR__ . '/../conexion.php';
    if (!file_exists($config_path)) {
        throw new Exception("Core connection file not found at $config_path");
    }
    require $config_path;

    if ($conn->connect_error) {
        throw new Exception("Database connection failed: " . $conn->connect_error);
    }

    /**
     * Helper to execute SQL file query-by-query for precise error reporting
     * Handles basic DELIMITER syntax for triggers/procedures
     */
    function executeSqlFile($mysqli, $filePath, $replacements = [])
    {
        if (!file_exists($filePath)) {
            return ["success" => false, "error" => "File not found: $filePath"];
        }

        $sql = file_get_contents($filePath);

        // Apply dynamic replacements (e.g. {{ID_REGISTRO}})
        if (!empty($replacements)) {
            foreach ($replacements as $search => $replace) {
                $sql = str_replace("{{" . $search . "}}", $mysqli->real_escape_string($replace), $sql);
            }
        }

        // Remove comments
        $sql = preg_replace('/--.*?\n/', '', $sql);
        $sql = preg_replace('/\/\*.*?\*\//s', '', $sql);

        $executed = 0;
        $errors = [];
        $currentDelimiter = ';';
        $blocks = preg_split("/(DELIMITER\s+\S+)/i", $sql, -1, PREG_SPLIT_DELIM_CAPTURE);

        foreach ($blocks as $block) {
            if (preg_match("/DELIMITER\s+(\S+)/i", $block, $matches)) {
                $currentDelimiter = $matches[1];
                continue;
            }

            $queries = explode($currentDelimiter, $block);
            foreach ($queries as $query) {
                $query = trim($query);
                if (empty($query))
                    continue;

                try {
                    $mysqli->query($query);
                    $executed++;
                } catch (Exception $e) {
                    $errMsg = $e->getMessage();
                    // Silenciar errores no críticos de duplicidad u objetos ya existentes
                    $isDuplicate = (strpos($errMsg, 'Duplicate') !== false ||
                        strpos($errMsg, 'already exists') !== false ||
                        strpos($errMsg, 'is not of type VIEW') !== false ||
                        strpos($errMsg, 'already closed') !== false);

                    if (!$isDuplicate) {
                        $errors[] = [
                            "error" => $errMsg,
                            "query" => substr($query, 0, 100)
                        ];
                    }
                }
            }
        }

        return [
            "success" => empty($errors),
            "queries_executed" => $executed,
            "errors" => $errors,
            "file" => basename($filePath)
        ];
    }

    /**
     * Helper to ensure a primary key has AUTO_INCREMENT
     * Fixes the common "Field 'id' doesn't have a default value" error on legacy DBs
     */
    function ensureIdAutoIncrement($mysqli, $table)
    {
        try {
            // Ignorar Vistas en el auto-healing
            $dbNameResult = $mysqli->query("SELECT DATABASE()");
            $dbName = ($dbNameResult) ? $dbNameResult->fetch_row()[0] : '';
            $tableStatus = $mysqli->query("SHOW FULL TABLES WHERE Table_type = 'VIEW' AND Tables_in_$dbName = '$table'");
            if ($tableStatus && $tableStatus->num_rows > 0)
                return "ok";

            $checkId = $mysqli->query("SHOW COLUMNS FROM `$table` LIKE 'id'");
            if ($checkId && $row = $checkId->fetch_assoc()) {
                $extra = strtolower($row['Extra']);
                $key = strtoupper($row['Key']);

                // 1. Ensure Primary Key (o al menos un índice para permitir AI)
                if ($key === '') {
                    try {
                        $mysqli->query("ALTER TABLE `$table` ADD PRIMARY KEY (`id`)");
                    } catch (Exception $e) {
                        try {
                            $mysqli->query("ALTER TABLE `$table` ADD INDEX (`id`)");
                        } catch (Exception $ex) {
                            return "error_key: " . $e->getMessage();
                        }
                    }
                }

                // 2. Ensure AUTO_INCREMENT
                if (strpos($extra, 'auto_increment') === false) {
                    try {
                        $mysqli->query("ALTER TABLE `$table` MODIFY `id` INT NOT NULL AUTO_INCREMENT");
                        return "fixed";
                    } catch (Exception $e) {
                        return "error_ai: " . $e->getMessage();
                    }
                }
                return "ok";
            }
            return "no_id_column";
        } catch (Exception $e) {
            return "exception: " . $e->getMessage();
        }
    }

    /**
     * Helper to add a column safely if it doesn't exist
     */
    function safeAddColumn($mysqli, $table, $column, $definition)
    {
        try {
            $check = $mysqli->query("SHOW COLUMNS FROM `$table` LIKE '$column'");
            if ($check->num_rows == 0) {
                $mysqli->query("ALTER TABLE `$table` ADD COLUMN `$column` $definition");
                return "added";
            }
            return "exists";
        } catch (Exception $e) {
            return "error: " . $e->getMessage();
        }
    }

    /**
     * Helper to rename a column safely
     */
    function safeRenameColumn($mysqli, $table, $oldColumn, $newColumn, $definition)
    {
        try {
            $checkOld = $mysqli->query("SHOW COLUMNS FROM `$table` LIKE '$oldColumn'");
            $checkNew = $mysqli->query("SHOW COLUMNS FROM `$table` LIKE '$newColumn'");

            if ($checkOld->num_rows > 0 && $checkNew->num_rows == 0) {
                $mysqli->query("ALTER TABLE `$table` CHANGE `$oldColumn` `$newColumn` $definition");
                return "renamed";
            }
            return "skipped";
        } catch (Exception $e) {
            return "error: " . $e->getMessage();
        }
    }

    // --- STEP 1: Core Baseline Foundation ---
    // Safety check for funcionario table collision BEFORE baseline script
    try {
        $checkFunc = $conn->query("SHOW TABLES LIKE 'funcionario'");
        if ($checkFunc->num_rows > 0) {
            $checkCols = $conn->query("SHOW COLUMNS FROM `funcionario` LIKE 'nombre_empresa'");
            if ($checkCols->num_rows > 0) {
                // This is the branding version, rename it to config_branding
                $conn->query("RENAME TABLE `funcionario` TO `config_branding`");
                $results["steps"]["self_healing"]["funcionario_collision"] = "renamed_branding_to_config";
            }
        }
    } catch (Exception $e) { /* ignore */
    }

    $results["steps"]["core_baseline"] = executeSqlFile($conn, __DIR__ . '/sql/core_base.sql');

    // --- STEP 1.5: Universal Self-Healing ---
    $results["steps"]["self_healing"] = [];
    $allTablesResult = $conn->query("SHOW TABLES");
    while ($tableRow = $allTablesResult->fetch_array()) {
        $tableName = $tableRow[0];

        // Limpieza de emergencia para la tabla branding (bloqueos de PK/AI)
        if ($tableName === 'branding') {
            try {
                // Borrar duplicados dejando solo uno por cada ID
                $conn->query("DELETE FROM branding WHERE id NOT IN (SELECT max_id FROM (SELECT MAX(id) as max_id FROM branding GROUP BY id) as x)");
            } catch (Exception $e) { /* ignore */
            }
        }

        $healStatus = ensureIdAutoIncrement($conn, $tableName);
        if ($healStatus !== "ok" && $healStatus !== "no_id_column") {
            $results["steps"]["self_healing"][$tableName] = $healStatus;
        }
    }

    // --- STEP 2: Automatic Module Discovery ---
    $results["steps"]["modules"] = [];
    $backend_root = realpath(__DIR__ . '/../');
    $results["debug"]["backend_root"] = $backend_root;

    // Increased scanning depth and skips node_modules/vendor
    $it = new RecursiveDirectoryIterator($backend_root, RecursiveDirectoryIterator::SKIP_DOTS);
    $files_scanned = 0;
    foreach (new RecursiveIteratorIterator($it) as $file) {
        $files_scanned++;
        if ($file->getFilename() === 'init.sql') {
            $path = $file->getPathname();
            if (strpos($path, 'node_modules') !== false || strpos($path, 'vendor') !== false || strpos($path, 'sql/core_base.sql') !== false)
                continue;

            $moduleName = basename(dirname($path));
            $results["steps"]["modules"][$moduleName] = executeSqlFile($conn, $path);
        }
    }
    $results["debug"]["files_scanned"] = $files_scanned;

    // --- STEP 3: Workflow & States Initialization ---
    $workflow_script = __DIR__ . '/../workflow/inicializar_workflow_estandar.sql';
    if (file_exists($workflow_script)) {
        $results["steps"]["workflow_standard"] = executeSqlFile($conn, $workflow_script);
    }

    // --- STEP 4: Incremental Migrations ---
    $migration_dir = __DIR__ . '/../migrations/';
    if (is_dir($migration_dir)) {
        $sql_files = glob($migration_dir . "*.sql");
        sort($sql_files);
        foreach ($sql_files as $file) {
            $results["steps"]["migration_sql_" . basename($file)] = executeSqlFile($conn, $file);
        }

        $php_files = glob($migration_dir . "*.php");
        sort($php_files);
        foreach ($php_files as $file) {
            $baseName = basename($file);
            if ($baseName === basename(__FILE__) || $baseName === 'run_seed_geografia.php')
                continue;

            // Capture output of the PHP migration script safely
            ob_start();
            try {
                include $file;
                $output = ob_get_clean();
                $results["steps"]["migration_php_" . $baseName] = ["success" => true, "output" => trim($output)];
            } catch (Exception $e) {
                ob_end_clean();
                $results["steps"]["migration_php_" . $baseName] = ["success" => false, "error" => $e->getMessage()];
            }
        }
    }

    // --- STEP 4.5: Ensure Administrator User ---
    $id_registro = 'dev'; // Default fallback
    $results["debug"][] = "Starting id_registro detection...";
    $detection_method = "default_fallback";

    // Priority 0: Manual override via REQUEST (GET/POST)
    if (isset($_REQUEST['id_registro']) && !empty(trim($_REQUEST['id_registro']))) {
        $id_registro = trim($_REQUEST['id_registro']);
        $detection_method = "request_parameter";
        $results["debug"][] = "Manual id_registro override via REQUEST: $id_registro";
    }

    // Priority 1: Check existing users in this local database
    if ($id_registro === 'dev') {
        try {
            $resLocal = $conn->query("SELECT ID_REGISTRO FROM usuarios WHERE ID_REGISTRO IS NOT NULL AND LOWER(ID_REGISTRO) != 'dev' AND ID_REGISTRO != '' LIMIT 1");
            if ($resLocal && $rowLocal = $resLocal->fetch_assoc()) {
                $id_registro = $rowLocal['ID_REGISTRO'];
                $detection_method = "existing_users";
                $results["debug"][] = "Detected id_registro from existing users: $id_registro";
            }
        } catch (Exception $e) { /* ignore */
        }
    }

    // Priority 2: Check branding/client_config tables if they exist
    if ($id_registro === 'dev') {
        try {
            $resBranding = $conn->query("SELECT id_registro FROM branding LIMIT 1");
            if ($resBranding && $rowB = $resBranding->fetch_assoc()) {
                $id_registro = $rowB['id_registro'];
                $detection_method = "branding_table";
                $results["debug"][] = "Detected id_registro from branding table: $id_registro";
            }
        } catch (Exception $e) { /* ignore */
        }
    }

    // Priority 3: Fallback to Admin DB lookup with exhaustive search
    if ($id_registro === 'dev') {
        $admin_conn_path = __DIR__ . '/../conexion_admin.php';
        if (file_exists($admin_conn_path)) {
            try {
                require_once $admin_conn_path;
                if (isset($conn_admin) && !$conn_admin->connect_error) {
                    $db_name_esc = $conn_admin->real_escape_string($database);
                    // Try to find ANY column that matches the database name
                    $colsRes = $conn_admin->query("SHOW COLUMNS FROM clientes");
                    $matchCol = null;
                    if ($colsRes) {
                        while ($c = $colsRes->fetch_assoc()) {
                            $colName = $c['Field'];
                            if (in_array(strtolower($colName), ['db_name', 'nombre_bd', 'database_name', 'base_datos', 'dbname', 'bd', 'nom_bd', 'db'])) {
                                $matchCol = $colName;
                                break;
                            }
                        }
                    }

                    if ($matchCol) {
                        $resIdSearch = $conn_admin->query("SELECT id_registro FROM clientes WHERE `$matchCol` = '$db_name_esc' LIMIT 1");
                        if ($resIdSearch && $rowS = $resIdSearch->fetch_assoc()) {
                            $id_registro = $rowS['id_registro'];
                            $detection_method = "admin_db_lookup";
                            $results["debug"][] = "Dynamic id_registro found in Admin DB: $id_registro";
                        }
                    }
                }
            } catch (Exception $e) { /* ignore */ }
        }
    }

    // --- NEW: Always fetch company metadata if we have a connection and id_registro ---
    $admin_conn_path = __DIR__ . '/../conexion_admin.php';
    if (file_exists($admin_conn_path)) {
        try {
            require_once $admin_conn_path;
            if (isset($conn_admin) && !$conn_admin->connect_error) {
                $id_reg_esc = $conn_admin->real_escape_string($id_registro);
                $sqlInfo = "SELECT nombre_cliente, nit, direccion, telefono, correo, url_web, contacto_principal, ciudad, regimen_tributario, resolucion_dian, instagram, facebook, whatsapp 
                           FROM clientes 
                           WHERE id_registro = '$id_reg_esc' LIMIT 1";
                $resInfo = $conn_admin->query($sqlInfo);
                if ($resInfo && $row = $resInfo->fetch_assoc()) {
                    $company_info = [
                        "NOMBRE_CLIENTE" => $row['nombre_cliente'] ?? ($id_registro !== 'dev' ? $id_registro : 'Administrador Sistema'),
                        "NIT" => $row['nit'] ?? '000000000',
                        "DIRECCION" => $row['direccion'] ?? '',
                        "TELEFONO" => $row['telefono'] ?? '',
                        "CORREO" => $row['correo'] ?? 'admin@admin.com',
                        "SITIO_WEB" => $row['url_web'] ?? '',
                        "CONTACTO" => $row['contacto_principal'] ?? '',
                        "CIUDAD" => $row['ciudad'] ?? '',
                        "REGIMEN" => $row['regimen_tributario'] ?? '',
                        "RESOLUCION" => $row['resolucion_dian'] ?? '',
                        "INSTAGRAM" => $row['instagram'] ?? '',
                        "FACEBOOK" => $row['facebook'] ?? '',
                        "WHATSAPP" => $row['whatsapp'] ?? ''
                    ];
                    $results["debug"][] = "Company profile metadata successfully fetched from Admin DB for ID: $id_registro. Name: " . $company_info['NOMBRE_CLIENTE'];
                } else {
                    $results["debug"][] = "Warning: No company record found in Admin DB for id_registro: $id_registro";
                }
            }
        } catch (Exception $e) { 
            $results["debug"][] = "Error fetching company metadata: " . $e->getMessage();
        }
    }

    if ($id_registro === 'dev' && $detection_method === 'default_fallback') {
        $results["debug"][] = "Warning: No id_registro detected, using 'dev' fallback.";
    }
    $results["debug"][] = "Final detection summary - ID: $id_registro (via $detection_method)";

    $admin_script = __DIR__ . '/create_full_admin.sql';
    // Repostponed to end of schema patches

    // --- STEP 5: Safe Schema Patching ---
    $results["steps"]["schema_patches"] = [
        // Ciudades/Clientes
        "ciudades_codigo" => safeAddColumn($conn, 'ciudades', 'codigo', "VARCHAR(10) AFTER id"),
        "clientes_perfil" => safeAddColumn($conn, 'clientes', 'perfil', "VARCHAR(100) AFTER limite_credito"),
        "clientes_dv" => safeAddColumn($conn, 'clientes', 'dv', "VARCHAR(10) AFTER documento_nit"),
        "clientes_email_fact" => safeAddColumn($conn, 'clientes', 'email_facturacion', "VARCHAR(150) AFTER email"),
        "clientes_regimen" => safeAddColumn($conn, 'clientes', 'regimen_tributario', "VARCHAR(100) AFTER perfil"),
        "clientes_resp_fiscal" => safeAddColumn($conn, 'clientes', 'responsabilidad_fiscal_id', "VARCHAR(50) DEFAULT 'R-99-PN' AFTER regimen_tributario"),
        "clientes_ciiu" => safeAddColumn($conn, 'clientes', 'codigo_ciiu', "VARCHAR(20) AFTER responsabilidad_fiscal_id"),
        "clientes_agente" => safeAddColumn($conn, 'clientes', 'es_agente_retenedor', "TINYINT(1) DEFAULT 0 AFTER codigo_ciiu"),
        "clientes_autorret" => safeAddColumn($conn, 'clientes', 'es_autorretenedor', "TINYINT(1) DEFAULT 0 AFTER es_agente_retenedor"),
        "clientes_gran_contrib" => safeAddColumn($conn, 'clientes', 'es_gran_contribuyente', "TINYINT(1) DEFAULT 0 AFTER es_autorretenedor"),

        // Usuarios
        "usuarios_can_edit_closed_ops" => safeAddColumn($conn, 'usuarios', 'can_edit_closed_ops', "TINYINT(1) DEFAULT 0 AFTER es_auditor"),
        "usuarios_regimen" => safeAddColumn($conn, 'usuarios', 'regimen_tributario', "VARCHAR(100) AFTER NIT"),
        "usuarios_sitio_web" => safeAddColumn($conn, 'usuarios', 'SITIO_WEB', "VARCHAR(255) AFTER CORREO"),
        "usuarios_resolucion" => safeAddColumn($conn, 'usuarios', 'RESOLUCION_DIAN', "TEXT AFTER SITIO_WEB"),
        "usuarios_instagram" => safeAddColumn($conn, 'usuarios', 'INSTAGRAM', "VARCHAR(100) AFTER RESOLUCION_DIAN"),
        "usuarios_facebook" => safeAddColumn($conn, 'usuarios', 'FACEBOOK', "VARCHAR(100) AFTER INSTAGRAM"),
        "usuarios_whatsapp" => safeAddColumn($conn, 'usuarios', 'WHATSAPP', "VARCHAR(50) AFTER FACEBOOK"),
        "usuarios_contacto" => safeAddColumn($conn, 'usuarios', 'NOMBRE_CONTACTO', "VARCHAR(150) AFTER WHATSAPP"),
        "usuarios_ciudad" => safeAddColumn($conn, 'usuarios', 'CIUDAD', "VARCHAR(100) AFTER NOMBRE_CONTACTO"),

        // Servicios
        "servicios_rename_estado" => safeRenameColumn($conn, 'servicios', 'estado_id', 'estado', "INT"),
        "servicios_fecha_registro" => safeAddColumn($conn, 'servicios', 'fecha_registro', "TIMESTAMP DEFAULT CURRENT_TIMESTAMP AFTER o_servicio"),
        "servicios_nombre_emp" => safeAddColumn($conn, 'servicios', 'nombre_emp', "VARCHAR(150) AFTER id_equipo"),
        "servicios_placa" => safeAddColumn($conn, 'servicios', 'placa', "VARCHAR(50) AFTER nombre_emp"),
        "servicios_responsable" => safeAddColumn($conn, 'servicios', 'responsable_id', "INT AFTER actividad_id"),
        "servicios_personal_confirmado" => safeAddColumn($conn, 'servicios', 'personal_confirmado', "TINYINT(1) DEFAULT 0 AFTER firma_confirmada"),
        "servicios_es_finalizado" => safeAddColumn($conn, 'servicios', 'es_finalizado', "TINYINT(1) DEFAULT 0 AFTER estado_comercial"),
        "servicios_fecha_actualizacion" => safeAddColumn($conn, 'servicios', 'fecha_actualizacion', "TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER es_finalizado"),
        "usuarios_fecha_contratacion" => safeAddColumn($conn, 'usuarios', 'FECHA_CONTRATACION', "DATE AFTER regimen_tributario"),
        "usuarios_cleanup_duplicates" => (function ($mysqli) {
            // Remove duplicates of 'administrator' keeping only the one with lowest ID
            $mysqli->query("DELETE FROM usuarios 
                           WHERE NOMBRE_USER = 'administrator' 
                           AND id NOT IN (SELECT * FROM (SELECT MIN(id) FROM usuarios WHERE NOMBRE_USER = 'administrator') as tmp)");
            return "cleaned";
        })($conn),
        "usuarios_unique_name" => (function ($mysqli) {
            $mysqli->query("ALTER TABLE usuarios ADD UNIQUE INDEX IF NOT EXISTS idx_nombre_user_unique (NOMBRE_USER)");
            return "verified";
        })($conn),
    ];

    // --- STEP 6: Administrative User Initialization (MOVED HERE) ---
    if (file_exists($admin_script)) {
        $replacements = ["ID_REGISTRO" => $id_registro];
        if (isset($company_info)) {
            $replacements = array_merge($replacements, $company_info);
        } else {
            $replacements = array_merge($replacements, [
                "NOMBRE_CLIENTE" => ($id_registro !== 'dev' ? $id_registro : "Dev"),
                "NIT" => "000000000",
                "DIRECCION" => "",
                "TELEFONO" => "",
                "CORREO" => "admin@admin.com",
                "SITIO_WEB" => "",
                "CONTACTO" => "",
                "CIUDAD" => "",
                "REGIMEN" => "",
                "RESOLUCION" => "",
                "INSTAGRAM" => "",
                "FACEBOOK" => "",
                "WHATSAPP" => ""
            ]);
        }
        $results["steps"]["admin_creation"] = executeSqlFile($conn, $admin_script, $replacements);
    }

    // Repuestos e Inventario
    $results["steps"]["schema_patches"] = array_merge($results["steps"]["schema_patches"], [
        "repuestos_notas" => safeAddColumn($conn, 'servicio_repuestos', 'notas', "TEXT NULL AFTER costo_total"),
        "repuestos_usuario_asigno" => safeAddColumn($conn, 'servicio_repuestos', 'usuario_asigno', "INT NULL AFTER notas"),
        "repuestos_fecha_asignacion" => safeAddColumn($conn, 'servicio_repuestos', 'fecha_asignacion', "DATETIME NULL AFTER usuario_asigno"),
        "inv_mov_ref_type" => safeAddColumn($conn, 'inventory_movements', 'reference_type', "VARCHAR(50) NULL AFTER unit_cost"),
        "inv_mov_ref_id" => safeAddColumn($conn, 'inventory_movements', 'reference_id', "INT NULL AFTER reference_type"),

        // Contabilidad - Fac Control
        "fcs_total_repuestos" => safeAddColumn($conn, 'fac_control_servicios', 'total_repuestos', "DECIMAL(18,2) DEFAULT 0.00 AFTER valor_snapshot"),
        "fcs_total_mano_obra" => safeAddColumn($conn, 'fac_control_servicios', 'total_mano_obra', "DECIMAL(18,2) DEFAULT 0.00 AFTER total_repuestos"),
        "fcs_estado_flexible" => (function($mysqli) {
            $mysqli->query("ALTER TABLE fac_control_servicios MODIFY COLUMN estado_comercial_cache VARCHAR(50) DEFAULT 'NO_FACTURADO'");
            return "upgraded";
        })($conn),

        // Servicio Staff
        "servicio_staff_usuario_id" => safeAddColumn($conn, 'servicio_staff', 'usuario_id', "INT NULL AFTER staff_id"),
        "servicio_staff_asignado_por" => safeAddColumn($conn, 'servicio_staff', 'asignado_por', "INT NULL AFTER costo_hora"),
        "servicio_staff_staff_nullable" => (function ($mysqli) use (&$results) {
            $result = $mysqli->query("SHOW COLUMNS FROM `servicio_staff` LIKE 'staff_id'");
            if ($result && $row = $result->fetch_assoc()) {
                $results["debug"][] = "Current staff_id Null: " . $row['Null'] . " (Expected: NO to trigger upgrade)";
                if ($row['Null'] === 'NO') {
                    // 1. DYNAMICALLY find the foreign key name for staff_id
                    $constraintRes = $mysqli->query("
                        SELECT CONSTRAINT_NAME 
                        FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE 
                        WHERE TABLE_NAME = 'servicio_staff' 
                        AND COLUMN_NAME = 'staff_id' 
                        AND TABLE_SCHEMA = DATABASE() 
                        AND REFERENCED_TABLE_NAME IS NOT NULL
                        LIMIT 1
                    ");
                    
                    if ($constraintRes && $cRow = $constraintRes->fetch_assoc()) {
                        $fkName = $cRow['CONSTRAINT_NAME'];
                        $mysqli->query("ALTER TABLE `servicio_staff` DROP FOREIGN KEY `$fkName` ");
                        $results["debug"][] = "Dropped FK: $fkName";
                    }
                    
                    // 2. Modify the column
                    if (!$mysqli->query("ALTER TABLE `servicio_staff` MODIFY COLUMN `staff_id` INT NULL DEFAULT NULL")) {
                        $results["debug"][] = "Error modifying staff_id: " . $mysqli->error;
                        return "error: " . $mysqli->error;
                    }

                    // 3. Re-add the foreign key (using a stable name)
                    $mysqli->query("ALTER TABLE `servicio_staff` ADD CONSTRAINT `fk_servicio_staff_staff` FOREIGN KEY (`staff_id`) REFERENCES `staff`(`id`) ON DELETE SET NULL");

                    $results["debug"][] = "Successfully made staff_id nullable in servicio_staff (Dynamic FK discovery)";
                    return "upgraded";
                }
            }
            return "skipped";
        })($conn),

        // Campos Adicionales
        "campos_adicionales_rename_ob" => safeRenameColumn($conn, 'campos_adicionales', 'requerido', 'obligatorio', "TINYINT(1) DEFAULT 0"),
        "campos_adicionales_rename_cre" => safeRenameColumn($conn, 'campos_adicionales', 'created_at', 'creado', "TIMESTAMP DEFAULT CURRENT_TIMESTAMP"),
        "campos_adicionales_estado_mostrar" => safeAddColumn($conn, 'campos_adicionales', 'estado_mostrar', "INT DEFAULT 1 AFTER estado_id"),
        "vca_fecha_ultima_modificacion" => safeAddColumn($conn, 'valores_campos_adicionales', 'fecha_ultima_modificacion', "TIMESTAMP NULL AFTER fecha_actualizacion"),
        "notas_es_automatica" => safeAddColumn($conn, 'notas', 'es_automatica', "TINYINT(1) DEFAULT 0 AFTER usuario_id"),

        // Plantillas
        "plantillas_rename_contenido" => safeRenameColumn($conn, 'plantillas', 'contenido', 'contenido_html', "LONGTEXT"),
        "plantillas_rename_created" => safeRenameColumn($conn, 'plantillas', 'created_at', 'fecha_creacion', "TIMESTAMP DEFAULT CURRENT_TIMESTAMP"),
        "plantillas_rename_updated" => safeRenameColumn($conn, 'plantillas', 'updated_at', 'fecha_actualizacion', "TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP"),
        "plantillas_cliente_id" => safeAddColumn($conn, 'plantillas', 'cliente_id', "INT NULL AFTER modulo"),
        "plantillas_es_general" => safeAddColumn($conn, 'plantillas', 'es_general', "TINYINT(1) DEFAULT 1 AFTER cliente_id"),
        "plantillas_usuario_creador" => safeAddColumn($conn, 'plantillas', 'usuario_creador', "INT NULL AFTER es_general"),
        "plantillas_tipo_nullable" => (function($mysqli) {
            $result = $mysqli->query("SHOW COLUMNS FROM `plantillas` LIKE 'tipo'");
            if ($result && $row = $result->fetch_assoc()) {
                if ($row['Null'] === 'NO') {
                    $mysqli->query("ALTER TABLE `plantillas` MODIFY COLUMN `tipo` VARCHAR(50) NULL");
                    return "upgraded";
                }
            }
            return "skipped";
        })($conn),

        // Inspecciones
        "inspecciones_deleted_at" => safeAddColumn($conn, 'inspecciones', 'deleted_at', "TIMESTAMP NULL AFTER updated_by"),
        "inspecciones_deleted_by" => safeAddColumn($conn, 'inspecciones', 'deleted_by', "INT NULL AFTER deleted_at"),
        "inspecciones_actividades_deleted_at" => safeAddColumn($conn, 'inspecciones_actividades', 'deleted_at', "TIMESTAMP NULL AFTER updated_at"),
        "inspecciones_actividades_deleted_by" => safeAddColumn($conn, 'inspecciones_actividades', 'deleted_by', "INT NULL AFTER deleted_at"),
        "inspecciones_actividades_created_by" => safeAddColumn($conn, 'inspecciones_actividades', 'created_by', "INT NULL AFTER updated_at"),
        "inspecciones_actividades_updated_by" => safeAddColumn($conn, 'inspecciones_actividades', 'updated_by', "INT NULL AFTER created_by"),
        "inspecciones_actividades_fecha_autorizacion" => safeAddColumn($conn, 'inspecciones_actividades', 'fecha_autorizacion', "DATETIME NULL AFTER notas"),

        // Sistemas
        "sistemas_updated_at" => safeAddColumn($conn, 'sistemas', 'updated_at', "TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER created_at"),

        // Desbloqueos de Repuestos
        "desbloqueos_usado" => safeAddColumn($conn, 'servicios_desbloqueos_repuestos', 'usado', "TINYINT(1) DEFAULT 0 AFTER motivo"),

        // Usuarios - Audit & Specialties
        "usuarios_actualizacion" => safeAddColumn($conn, 'usuarios', 'USUARIO_ACTUALIZACION', "INT NULL AFTER URL_FOTO"),
        "usuarios_especialidad" => safeAddColumn($conn, 'usuarios', 'ID_ESPECIALIDAD', "INT NULL AFTER USUARIO_ACTUALIZACION"),
        "usuarios_role_upgrade" => (function($mysqli) {
            // Check if 'administrador' is already in the ENUM
            $result = $mysqli->query("SHOW COLUMNS FROM `usuarios` LIKE 'TIPO_ROL'");
            if ($result && $row = $result->fetch_assoc()) {
                if (strpos($row['Type'], "'administrador'") === false) {
                    $mysqli->query("ALTER TABLE `usuarios` MODIFY COLUMN `TIPO_ROL` ENUM('admin', 'administrador', 'gerente', 'rh', 'tecnico', 'cliente', 'colaborador') NOT NULL");
                    return "upgraded";
                }
            }
            return "skipped";
        })($conn),

        // Impuestos - ICA Precision
        "ica_precision" => (function($mysqli) {
            $result = $mysqli->query("SHOW COLUMNS FROM `cnf_tarifas_ica` LIKE 'tarifa_x_mil'");
            if ($result && $row = $result->fetch_assoc()) {
                if ($row['Type'] !== 'decimal(10,4)') {
                    $mysqli->query("ALTER TABLE `cnf_tarifas_ica` MODIFY COLUMN `tarifa_x_mil` DECIMAL(10,4) NOT NULL, MODIFY COLUMN `base_minima_uvt` DECIMAL(15,2) DEFAULT 0.00");
                    return "upgraded";
                }
            }
            return "skipped";
        })($conn),

        // Campos Adicionales V2 (Typed)
        "vca_rename_id" => safeRenameColumn($conn, 'valores_campos_adicionales', 'registro_id', 'servicio_id', "INT NOT NULL"),
        "vca_rename_created" => safeRenameColumn($conn, 'valores_campos_adicionales', 'created_at', 'fecha_creacion', "TIMESTAMP DEFAULT CURRENT_TIMESTAMP"),
        "vca_rename_updated" => safeRenameColumn($conn, 'valores_campos_adicionales', 'updated_at', 'fecha_actualizacion', "TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP"),
        "vca_texto" => safeAddColumn($conn, 'valores_campos_adicionales', 'valor_texto', "TEXT AFTER campo_id"),
        "vca_numero" => safeAddColumn($conn, 'valores_campos_adicionales', 'valor_numero', "DECIMAL(18,2) AFTER valor_texto"),
        "vca_fecha" => safeAddColumn($conn, 'valores_campos_adicionales', 'valor_fecha', "DATE AFTER valor_numero"),
        "vca_hora" => safeAddColumn($conn, 'valores_campos_adicionales', 'valor_hora', "TIME AFTER valor_fecha"),
        "vca_datetime" => safeAddColumn($conn, 'valores_campos_adicionales', 'valor_datetime', "DATETIME AFTER valor_hora"),
        "vca_archivo" => safeAddColumn($conn, 'valores_campos_adicionales', 'valor_archivo', "VARCHAR(500) AFTER valor_datetime"),
        "vca_booleano" => safeAddColumn($conn, 'valores_campos_adicionales', 'valor_booleano', "TINYINT(1) AFTER valor_archivo"),
        "vca_tipo" => safeAddColumn($conn, 'valores_campos_adicionales', 'tipo_campo', "VARCHAR(50) AFTER valor_booleano"),
        "vca_creacion_fallback" => safeAddColumn($conn, 'valores_campos_adicionales', 'fecha_creacion', "TIMESTAMP DEFAULT CURRENT_TIMESTAMP AFTER tipo_campo"),
        "vca_actualizacion_fallback" => safeAddColumn($conn, 'valores_campos_adicionales', 'fecha_actualizacion', "TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER fecha_creacion"),
        "tipos_mantenimiento_table" => (function($mysqli) {
            $mysqli->query("CREATE TABLE IF NOT EXISTS tipos_mantenimiento (
                id INT AUTO_INCREMENT PRIMARY KEY,
                nombre VARCHAR(50) NOT NULL UNIQUE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
            $mysqli->query("INSERT IGNORE INTO tipos_mantenimiento (nombre) VALUES ('preventivo'), ('correctivo'), ('predictivo')");
            return "created";
        })($conn),

        // Auditoría SoD
        "audit_ciclos_table" => (function($mysqli) {
            $mysqli->query("CREATE TABLE IF NOT EXISTS fac_audit_ciclos (
                servicio_id INT PRIMARY KEY,
                ciclo_actual INT NOT NULL DEFAULT 1,
                fecha_ultima_moficiacion DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                FOREIGN KEY (servicio_id) REFERENCES servicios(id) ON DELETE CASCADE
            )");
            return "verified";
        })($conn),
        "audit_servicios_table" => (function($mysqli) {
            $mysqli->query("CREATE TABLE IF NOT EXISTS fac_auditorias_servicio (
                id INT AUTO_INCREMENT PRIMARY KEY,
                servicio_id INT NOT NULL,
                auditor_id INT NOT NULL,
                comentario TEXT,
                ciclo INT NOT NULL DEFAULT 1,
                es_excepcion TINYINT(1) DEFAULT 0,
                fecha_auditoria DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (servicio_id) REFERENCES servicios(id) ON DELETE CASCADE,
                FOREIGN KEY (auditor_id) REFERENCES usuarios(id)
            )");
            return "verified";
        })($conn),
        "audit_servicios_ciclo_col" => safeAddColumn($conn, 'fac_auditorias_servicio', 'ciclo', "INT NOT NULL DEFAULT 1 AFTER comentario"),
        "estados_servicios_log" => (function($mysqli) {
            $mysqli->query("CREATE TABLE IF NOT EXISTS estados_servicios_log (
                id INT AUTO_INCREMENT PRIMARY KEY,
                servicio_id INT NOT NULL,
                estado_anterior_id INT NULL,
                estado_nuevo_id INT NOT NULL,
                modulo VARCHAR(50) DEFAULT 'OPERACIONES',
                usuario_id INT NOT NULL,
                observacion TEXT,
                fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX idx_log_servicio (servicio_id),
                INDEX idx_log_usuario (usuario_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
            return "verified";
        })($conn),
    ]);

    // --- STEP 6: Initialize Default Data ---
    $conn->query("INSERT IGNORE INTO departments (id, name, description) VALUES (1, 'Administración', 'Gestión general'), (2, 'Recursos Humanos', 'Talento humano'), (3, 'Tecnología', 'Sistemas e infraestructura'), (4, 'Operaciones', 'Mantenimiento y servicios')");
    $conn->query("INSERT IGNORE INTO positions (title, department_id) VALUES ('Gerente', 1), ('Analista', 3), ('Técnico', 4)");

    // --- STEP 7: Full Geographical Seeding ---
    $apiUrl = "https://www.datos.gov.co/resource/gdxc-w37w.json?\$limit=2000";
    $json = @file_get_contents($apiUrl);
    if ($json !== false) {
        $data = json_decode($json, true);
        if (is_array($data)) {
            $conn->query("SET FOREIGN_KEY_CHECKS = 0");
            $conn->query("TRUNCATE TABLE ciudades");
            $conn->query("TRUNCATE TABLE departamentos");
            $conn->query("SET FOREIGN_KEY_CHECKS = 1");

            $stmtDep = $conn->prepare("INSERT INTO departamentos (id, nombre) VALUES (?, ?)");
            $deps = [];
            foreach ($data as $item)
                $deps[(int) $item['cod_dpto']] = strtoupper($item['dpto']);
            foreach ($deps as $id => $nombre) {
                $stmtDep->bind_param("is", $id, $nombre);
                $stmtDep->execute();
            }
            $stmtDep->close();

            $stmtMpio = $conn->prepare("INSERT INTO ciudades (codigo, nombre, departamento, departamento_id) VALUES (?, ?, ?, ?)");
            $inserted = 0;
            foreach ($data as $item) {
                $codigo = $item['cod_mpio'];
                $nombre = strtoupper($item['nom_mpio']);
                $depto = strtoupper($item['dpto']);
                $deptoId = (int) $item['cod_dpto'];
                $stmtMpio->bind_param("sssi", $codigo, $nombre, $depto, $deptoId);
                if ($stmtMpio->execute())
                    $inserted++;
            }
            $stmtMpio->close();
            $results["steps"]["geography_seeding"] = ["success" => true, "inserted" => $inserted];
        }
    }

    // --- DIAGNOSTICS: Check servicio_staff schema ---
    $diag = $conn->query("SHOW COLUMNS FROM `servicio_staff` WHERE Field = 'staff_id'");
    if ($diag && $row = $diag->fetch_assoc()) {
        $results["debug"][] = "DIAGNOSTIC - servicio_staff.staff_id: Null=" . $row['Null'] . ", Default=" . ($row['Default'] ?? 'NULL_LITERAL');
    }
    
    if ($create && $row = $create->fetch_row()) {
        $results["debug"][] = "DIAGNOSTIC - CREATE TABLE: " . $row[1];
    }

    // --- DIAGNOSTICS: Check for orphaned services ---
    $orphans = $conn->query("SELECT COUNT(*) as count FROM servicios WHERE cliente_id IS NULL OR cliente_id = 0");
    if ($orphans && $row = $orphans->fetch_assoc()) {
        if ($row['count'] > 0) {
            $results["errors"][] = "INTEGRITY ALERT: Found " . $row['count'] . " services without a valid cliente_id. Accounting snapshots will fail for these services.";
        }
    }

    $results["status"] = "completed";
    echo json_encode($results, JSON_PRETTY_PRINT);

} catch (Exception $e) {
    $results["status"] = "failed";
    $results["errors"][] = $e->getMessage();
    // Try to include query trace if possible
    echo json_encode($results, JSON_PRETTY_PRINT);
}
