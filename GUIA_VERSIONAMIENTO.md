# Guía de Gestión de Versiones y Despliegue

Este documento explica cómo actualizar la versión de la aplicación correctamente para que el sistema de "Nueva actualización disponible" funcione.

## Paso 1: Incrementar la Versión (Manual)
El archivo maestro de la versión es `pubspec.yaml`. Debes editarlo manualmente.

1. Abre `pubspec.yaml`.
2. Busca la línea `version:`.
3. Incrementa el número.
   - Ejemplo: De `1.0.1+1` a `1.0.2+1`.
   - El formato es `MAYOR.MENOR.PARCHE+NUMERO_CONSTRUCCION`.
   - **Importante:** Para que el sistema detecte "Nueva versión", el número debe ser **mayor** semánticamente.

## Paso 2: Sincronizar Versiones (Automático)
Una vez guardado el `pubspec.yaml`, ejecuta el script que sincroniza esta versión con el backend/web.

```bash
dart scripts/update_version_json.dart
```

Esto actualizará automáticamente `web/version.json`.

## Paso 3: Compilar y Desplegar
Ahora puedes construir tu aplicación normalmente.

- **Web:** `flutter build web --release`
- **Android:** `flutter build apk --release`

Al subir los nuevos archivos al servidor (especialmente el `web/version.json`), los usuarios que tengan una versión anterior verán el aviso de "Nueva versión disponible".
