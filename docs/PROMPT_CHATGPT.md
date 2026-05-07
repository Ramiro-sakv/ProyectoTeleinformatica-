# Prompt para pedir ayuda a ChatGPT

Copia y pega este prompt en tu otro chat de ChatGPT. Sirve para que te ayude a redactar la parte personal de IA, conclusiones y practica de defensa sin inventar datos tecnicos.

```text
Estoy preparando la defensa final de mi proyecto de Teleinformatica.

Contexto del proyecto:
- Nombre: Telegame.
- Lenguaje: C.
- Sistema: Linux Mint.
- Arquitectura: cliente-servidor.
- El servidor central usa sockets TCP y select(2), no usa fork ni pthreads.
- El servidor permite n clientes dinamicos usando estructuras enlazadas.
- Los jugadores se registran con HELLO <nombre>.
- Pueden pedir PLAYERS, SCORE, BOARD, entrar a cola con QUEUE, jugar con MOVE <1-9> y salir con QUIT.
- El juego implementado es tres en raya 1 vs 1.
- El servidor administra todo: cola, participantes, turnos, movimientos, tablero, ganador, empate, abandono y marcador efimero.
- Existe documentacion RFC en docs/RFC-TELEGAME.md.
- Existe una guia tecnica en docs/DEFENSA.md.

Mi docente pide una seccion de "IA y Conclusiones" con:
1. Indicar que herramienta/plataforma de IA utilice y si fue gratuita o de pago.
2. Evaluar la pertinencia y correctitud de los aportes realizados por la IA.
3. Elaborar un punteo con conclusiones del desarrollo.
4. Describir los principales aprendizajes alcanzados.

Quiero que me ayudes a redactar esa seccion en primera persona, con lenguaje natural de estudiante, sin sonar exagerado ni falso.

Datos que debes preguntarme antes de redactar:
- Que IA use exactamente.
- Si fue gratuita o de pago.
- Que partes me ayudo a hacer la IA.
- Que partes revise o entendi personalmente.
- Que aprendi de sockets, select, protocolo y estructuras.

Luego quiero que generes:
1. Una version corta para poner en un .md.
2. Una version oral para decirla en la defensa.
3. Cinco preguntas que podria hacerme el docente y respuestas sugeridas.

Importante:
- No digas que la IA hizo todo sola.
- No inventes que use herramientas que no mencione.
- No uses palabras demasiado tecnicas si no son necesarias.
- Manten el texto honesto: la IA ayudo, pero yo debo explicar y defender el codigo.
```

## Prompt extra para practicar defensa

```text
Actua como docente de Teleinformatica. Hazme preguntas de defensa sobre mi proyecto Telegame en C.

Evalua estos temas:
- arquitectura cliente-servidor;
- por que se usa select;
- que hace struct Player;
- que hace struct Game;
- como funciona la cola de espera;
- como se interpreta un comando recibido;
- como se responde al cliente;
- como se valida una jugada;
- que pasa cuando gana un jugador;
- que pasa si un cliente se desconecta;
- que significa que el registro sea efimero;
- diferencias entre 127.0.0.1 y 0.0.0.0.

Hazme una pregunta a la vez. Espera mi respuesta, corrige si esta mal y dame una version mejorada.
```
