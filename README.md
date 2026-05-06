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

## Estructura

```text
.
├── README.md
├── docs/
│   └── RFC-TELEGAME.md
├── src/
│   ├── client.py
│   └── server.py
└── tests/
    └── smoke_test.py
```

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

## Demo sugerida

1. Ejecutar el servidor.
2. Conectar dos clientes.
3. En ambos clientes enviar `QUEUE`.
4. Mostrar que el servidor empareja jugadores.
5. Jugar turnos usando `MOVE <casilla>`.
6. Mostrar que el servidor rechaza movimientos inválidos o fuera de turno.
7. Finalizar una partida con victoria o empate.

## Pruebas

Compilar/verificar sintaxis:

```bash
python3 -m py_compile src/server.py src/client.py tests/smoke_test.py
```

Ejecutar prueba automática básica:

```bash
python3 tests/smoke_test.py
```
