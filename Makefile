CC := gcc
CFLAGS := -std=c11 -Wall -Wextra -pedantic -O2
BIN_DIR := bin

.PHONY: all clean test

all: $(BIN_DIR)/telegame_server $(BIN_DIR)/telegame_client

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

$(BIN_DIR)/telegame_server: src/server.c | $(BIN_DIR)
	$(CC) $(CFLAGS) -o $@ $<

$(BIN_DIR)/telegame_client: src/client.c | $(BIN_DIR)
	$(CC) $(CFLAGS) -o $@ $<

test: all
	bash tests/smoke_test.sh

clean:
	rm -rf $(BIN_DIR)
