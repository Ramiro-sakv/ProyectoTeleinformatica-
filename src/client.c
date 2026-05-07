#include <arpa/inet.h>
#include <errno.h>
#include <netdb.h>
#include <netinet/in.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <unistd.h>

#define DEFAULT_HOST "127.0.0.1"
#define DEFAULT_PORT 5000
#define BUFFER_SIZE 2048

static void render_board(const char *cells) {
    char values[9];
    for (int i = 0; i < 9; i++) {
        values[i] = cells[i] == '.' ? (char)('1' + i) : cells[i];
    }
    printf("\nTablero\n");
    printf(" %c | %c | %c\n", values[0], values[1], values[2]);
    printf("---+---+---\n");
    printf(" %c | %c | %c\n", values[3], values[4], values[5]);
    printf("---+---+---\n");
    printf(" %c | %c | %c\n\n", values[6], values[7], values[8]);
}

static void print_server_message(const char *message) {
    if (strncmp(message, "BOARD ", 6) == 0 && strlen(message + 6) >= 9) {
        render_board(message + 6);
    } else if (strncmp(message, "TURN ", 5) == 0) {
        printf("< Turno: %s\n", message + 5);
    } else if (strncmp(message, "MATCH ", 6) == 0) {
        printf("< Partida creada: %s\n", message + 6);
    } else if (strncmp(message, "RESULT WIN ", 11) == 0) {
        printf("< Ganador: %s\n", message + 11);
    } else if (strcmp(message, "RESULT DRAW") == 0) {
        printf("< Resultado: empate\n");
    } else if (strncmp(message, "PLAYER ", 7) == 0) {
        printf("< Participante: %s\n", message + 7);
    } else if (strncmp(message, "SCORE ", 6) == 0) {
        printf("< Marcador: %s\n", message + 6);
    } else {
        printf("< %s\n", message);
    }
    fflush(stdout);
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

static int connect_to_server(const char *host, int port) {
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    struct sockaddr_in server_addr;

    if (fd < 0) {
        perror("socket");
        exit(EXIT_FAILURE);
    }

    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons((uint16_t)port);
    if (inet_pton(AF_INET, host, &server_addr.sin_addr) <= 0) {
        fprintf(stderr, "Host invalido: %s\n", host);
        close(fd);
        exit(EXIT_FAILURE);
    }

    if (connect(fd, (struct sockaddr *)&server_addr, sizeof(server_addr)) < 0) {
        perror("connect");
        close(fd);
        exit(EXIT_FAILURE);
    }
    return fd;
}

static void process_received_data(char *buffer, size_t *buffer_len, const char *data, size_t data_len) {
    if (*buffer_len + data_len >= BUFFER_SIZE) {
        *buffer_len = 0;
    }

    memcpy(buffer + *buffer_len, data, data_len);
    *buffer_len += data_len;
    buffer[*buffer_len] = '\0';

    char *start = buffer;
    char *newline;
    while ((newline = strchr(start, '\n')) != NULL) {
        *newline = '\0';
        if (newline > start && *(newline - 1) == '\r') {
            *(newline - 1) = '\0';
        }
        print_server_message(start);
        start = newline + 1;
    }

    size_t remaining = strlen(start);
    memmove(buffer, start, remaining);
    *buffer_len = remaining;
    buffer[*buffer_len] = '\0';
}

static void print_usage(const char *program) {
    fprintf(stderr, "Uso: %s [--host IP] [--port PUERTO] [--name NOMBRE]\n", program);
}

int main(int argc, char **argv) {
    const char *host = DEFAULT_HOST;
    const char *name = NULL;
    int port = DEFAULT_PORT;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--host") == 0 && i + 1 < argc) {
            host = argv[++i];
        } else if (strcmp(argv[i], "--port") == 0 && i + 1 < argc) {
            port = atoi(argv[++i]);
        } else if (strcmp(argv[i], "--name") == 0 && i + 1 < argc) {
            name = argv[++i];
        } else {
            print_usage(argv[0]);
            return EXIT_FAILURE;
        }
    }

    int fd = connect_to_server(host, port);
    char receive_buffer[BUFFER_SIZE] = {0};
    size_t receive_len = 0;

    printf("Cliente conectado a %s:%d\n", host, port);
    printf("Comandos: HELP, QUEUE, PLAYERS, SCORE, BOARD, MOVE <1-9>, QUIT\n");
    if (name) {
        char hello[128];
        snprintf(hello, sizeof(hello), "HELLO %s\n", name);
        send_all(fd, hello);
    }

    while (1) {
        fd_set read_fds;
        int max_fd = fd > STDIN_FILENO ? fd : STDIN_FILENO;

        FD_ZERO(&read_fds);
        FD_SET(fd, &read_fds);
        FD_SET(STDIN_FILENO, &read_fds);

        if (select(max_fd + 1, &read_fds, NULL, NULL, NULL) < 0) {
            if (errno == EINTR) {
                continue;
            }
            perror("select");
            break;
        }

        if (FD_ISSET(fd, &read_fds)) {
            char chunk[512];
            ssize_t n = recv(fd, chunk, sizeof(chunk), 0);
            if (n <= 0) {
                printf("Servidor cerro la conexion\n");
                break;
            }
            process_received_data(receive_buffer, &receive_len, chunk, (size_t)n);
        }

        if (FD_ISSET(STDIN_FILENO, &read_fds)) {
            char line[512];
            if (!fgets(line, sizeof(line), stdin)) {
                break;
            }
            if (send_all(fd, line) < 0) {
                perror("send");
                break;
            }
            if (strncasecmp(line, "QUIT", 4) == 0) {
                break;
            }
        }
    }

    close(fd);
    return EXIT_SUCCESS;
}
