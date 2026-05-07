# Proyecto Final Telegame

Telegame es un sistema cliente-servidor escrito en C para Linux. El servidor maestro acepta clientes dinamicos, empareja jugadores 1 vs 1, valida turnos y administra completamente el juego de tres en raya. Los clientes no se comunican directamente entre si: todo pasa por el servidor.

## Arquitectura

- Servidor maestro con n clientes dinamicos, sin un numero maximo fijo definido en el codigo.
- Servidor multiplexico con `select`, un solo proceso atiende el socket de escucha y todos los clientes conectados.
- Juego gestionado por el servidor: participantes, cola, turnos, tablero, ganador, empate y abandono.
- Modo implementado: 1 vs 1. Si hay mas de dos jugadores, el servidor empareja de dos en dos desde la cola, permitiendo una demo tipo todos contra todos por rondas.
- Protocolo de texto `TELEGAME/1.0` sobre TCP.

## Requisitos en Linux Mint

Instalar herramientas de compilacion:

```bash
sudo apt update
sudo apt install build-essential make
```

El proyecto no usa librerias externas. Solo requiere GCC, Make y las cabeceras POSIX normales de Linux.

## Estructura

```text
.
├── Makefile
├── README.md
├── docs/
│   └── RFC-TELEGAME.md
├── scripts/
│   └── install_telegame_local.sh
├── src/
│   ├── client.c
│   └── server.c
└── tests/
    └── smoke_test.sh
```

## Compilar

Desde la carpeta del proyecto:

```bash
make
```

Esto genera:

```text
bin/telegame_server
bin/telegame_client
```

Para limpiar binarios:

```bash
make clean
```

## Ejecucion rapida en una sola computadora

Abre tres terminales en Linux Mint o en la terminal integrada de Visual Studio Code.

Terminal 1, servidor:

```bash
./bin/telegame_server --host 127.0.0.1 --port 5000
```

Terminal 2, jugador 1:

```bash
./bin/telegame_client --host 127.0.0.1 --port 5000 --name Alice
```

Terminal 3, jugador 2:

```bash
./bin/telegame_client --host 127.0.0.1 --port 5000 --name Bob
```

En ambos clientes escribe:

```text
QUEUE
```

El servidor crea la partida, asigna `X` y `O`, muestra participantes, tablero y turno actual.

## Ejecucion desde dos computadoras

En la computadora que sera servidor, revisa su IP:

```bash
ip addr
```

Ejemplo de IP: `192.168.1.50`.

Inicia el servidor escuchando en todas las interfaces:

```bash
./bin/telegame_server --host 0.0.0.0 --port 5000
```

Si el firewall esta activo:

```bash
sudo ufw allow 5000/tcp
```

En cada computadora cliente, usa la IP real del servidor:

```bash
./bin/telegame_client --host 192.168.1.50 --port 5000 --name Alice
./bin/telegame_client --host 192.168.1.50 --port 5000 --name Bob
```

Importante: `127.0.0.1` solo sirve para conectarse a la misma computadora. Para dos computadoras usa la IP LAN o VPN del servidor.

## Comandos del cliente

```text
HELP              Muestra comandos disponibles.
QUEUE             Entra a la cola de espera.
PLAYERS           Muestra participantes conectados y su estado.
SCORE             Muestra victorias, empates y derrotas.
BOARD             Muestra tablero y turno actual.
MOVE <1-9>        Marca una casilla si es tu turno.
QUIT              Sale del sistema o abandona la partida.
```

Las casillas del tablero son:

```text
1 | 2 | 3
---------
4 | 5 | 6
---------
7 | 8 | 9
```

## Demo sugerida para la defensa

1. Ejecutar `make`.
2. Iniciar el servidor con `./bin/telegame_server --host 127.0.0.1 --port 5000`.
3. Abrir dos clientes con nombres distintos.
4. Enviar `PLAYERS` para mostrar participantes conectados.
5. En ambos clientes enviar `QUEUE`.
6. Mostrar que el servidor asigna `X` y `O`.
7. Jugar movimientos con `MOVE <casilla>`.
8. Probar un error, por ejemplo que Bob juegue cuando el turno es de Alice.
9. Completar una partida y mostrar `RESULT WIN X Alice` o `RESULT DRAW`.
10. Al terminar, el servidor muestra automaticamente participantes en lobby y marcador.
11. Si quieren jugar otra vez, ambos jugadores escriben `QUEUE`.

Ejemplo donde gana `X`:

```text
Alice: QUEUE
Bob:   QUEUE
Alice recibe: MATCH 1 X Bob
Bob recibe:   MATCH 1 O Alice
Servidor:     TURN X Alice
Alice: MOVE 1
Bob:   MOVE 4
Alice: MOVE 2
Bob:   MOVE 5
Alice: MOVE 3
Servidor: RESULT WIN X Alice
Servidor: INFO PARTIDA FINALIZADA: los jugadores vuelven al lobby
Servidor: PLAYER Bob LOBBY
Servidor: PLAYER Alice LOBBY
Servidor: SCORE Bob 0 0 1
Servidor: SCORE Alice 1 0 0
```

## Pruebas

Ejecuta:

```bash
make test
```

La prueba compila el servidor y cliente, levanta el servidor localmente, conecta dos jugadores usando TCP, juega una partida y valida turno, tablero, ganador y marcador.
