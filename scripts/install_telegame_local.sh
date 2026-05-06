#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${1:-$HOME/ProyectoTeleinformatica}"

mkdir -p "$TARGET_DIR/docs" "$TARGET_DIR/src" "$TARGET_DIR/tests"

cat > "$TARGET_DIR/.gitignore" <<'FILE'
__pycache__/
*.py[cod]
.pytest_cache/
FILE

cat > "$TARGET_DIR/README.md" <<'FILE'
# Proyecto Final Telegame

Telegame es un sistema cliente-servidor para la materia de Teleinformática. El servidor maestro acepta clientes dinámicos y gestiona completamente el juego, sin comunicación directa entre jugadores.

## Arquitectura

- **Servidor maestro**: acepta cualquier cantidad de clientes, sin un máximo fijo definido en el código.
- **Multiplexación con `select`**: un solo proceso atiende múltiples sockets TCP.
- **Juego gestionado por servidor**: los clientes solo envían comandos; el servidor valida turnos, movimientos, victorias y empates.
- **Modo implementado**: 1 vs 1 usando tres en raya.

## Requisitos

- Linux.
- Python 3.10 o superior recomendado.
- No requiere librerías externas.

## Ejecución rápida en una sola computadora

Este modo sirve para probar la lógica usando tres terminales en el mismo Linux.

En una terminal inicia el servidor:

```bash
python3 src/server.py --host 127.0.0.1 --port 5000
```

En otra terminal abre el primer cliente:

```bash
python3 src/client.py --host 127.0.0.1 --port 5000 --name Alice
```

En una tercera terminal abre el segundo cliente:

```bash
python3 src/client.py --host 127.0.0.1 --port 5000 --name Bob
```

## Ejecución desde dos computadoras

Sí, el proyecto puede jugarse desde dos computadoras. Para eso una computadora ejecuta el servidor y las dos computadoras ejecutan clientes que se conectan a la IP del servidor.

### 1. En la computadora servidor

Obtén la IP de la computadora servidor en la red o VPN:

```bash
ip addr
```

Busca una IP parecida a `192.168.x.x`, `10.x.x.x` o la IP asignada por la VPN. En estos ejemplos usaremos `192.168.1.50`; cámbiala por la IP real de tu servidor.

Inicia el servidor escuchando en todas las interfaces de red:

```bash
python3 src/server.py --host 0.0.0.0 --port 5000
```

Si tienes firewall activo, permite el puerto TCP 5000. Por ejemplo, con UFW:

```bash
sudo ufw allow 5000/tcp
```

### 2. En la computadora del jugador 1

Conéctate usando la IP real del servidor:

```bash
python3 src/client.py --host 192.168.1.50 --port 5000 --name Alice
```

### 3. En la computadora del jugador 2

Conéctate a la misma IP del servidor:

```bash
python3 src/client.py --host 192.168.1.50 --port 5000 --name Bob
```

Importante: `127.0.0.1` solo sirve para conectarse a la misma computadora. Para dos computadoras debes usar la IP de red/VPN del servidor.

## Cómo se juega

1. Cada jugador entra al cliente.
2. Cada jugador escribe `QUEUE` y presiona Enter.
3. El servidor empareja automáticamente a dos jugadores.
4. El servidor responde con `MATCH`: a un jugador le asigna `X` y al otro `O`.
5. Siempre empieza `X`.
6. Cuando el servidor muestre `TURN X`, juega quien tenga `X`; cuando muestre `TURN O`, juega quien tenga `O`.
7. Para marcar una casilla escribe `MOVE <numero>`, por ejemplo `MOVE 5`.
8. Gana quien complete una fila, columna o diagonal. Si nadie gana y se llena el tablero, hay empate.

Comandos útiles dentro del cliente:

```text
HELP
QUEUE
MOVE 1
MOVE 5
BOARD
QUIT
```

Las casillas del tablero van del 1 al 9:

```text
1 | 2 | 3
---------
4 | 5 | 6
---------
7 | 8 | 9
```

Ejemplo de partida rápida donde gana `X` arriba:

```text
Alice: QUEUE
Bob:   QUEUE
Alice recibe: MATCH 1 X Bob
Bob recibe:   MATCH 1 O Alice
Alice: MOVE 1
Bob:   MOVE 4
Alice: MOVE 2
Bob:   MOVE 5
Alice: MOVE 3
Servidor: RESULT WIN X
```

## Pruebas

```bash
python3 -m py_compile src/server.py src/client.py tests/smoke_test.py
python3 tests/smoke_test.py
```
FILE

cat > "$TARGET_DIR/docs/RFC-TELEGAME.md" <<'FILE'
# RFC-TELEGAME/1.0

## 1. Nombre del protocolo

**TELEGAME/1.0** es un protocolo de texto sobre TCP para conectar jugadores a un servidor maestro que administra partidas 1 vs 1 de tres en raya.

## 2. Objetivo

Permitir que varios clientes se conecten dinámicamente a un servidor central. El servidor realiza el emparejamiento, valida comandos y ejecuta el estado completo del juego. No existe comunicación peer-to-peer entre clientes.

## 3. Transporte

- Protocolo de transporte: TCP.
- Formato de mensajes: texto UTF-8 terminado en salto de línea `\n`.
- Puerto sugerido para demo local o LAN/VPN: `5000`.
- Para prueba local se puede usar `127.0.0.1`.
- Para dos computadoras se debe usar la IP LAN/VPN del servidor, no `127.0.0.1`.
- El servidor debe escuchar en `0.0.0.0` cuando se acepten clientes desde otras computadoras.
- Cada comando enviado por el cliente ocupa una línea.
- Cada respuesta del servidor ocupa una línea.

## 4. Arquitectura del servicio

```text
+-----------+        TCP         +----------------+        TCP        +-----------+
| Cliente A | <----------------> | Servidor       | <---------------> | Cliente B |
| Jugador X |                    | maestro/juego  |                   | Jugador O |
+-----------+                    +----------------+                   +-----------+
```

El servidor:

1. Acepta conexiones nuevas desde la misma máquina, una LAN o una VPN.
2. Registra nombre de jugador.
3. Mantiene una cola de espera.
4. Crea partidas 1 vs 1.
5. Valida turnos y movimientos.
6. Notifica tablero, victoria, empate o abandono.

Ejemplo de despliegue en dos computadoras:

```text
Servidor: 192.168.1.50:5000 ejecuta server.py con --host 0.0.0.0
Cliente A: se conecta a 192.168.1.50:5000
Cliente B: se conecta a 192.168.1.50:5000
```

## 5. Comandos del cliente

| Comando | Estado permitido | Descripción |
| --- | --- | --- |
| `HELLO <nombre>` | Conectado sin nombre | Registra el nombre del jugador. |
| `HELP` | Cualquier estado | Lista comandos disponibles. |
| `QUEUE` | Lobby | Entra a cola para jugar. |
| `BOARD` | En partida | Solicita el tablero actual. |
| `MOVE <1-9>` | En partida y turno propio | Intenta marcar una casilla. |
| `QUIT` | Cualquier estado | Cierra sesión o abandona partida. |

## 6. Respuestas del servidor

| Respuesta | Significado |
| --- | --- |
| `WELCOME <texto>` | Saludo inicial del servidor. |
| `OK <texto>` | Operación aceptada. |
| `ERR <texto>` | Operación rechazada. |
| `INFO <texto>` | Mensaje informativo. |
| `MATCH <id> <simbolo> <oponente>` | Partida creada. |
| `BOARD <celdas>` | Estado del tablero, 9 caracteres. `.` indica vacío. |
| `TURN <simbolo>` | Indica a quién le toca. |
| `RESULT WIN <simbolo>` | La partida terminó con ganador. |
| `RESULT DRAW` | La partida terminó en empate. |
| `RESULT ABORT <texto>` | La partida terminó por desconexión o abandono. |
| `BYE <texto>` | Cierre de sesión. |

## 7. Representación del tablero

El servidor envía el tablero como una cadena de 9 caracteres:

```text
BOARD X.O...X..
```

Equivalencia de posiciones:

```text
1 | 2 | 3
---------
4 | 5 | 6
---------
7 | 8 | 9
```

Caracteres válidos:

- `X`: marca del jugador X.
- `O`: marca del jugador O.
- `.`: casilla vacía.

## 8. Autómata de estados del cliente

```text
[DESCONECTADO]
      |
      | conexión TCP
      v
[CONECTADO]
      |
      | HELLO <nombre>
      v
[LOBBY]
      |
      | QUEUE
      v
[EN_COLA]
      |
      | servidor encuentra rival
      v
[EN_PARTIDA]
      |
      | victoria / empate / abandono
      v
[LOBBY]
      |
      | QUIT
      v
[DESCONECTADO]
```

## 9. Reglas del juego

1. Cada partida tiene dos jugadores.
2. El primer jugador emparejado usa `X`.
3. El segundo jugador usa `O`.
4. Siempre inicia `X`.
5. Un jugador solo puede jugar cuando el servidor indica su turno.
6. Un movimiento válido usa una casilla libre entre 1 y 9.
7. Gana quien complete una línea horizontal, vertical o diagonal.
8. Si se llenan las nueve casillas sin ganador, la partida termina en empate.

## 10. Errores esperados

Ejemplos de errores:

- `ERR Primero debes registrarte con HELLO <nombre>`
- `ERR Ya estas en cola`
- `ERR No es tu turno`
- `ERR Movimiento invalido`
- `ERR Casilla ocupada`

## 11. Seguridad y límites

- El servidor limita el tamaño de cada línea recibida.
- El servidor valida nombres y movimientos.
- La desconexión de un jugador aborta la partida para ambos.
- No se define número máximo fijo de clientes; el límite práctico depende del sistema operativo y recursos disponibles.
FILE

cat > "$TARGET_DIR/src/server.py" <<'FILE'
#!/usr/bin/env python3
"""Servidor maestro TELEGAME/1.0.

Implementa un servidor TCP multiplexado con select. El servidor acepta clientes
sin un maximo fijo, los empareja en partidas 1 vs 1 y administra tres en raya.
"""

from __future__ import annotations

import argparse
import select
import socket
from dataclasses import dataclass, field
from typing import Dict, List, Optional

MAX_LINE_BYTES = 1024
WIN_LINES = (
    (0, 1, 2),
    (3, 4, 5),
    (6, 7, 8),
    (0, 3, 6),
    (1, 4, 7),
    (2, 5, 8),
    (0, 4, 8),
    (2, 4, 6),
)


@dataclass
class Player:
    sock: socket.socket
    address: tuple[str, int]
    name: Optional[str] = None
    buffer: bytes = b""
    in_queue: bool = False
    game_id: Optional[int] = None
    symbol: Optional[str] = None


@dataclass
class Game:
    game_id: int
    x_player: Player
    o_player: Player
    board: List[str] = field(default_factory=lambda: ["."] * 9)
    turn: str = "X"

    def player_for_symbol(self, symbol: str) -> Player:
        return self.x_player if symbol == "X" else self.o_player

    def opponent_of(self, player: Player) -> Player:
        return self.o_player if player is self.x_player else self.x_player

    def board_text(self) -> str:
        return "".join(self.board)

    def winner(self) -> Optional[str]:
        for a, b, c in WIN_LINES:
            if self.board[a] != "." and self.board[a] == self.board[b] == self.board[c]:
                return self.board[a]
        return None

    def is_draw(self) -> bool:
        return "." not in self.board and self.winner() is None


class TelegameServer:
    def __init__(self, host: str, port: int) -> None:
        self.host = host
        self.port = port
        self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.players: Dict[socket.socket, Player] = {}
        self.waiting_queue: List[Player] = []
        self.games: Dict[int, Game] = {}
        self.next_game_id = 1

    def start(self) -> None:
        self.server_socket.bind((self.host, self.port))
        self.server_socket.listen()
        self.server_socket.setblocking(False)
        print(f"Servidor TELEGAME escuchando en {self.host}:{self.port}")

        while True:
            read_list = [self.server_socket, *self.players.keys()]
            readable, _, exceptional = select.select(read_list, [], read_list)

            for ready in readable:
                if ready is self.server_socket:
                    self.accept_player()
                else:
                    self.receive_from_player(ready)

            for failed in exceptional:
                if failed is not self.server_socket:
                    self.disconnect_player(failed, "error de socket")

    def accept_player(self) -> None:
        client_socket, address = self.server_socket.accept()
        client_socket.setblocking(False)
        player = Player(sock=client_socket, address=address)
        self.players[client_socket] = player
        self.send(player, "WELCOME TELEGAME/1.0 usa HELLO <nombre>")
        print(f"Conexion aceptada desde {address[0]}:{address[1]}")

    def receive_from_player(self, player_socket: socket.socket) -> None:
        player = self.players[player_socket]
        try:
            chunk = player_socket.recv(4096)
        except ConnectionError:
            self.disconnect_player(player_socket, "conexion interrumpida")
            return

        if not chunk:
            self.disconnect_player(player_socket, "cliente desconectado")
            return

        player.buffer += chunk
        if len(player.buffer) > MAX_LINE_BYTES * 4:
            self.send(player, "ERR buffer excedido")
            self.disconnect_player(player_socket, "buffer excedido")
            return

        while b"\n" in player.buffer:
            line, player.buffer = player.buffer.split(b"\n", 1)
            if len(line) > MAX_LINE_BYTES:
                self.send(player, "ERR linea demasiado larga")
                continue
            command = line.decode("utf-8", errors="replace").strip()
            if command:
                self.handle_command(player, command)

    def handle_command(self, player: Player, command_line: str) -> None:
        parts = command_line.split(maxsplit=1)
        command = parts[0].upper()
        argument = parts[1] if len(parts) == 2 else ""

        if command == "HELLO":
            self.handle_hello(player, argument)
        elif command == "HELP":
            self.send(player, "INFO Comandos: HELLO <nombre>, QUEUE, BOARD, MOVE <1-9>, QUIT")
        elif command == "QUEUE":
            self.handle_queue(player)
        elif command == "BOARD":
            self.handle_board(player)
        elif command == "MOVE":
            self.handle_move(player, argument)
        elif command == "QUIT":
            self.send(player, "BYE hasta luego")
            self.disconnect_player(player.sock, "salida voluntaria")
        else:
            self.send(player, f"ERR comando desconocido: {command}")

    def handle_hello(self, player: Player, name: str) -> None:
        name = name.strip()
        if not name:
            self.send(player, "ERR uso: HELLO <nombre>")
            return
        if len(name) > 20 or not name.replace("_", "").isalnum():
            self.send(player, "ERR nombre invalido: usa letras, numeros o _ hasta 20 caracteres")
            return
        player.name = name
        self.send(player, f"OK registrado como {name}")

    def handle_queue(self, player: Player) -> None:
        if not player.name:
            self.send(player, "ERR Primero debes registrarte con HELLO <nombre>")
            return
        if player.game_id is not None:
            self.send(player, "ERR Ya estas en una partida")
            return
        if player.in_queue:
            self.send(player, "ERR Ya estas en cola")
            return

        player.in_queue = True
        self.waiting_queue.append(player)
        self.send(player, "OK en cola de espera")
        self.try_match_players()

    def try_match_players(self) -> None:
        while len(self.waiting_queue) >= 2:
            x_player = self.waiting_queue.pop(0)
            o_player = self.waiting_queue.pop(0)
            if x_player.sock not in self.players or o_player.sock not in self.players:
                continue

            game_id = self.next_game_id
            self.next_game_id += 1
            game = Game(game_id=game_id, x_player=x_player, o_player=o_player)
            self.games[game_id] = game

            x_player.in_queue = False
            o_player.in_queue = False
            x_player.game_id = game_id
            o_player.game_id = game_id
            x_player.symbol = "X"
            o_player.symbol = "O"

            self.send(x_player, f"MATCH {game_id} X {o_player.name}")
            self.send(o_player, f"MATCH {game_id} O {x_player.name}")
            self.broadcast_game(game, f"BOARD {game.board_text()}")
            self.broadcast_game(game, "TURN X")
            print(f"Partida {game_id}: {x_player.name} vs {o_player.name}")

    def handle_board(self, player: Player) -> None:
        game = self.game_for_player(player)
        if not game:
            self.send(player, "ERR No estas en una partida")
            return
        self.send(player, f"BOARD {game.board_text()}")
        self.send(player, f"TURN {game.turn}")

    def handle_move(self, player: Player, argument: str) -> None:
        game = self.game_for_player(player)
        if not game:
            self.send(player, "ERR No estas en una partida")
            return
        if player.symbol != game.turn:
            self.send(player, "ERR No es tu turno")
            return
        try:
            position = int(argument)
        except ValueError:
            self.send(player, "ERR uso: MOVE <1-9>")
            return
        if position < 1 or position > 9:
            self.send(player, "ERR Movimiento invalido")
            return

        index = position - 1
        if game.board[index] != ".":
            self.send(player, "ERR Casilla ocupada")
            return

        game.board[index] = player.symbol or "."
        self.broadcast_game(game, f"BOARD {game.board_text()}")

        winner = game.winner()
        if winner:
            self.broadcast_game(game, f"RESULT WIN {winner}")
            self.finish_game(game)
            return
        if game.is_draw():
            self.broadcast_game(game, "RESULT DRAW")
            self.finish_game(game)
            return

        game.turn = "O" if game.turn == "X" else "X"
        self.broadcast_game(game, f"TURN {game.turn}")

    def game_for_player(self, player: Player) -> Optional[Game]:
        if player.game_id is None:
            return None
        return self.games.get(player.game_id)

    def broadcast_game(self, game: Game, message: str) -> None:
        self.send(game.x_player, message)
        self.send(game.o_player, message)

    def finish_game(self, game: Game) -> None:
        for player in (game.x_player, game.o_player):
            player.game_id = None
            player.symbol = None
            player.in_queue = False
        self.games.pop(game.game_id, None)

    def send(self, player: Player, message: str) -> None:
        try:
            player.sock.sendall((message + "\n").encode("utf-8"))
        except OSError:
            self.disconnect_player(player.sock, "no se pudo enviar")

    def disconnect_player(self, player_socket: socket.socket, reason: str) -> None:
        player = self.players.pop(player_socket, None)
        if not player:
            return

        if player in self.waiting_queue:
            self.waiting_queue.remove(player)

        game = self.game_for_player(player)
        if game:
            opponent = game.opponent_of(player)
            self.send(opponent, f"RESULT ABORT {player.name or 'jugador'} abandono la partida")
            self.finish_game(game)

        try:
            player_socket.close()
        except OSError:
            pass
        print(f"Desconexion {player.address[0]}:{player.address[1]} ({reason})")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Servidor maestro TELEGAME/1.0")
    parser.add_argument("--host", default="0.0.0.0", help="IP de escucha")
    parser.add_argument("--port", type=int, default=5000, help="Puerto TCP de escucha")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    TelegameServer(args.host, args.port).start()


if __name__ == "__main__":
    main()
FILE

cat > "$TARGET_DIR/src/client.py" <<'FILE'
#!/usr/bin/env python3
"""Cliente interactivo TELEGAME/1.0."""

from __future__ import annotations

import argparse
import select
import socket
import sys


def render_board(cells: str) -> str:
    values = [cell if cell != "." else str(index + 1) for index, cell in enumerate(cells)]
    return (
        f"{values[0]} | {values[1]} | {values[2]}\n"
        "---------\n"
        f"{values[3]} | {values[4]} | {values[5]}\n"
        "---------\n"
        f"{values[6]} | {values[7]} | {values[8]}"
    )


def print_server_message(message: str) -> None:
    if message.startswith("BOARD "):
        print("\nTablero:")
        print(render_board(message.split(maxsplit=1)[1]))
    else:
        print(f"< {message}")


def run_client(host: str, port: int, name: str | None) -> None:
    with socket.create_connection((host, port)) as sock:
        sock.setblocking(False)
        if name:
            sock.sendall(f"HELLO {name}\n".encode("utf-8"))
        print("Cliente conectado. Escribe HELP para ver comandos.")

        receive_buffer = b""
        while True:
            readable, _, _ = select.select([sock, sys.stdin], [], [])
            for ready in readable:
                if ready is sock:
                    chunk = sock.recv(4096)
                    if not chunk:
                        print("Servidor cerro la conexion")
                        return
                    receive_buffer += chunk
                    while b"\n" in receive_buffer:
                        line, receive_buffer = receive_buffer.split(b"\n", 1)
                        print_server_message(line.decode("utf-8", errors="replace").strip())
                else:
                    user_input = sys.stdin.readline()
                    if not user_input:
                        return
                    sock.sendall(user_input.encode("utf-8"))
                    if user_input.strip().upper() == "QUIT":
                        return


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Cliente TELEGAME/1.0")
    parser.add_argument("--host", default="127.0.0.1", help="IP del servidor")
    parser.add_argument("--port", type=int, default=5000, help="Puerto TCP del servidor")
    parser.add_argument("--name", help="Nombre de jugador opcional")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    run_client(args.host, args.port, args.name)


if __name__ == "__main__":
    main()
FILE

cat > "$TARGET_DIR/tests/smoke_test.py" <<'FILE'
#!/usr/bin/env python3
"""Prueba funcional basica de servidor y protocolo TELEGAME."""

from __future__ import annotations

import socket
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SERVER = ROOT / "src" / "server.py"
HOST = "127.0.0.1"
PORT = 5055


def read_line(sock: socket.socket) -> str:
    data = b""
    while not data.endswith(b"\n"):
        chunk = sock.recv(1)
        if not chunk:
            raise RuntimeError("conexion cerrada inesperadamente")
        data += chunk
    return data.decode("utf-8").strip()


def send_line(sock: socket.socket, message: str) -> None:
    sock.sendall((message + "\n").encode("utf-8"))


def connect_player(name: str) -> socket.socket:
    sock = socket.create_connection((HOST, PORT), timeout=3)
    assert read_line(sock).startswith("WELCOME")
    send_line(sock, f"HELLO {name}")
    assert read_line(sock) == f"OK registrado como {name}"
    return sock


def main() -> None:
    process = subprocess.Popen(
        [sys.executable, str(SERVER), "--host", HOST, "--port", str(PORT)],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    try:
        time.sleep(0.4)
        alice = connect_player("Alice")
        bob = connect_player("Bob")

        send_line(alice, "QUEUE")
        assert read_line(alice) == "OK en cola de espera"
        send_line(bob, "QUEUE")
        assert read_line(bob) == "OK en cola de espera"

        assert read_line(alice).startswith("MATCH 1 X Bob")
        assert read_line(bob).startswith("MATCH 1 O Alice")
        assert read_line(alice) == "BOARD ........."
        assert read_line(bob) == "BOARD ........."
        assert read_line(alice) == "TURN X"
        assert read_line(bob) == "TURN X"

        send_line(bob, "MOVE 1")
        assert read_line(bob) == "ERR No es tu turno"

        for sock, move in ((alice, 1), (bob, 4), (alice, 2), (bob, 5), (alice, 3)):
            send_line(sock, f"MOVE {move}")
            board_a = read_line(alice)
            board_b = read_line(bob)
            assert board_a.startswith("BOARD ")
            assert board_b.startswith("BOARD ")
            if move != 3:
                assert read_line(alice).startswith("TURN ")
                assert read_line(bob).startswith("TURN ")

        assert read_line(alice) == "RESULT WIN X"
        assert read_line(bob) == "RESULT WIN X"
        alice.close()
        bob.close()
    finally:
        process.terminate()
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()


if __name__ == "__main__":
    main()
FILE

chmod +x "$TARGET_DIR/src/server.py" "$TARGET_DIR/src/client.py" "$TARGET_DIR/tests/smoke_test.py"

cat <<MSG
Proyecto creado en: $TARGET_DIR

Para abrirlo:
  cd "$TARGET_DIR"

Para probarlo:
  python3 -m py_compile src/server.py src/client.py tests/smoke_test.py
  python3 tests/smoke_test.py

Para iniciar servidor local:
  python3 src/server.py --host 127.0.0.1 --port 5000
MSG
