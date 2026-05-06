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
