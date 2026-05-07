# RFC-TELEGAME/1.0

## 1. Nombre del protocolo

`TELEGAME/1.0` es un protocolo de texto sobre TCP para conectar jugadores a un servidor maestro que administra partidas de tres en raya.

## 2. Objetivo

Permitir que n clientes se conecten dinamicamente a un servidor central. El servidor realiza el registro, lista participantes, administra una cola de espera, empareja jugadores, valida turnos, procesa movimientos y determina ganador, empate o abandono. No existe comunicacion directa cliente-cliente.

## 3. Transporte

- Transporte: TCP.
- Formato: texto terminado en salto de linea `\n`.
- Codificacion recomendada: UTF-8.
- Puerto sugerido para demo: `5000`.
- Prueba local: `127.0.0.1`.
- Red LAN o VPN: el servidor escucha en `0.0.0.0` y los clientes usan la IP real del servidor.

## 4. Arquitectura del servicio

```text
+-----------+        TCP         +---------------------+        TCP        +-----------+
| Cliente A | <----------------> | Servidor maestro    | <---------------> | Cliente B |
| Jugador X |                    | select + juego      |                   | Jugador O |
+-----------+                    +---------------------+                   +-----------+
                                      ^
                                      |
                                      | TCP
                                      |
                                  +-----------+
                                  | Cliente N |
                                  +-----------+
```

Responsabilidades del servidor:

1. Aceptar clientes nuevos con `accept`.
2. Atender multiples sockets con `select`.
3. Registrar nombres de jugadores.
4. Mantener participantes conectados y cola de espera.
5. Crear partidas 1 vs 1.
6. Validar turnos y movimientos.
7. Notificar tablero, turno, ganador, empate, marcador y abandono.

## 5. Estados del jugador

| Estado | Significado |
| --- | --- |
| `CONECTADO` | El cliente ya tiene conexion TCP, pero aun no envio `HELLO`. |
| `LOBBY` | El jugador esta registrado y puede entrar a cola. |
| `EN_COLA` | El jugador espera rival. |
| `EN_PARTIDA` | El jugador esta en una partida activa. |
| `DESCONECTADO` | El socket fue cerrado por salida, error o fin del servidor. |

## 6. Comandos del cliente

| Comando | Estado permitido | Descripcion |
| --- | --- | --- |
| `HELLO <nombre>` | `CONECTADO`, `LOBBY` | Registra o actualiza el nombre. Acepta letras, numeros y `_`, maximo 20 caracteres. |
| `HELP` | Cualquier estado | Lista comandos disponibles. |
| `QUEUE` | `LOBBY` | Ingresa a cola de espera. |
| `PLAYERS` | Cualquier estado | Lista participantes conectados y estado actual. Alias: `LIST`. |
| `SCORE` | Cualquier estado | Muestra victorias, empates y derrotas de jugadores registrados. |
| `BOARD` | `EN_PARTIDA` | Solicita tablero y turno actual. |
| `MOVE <1-9>` | `EN_PARTIDA` y turno propio | Intenta marcar una casilla. |
| `QUIT` | Cualquier estado | Cierra sesion o abandona partida. |

## 7. Respuestas del servidor

| Respuesta | Significado |
| --- | --- |
| `WELCOME TELEGAME/1.0 usa HELLO <nombre>` | Saludo inicial al conectar. |
| `OK <texto>` | Operacion aceptada. |
| `ERR <texto>` | Operacion rechazada. |
| `INFO <texto>` | Mensaje informativo. |
| `PLAYER <nombre> <estado>` | Participante conectado y estado. |
| `SCORE <nombre> <victorias> <empates> <derrotas>` | Marcador de un jugador. |
| `MATCH <id> <simbolo> <oponente>` | Partida creada para el jugador. |
| `BOARD <celdas>` | Tablero de 9 caracteres. `.` indica vacio. |
| `TURN <simbolo> <nombre>` | Indica simbolo y nombre del jugador con turno. |
| `RESULT WIN <simbolo> <nombre>` | Partida terminada con ganador. |
| `RESULT DRAW` | Partida terminada en empate. |
| `RESULT ABORT <texto>` | Partida terminada por abandono o desconexion. |
| `BYE <texto>` | Cierre normal de sesion. |

Despues de `RESULT WIN` o `RESULT DRAW`, el servidor envia automaticamente a ambos jugadores el estado de participantes (`PLAYER`), el marcador (`SCORE`) y una indicacion para volver a jugar con `QUEUE`.

## 8. Representacion del tablero

El servidor envia una cadena de 9 caracteres:

```text
BOARD X.O...X..
```

Equivalencia:

```text
1 | 2 | 3
---------
4 | 5 | 6
---------
7 | 8 | 9
```

Caracteres:

- `X`: marca del primer jugador emparejado.
- `O`: marca del segundo jugador emparejado.
- `.`: casilla vacia.

## 9. Automata de estados del jugador

```text
[DESCONECTADO]
      |
      | conexion TCP aceptada
      v
[CONECTADO]
      |
      | HELLO <nombre>
      v
[LOBBY] <--------------------------+
      |                            |
      | QUEUE                      | fin de partida
      v                            |
[EN_COLA]                          |
      | servidor encuentra rival   |
      v                            |
[EN_PARTIDA] ----------------------+
      |
      | QUIT / error / desconexion
      v
[DESCONECTADO]
```

## 10. Reglas del juego

1. Cada partida tiene dos jugadores.
2. El primer jugador que sale de la cola usa `X`.
3. El segundo jugador usa `O`.
4. Siempre inicia `X`.
5. Solo puede jugar el jugador indicado por `TURN`.
6. Un movimiento valido usa una casilla libre entre 1 y 9.
7. Gana quien completa fila, columna o diagonal.
8. Si se llenan las nueve casillas sin ganador, la partida termina en empate.
9. Al terminar una partida, ambos jugadores vuelven a `LOBBY`.
10. El marcador se conserva mientras el jugador siga conectado.

## 11. Servicio completo jugador-servidor

Ejemplo de partida:

```text
Servidor -> Alice: WELCOME TELEGAME/1.0 usa HELLO <nombre>
Alice    -> Servidor: HELLO Alice
Servidor -> Alice: OK registrado como Alice

Servidor -> Bob: WELCOME TELEGAME/1.0 usa HELLO <nombre>
Bob      -> Servidor: HELLO Bob
Servidor -> Bob: OK registrado como Bob

Alice -> Servidor: PLAYERS
Servidor -> Alice: INFO PARTICIPANTES conectados=2 en_cola=0 partidas=0
Servidor -> Alice: PLAYER Bob LOBBY
Servidor -> Alice: PLAYER Alice LOBBY

Alice -> Servidor: QUEUE
Bob   -> Servidor: QUEUE

Servidor -> Alice: MATCH 1 X Bob
Servidor -> Bob:   MATCH 1 O Alice
Servidor -> ambos: INFO PARTICIPANTES X=Alice O=Bob
Servidor -> ambos: BOARD .........
Servidor -> ambos: TURN X Alice

Alice -> Servidor: MOVE 1
Servidor -> ambos: BOARD X........
Servidor -> ambos: TURN O Bob

Bob -> Servidor: MOVE 4
Servidor -> ambos: BOARD X..O.....
Servidor -> ambos: TURN X Alice

Alice -> Servidor: MOVE 2
Bob   -> Servidor: MOVE 5
Alice -> Servidor: MOVE 3

Servidor -> ambos: BOARD XXXOO....
Servidor -> ambos: RESULT WIN X Alice
Servidor -> ambos: INFO PARTIDA FINALIZADA: los jugadores vuelven al lobby
Servidor -> ambos: INFO PARTICIPANTES conectados=2 en_cola=0 partidas=0
Servidor -> ambos: PLAYER Bob LOBBY
Servidor -> ambos: PLAYER Alice LOBBY
Servidor -> ambos: INFO MARCADOR
Servidor -> ambos: SCORE Bob 0 0 1
Servidor -> ambos: SCORE Alice 1 0 0
Servidor -> ambos: INFO Para jugar otra partida escribe QUEUE

Alice -> Servidor: SCORE
Servidor -> Alice: INFO MARCADOR
Servidor -> Alice: SCORE Bob 0 0 1
Servidor -> Alice: SCORE Alice 1 0 0
```

## 12. Errores esperados

```text
ERR primero debes registrarte con HELLO <nombre>
ERR ya estas en cola
ERR ya estas en una partida
ERR no estas en una partida
ERR no es tu turno
ERR uso: MOVE <1-9>
ERR casilla ocupada
ERR comando desconocido: <comando>
```

## 13. Seguridad y limites

- El servidor limita el tamano de linea recibida.
- El servidor valida nombres y movimientos.
- Si un jugador abandona, el rival recibe `RESULT ABORT`.
- No hay un numero maximo fijo de clientes en el codigo. El limite practico depende del sistema operativo, memoria y `FD_SETSIZE` usado por `select`.

## 14. Estructuras de datos de la implementacion

La implementacion principal esta en `src/server.c`.

### `struct Player`

Representa a un jugador conectado al servidor.

| Campo | Rol |
| --- | --- |
| `fd` | Descriptor del socket TCP asociado al cliente. |
| `address` | Direccion IP del cliente en texto. |
| `port` | Puerto remoto del cliente. |
| `name` | Nombre registrado con `HELLO`. |
| `registered` | Indica si el cliente ya completo su registro. |
| `buffer` | Buffer de recepcion para mensajes TCP incompletos. |
| `buffer_len` | Cantidad de bytes usados dentro del buffer. |
| `in_queue` | Indica si el jugador esta esperando rival. |
| `game_id` | Identificador de la partida activa; `0` si no esta jugando. |
| `symbol` | Simbolo asignado en la partida: `X`, `O` o vacio. |
| `wins`, `losses`, `draws` | Registro efimero de resultados mientras el servidor esta ejecutandose. |
| `next` | Enlace a la lista dinamica de jugadores conectados. |
| `queue_next` | Enlace a la cola dinamica de espera. |

### `struct Game`

Representa una partida 1 vs 1.

| Campo | Rol |
| --- | --- |
| `id` | Identificador incremental de la partida. |
| `x_player` | Jugador asignado al simbolo `X`. |
| `o_player` | Jugador asignado al simbolo `O`. |
| `board` | Tablero de 9 posiciones. |
| `turn` | Simbolo que debe jugar en el turno actual. |
| `next` | Enlace a la lista dinamica de partidas activas. |

## 15. Mapa de implementacion

| Requisito | Archivo y linea aproximada |
| --- | --- |
| Estructura dinamica de jugadores | `src/server.c`, desde linea 24 (`struct Player`). |
| Estructura de partidas | `src/server.c`, desde linea 42 (`struct Game`). |
| Cola de espera | `src/server.c`, lineas 156 y 168 (`enqueue_player`, `dequeue_player`). |
| Multiplexacion con `select` | `src/server.c`, linea 702. |
| Aceptar conexiones | `src/server.c`, linea 597 (`accept_player`). |
| Registro con `HELLO` | `src/server.c`, linea 359 (`handle_hello`). |
| Interpretacion de comandos | `src/server.c`, linea 492 (`handle_command`). |
| Recepcion de mensajes TCP | `src/server.c`, linea 555 (`receive_from_player`). |
| Envio de respuestas | `src/server.c`, linea 80 (`send_line`). |
| Listado de jugadores | `src/server.c`, linea 287 (`send_players_to`). |
| Marcador | `src/server.c`, linea 277 (`send_score_to`). |
| Creacion de partida | `src/server.c`, linea 306 (`create_match`). |
| Validacion de movimientos | `src/server.c`, linea 400 (`handle_move`). |
| Cliente: lectura de mensajes del servidor | `src/client.c`, linea 95 (`process_received_data`). |
| Cliente: interpretacion visual de respuestas | `src/client.c`, linea 31 (`print_server_message`). |
| Cliente: multiplexacion teclado/socket | `src/client.c`, linea 163 (`select`). |

Los numeros pueden cambiar si el codigo se edita, pero los nombres de funciones se mantienen como referencia principal.

## 16. Elementos investigados

Estos elementos pertenecen a la API POSIX de sockets en Linux:

- `socket(2)`: crea un endpoint TCP.
- `setsockopt(2)`: configura opciones del socket, por ejemplo `SO_REUSEADDR`.
- `bind(2)`: asocia el servidor a una IP y puerto.
- `listen(2)`: pone el socket del servidor en modo escucha.
- `accept(2)`: acepta una conexion entrante.
- `select(2)`: permite atender varios descriptores sin `fork` ni `pthread`.
- `recv(2)`: recibe bytes enviados por un cliente.
- `send(2)`: envia bytes hacia un cliente.
- `inet_pton(3)` e `inet_ntop(3)`: convierten direcciones IP entre texto y formato binario.

Referencias consultables en Linux Mint:

```bash
man 2 socket
man 2 bind
man 2 listen
man 2 accept
man 2 select
man 2 recv
man 2 send
man 3 inet_pton
```
