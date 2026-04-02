<?php
// tags.php - Protegido con JWT (VERSIÓN CORREGIDA PARA FIRMAS)

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

define('DEBUG_LOG', __DIR__ . '/debug_tags.txt');

function log_debug($msg)
{
  $time = date('Y-m-d H:i:s');
  $memoryMB = round(memory_get_usage() / 1024 / 1024, 2);
  file_put_contents(DEBUG_LOG, "[$time][MEM: {$memoryMB}MB] $msg\n", FILE_APPEND);
}

register_shutdown_function(function () {
  $error = error_get_last();
  if ($error !== null && in_array($error['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR])) {
    log_debug("🔴 ERROR FATAL: " . $error['message']);
    log_debug("📁 Archivo: " . $error['file'] . " Línea: " . $error['line']);
  }
});

set_exception_handler(function ($e) {
  log_debug("🔴 EXCEPCIÓN NO MANEJADA: " . $e->getMessage());
  log_debug("📁 Archivo: " . $e->getFile() . " Línea: " . $e->getLine());
  log_debug("📚 Stack: " . $e->getTraceAsString());
});

log_debug("========================================");
log_debug("🆕 NUEVA REQUEST INICIADA - GET /tags");
log_debug("========================================");
log_debug("🌐 IP: " . ($_SERVER['REMOTE_ADDR'] ?? 'unknown'));
log_debug("📨 Método: " . $_SERVER['REQUEST_METHOD']);
log_debug("🔗 URI: " . ($_SERVER['REQUEST_URI'] ?? 'unknown'));

require_once '../login/auth_middleware.php';

try {
  log_debug("✅ auth_middleware cargado");

  $currentUser = requireAuth();
  log_debug("👤 Usuario autenticado: " . $currentUser['usuario'] . " (ID: " . $currentUser['id'] . ")");

  logAccess($currentUser, '/tags/tags.php', 'get_tags');
  log_debug("✅ Acceso registrado");

  if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    log_debug("❌ Método no permitido: " . $_SERVER['REQUEST_METHOD']);
    sendJsonResponse(errorResponse('Método no permitido'), 405);
  }

  log_debug("📦 Requiriendo conexión...");
  require '../conexion.php';
  log_debug("✅ conexion.php cargado");

  // ==================================================
  // OBTENER MÓDULO (FILTRO)
  // ==================================================
  $modulo_filtro = isset($_GET['modulo']) ? trim($_GET['modulo']) : 'servicios';
  log_debug("🎯 Módulo filtro: $modulo_filtro");

  log_debug("🏗️ Iniciando generación de tags dinámicos...");

  // ==================================================
  // FUNCIÓN AUXILIAR: Obtener columnas de una tabla
  // ==================================================
  function getTableColumns($conn, $tableName)
  {
    log_debug("🔍 Obteniendo columnas de tabla: $tableName");
    $query = "SHOW COLUMNS FROM `$tableName`";
    $result = $conn->query($query);

    if (!$result) {
      log_debug("❌ Error obteniendo columnas de $tableName: " . $conn->error);
      throw new Exception("Error obteniendo columnas de $tableName");
    }

    $columns = [];
    while ($row = $result->fetch_assoc()) {
      $columns[] = $row;
    }

    log_debug("✅ Obtenidas " . count($columns) . " columnas de $tableName");
    return $columns;
  }

  // ==================================================
  // FUNCIÓN AUXILIAR: Generar descripción legible
  // ==================================================
  function getFieldDescription($fieldName, $tableName)
  {
    $readable = str_replace('_', ' ', $fieldName);
    return ucfirst($readable) . " del " . $tableName;
  }

  // ==================================================
  // FUNCIÓN AUXILIAR: Convertir nombre a slug
  // ==================================================
  function slugify($text)
  {
    $text = iconv('UTF-8', 'ASCII//TRANSLIT', $text);
    $text = strtolower($text);
    $text = preg_replace('/[^a-z0-9]+/', '_', $text);
    $text = trim($text, '_');
    return $text;
  }

  $serviciosTags = [];
  if ($modulo_filtro === 'servicios') {
    log_debug("📋 Generando tags de SERVICIOS...");
    $serviciosColumns = getTableColumns($conn, 'servicios');

    $excludedServiceFields = ['id', 'usuario_creador', 'usuario_ultima_actualizacion', 'id_equipo'];

    foreach ($serviciosColumns as $column) {
      $fieldName = $column['Field'];
      if (in_array($fieldName, $excludedServiceFields) || preg_match('/_id$/i', $fieldName)) {
        continue;
      }

      $serviciosTags[] = [
        'tag' => '{{' . $fieldName . '}}',
        'field' => $fieldName,
        'description' => getFieldDescription($fieldName, 'servicios'),
        'type' => $column['Type']
      ];
    }

    // Agregar tags de nombres explícitos (en lugar de IDs)
    $serviciosTags[] = [
      'tag' => '{{autorizado_por_nombre}}',
      'field' => 'autorizado_por',
      'description' => 'Nombre de la persona que autorizó el servicio',
      'type' => 'varchar(100)'
    ];
    $serviciosTags[] = [
      'tag' => '{{responsable_nombre}}',
      'field' => 'responsable_id',
      'description' => 'Nombre del responsable del servicio',
      'type' => 'varchar(100)'
    ];

    // Si existe el campo actividad_id en servicios, agregar un tag derivado
    $hasActividadId = array_reduce($serviciosColumns, function ($carry, $col) {
      return $carry || ($col['Field'] === 'actividad_id');
    }, false);

    if ($hasActividadId) {
      $serviciosTags[] = [
        'tag' => '{{actividad_nombre}}',
        'field' => 'actividad_id',
        'description' => 'Nombre de la actividad estándar',
        'type' => 'varchar(255)'
      ];
      $serviciosTags[] = [
        'tag' => '{{actividad_horas}}',
        'field' => 'actividad_id',
        'description' => 'Horas estimadas de la actividad',
        'type' => 'decimal(10,2)'
      ];
      $serviciosTags[] = [
        'tag' => '{{actividad_tecnicos}}',
        'field' => 'actividad_id',
        'description' => 'Número de técnicos requeridos',
        'type' => 'int'
      ];
      $serviciosTags[] = [
        'tag' => '{{sistema_nombre}}',
        'field' => 'actividad_id',
        'description' => 'Nombre del sistema asociado a la actividad',
        'type' => 'varchar(255)'
      ];
    }
    // Tags de Operaciones del servicio
    $serviciosTags[] = [
      'tag' => '{{operaciones_lista}}',
      'field' => 'operaciones',
      'description' => 'Lista HTML con todas las operaciones registradas en el servicio',
      'type' => 'html_list'
    ];
    $serviciosTags[] = [
      'tag' => '{{operaciones_tabla}}',
      'field' => 'operaciones',
      'description' => 'Tabla HTML con todas las operaciones (nombre, descripción, observaciones)',
      'type' => 'html_table'
    ];
    $serviciosTags[] = [
      'tag' => '{{operacion_principal}}',
      'field' => 'operaciones',
      'description' => 'Nombre/descripción de la operación principal (maestro) del servicio',
      'type' => 'varchar(255)'
    ];
    $serviciosTags[] = [
      'tag' => '{{operaciones_observaciones}}',
      'field' => 'operaciones',
      'description' => 'Observaciones de la operación principal del servicio',
      'type' => 'text'
    ];
    log_debug("✅ Generados " . count($serviciosTags) . " tags de servicios");
  }

  // ==================================================
  // 1.1 TAGS DE INSPECCIONES
  // ==================================================
  $inspeccionesTags = [];
  if ($modulo_filtro === 'inspecciones') {
    log_debug("📋 Generando tags de INSPECCIONES...");
    $inspeccionesColumns = getTableColumns($conn, 'inspecciones');

    $excludedInspeccionFields = ['id', 'usuario_creador', 'equipo_id', 'cliente_id'];

    foreach ($inspeccionesColumns as $column) {
      $fieldName = $column['Field'];
      if (in_array($fieldName, $excludedInspeccionFields) || preg_match('/_id$/i', $fieldName)) {
        continue;
      }

      $inspeccionesTags[] = [
        'tag' => '{{' . $fieldName . '}}',
        'field' => $fieldName,
        'description' => getFieldDescription($fieldName, 'inspecciones'),
        'type' => $column['Type']
      ];
    }
    log_debug("✅ Generados " . count($inspeccionesTags) . " tags de inspecciones");
  }

  // ==================================================
  // 2. TAGS DE EQUIPOS
  // ==================================================
  log_debug("📋 Generando tags de EQUIPOS...");
  $equiposColumns = getTableColumns($conn, 'equipos');

  $excludedEquipoFields = ['id', 'usuario_registro', 'activo'];
  $equiposTags = [];

  foreach ($equiposColumns as $column) {
    $fieldName = $column['Field'];
    if (in_array($fieldName, $excludedEquipoFields) || preg_match('/_id$/i', $fieldName)) {
      continue;
    }

    $equiposTags[] = [
      'tag' => '{{equipo_' . $fieldName . '}}',
      'field' => $fieldName,
      'description' => getFieldDescription($fieldName, 'equipos'),
      'type' => $column['Type']
    ];
  }

  log_debug("✅ Generados " . count($equiposTags) . " tags de equipos");

  // ==================================================
  // 3. TAGS DE CLIENTE (desde equipos)
  // ==================================================
  log_debug("📋 Generando tags de CLIENTE...");
  $clienteTags = [
    [
      'tag' => '{{cliente_nombre}}',
      'field' => 'nombre_empresa',
      'description' => 'Nombre de la empresa/cliente',
      'type' => 'varchar(100)'
    ],
    [
      'tag' => '{{cliente_ciudad}}',
      'field' => 'ciudad',
      'description' => 'Ciudad del cliente',
      'type' => 'varchar(100)'
    ],
    [
      'tag' => '{{cliente_city}}',
      'field' => 'ciudad',
      'description' => 'Ciudad del cliente (Alias)',
      'type' => 'varchar(100)'
    ],
    [
      'tag' => '{{cliente_planta}}',
      'field' => 'planta',
      'description' => 'Planta/sucursal del cliente',
      'type' => 'varchar(100)'
    ],
    [
      'tag' => '{{cliente_codigo}}',
      'field' => 'codigo',
      'description' => 'Código del cliente',
      'type' => 'varchar(100)'
    ]
  ];

  log_debug("✅ Generados " . count($clienteTags) . " tags de cliente");

  // ==================================================
  // 4. TAGS DE CAMPOS ADICIONALES (DINÁMICOS POR MÓDULO)
  // ==================================================
  log_debug("📋 Generando tags de CAMPOS ADICIONALES dinámicamente...");

  // ==================================================
  // 4. TAGS DE CAMPOS ADICIONALES (BÚSQUEDA GLOBAL)
  // ==================================================
  log_debug("📋 Generando tags de CAMPOS ADICIONALES (Búsqueda Global)...");

  // Consultamos TODOS los campos adicionales sin filtrar por módulo inicialmente
  // Esto soluciona problemas de singular/plural (servicio vs servicios)
  $queryCampos = "
        SELECT id, modulo, nombre_campo, tipo_campo, estado_mostrar
        FROM campos_adicionales 
        ORDER BY modulo ASC, nombre_campo ASC
    ";

  $resultCampos = $conn->query($queryCampos);

  if (!$resultCampos) {
    log_debug("❌ Error obteniendo campos adicionales: " . $conn->error);
    throw new Exception("Error obteniendo campos adicionales: " . $conn->error);
  }

  $camposPorModulo = [];
  $camposCountTotal = 0;
  while ($campo = $resultCampos->fetch_assoc()) {
    $mod_db = strtolower(trim($campo['modulo']));
    $est = (int) $campo['estado_mostrar'];

    // Solo procesar si estado_mostrar > 0
    if ($est <= 0) {
      continue;
    }

    $camposCountTotal++;
    $fieldSlug = slugify($campo['nombre_campo']);

    // Mapeo estético de nombres de categorías
    $categoryMap = [
      'servicio' => 'Servicios',
      'equipo' => 'Equipos',
      'inspeccion' => 'Inspecciones'
    ];
    $moduloNamePretty = isset($categoryMap[$mod_db]) ? $categoryMap[$mod_db] : ucfirst($mod_db);

    if (!isset($camposPorModulo[$moduloNamePretty])) {
      $camposPorModulo[$moduloNamePretty] = [];
    }

    $camposPorModulo[$moduloNamePretty][] = [
      'tag' => '{{campo_' . $fieldSlug . '}}',
      'field' => $fieldSlug,
      'description' => $campo['nombre_campo'],
      'type' => $campo['tipo_campo']
    ];
  }

  log_debug("✅ Generados tags para " . count($camposPorModulo) . " categorías de campos adicionales");

  // ==================================================
  // 5. TAGS DE FOTOS (MÚLTIPLES)
  // ==================================================
  log_debug("📋 Generando tags de FOTOS...");
  $fotosTags = [
    [
      'tag' => '{{foto_antes}}',
      'field' => "tipo_foto = 'antes'",
      'description' => 'Primera imagen antes del servicio',
      'type' => 'image'
    ],
    [
      'tag' => '{{foto_despues}}',
      'field' => "tipo_foto = 'despues'",
      'description' => 'Primera imagen después del servicio',
      'type' => 'image'
    ],
    [
      'tag' => '{{fotos_antes_todas}}',
      'field' => "tipo_foto = 'antes'",
      'description' => 'Todas las fotos ANTES del servicio (múltiples)',
      'type' => 'image_list'
    ],
    [
      'tag' => '{{fotos_despues_todas}}',
      'field' => "tipo_foto = 'despues'",
      'description' => 'Todas las fotos DESPUÉS del servicio (múltiples)',
      'type' => 'image_list'
    ],
    [
      'tag' => '{{fotos_todas}}',
      'field' => 'todas',
      'description' => 'Todas las fotos del servicio (antes + después)',
      'type' => 'image_list'
    ]
  ];

  log_debug("✅ Generados " . count($fotosTags) . " tags de fotos");

  // ==================================================
  // 6. TAGS DE REPUESTOS (MÚLTIPLES)
  // ==================================================
  log_debug("📋 Generando tags de REPUESTOS...");
  $repuestosTags = [
    [
      'tag' => '{{repuestos_filas}}',
      'field' => 'inventory_item_id',
      'description' => 'Filas HTML de tabla con todos los repuestos (para usar dentro de <table>)',
      'type' => 'html_table_rows'
    ],
    [
      'tag' => '{{repuestos_lista}}',
      'field' => 'inventory_item_id',
      'description' => 'Lista completa de repuestos en formato HTML',
      'type' => 'html_list'
    ]
  ];

  log_debug("✅ Generados " . count($repuestosTags) . " tags de repuestos");

  // ==================================================
  // 7. TAGS DE FIRMAS (TABLA firmas) - CORREGIDO
  // ==================================================
  log_debug("📋 Generando tags de FIRMAS desde tabla 'firmas' (CORREGIDO)...");

  $firmasTags = [
    // Usuario que entrega (desde tabla usuarios)
/*
    [
      'tag' => '{{firma_usuario_id}}',
      'field' => 'id_staff_entrega',
      'description' => 'ID del usuario que entrega',
      'type' => 'int(11)'
    ],
    */
    [
      'tag' => '{{firma_usuario_nombre}}',
      'field' => 'id_staff_entrega',
      'description' => 'Nombre del usuario que entrega (JOIN usuarios.NOMBRE_USER)',
      'type' => 'varchar(100)',
      'requires_join' => true,
      'join_table' => 'usuarios',
      'join_column' => 'NOMBRE_USER'
    ],
    [
      'tag' => '{{firma_usuario_correo}}',
      'field' => 'id_staff_entrega',
      'description' => 'Correo del usuario que entrega (JOIN usuarios.correo)',
      'type' => 'varchar(100)',
      'requires_join' => true,
      'join_table' => 'usuarios',
      'join_column' => 'correo'
    ],
    [
      'tag' => '{{firma_usuario_telefono}}',
      'field' => 'id_staff_entrega',
      'description' => 'Teléfono del usuario que entrega (JOIN usuarios.telefono)',
      'type' => 'varchar(20)',
      'requires_join' => true,
      'join_table' => 'usuarios',
      'join_column' => 'telefono'
    ],
    [
      'tag' => '{{firma_usuario_imagen}}',
      'field' => 'firma_staff_base64',
      'description' => 'Firma digital del usuario que entrega (imagen base64)',
      'type' => 'longtext'
    ],
    [
      'tag' => '{{firma_nota_entrega}}',
      'field' => 'nota_entrega',
      'description' => 'Nota o comentario del usuario al entregar',
      'type' => 'text'
    ],

    // Funcionario que recibe (desde tabla funcionario - SINGULAR)
/*
    [
      'tag' => '{{firma_funcionario_id}}',
      'field' => 'id_funcionario_recibe',
      'description' => 'ID del funcionario que recibe',
      'type' => 'int(11)'
    ],
    */
    [
      'tag' => '{{firma_funcionario_nombre}}',
      'field' => 'id_funcionario_recibe',
      'description' => 'Nombre del funcionario que recibe (JOIN funcionario.nombre)',
      'type' => 'varchar(100)',
      'requires_join' => true,
      'join_table' => 'funcionario',
      'join_column' => 'nombre'
    ],
    [
      'tag' => '{{firma_funcionario_cargo}}',
      'field' => 'id_funcionario_recibe',
      'description' => 'Cargo del funcionario que recibe (JOIN funcionario.cargo)',
      'type' => 'varchar(100)',
      'requires_join' => true,
      'join_table' => 'funcionario',
      'join_column' => 'cargo'
    ],
    [
      'tag' => '{{firma_funcionario_empresa}}',
      'field' => 'id_funcionario_recibe',
      'description' => 'Empresa del funcionario que recibe (JOIN funcionario.empresa)',
      'type' => 'varchar(100)',
      'requires_join' => true,
      'join_table' => 'funcionario',
      'join_column' => 'empresa'
    ],
    [
      'tag' => '{{firma_funcionario_imagen}}',
      'field' => 'firma_funcionario_base64',
      'description' => 'Firma digital del funcionario que recibe (imagen base64)',
      'type' => 'longtext'
    ],
    [
      'tag' => '{{firma_nota_recepcion}}',
      'field' => 'nota_recepcion',
      'description' => 'Nota o comentario del funcionario al recibir',
      'type' => 'text'
    ],

    // Fechas
    [
      'tag' => '{{firma_fecha_creacion}}',
      'field' => 'created_at',
      'description' => 'Fecha y hora en que se creó la firma',
      'type' => 'timestamp'
    ],

    // Tags legacy (mantener compatibilidad con plantillas antiguas)
    [
      'tag' => '{{firma_tecnico}}',
      'field' => 'firma_staff_base64',
      'description' => 'Firma del técnico/usuario (alias de firma_usuario_imagen)',
      'type' => 'signature',
      'is_alias' => true
    ],
    [
      'tag' => '{{firma_cliente}}',
      'field' => 'firma_funcionario_base64',
      'description' => 'Firma del cliente/funcionario (alias de firma_funcionario_imagen)',
      'type' => 'signature',
      'is_alias' => true
    ],
    [
      'tag' => '{{cliente_contacto}}',
      'field' => 'id_funcionario_recibe',
      'description' => 'Contacto del cliente (alias de firma_funcionario_nombre)',
      'type' => 'varchar(100)',
      'is_alias' => true
    ]
  ];

  log_debug("✅ Generados " . count($firmasTags) . " tags de firmas ");

  // ==================================================
  // 8. TAGS DE USUARIOS (TABLA usuarios)
  // ==================================================
  log_debug("📋 Generando tags de USUARIOS...");

  $usuariosTags = [
    [
      'tag' => '{{usuario_nombre_cliente}}',
      'field' => 'NOMBRE_CLIENTE',
      'description' => 'Nombre de la empresa/cliente',
      'type' => 'varchar(100)'
    ],
    [
      'tag' => '{{usuario_nit}}',
      'field' => 'NIT',
      'description' => 'NIT del cliente',
      'type' => 'varchar(50)'
    ],
    [
      'tag' => '{{usuario_correo}}',
      'field' => 'CORREO',
      'description' => 'Correo electrónico del usuario creador',
      'type' => 'varchar(100)'
    ],
    [
      'tag' => '{{usuario_nombre}}',
      'field' => 'NOMBRE_USER',
      'description' => 'Nombre del usuario creador',
      'type' => 'varchar(100)'
    ],
    [
      'tag' => '{{usuario_telefono}}',
      'field' => 'TELEFONO',
      'description' => 'Teléfono del usuario creador',
      'type' => 'varchar(20)'
    ]
  ];

  log_debug("✅ Generados " . count($usuariosTags) . " tags de usuarios");

  // ==================================================
  // 9. TAGS DE BRANDING
  // ==================================================
  log_debug("📋 Generando tags de BRANDING...");

  $brandingTags = [
    [
      'tag' => '{{branding_logo_url}}',
      'field' => 'logo_url',
      'description' => 'URL del logo de la empresa/branding',
      'type' => 'varchar(500)'
    ]
  ];

  log_debug("✅ Generados " . count($brandingTags) . " tags de branding");

  // ==================================================
  // CONSTRUCCIÓN DE LA RESPUESTA FINAL
  // ==================================================
  log_debug("🏗️ Construyendo respuesta final...");

  $categories = [];

  if ($modulo_filtro === 'servicios') {
    $categories[] = [
      'name' => 'Servicio',
      'description' => 'Información general del servicio técnico',
      'tags' => $serviciosTags
    ];
  } else if ($modulo_filtro === 'inspecciones') {
    $categories[] = [
      'name' => 'Inspección',
      'description' => 'Información de la inspección técnica',
      'tags' => $inspeccionesTags
    ];
  }

  $categories[] = [
    'name' => 'Equipo',
    'description' => 'Información del equipo asociado',
    'tags' => $equiposTags
  ];

  $categories[] = [
    'name' => 'Cliente',
    'description' => 'Información del cliente',
    'tags' => $clienteTags
  ];

  // Agregar categorías dinámicas por módulo
  foreach ($camposPorModulo as $moduloName => $tags) {
    $categories[] = [
      'name' => 'Campos Adicionales - ' . $moduloName,
      'description' => 'Campos personalizados del módulo ' . $moduloName,
      'tags' => $tags
    ];
  }

  // Agregar el resto de categorías fijas
  $categories = array_merge($categories, [
    [
      'name' => 'Fotos',
      'description' => 'Imágenes del servicio (únicas y múltiples)',
      'tags' => $fotosTags
    ],
    [
      'name' => 'Repuestos',
      'description' => 'Repuestos utilizados en el servicio',
      'tags' => $repuestosTags
    ],
    [
      'name' => 'Firmas',
      'description' => 'Firmas digitales y datos de entrega/recepción (CORREGIDO)',
      'tags' => $firmasTags
    ],
    [
      'name' => 'Usuarios',
      'description' => 'Información del usuario que creó o gestionó el servicio',
      'tags' => $usuariosTags
    ],
    [
      'name' => 'Branding',
      'description' => 'Elementos de branding y personalización',
      'tags' => $brandingTags
    ]
  ]);

  $totalTags = array_sum(array_map(function ($cat) {
    return count($cat['tags']);
  }, $categories));

  log_debug("========================================");
  log_debug("✅ RESUMEN DE CATEGORÍAS GENERADAS:");
  log_debug("========================================");
  foreach ($categories as $cat) {
    log_debug("   📂 " . $cat['name'] . ": " . count($cat['tags']) . " tags");
  }
  log_debug("========================================");
  log_debug("✅ TOTAL DE TAGS GENERADOS: $totalTags");
  log_debug("========================================");

  $response = [
    'success' => true,
    'message' => 'Tags obtenidos exitosamente',
    'total_categories' => count($categories),
    'total_tags' => $totalTags,
    'data' => [
      'categories' => $categories
    ]
  ];

  log_debug("📤 Enviando respuesta JSON...");
  log_debug("📊 Tamaño respuesta: " . strlen(json_encode($response)) . " bytes");

  sendJsonResponse($response, 200);

  log_debug("✅ Respuesta enviada exitosamente");
} catch (Exception $e) {
  log_debug("🔴🔴🔴 EXCEPTION CAPTURADA 🔴🔴🔴");
  log_debug("❌ Mensaje: " . $e->getMessage());
  log_debug("📁 Archivo: " . $e->getFile());
  log_debug("📍 Línea: " . $e->getLine());
  log_debug("📚 Trace: " . $e->getTraceAsString());
  log_debug("📤 Enviando error response...");
  sendJsonResponse(errorResponse($e->getMessage()), 500);
  log_debug("✅ Error response enviado");
} finally {
  if (isset($conn)) {
    $conn->close();
    log_debug("🔒 Conexión cerrada");
  }
  log_debug("========================================");
  log_debug("🏁 REQUEST FINALIZADA");
  log_debug("========================================\n");
}
