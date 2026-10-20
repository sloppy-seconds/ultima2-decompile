# engine/Makefile — portable C engine, CP0 skeleton.
#
# Hard rule from docs/phase4-plan.md §2: the terminal build needs nothing but
# a C11 compiler. No third-party libraries, no generated content required to
# build or to run the CP0 smoke test. SDL2 is a CP9 target and stays behind
# its own goal, because installing it is an owner decision.

CC       ?= cc
STD      ?= -std=c11
WARN     := -Wall -Wextra -Werror -Wshadow -Wstrict-prototypes -Wmissing-prototypes \
            -Wpointer-arith -Wwrite-strings -Wno-unused-parameter
OPT      ?= -O2
CPPFLAGS += -Isrc -Ibuild
CFLAGS   += $(STD) $(WARN) $(OPT)

BIN      := u2
BUILD    := build
GEN      := $(BUILD)/gen_content.h
EXE      ?= ../original/ultimaii.exe
SRCS     := src/main.c \
            $(wildcard src/core/*.c) \
            $(wildcard src/game/*.c) \
            $(wildcard src/platform/*.c) \
            $(wildcard src/debug/*.c)
OBJS     := $(patsubst %.c,$(BUILD)/%.o,$(SRCS))
DEPS     := $(OBJS:.o=.d)

.PHONY: all run headless test test-cp0 test-cp1 test-cp2 test-cp3 test-cp4 clean content content-check sdl help

all: $(BIN)

# Game content is extracted from the user's own copy at build time and lands
# in build/ (gitignored). With no copy present the extractor falls back to the
# db lines of the byte-proven asm/ tree, which is what CI has. The copy is a
# prerequisite so a replaced or patched exe rebuilds the header.
ifneq ($(wildcard $(EXE)),)
GEN_DEPS := $(EXE)
endif

content: $(GEN)

$(GEN): tools/extract/extractor.py $(GEN_DEPS) ../asm/014B_sub_014b.asm ../asm/03AC_sub_03ac.asm
	@mkdir -p $(BUILD)
	python3 tools/extract/extractor.py --exe $(EXE) -o $@

content-check: $(GEN)
	python3 tools/extract/extractor.py --exe $(EXE) --check

$(BIN): $(OBJS)
	$(CC) $(LDFLAGS) -o $@ $^

$(BUILD)/%.o: %.c $(GEN)
	@mkdir -p $(dir $@)
	$(CC) $(CPPFLAGS) $(CFLAGS) -MMD -MP -c $< -o $@

# Interactive terminal play.
run: $(BIN)
	./$(BIN)

# The CP0 acceptance command, verbatim from the plan.
headless: $(BIN)
	./$(BIN) --headless --script tests/title.keys --dump-state

test: test-cp0 test-cp1 test-cp2 test-cp3 test-cp4

test-cp0: $(BIN)
	bash tests/run_cp0.sh

test-cp1: $(BIN)
	bash tests/run_cp1.sh

test-cp2: $(BIN)
	bash tests/run_cp2.sh

test-cp3: $(BIN)
	bash tests/run_cp3.sh

test-cp4: $(BIN)
	bash tests/run_cp4.sh

# CP9 placeholder. SDL2 must be approved and installed by the owner first;
# this target deliberately does not attempt any install.
# SDL2 is an owner-approved dependency (docs/phase4-plan.md § 6 stop-and-ask), so
# it never enters the default build: the objects are compiled a second time into
# a separate directory with -DU2_HAVE_SDL, and src/platform/*_sdl.c are empty
# without that define. `make` alone still needs nothing but a C compiler.
SDL_CFLAGS := $(shell sdl2-config --cflags 2>/dev/null)
SDL_LIBS   := $(shell sdl2-config --libs 2>/dev/null)
SDLOBJ     := $(BUILD)-sdl
SDL_BIN    := u2-sdl

sdl: $(SDL_BIN)

$(SDL_BIN): $(patsubst %.c,$(SDLOBJ)/%.o,$(SRCS))
	$(CC) $(LDFLAGS) -o $@ $^ $(SDL_LIBS)

$(SDLOBJ)/%.o: %.c $(GEN)
	@test -n "$(SDL_CFLAGS)" || { echo "sdl: SDL2 not found. On Bazzite the low-friction" \
	     "install is 'brew install sdl2' (no reboot, no OS layering)."; exit 1; }
	@mkdir -p $(dir $@)
	$(CC) $(CPPFLAGS) $(CFLAGS) -DU2_HAVE_SDL $(SDL_CFLAGS) -MMD -MP -c $< -o $@

sdl-run: $(SDL_BIN)
	./$(SDL_BIN) --sdl --play-map --data-dir ../original --save-dir saves

clean:
	rm -rf $(BUILD) $(SDLOBJ) $(BIN) $(SDL_BIN)

help:
	@echo "targets: all run headless test test-cp0 test-cp1 test-cp2 test-cp3 test-cp4 sdl sdl-run clean content content-check help"

-include $(DEPS)
