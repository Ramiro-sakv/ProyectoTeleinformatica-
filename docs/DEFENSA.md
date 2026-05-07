# Guia de defensa

Este documento resume que explicar durante la defensa del proyecto Telegame.

## 1. Servicio implementado

Telegame implementa un servicio cliente-servidor para un juego en red. El servidor central mantiene los jugadores conectados, registra su participacion, administra una cola de espera, crea partidas 1 vs 1 y controla toda la logica del tres en raya.

Los clientes no se comunican directamente entre si. Cada cliente envia comandos al servidor y el servidor responde con mensajes definidos por el protocolo `TELEGAME/1.0`.

## 2. Logica del juego

El juego elegido es tres en raya porque permite demostrar turnos, validacion de movimientos, ganador y empate sin complicar demasiado la parte de red.

Reglas principales:

- La partida tiene dos jugadores.
- El primer jugador emparejado usa `X`.
- El segundo jugador usa `O`.
- Siempre empieza `X`.
- El servidor rechaza movimientos fuera de turno.
- El servidor rechaza casillas ocupadas o posiciones fuera de `1-9`.
- Gana quien completa fila, columna o diagonal.
- Si se llena el tablero sin ganador, hay empate.

## 3. Protocolo

El protocolo esta documentado en `docs/RFC-TELEGAME.md`.

Comandos principales:

| Comando | Uso |
| --- | --- |
| `HELLO <nombre>` | Registra al jugador. |
| `HELP` | Muestra comandos. |
| `QUEUE` | Entra a cola para jugar. |
| `PLAYERS` | Lista participantes conectados. |
| `SCORE` | Muestra victorias, empates y derrotas. |
| `BOARD` | Muestra tablero y turno. |
| `MOVE <1-9>` | Realiza una jugada. |
| `QUIT` | Sale del sistema o abandona partida. |

Respuestas importantes:

| Respuesta | Significado |
| --- | --- |
| `WELCOME` | El servidor acepto la conexion. |
| `OK` | Operacion aceptada. |
| `ERR` | Operacion rechazada. |
| `PLAYER` | Participante y estado. |
| `SCORE` | Marcador. |
| `MATCH` | Partida creada. |
| `BOARD` | Estado del tablero. |
| `TURN` | Turno actual. |
| `RESULT WIN` | Ganador. |
| `RESULT DRAW` | Empate. |
| `RESULT ABORT` | Partida abortada. |

## 4. Estructuras de datos

### `struct Player`

Esta estructura representa a cada cliente conectado. Guarda el socket, IP, puerto, nombre, estado de registro, buffer de entrada, estado de cola, partida actual, simbolo, marcador y punteros para listas dinamicas.

Campos clave:

- `fd`: socket del cliente.
- `name`: nombre del jugador.
- `registered`: indica si ya se registro.
- `buffer` y `buffer_len`: guardan mensajes recibidos por TCP hasta encontrar `\n`.
- `in_queue`: indica si esta esperando rival.
- `game_id`: indica si esta en partida.
- `symbol`: `X` u `O`.
- `wins`, `losses`, `draws`: registro efimero de participacion.
- `next`: lista de jugadores conectados.
- `queue_next`: cola de espera.

### `struct Game`

Esta estructura representa una partida activa.

Campos clave:

- `id`: identificador de partida.
- `x_player`: jugador con `X`.
- `o_player`: jugador con `O`.
- `board`: tablero de 9 posiciones.
- `turn`: turno actual.
- `next`: lista de partidas activas.

## 5. Organizacion de jugadores y cola

El servidor usa una lista enlazada para los jugadores conectados. Esto cumple el requisito de no tener un numero maximo fijo de jugadores definido por el codigo.

La cola de espera tambien es dinamica. Cuando un jugador envia `QUEUE`, entra a la cola. Cuando hay dos jugadores esperando, el servidor los saca de la cola y crea una partida con `create_match`.

## 6. Multiplexacion con `select`

El servidor no usa `fork` ni `pthread`. Usa `select` para vigilar al mismo tiempo:

- el socket del servidor, para aceptar nuevas conexiones;
- los sockets de todos los clientes, para recibir comandos.

Cuando `select` indica actividad en el socket del servidor, se ejecuta `accept_player`. Cuando indica actividad en un cliente, se ejecuta `receive_from_player`.

## 7. Intercambio de mensajes

Flujo general:

1. El cliente se conecta por TCP.
2. El servidor responde `WELCOME`.
3. El cliente envia `HELLO <nombre>`.
4. El servidor registra al jugador y responde `OK`.
5. El cliente puede pedir `PLAYERS`, `SCORE` o entrar con `QUEUE`.
6. Cuando dos jugadores estan en cola, el servidor crea una partida.
7. Cada `MOVE` es validado por el servidor.
8. El servidor responde con `BOARD`, `TURN` o `RESULT`.

El servidor imprime en consola mensajes de recepcion y envio con prefijos:

```text
[RX <- Ramiro] MOVE 5
[TX -> Paulo] TURN O Paulo
```

Esto permite demostrar el intercambio de mensajes durante la partida.

## 8. Demo recomendada

Usar cuatro terminales:

1. Servidor.
2. Cliente Ramiro.
3. Cliente Paulo.
4. Cliente Carla.

Comandos:

```bash
make clean
make
./bin/telegame_server --host 127.0.0.1 --port 5000
./bin/telegame_client --host 127.0.0.1 --port 5000 --name Ramiro
./bin/telegame_client --host 127.0.0.1 --port 5000 --name Paulo
./bin/telegame_client --host 127.0.0.1 --port 5000 --name Carla
```

Durante la demo:

1. En Carla escribir `PLAYERS` para mostrar tres clientes.
2. En Ramiro y Paulo escribir `QUEUE`.
3. Intentar una jugada fuera de turno para mostrar `ERR no es tu turno`.
4. Completar una partida.
5. Mostrar `RESULT WIN` o `RESULT DRAW`.
6. Mostrar que al finalizar todos vuelven a `LOBBY` y aparece el marcador.

## 9. Lineas importantes

| Tema | Ubicacion |
| --- | --- |
| `struct Player` | `src/server.c`, cerca de la linea 24. |
| `struct Game` | `src/server.c`, cerca de la linea 42. |
| Cola de espera | `src/server.c`, `enqueue_player` y `dequeue_player`. |
| `select` del servidor | `src/server.c`, ciclo principal. |
| Recepcion de comandos | `src/server.c`, `receive_from_player`. |
| Interpretacion de comandos | `src/server.c`, `handle_command`. |
| Envio de respuestas | `src/server.c`, `send_line`. |
| Validacion de jugadas | `src/server.c`, `handle_move`. |
| Cliente | `src/client.c`. |

## 10. Conclusiones tecnicas

- El protocolo de texto facilita la prueba desde terminal y la explicacion en defensa.
- `select` permite manejar varios clientes sin crear procesos ni hilos.
- El servidor central mantiene control completo del juego, lo que evita inconsistencias entre clientes.
- La cola dinamica permite agregar mas jugadores sin cambiar un limite fijo en el codigo.
- Separar comandos y respuestas hace que el cliente y el servidor sean mas faciles de explicar.
