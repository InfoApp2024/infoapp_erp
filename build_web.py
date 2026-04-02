#!/usr/bin/env python3
"""
Script de build automático para Flutter Web.
Sincroniza la versión en pubspec.yaml → app_version.dart → web/version.json
y luego ejecuta 'flutter build web'.

Uso:
    python build_web.py
"""

import re
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).parent

PUBSPEC       = ROOT / "pubspec.yaml"
APP_VERSION   = ROOT / "lib" / "core" / "version" / "app_version.dart"
VERSION_JSON  = ROOT / "web" / "version.json"


def leer_version_pubspec():
    content = PUBSPEC.read_text(encoding="utf-8")
    match = re.search(r"^version:\s*(\S+)", content, re.MULTILINE)
    if not match:
        print("❌ No se encontró la clave 'version' en pubspec.yaml")
        sys.exit(1)
    return match.group(1).split("+")[0]  # Solo la parte semver, sin build-number


def actualizar_app_version(version):
    contenido = (
        "// Archivo generado automáticamente por build_web.py - NO EDITAR MANUALMENTE\n"
        f"const String kAppVersion = '{version}';\n"
    )
    APP_VERSION.write_text(contenido, encoding="utf-8")
    print(f"   ✅ app_version.dart → '{version}'")


def actualizar_version_json(version):
    data = {"version": version}
    VERSION_JSON.write_text(
        json.dumps(data, indent=4) + "\n",
        encoding="utf-8"
    )
    print(f"   ✅ web/version.json → '{version}'")


def ejecutar_flutter_build():
    print("\n🚀 Ejecutando: flutter build web --release ...\n")
    # En Windows, flutter es un .bat → necesita shell=True
    result = subprocess.run(
        "flutter build web --release",
        cwd=str(ROOT),
        shell=True,
    )
    if result.returncode != 0:
        print("\n❌ El build de Flutter falló.")
        sys.exit(result.returncode)
    print("\n✅ Build completado exitosamente.")


if __name__ == "__main__":
    print("=" * 50)
    print("  🏗️  Script de Build Web - InfoApp (Manual Update Only)")
    print("=" * 50)

    version = leer_version_pubspec()
    print(f"\n📦 Versión detectada en pubspec.yaml: {version}\n")

    print("🔄 Sincronizando archivos de versión...")
    actualizar_app_version(version)
    actualizar_version_json(version)

    ejecutar_flutter_build()

    print("\n" + "=" * 50)
    print(f"  ✅ Build {version} listo para desplegar.")
    print("  ⚠️  RECUERDA: La actualización en el cliente es MANUAL vía botón.")
    print("=" * 50 + "\n")
