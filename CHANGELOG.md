# Changelog

## 0.1.0 — unreleased (tag pending owner decision)

The first release of the reproduction. What this project is, in one line: a
byte-exact assembly reconstruction of the MS-DOS *Ultima II* binary, a portable
C11 reimplementation of its engine, and automated proof standing behind both.

### The reconstruction (Phases 1–3, complete and signed off)

* `asm/` reconstructs the entire 37,344-byte executable as 1,222
  one-function-per-file MASM-dialect sources, each carrying evidence,
  provenance and confidence headers.
* `tools/assemble_clean.sh` rebuilds the whole binary from `asm/` and verifies
  it against the known md5; the CI workflow `asm-checksum` runs it on every
  push and has never been permitted to go red.
* Runtime evidence was captured with an instrumented emulator (Spice86):
  executed-instruction traces, memory dumps and screenshots back the named
  routines; `captures/` holds the named evidence the docs cite.

### The engine (Phase 4, in progress — CP0..CP7 green)

* Portable C11, no third-party dependencies for the terminal build; the game
  ships with **zero copyrighted content** — strings and tile geometry are
  extracted at build time from the player's own copy, and the substitute tile
  art was drawn under a documented cleanroom procedure
  (`docs/cleanroom-procedure.md`).
* Implemented and gated: character creation (byte-compatible save records),
  the overworld with the proven passability ladder, towns and sites, monsters
  with the decoded spawn/AI rules, combat, commerce (TRANSACT and the talking
  arm), the command dispatcher with all 26 letter handlers implemented and
  every one observed executing in a capture, time-door gates, and the dungeon
  engine (CP7: entry, lighting, movement, fight, loot, descent).
* Save compatibility with the original is checked by loading each side's
  records into the other (`tools/save_cross_load.py`).
* Acceptance gates CP0..CP7 run under `make -C engine test`; the gates are
  mutation-tested — each can be demonstrated red on a deliberately wrong
  model, which is the project's standing rule for any checker.

### Release engineering (2026-11-02)

* Single-file player binaries: `make sdl-static` (Linux; links only
  libc/libm — SDL dlopens the rest at runtime) and `make sdl-win` (Windows
  x86_64; stock-DLL imports only), both reproducible from build containers
  (`deploy/linuxbuild`, `deploy/winbuild`) that pin SDL2 2.32.8 built from the
  official source.
* `release-builds.yml` builds both and attaches them with SHA256SUMS on a `v*`
  tag; the workflow itself fails if either binary's link stops being static.
* macOS is a planned CI job (Apple SDK precludes cross-compiling from Linux).

### Fidelity notes worth knowing before playing

* The engine reproduces the original's bugs where they are load-bearing
  (packed-decimal stat wraps, the diagonal melee asymmetry, the
  message-promises-more-than-the-code-does handlers) and says so in place.
* Two fidelity modes: original (default, byte-faithful behaviour including its
  silences) and `--enhanced` (dead ends removed, engine-authored announcements
  added through one audited seam).
* Environmental damage matches the bytes exactly: swamp costs 5 HP on entry
  with borrow propagated (0400 -> 0395, observed live), silently, because the
  original is silent; the force field costs 1000 unless a ring protects. The
  wound flash ring fires on the hit unit's cell in both directions — observed
  from a live playtest — and deliberately on nothing else.

### Known gaps

* CP4b T5 (baseline move) and a handful of capture questions remain open in
  `docs/needs-gameplay.md`; none blocks play.
* The `asm/5EAC` wound-loop tone is not wired (duration neither decoded nor
  measured); the floating damage number and sprite hit animation (E2/E4) are
  parked behind an animation-clock design question.
* The Windows binary is link-verified but not yet run-verified (no wine smoke
  test); the macOS build does not exist yet.
