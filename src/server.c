#include <arpa/inet.h>
#include <ctype.h>
#include <errno.h>
#include <netinet/in.h>
#include <signal.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <unistd.h>

#define DEFAULT_HOST "0.0.0.0"
#define DEFAULT_PORT 5000
#define MAX_LINE 1024
#define NAME_SIZE 21
#define BOARD_SIZE 9

typedef struct Player Player;
typedef struct Game Game;

struct Player {
    int fd;
    char address[64];
    int port;
    char name[NAME_SIZE];
    int registered;
    char buffer[MAX_LINE * 2];
    size_t buffer_len;
    int in_queue;
    int game_id;
    char symbol;
    int wins;
    int losses;
    int draws;
    Player *next;
    Player *queue_next;
};

struct Game {
    int id;
    Player *x_player;
    Player *o_player;
    char board[BOARD_SIZE + 1];
    char turn;
    Game *next;
};

static Player *players = NULL;
static Player *queue_head = NULL;
static Player *queue_tail = NULL;
static Game *games = NULL;
static int next_game_id = 1;
static volatile sig_atomic_t running = 1;

static void stop_server(int signal_number) {
    (void)signal_number;
    running = 0;
}

static int send_all(int fd, const char *message) {
    size_t sent = 0;
    size_t length = strlen(message);

    while (sent < length) {
        ssize_t n = send(fd, message + sent, length - sent, 0);
        if (n < 0) {
            if (errno == EINTR) {
                continue;
            }
            return -1;
        }
        sent += (size_t)n;
    }
    return 0;
}

static int send_line(Player *player, const char *format, ...) {
    char line[1400];
    va_list args;

    va_start(args, format);
    vsnprintf(line, sizeof(line), format, args);
    va_end(args);

    printf("[TX -> %s] %s\n", player->registered ? player->name : player->address, line);
    fflush(stdout);

    strncat(line, "\n", sizeof(line) - strlen(line) - 1);
    return send_all(player->fd, line);
}

static int count_players(void) {
    int total = 0;
    for (Player *player = players; player; player = player->next) {
        total++;
    }
    return total;
}

static int count_queue(void) {
    int total = 0;
    for (Player *player = queue_head; player; player = player->queue_next) {
        total++;
    }
    return total;
}

static int count_games(void) {
    int total = 0;
    for (Game *game = games; game; game = game->next) {
        total++;
    }
    return total;
}

static const char *player_display_name(Player *player) {
    return player->registered ? player->name : "sin_nombre";
}

static const char *player_state(Player *player) {
    if (player->game_id != 0) {
        return "EN_PARTIDA";
    }
    if (player->in_queue) {
        return "EN_COLA";
    }
    if (player->registered) {
        return "LOBBY";
    }
    return "CONECTADO";
}

static void remove_from_queue(Player *target) {
    Player *previous = NULL;
    Player *current = queue_head;

    while (current) {
        if (current == target) {
            if (previous) {
                previous->queue_next = current->queue_next;
            } else {
                queue_head = current->queue_next;
            }
            if (queue_tail == current) {
                queue_tail = previous;
            }
            current->queue_next = NULL;
            current->in_queue = 0;
            return;
        }
        previous = current;
        current = current->queue_next;
    }
}

static void enqueue_player(Player *player) {
    player->queue_next = NULL;
    player->in_queue = 1;
    if (!queue_tail) {
        queue_head = player;
        queue_tail = player;
        return;
    }
    queue_tail->queue_next = player;
    queue_tail = player;
}

static Player *dequeue_player(void) {
    Player *player = queue_head;
    if (!player) {
        return NULL;
    }
    queue_head = player->queue_next;
    if (!queue_head) {
        queue_tail = NULL;
    }
    player->queue_next = NULL;
    player->in_queue = 0;
    return player;
}

static Game *find_game(int game_id) {
    for (Game *game = games; game; game = game->next) {
        if (game->id == game_id) {
            return game;
        }
    }
    return NULL;
}

static Game *game_for_player(Player *player) {
    if (player->game_id == 0) {
        return NULL;
    }
    return find_game(player->game_id);
}

static Player *opponent_of(Game *game, Player *player) {
    return player == game->x_player ? game->o_player : game->x_player;
}

static Player *player_for_symbol(Game *game, char symbol) {
    return symbol == 'X' ? game->x_player : game->o_player;
}

static void broadcast_game(Game *game, const char *format, ...) {
    char message[1200];
    va_list args;

    va_start(args, format);
    vsnprintf(message, sizeof(message), format, args);
    va_end(args);

    send_line(game->x_player, "%s", message);
    send_line(game->o_player, "%s", message);
}

static char winner_of(Game *game) {
    static const int lines[8][3] = {
        {0, 1, 2}, {3, 4, 5}, {6, 7, 8},
        {0, 3, 6}, {1, 4, 7}, {2, 5, 8},
        {0, 4, 8}, {2, 4, 6}
    };

    for (int i = 0; i < 8; i++) {
        int a = lines[i][0];
        int b = lines[i][1];
        int c = lines[i][2];
        if (game->board[a] != '.' &&
            game->board[a] == game->board[b] &&
            game->board[b] == game->board[c]) {
            return game->board[a];
        }
    }
    return '\0';
}

static int is_draw(Game *game) {
    if (winner_of(game)) {
        return 0;
    }
    for (int i = 0; i < BOARD_SIZE; i++) {
        if (game->board[i] == '.') {
            return 0;
        }
    }
    return 1;
}

static void remove_game(Game *target) {
    Game *previous = NULL;
    Game *current = games;

    while (current) {
        if (current == target) {
            if (previous) {
                previous->next = current->next;
            } else {
                games = current->next;
            }
            free(current);
            return;
        }
        previous = current;
        current = current->next;
    }
}

static void finish_game(Game *game) {
    game->x_player->game_id = 0;
    game->x_player->symbol = '\0';
    game->o_player->game_id = 0;
    game->o_player->symbol = '\0';
    remove_game(game);
}

static void send_score_to(Player *receiver) {
    send_line(receiver, "INFO MARCADOR");
    for (Player *player = players; player; player = player->next) {
        if (player->registered) {
            send_line(receiver, "SCORE %s %d %d %d",
                      player->name, player->wins, player->draws, player->losses);
        }
    }
}

static void send_players_to(Player *receiver) {
    send_line(receiver, "INFO PARTICIPANTES conectados=%d en_cola=%d partidas=%d",
              count_players(), count_queue(), count_games());
    for (Player *player = players; player; player = player->next) {
        send_line(receiver, "PLAYER %s %s", player_display_name(player), player_state(player));
    }
}

static void send_post_game_status(Player *x_player, Player *o_player) {
    Player *receivers[2] = {x_player, o_player};

    for (int i = 0; i < 2; i++) {
        send_line(receivers[i], "INFO PARTIDA FINALIZADA: los jugadores vuelven al lobby");
        send_players_to(receivers[i]);
        send_score_to(receivers[i]);
        send_line(receivers[i], "INFO Para jugar otra partida escribe QUEUE");
    }
}

static void create_match(Player *x_player, Player *o_player) {
    Game *game = calloc(1, sizeof(*game));
    if (!game) {
        send_line(x_player, "ERR sin memoria para crear partida");
        send_line(o_player, "ERR sin memoria para crear partida");
        return;
    }

    game->id = next_game_id++;
    game->x_player = x_player;
    game->o_player = o_player;
    memset(game->board, '.', BOARD_SIZE);
    game->board[BOARD_SIZE] = '\0';
    game->turn = 'X';
    game->next = games;
    games = game;

    x_player->game_id = game->id;
    o_player->game_id = game->id;
    x_player->symbol = 'X';
    o_player->symbol = 'O';

    send_line(x_player, "MATCH %d X %s", game->id, o_player->name);
    send_line(o_player, "MATCH %d O %s", game->id, x_player->name);
    broadcast_game(game, "INFO PARTICIPANTES X=%s O=%s", x_player->name, o_player->name);
    broadcast_game(game, "BOARD %s", game->board);
    broadcast_game(game, "TURN X %s", x_player->name);

    printf("Partida %d creada: X=%s O=%s\n", game->id, x_player->name, o_player->name);
    fflush(stdout);
}

static void try_match_players(void) {
    while (queue_head && queue_head->queue_next) {
        Player *x_player = dequeue_player();
        Player *o_player = dequeue_player();
        create_match(x_player, o_player);
    }
}

static int valid_name(const char *name) {
    size_t length = strlen(name);
    if (length == 0 || length >= NAME_SIZE) {
        return 0;
    }
    for (size_t i = 0; i < length; i++) {
        if (!isalnum((unsigned char)name[i]) && name[i] != '_') {
            return 0;
        }
    }
    return 1;
}

static void handle_hello(Player *player, char *argument) {
    while (*argument == ' ') {
        argument++;
    }
    if (!valid_name(argument)) {
        send_line(player, "ERR nombre invalido: usa letras, numeros o _ hasta 20 caracteres");
        return;
    }
    snprintf(player->name, sizeof(player->name), "%s", argument);
    player->registered = 1;
    send_line(player, "OK registrado como %s", player->name);
}

static void handle_queue(Player *player) {
    if (!player->registered) {
        send_line(player, "ERR primero debes registrarte con HELLO <nombre>");
        return;
    }
    if (player->game_id != 0) {
        send_line(player, "ERR ya estas en una partida");
        return;
    }
    if (player->in_queue) {
        send_line(player, "ERR ya estas en cola");
        return;
    }
    enqueue_player(player);
    send_line(player, "OK en cola de espera");
    try_match_players();
}

static void handle_board(Player *player) {
    Game *game = game_for_player(player);
    if (!game) {
        send_line(player, "ERR no estas en una partida");
        return;
    }
    send_line(player, "BOARD %s", game->board);
    send_line(player, "TURN %c %s", game->turn, player_for_symbol(game, game->turn)->name);
}

static void handle_move(Player *player, char *argument) {
    Game *game = game_for_player(player);
    int position;
    char winner;

    if (!game) {
        send_line(player, "ERR no estas en una partida");
        return;
    }
    if (player->symbol != game->turn) {
        send_line(player, "ERR no es tu turno");
        return;
    }
    if (sscanf(argument, "%d", &position) != 1 || position < 1 || position > 9) {
        send_line(player, "ERR uso: MOVE <1-9>");
        return;
    }
    if (game->board[position - 1] != '.') {
        send_line(player, "ERR casilla ocupada");
        return;
    }

    game->board[position - 1] = player->symbol;
    printf("Partida %d: %s juega %c en casilla %d\n",
           game->id, player->name, player->symbol, position);
    fflush(stdout);

    broadcast_game(game, "BOARD %s", game->board);
    winner = winner_of(game);
    if (winner) {
        Player *x_player = game->x_player;
        Player *o_player = game->o_player;
        Player *winner_player = player_for_symbol(game, winner);
        Player *loser_player = opponent_of(game, winner_player);
        winner_player->wins++;
        loser_player->losses++;
        broadcast_game(game, "RESULT WIN %c %s", winner, winner_player->name);
        printf("Partida %d terminada: ganador %s (%c)\n",
               game->id, winner_player->name, winner);
        fflush(stdout);
        finish_game(game);
        send_post_game_status(x_player, o_player);
        return;
    }
    if (is_draw(game)) {
        Player *x_player = game->x_player;
        Player *o_player = game->o_player;
        game->x_player->draws++;
        game->o_player->draws++;
        broadcast_game(game, "RESULT DRAW");
        printf("Partida %d terminada: empate\n", game->id);
        fflush(stdout);
        finish_game(game);
        send_post_game_status(x_player, o_player);
        return;
    }

    game->turn = game->turn == 'X' ? 'O' : 'X';
    broadcast_game(game, "TURN %c %s", game->turn, player_for_symbol(game, game->turn)->name);
}

static void disconnect_player(Player *target, const char *reason) {
    Player *previous = NULL;
    Player *current = players;
    Game *game = game_for_player(target);

    if (game) {
        Player *opponent = opponent_of(game, target);
        send_line(opponent, "RESULT ABORT %s abandono la partida", player_display_name(target));
        finish_game(game);
    }

    remove_from_queue(target);

    while (current) {
        if (current == target) {
            if (previous) {
                previous->next = current->next;
            } else {
                players = current->next;
            }
            printf("Desconexion %s:%d (%s)\n", target->address, target->port, reason);
            fflush(stdout);
            close(target->fd);
            free(target);
            return;
        }
        previous = current;
        current = current->next;
    }
}

static int handle_command(Player *player, char *line) {
    char *command = line;
    char *argument;

    while (isspace((unsigned char)*command)) {
        command++;
    }
    if (*command == '\0') {
        return 1;
    }
    argument = command;
    while (*argument && !isspace((unsigned char)*argument)) {
        argument++;
    }
    if (*argument) {
        *argument = '\0';
        argument++;
        while (isspace((unsigned char)*argument)) {
            argument++;
        }
    } else {
        argument = "";
    }

    for (char *p = command; *p; p++) {
        *p = (char)toupper((unsigned char)*p);
    }

    if (strcmp(command, "HELLO") == 0) {
        handle_hello(player, argument);
    } else if (strcmp(command, "HELP") == 0) {
        send_line(player, "INFO comandos: HELLO <nombre>, QUEUE, PLAYERS, SCORE, BOARD, MOVE <1-9>, QUIT");
    } else if (strcmp(command, "QUEUE") == 0) {
        handle_queue(player);
    } else if (strcmp(command, "PLAYERS") == 0 || strcmp(command, "LIST") == 0) {
        send_players_to(player);
    } else if (strcmp(command, "SCORE") == 0) {
        send_score_to(player);
    } else if (strcmp(command, "BOARD") == 0) {
        handle_board(player);
    } else if (strcmp(command, "MOVE") == 0) {
        handle_move(player, argument);
    } else if (strcmp(command, "QUIT") == 0) {
        send_line(player, "BYE hasta luego");
        disconnect_player(player, "salida voluntaria");
        return 0;
    } else {
        send_line(player, "ERR comando desconocido: %s", command);
    }
    return 1;
}

static int process_player_line(Player *player, char *line) {
    size_t length = strlen(line);
    while (length > 0 && (line[length - 1] == '\n' || line[length - 1] == '\r')) {
        line[--length] = '\0';
    }
    if (length > 0) {
        printf("[RX <- %s] %s\n", player->registered ? player->name : player->address, line);
        fflush(stdout);
        return handle_command(player, line);
    }
    return 1;
}

static void receive_from_player(Player *player) {
    char chunk[512];
    ssize_t received = recv(player->fd, chunk, sizeof(chunk), 0);

    if (received <= 0) {
        disconnect_player(player, received == 0 ? "cliente desconectado" : "error de recepcion");
        return;
    }
    if (player->buffer_len + (size_t)received >= sizeof(player->buffer)) {
        send_line(player, "ERR linea demasiado larga");
        disconnect_player(player, "buffer excedido");
        return;
    }

    memcpy(player->buffer + player->buffer_len, chunk, (size_t)received);
    player->buffer_len += (size_t)received;
    player->buffer[player->buffer_len] = '\0';

    char *start = player->buffer;
    char *newline;
    while ((newline = strchr(start, '\n')) != NULL) {
        char line[MAX_LINE + 1];
        size_t line_length = (size_t)(newline - start);
        if (line_length > MAX_LINE) {
            send_line(player, "ERR linea demasiado larga");
            start = newline + 1;
            continue;
        }
        memcpy(line, start, line_length);
        line[line_length] = '\0';
        if (!process_player_line(player, line)) {
            return;
        }
        start = newline + 1;
    }

    size_t remaining = strlen(start);
    memmove(player->buffer, start, remaining);
    player->buffer_len = remaining;
    player->buffer[player->buffer_len] = '\0';
}

static void accept_player(int server_fd) {
    struct sockaddr_in client_addr;
    socklen_t client_len = sizeof(client_addr);
    int client_fd = accept(server_fd, (struct sockaddr *)&client_addr, &client_len);
    if (client_fd < 0) {
        perror("accept");
        return;
    }

    Player *player = calloc(1, sizeof(*player));
    if (!player) {
        close(client_fd);
        return;
    }

    player->fd = client_fd;
    inet_ntop(AF_INET, &client_addr.sin_addr, player->address, sizeof(player->address));
    player->port = ntohs(client_addr.sin_port);
    player->next = players;
    players = player;

    send_line(player, "WELCOME TELEGAME/1.0 usa HELLO <nombre>");
    printf("Conexion aceptada desde %s:%d\n", player->address, player->port);
    fflush(stdout);
}

static int create_server_socket(const char *host, int port) {
    int server_fd = socket(AF_INET, SOCK_STREAM, 0);
    int enabled = 1;
    struct sockaddr_in server_addr;

    if (server_fd < 0) {
        perror("socket");
        exit(EXIT_FAILURE);
    }

    if (setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &enabled, sizeof(enabled)) < 0) {
        perror("setsockopt");
        close(server_fd);
        exit(EXIT_FAILURE);
    }

    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons((uint16_t)port);
    if (inet_pton(AF_INET, host, &server_addr.sin_addr) <= 0) {
        fprintf(stderr, "Host invalido: %s\n", host);
        close(server_fd);
        exit(EXIT_FAILURE);
    }

    if (bind(server_fd, (struct sockaddr *)&server_addr, sizeof(server_addr)) < 0) {
        perror("bind");
        close(server_fd);
        exit(EXIT_FAILURE);
    }
    if (listen(server_fd, SOMAXCONN) < 0) {
        perror("listen");
        close(server_fd);
        exit(EXIT_FAILURE);
    }
    return server_fd;
}

static void print_usage(const char *program) {
    fprintf(stderr, "Uso: %s [--host IP] [--port PUERTO]\n", program);
}

int main(int argc, char **argv) {
    const char *host = DEFAULT_HOST;
    int port = DEFAULT_PORT;
    int server_fd;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--host") == 0 && i + 1 < argc) {
            host = argv[++i];
        } else if (strcmp(argv[i], "--port") == 0 && i + 1 < argc) {
            port = atoi(argv[++i]);
        } else {
            print_usage(argv[0]);
            return EXIT_FAILURE;
        }
    }

    signal(SIGINT, stop_server);
    signal(SIGTERM, stop_server);
    signal(SIGPIPE, SIG_IGN);

    server_fd = create_server_socket(host, port);
    printf("Servidor TELEGAME escuchando en %s:%d\n", host, port);
    fflush(stdout);

    while (running) {
        fd_set read_fds;
        int max_fd = server_fd;

        FD_ZERO(&read_fds);
        FD_SET(server_fd, &read_fds);
        for (Player *player = players; player; player = player->next) {
            FD_SET(player->fd, &read_fds);
            if (player->fd > max_fd) {
                max_fd = player->fd;
            }
        }

        if (select(max_fd + 1, &read_fds, NULL, NULL, NULL) < 0) {
            if (errno == EINTR) {
                continue;
            }
            perror("select");
            break;
        }

        if (FD_ISSET(server_fd, &read_fds)) {
            accept_player(server_fd);
        }

        for (Player *player = players; player;) {
            Player *next = player->next;
            if (FD_ISSET(player->fd, &read_fds)) {
                receive_from_player(player);
            }
            player = next;
        }
    }

    close(server_fd);
    while (players) {
        disconnect_player(players, "apagado del servidor");
    }
    return EXIT_SUCCESS;
}
