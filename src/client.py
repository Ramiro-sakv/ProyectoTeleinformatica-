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
