#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${1:-$HOME/ProyectoTeleinformatica}"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mkdir -p "$TARGET_DIR"
cp -R "$SOURCE_DIR"/. "$TARGET_DIR"/

cd "$TARGET_DIR"
make

cat <<MSG
Proyecto instalado en: $TARGET_DIR

Para abrirlo:
  cd "$TARGET_DIR"

Para ejecutar el servidor:
  ./bin/telegame_server --host 127.0.0.1 --port 5000

Para ejecutar un cliente:
  ./bin/telegame_client --host 127.0.0.1 --port 5000 --name Alice

Para probar:
  make test
MSG
