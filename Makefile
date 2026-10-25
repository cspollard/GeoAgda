AGDA ?= $(shell which agda 2>/dev/null || echo $(HOME)/.cabal/bin/agda)
export PATH := $(HOME)/.cabal/bin:$(HOME)/.ghcup/bin:/opt/homebrew/bin:/usr/local/bin:$(PATH)

BUILD_DIR := build
BIN_DIR := bin
TARGET := $(BIN_DIR)/Main
MAIN_SRC := exe/Main.agda

.PHONY: all check typecheck test run clean

all: $(TARGET)

SRC_FILES := $(shell find src parsnip/src -name "*.agda" 2>/dev/null)

$(TARGET): $(MAIN_SRC) $(SRC_FILES)
	@mkdir -p $(BUILD_DIR) $(BIN_DIR)
	$(AGDA) --compile --compile-dir=$(BUILD_DIR) --ghc-flag=-O2 --ghc-flag=-o --ghc-flag=$(TARGET) $(MAIN_SRC)

check:
	$(AGDA) $(MAIN_SRC)

typecheck: check

# Typecheck every module under src/, including the tests.
test:
	bash make-everything.sh

run: $(TARGET)
	./$(TARGET)

clean:
	rm -rf $(BUILD_DIR) $(TARGET)
