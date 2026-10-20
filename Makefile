# Top-level Makefile — the two things an agent or the owner actually run.
#
# The engine lives in engine/ and has its own Makefile; this wraps it so that
# "build it", "test it" and "play it" are one command from the repo root, and so
# the Phase 3 byte-exact invariants are part of `make test` rather than something
# someone remembers to run.
#
# Run `make help`.

BIN      := engine/u2
CLEANBIN := /var/tmp/u2-clean-rebuild.bin

.PHONY: help all engine play run headless test test-engine test-phase3 content clean

help:
	@echo "make engine      build the engine (cc only, no dependencies)"
	@echo "make play        play it interactively  (same as make run)"
	@echo "make run         play it interactively"
	@echo "make headless    one scripted headless run, with a state dump"
	@echo "make test        engine checkpoint tests + Phase 3 invariants"
	@echo "make content     regenerate build/gen_content.h from original/"
	@echo "make clean       remove engine build output"

engine: $(BIN)

$(BIN):
	@$(MAKE) -C engine all

run: $(BIN)
	@$(BIN)

play: run

headless: $(BIN)
	@$(BIN) --headless --script engine/tests/play_to/reach_everything_today.keys \
	    --save-dir /var/tmp/u2-play --dump-state

# --- tests ---------------------------------------------------------------
# Both halves matter. The engine tests prove the engine does what we say; the
# Phase 3 checks prove we never disturbed the byte-exact reconstruction that the
# engine is derived from.

test: test-engine test-phase3
	@printf '\nALL CHECKS PASSED\n'

test-engine: $(BIN)
	@$(MAKE) -C engine test

test-phase3:
	@printf '\nphase 3 invariants\n'
	@bash tools/assemble_clean.sh $(CLEANBIN) >/var/tmp/u2-clean.log 2>&1 \
	    && tail -1 /var/tmp/u2-clean.log \
	    || { echo "  FAIL  clean rebuild"; tail -5 /var/tmp/u2-clean.log; exit 1; }
	@md5sum original/ultimaii.exe | grep -q fe884d5117971073ac8097cc7a6aca25 \
	    && echo "  ok    original/ultimaii.exe unchanged" \
	    || { echo "  FAIL  original/ has changed"; exit 1; }
	@git status --porcelain -- asm original references | grep -q . \
	    && { echo "  FAIL  asm/ original/ or references/ are dirty"; exit 1; } \
	    || echo "  ok    asm/ original/ references/ untouched"

content:
	@$(MAKE) -C engine content

clean:
	@$(MAKE) -C engine clean
