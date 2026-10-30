AGDA ?= $(shell which agda 2>/dev/null || echo $(HOME)/.cabal/bin/agda)
export PATH := $(HOME)/.cabal/bin:$(HOME)/.ghcup/bin:/opt/homebrew/bin:/usr/local/bin:$(PATH)

BUILD_DIR := build
BIN_DIR := bin
TARGET := $(BIN_DIR)/Main
MAIN_SRC := exe/Main.agda
EARTH_TARGET := $(BIN_DIR)/Earth
EARTH_SRC := exe/Earth.agda

ELEVATION_DIR := data/cache/elevation
ELEVATION_STAMP := $(ELEVATION_DIR)/elevation_0.json
LAKE_DEPTHS := data/cache/lake_depths.json

.PHONY: all check typecheck test html run earth elevation clean

all: $(TARGET)

SRC_FILES := $(shell find src parsnip/src -name "*.agda" 2>/dev/null)

$(TARGET): $(MAIN_SRC) $(SRC_FILES)
	@mkdir -p $(BUILD_DIR) $(BIN_DIR)
	$(AGDA) --compile --compile-dir=$(BUILD_DIR) --ghc-flag=-O2 --ghc-flag=-o --ghc-flag=$(TARGET) $(MAIN_SRC)

$(EARTH_TARGET): $(EARTH_SRC) $(SRC_FILES)
	@mkdir -p $(BUILD_DIR)/earth $(BIN_DIR)
	$(AGDA) --compile --compile-dir=$(BUILD_DIR)/earth --ghc-flag=-O2 --ghc-flag=-o --ghc-flag=$(EARTH_TARGET) $(EARTH_SRC)

# Elevation bands vectorized from NOAA ETOPO 2022 (downloads ~470 MB on first use)
$(ELEVATION_STAMP): scripts/build_elevation_bands.py
	python3 scripts/build_elevation_bands.py $(ELEVATION_DIR)

elevation: $(ELEVATION_STAMP)

# Lake depth bands (needs the elevation grid downloaded by the rule above)
$(LAKE_DEPTHS): scripts/build_lake_depths.py $(ELEVATION_STAMP)
	python3 scripts/build_lake_depths.py $(LAKE_DEPTHS)

# Compose the earth-with-elevation map: bin/Earth [options] [data-dir [out.svg]]
earth: $(EARTH_TARGET) $(ELEVATION_STAMP) $(LAKE_DEPTHS)
	./$(EARTH_TARGET) --elevation-bands=$(ELEVATION_DIR) --lake-depths=$(LAKE_DEPTHS) --precision=0

check:
	$(AGDA) $(MAIN_SRC)

typecheck: check

# Typecheck every module under src/, including the tests.
test:
	bash make-everything.sh

# Typecheck every module under src/ and render highlighted HTML to html/.
html:
	@mkdir -p $(BUILD_DIR)
	@(echo "module Everything where"; for f in $$(find src -name '*.agda' | sort); do \
	    echo "import $$(echo $${f#src/} | sed -E 's#/#.#g; s#\.agda$$##')"; done) > $(BUILD_DIR)/Everything.agda
	$(AGDA) --html --html-dir=html -i $(BUILD_DIR) $(BUILD_DIR)/Everything.agda

run: $(TARGET)
	./$(TARGET)

clean:
	rm -rf $(BUILD_DIR) html $(TARGET) $(EARTH_TARGET)
