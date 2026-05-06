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
            # Cada movimiento valido notifica tablero a ambos clientes.
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
