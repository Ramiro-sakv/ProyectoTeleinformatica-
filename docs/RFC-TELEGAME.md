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
