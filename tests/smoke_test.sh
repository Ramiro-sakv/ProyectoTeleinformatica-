#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT=5055
SERVER_LOG="$ROOT_DIR/server-test.log"
SERVER_PID=""

cleanup() {
  if [[ -n "${SERVER_PID}" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

expect_line() {
  local fd="$1"
  local expected="$2"
  local line
  if ! read -r -t 3 -u "$fd" line; then
    echo "No se recibio respuesta esperada: $expected" >&2
    exit 1
  fi
  if [[ "$line" != "$expected" ]]; then
    echo "Respuesta inesperada. Esperado: '$expected'. Recibido: '$line'" >&2
    exit 1
  fi
}

expect_prefix() {
  local fd="$1"
  local expected="$2"
  local line
  if ! read -r -t 3 -u "$fd" line; then
    echo "No se recibio respuesta con prefijo: $expected" >&2
    exit 1
  fi
  if [[ "$line" != "$expected"* ]]; then
    echo "Respuesta inesperada. Prefijo: '$expected'. Recibido: '$line'" >&2
    exit 1
  fi
}

"$ROOT_DIR/bin/telegame_server" --host 127.0.0.1 --port "$PORT" >"$SERVER_LOG" 2>&1 &
SERVER_PID=$!
sleep 0.4

exec 3<>"/dev/tcp/127.0.0.1/$PORT"
expect_prefix 3 "WELCOME"
printf 'HELLO Alice\n' >&3
expect_line 3 "OK registrado como Alice"

exec 4<>"/dev/tcp/127.0.0.1/$PORT"
expect_prefix 4 "WELCOME"
printf 'HELLO Bob\n' >&4
expect_line 4 "OK registrado como Bob"

printf 'QUEUE\n' >&3
expect_line 3 "OK en cola de espera"
printf 'QUEUE\n' >&4
expect_line 4 "OK en cola de espera"

expect_prefix 3 "MATCH 1 X Bob"
expect_prefix 4 "MATCH 1 O Alice"
expect_line 3 "INFO PARTICIPANTES X=Alice O=Bob"
expect_line 4 "INFO PARTICIPANTES X=Alice O=Bob"
expect_line 3 "BOARD ........."
expect_line 4 "BOARD ........."
expect_line 3 "TURN X Alice"
expect_line 4 "TURN X Alice"

printf 'MOVE 1\n' >&4
expect_line 4 "ERR no es tu turno"

printf 'MOVE 1\n' >&3
expect_line 3 "BOARD X........"
expect_line 4 "BOARD X........"
expect_line 3 "TURN O Bob"
expect_line 4 "TURN O Bob"

printf 'MOVE 4\n' >&4
expect_line 3 "BOARD X..O....."
expect_line 4 "BOARD X..O....."
expect_line 3 "TURN X Alice"
expect_line 4 "TURN X Alice"

printf 'MOVE 2\n' >&3
expect_line 3 "BOARD XX.O....."
expect_line 4 "BOARD XX.O....."
expect_line 3 "TURN O Bob"
expect_line 4 "TURN O Bob"

printf 'MOVE 5\n' >&4
expect_line 3 "BOARD XX.OO...."
expect_line 4 "BOARD XX.OO...."
expect_line 3 "TURN X Alice"
expect_line 4 "TURN X Alice"

printf 'MOVE 3\n' >&3
expect_line 3 "BOARD XXXOO...."
expect_line 4 "BOARD XXXOO...."
expect_line 3 "RESULT WIN X Alice"
expect_line 4 "RESULT WIN X Alice"

expect_line 3 "INFO PARTIDA FINALIZADA: los jugadores vuelven al lobby"
expect_line 3 "INFO PARTICIPANTES conectados=2 en_cola=0 partidas=0"
expect_line 3 "PLAYER Bob LOBBY"
expect_line 3 "PLAYER Alice LOBBY"
expect_line 3 "INFO MARCADOR"
expect_line 3 "SCORE Bob 0 0 1"
expect_line 3 "SCORE Alice 1 0 0"
expect_line 3 "INFO Para jugar otra partida escribe QUEUE"

expect_line 4 "INFO PARTIDA FINALIZADA: los jugadores vuelven al lobby"
expect_line 4 "INFO PARTICIPANTES conectados=2 en_cola=0 partidas=0"
expect_line 4 "PLAYER Bob LOBBY"
expect_line 4 "PLAYER Alice LOBBY"
expect_line 4 "INFO MARCADOR"
expect_line 4 "SCORE Bob 0 0 1"
expect_line 4 "SCORE Alice 1 0 0"
expect_line 4 "INFO Para jugar otra partida escribe QUEUE"

exec 3>&-
exec 4>&-
echo "Smoke test OK"
