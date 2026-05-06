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
