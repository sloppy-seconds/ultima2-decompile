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

engine:
	@$(MAKE) -C engine all

run: engine
	@$(BIN)

play: run

headless: engine
	@$(BIN) --headless --script engine/tests/play_to/reach_everything_today.keys \
	    --save-dir /var/tmp/u2-play --dump-state

# --- tests ---------------------------------------------------------------
# Two tiers, because the two halves cost wildly different amounts of time.
#
# `make test` is the loop you stay in: engine suites plus a cheap guard on the
# Phase 3 artefacts. About 6 seconds.
#
# `make test-full` adds the clean re-assemble of all 1299 reconstructed
# functions with jwasm. That is ~73 of the 78 seconds, and it only proves
# something new when asm/ has changed - which Phase 4 never does. CI runs it on
# every push, so the fast tier is not skipping the check, just not paying for it
# on every keystroke-sized iteration.
#
# The cheap guard is not a no-op: it fails if original/ is modified or if asm/, 
# original/ or references/ are dirty, and it tells you to run test-full when
# asm/ has moved since HEAD.

test: test-engine test-phase3-quick
	@printf '\nALL CHECKS PASSED (fast tier; run make test-full for the clean rebuild)\n'

test-full: test-engine test-phase3
	@printf '\nALL CHECKS PASSED (full tier)\n'

test-engine: engine
	@$(MAKE) -C engine test

# Cheap: sub-second, and catches the two things that actually go wrong.
test-phase3-quick:
	@printf '\nphase 3 guard (cheap)\n'
	@md5sum original/ultimaii.exe | grep -q fe884d5117971073ac8097cc7a6aca25 \
	    && echo "  ok    original/ultimaii.exe unchanged" \
	    || { echo "  FAIL  original/ has changed"; exit 1; }
	@git status --porcelain -- asm original references | grep -q . \
	    && { echo "  FAIL  asm/ original/ or references/ are dirty - run make test-full"; exit 1; } \
	    || echo "  ok    asm/ original/ references/ untouched"
	@if git diff --quiet HEAD -- asm 2>/dev/null; then :; else \
	    echo "  NOTE  asm/ differs from HEAD; run make test-full"; fi

# Expensive: the clean re-assemble. ~73s, run by CI and by make test-full.
test-phase3:
	@printf '\nphase 3 invariants (full)\n'
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
