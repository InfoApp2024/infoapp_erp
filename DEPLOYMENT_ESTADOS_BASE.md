# 🚀 Instrucciones de Despliegue - Sistema de Estados Base

## ✅ Archivos Creados

### Backend (PHP)
- `backend/workflow/estados_base.sql` - Crear tabla estados_base
- `backend/workflow/migrar_tabla_estados.sql` - Migrar tabla estados_servicio
- `backend/workflow/listar_estados.php` - ✅ MODIFICADO (incluye estado_base)
- `backend/workflow/crear_estado.php` - ✅ MODIFICADO (valida estado_base)
- `backend/workflow/listar_estados_base.php` - ✅ NUEVO endpoint

### Frontend (Flutter)
- `lib/pages/servicios/models/estado_base_enum.dart` - ✅ NUEVO enum
- `lib/pages/servicios/models/estado_model.dart` - ✅ MODIFICADO
- `lib/pages/servicios/services/estados_service.dart` - ✅ MODIFICADO
- `lib/pages/servicios/validators/transicion_validator.dart` - ✅ NUEVO (opcional)
- `lib/pages/estados_transiciones_page.dart` - ✅ MODIFICADO

---

## 📋 Pasos de Despliegue

### 1️⃣ Base de Datos (CRÍTICO - Ejecutar primero)

```bash
# Conectar a tu base de datos MySQL
mysql -u tu_usuario -p tu_base_de_datos

# O usar phpMyAdmin / MySQL Workbench
```

**Ejecutar en orden:**

1. **Crear tabla estados_base:**
   ```sql
   -- Copiar y ejecutar contenido de:
   backend/workflow/estados_base.sql
   ```

2. **Migrar tabla estados_servicio:**
   ```sql
   -- Copiar y ejecutar contenido de:
   backend/workflow/migrar_tabla_estados.sql
   ```

3. **Verificar:**
   ```sql
   -- Verificar que estados_base tiene 7 registros
   SELECT * FROM estados_base ORDER BY orden;
   
   -- Verificar que estados_servicio tiene nuevas columnas
   DESCRIBE estados_servicio;
   ```

**⚠️ IMPORTANTE:** Si tienes datos de prueba, todos los estados existentes tendrán `estado_base_codigo = 'ABIERTO'` por defecto.

---

### 2️⃣ Backend PHP (Automático)

Los archivos PHP ya están modificados y listos. **No requiere acción adicional.**

✅ Endpoints actualizados:
- `/workflow/listar_estados.php` - Ahora incluye campos de estado base
- `/workflow/crear_estado.php` - Valida y guarda estado_base_codigo
- `/workflow/listar_estados_base.php` - Nuevo endpoint

---

### 3️⃣ Frontend Flutter

**Opción A: Hot Reload (Desarrollo)**
```bash
# Si tienes flutter run activo, presiona:
r  # Hot reload
```

**Opción B: Restart (Recomendado)**
```bash
# Detener app actual y reiniciar:
flutter run
```

**Opción C: Compilar Release**
```bash
flutter build windows  # Para Windows
flutter build apk      # Para Android
```

---

## 🧪 Testing Manual

### Test 1: Verificar Estados Base Disponibles

1. Abrir app Flutter
2. Ir a **Estados y Transiciones**
3. Expandir **"Crear nuevo estado"**
4. **Verificar:** Debe aparecer dropdown "Estado Base del Sistema" con 7 opciones

### Test 2: Crear Estado con Estado Base

1. Llenar formulario:
   - Nombre: "Esperando repuestos"
   - Color: Naranja (#FF5722)
   - Estado Base: **"ASIGNADO"**
   - Bloquea cierre: ☐ No
2. Click **"Guardar estado"**
3. **Verificar:** Estado creado exitosamente

### Test 3: Verificar en Base de Datos

```sql
SELECT 
  id,
  nombre_estado,
  estado_base_codigo,
  bloquea_cierre
FROM estados_servicio
WHERE nombre_estado = 'Esperando repuestos';
```

**Esperado:**
- `estado_base_codigo` = `'ASIGNADO'`
- `bloquea_cierre` = `0`

### Test 4: Verificar Retrocompatibilidad

1. Verificar que estados existentes siguen funcionando
2. Crear servicio y cambiar estados
3. Verificar que campos adicionales siguen funcionando

---

## 📊 Queries de Analytics (Ejemplos)

### Tiempo promedio por estado base
```sql
SELECT 
    e.estado_base_codigo,
    eb.nombre as estado_base,
    COUNT(*) as total_servicios,
    AVG(TIMESTAMPDIFF(HOUR, s.created_at, s.updated_at)) as horas_promedio
FROM servicios s
JOIN estados_servicio e ON s.estado_id = e.id  
JOIN estados_base eb ON e.estado_base_codigo = eb.codigo
GROUP BY e.estado_base_codigo, eb.nombre
ORDER BY eb.orden;
```

### Distribución de servicios por estado base
```sql
SELECT 
    eb.nombre as estado_base,
    COUNT(*) as cantidad,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM servicios), 2) as porcentaje
FROM servicios s
JOIN estados_servicio e ON s.estado_id = e.id
JOIN estados_base eb ON e.estado_base_codigo = eb.codigo
GROUP BY eb.nombre, eb.orden
ORDER BY eb.orden;
```

---

## 🔧 Troubleshooting

### Error: "Table 'estados_base' doesn't exist"

**Solución:** Ejecutar `backend/workflow/estados_base.sql`

### Error: "Unknown column 'estado_base_codigo'"

**Solución:** Ejecutar `backend/workflow/migrar_tabla_estados.sql`

### Dropdown de estado base no aparece

**Causas posibles:**
1. Tabla `estados_base` no existe → Ejecutar SQL
2. Endpoint no responde → Verificar `listar_estados_base.php`
3. Error de red → Revisar consola Flutter

**Debug:**
```dart
// En _cargarEstadosBase(), descomentar:
print('Estados base cargados: $_estadosBase');
```

### Estados existentes no tienen estado_base_codigo

**Solución:** Ejecutar UPDATE manual:
```sql
UPDATE estados_servicio 
SET estado_base_codigo = 'ABIERTO' 
WHERE estado_base_codigo IS NULL OR estado_base_codigo = '';
```

---

## ✨ Funcionalidades Implementadas

### ✅ Completadas
- [x] 7 estados base del sistema
- [x] Tabla `estados_base` con metadata
- [x] Migración de `estados_servicio`
- [x] API modificada para incluir estado_base
- [x] Enum `EstadoBase` en Flutter
- [x] Modelo `EstadoModel` actualizado
- [x] UI con dropdown y checkbox
- [x] Validador de transiciones (código presente)
- [x] 100% retrocompatible

### 🔄 Opcionales (Desactivadas por defecto)
- [ ] Validación de transiciones en `ServiciosController`
- [ ] Indicadores visuales en tabla de estados
- [ ] Filtros por estado base

---

## 🎯 Próximos Pasos (Opcionales)

### Activar Validación de Transiciones

En `servicios_controller.dart`:
```dart
// Cambiar de:
await cambiarEstadoServicio(id, nuevoEstadoId);

// A:
await cambiarEstadoServicio(
  id, 
  nuevoEstadoId,
  validarTransicion: true, // ✅ Activar validación
);
```

### Agregar Indicador Visual en Tabla

En `estados_transiciones_page.dart`, agregar columna:
```dart
DataColumn(label: Text('Estado Base')),

// En celdas:
DataCell(
  Chip(
    label: Text(estado['estado_base_nombre'] ?? 'N/A'),
    backgroundColor: Colors.blue.shade100,
  ),
),
```

---

## 📝 Notas Importantes

1. **Datos de prueba:** Como tienes datos de prueba, no necesitas script de migración inteligente. Todos los estados existentes tendrán `estado_base_codigo = 'ABIERTO'` por defecto.

2. **Validaciones:** Las validaciones de transición están **desactivadas por defecto** para no romper flujos existentes.

3. **Campos adicionales:** Siguen funcionando normalmente, no se ven afectados.

4. **Performance:** Se agregó índice en `estado_base_codigo` para optimizar queries.

---

## ✅ Checklist de Verificación

- [ ] SQL ejecutado: `estados_base.sql`
- [ ] SQL ejecutado: `migrar_tabla_estados.sql`
- [ ] Verificado: 7 registros en `estados_base`
- [ ] Verificado: Columnas nuevas en `estados_servicio`
- [ ] Flutter reiniciado
- [ ] Dropdown de estado base visible
- [ ] Estado creado con estado base
- [ ] Estados existentes funcionan
- [ ] Campos adicionales funcionan

---

**🎉 ¡Implementación completa! El sistema de estados base está listo para usar.**
