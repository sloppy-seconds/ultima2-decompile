# Changelog

## 0.1.0 — unreleased (first build tag is `v0.0.2`, cut 2026-11-02 to prove the release pipeline)

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

* Portable C11, no third-party dependencies for the terminal build. Copyrighted
  content is split three ways and each part says so: the game's **text** is
  committed in one generated file (`engine/content/gen_content.h`, extractor-
  written, gated against `asm/`), the **art** is substituted under a documented
  cleanroom procedure (`docs/cleanroom-procedure.md`), and the **world data** —
  sector maps, monsters, dialogue, pictures — stays on the player's disk and is
  never in this repository.
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

### Gameplay fidelity (2026-11-02, v0.0.5)

* **Two owner-reported bugs, one root cause: the engine applied a world-map rule to
  a site sector.** Time doors were stamped inside Port Boniface, and water appeared
  around the town's south exit. Both were reproduced live in sector 31 and both are
  fixed. The original stamps no door inside a settlement and does not even run the
  door's countdown there — two independent mechanisms, so both are now gated on the
  world map. And the viewport wraps only on the world map: `asm/5AB1` branches on
  the mode byte and only the world-map arm masks the origin with `and $0x3f`, while
  the interior arm deliberately does not. Past the edge of a site the original draws
  the sector's own ground byte, `0x08`, which is why it reads as grass and not as a
  glitch; the engine was wrapping and pulling the town's north sign band onto the
  bottom of the screen.
* **Why no earlier capture caught the wrap.** Every sector measured before this had
  water at both its north and south rows, so wrapping and filling are pixel-identical
  there. A settlement is the only sector whose north edge is not water, which makes it
  the only place the two hypotheses can be told apart. The lesson is recorded in
  `docs/harness-portability.md`: a capture earns its citation only if it could have
  failed to.
* **A third defect, found by trying to prove the first.** The view mode was set on
  site entry and never re-derived, so a save loaded inside a town still wrapped, and
  walking out of one would have left the world map un-wrapped. The mode is a function
  of the sector's ones digit, not an event.
* **Verified frame against frame.** With the same record loaded, the engine's render
  of sector 31 at `(31,62)` now matches the original on all ten viewport rows and all
  four CGA colours, counts included. `tests/site_viewport_gate.py` is new: it builds
  its own town save, renders it, and asserts the property that distinguishes filler
  from wrap. It was run against the real pre-fix mutation and went red, and so did
  CP4; five selftest controls are demonstrated red on every `make test`.
* `--dump-map` renders from the loaded save when one is present, not only from the
  fixed probe sector. That is what made the comparison above possible at all.

### Splash graphics (2026-11-03)

* **The engine now shows the original's splash pictures.** The owner noticed it did not,
  and the reason turned out to be a deferral to a milestone that was never the obstacle:
  the original does not decode these files at all. `asm/5351` points `DS` at `0xB800` and
  `asm/535A` reads raw sectors into it, so a `PIC` file is a literal image of CGA mode-4
  video memory, and the engine's frame already stores one CGA index per pixel. The
  "bitmap pipeline" is a planar unpack of 16,000 bytes.
* The intro now shows the **Ultima II dragon logo** between the second presentation screen
  and the title menu, held about five seconds as the original does, and the `'D'`
  demonstration now runs the **whole** story poem over the starfield and the pyramid
  instead of the two-couplet placeholder. Both fall back to the text screens exactly as
  before when the player has no picture file or the backend takes no frames, so a terminal
  build and a player without the data are unchanged.
* `tests/pic_check.c` gates the unpack, and it is a lesson in what a census cannot prove:
  every candidate layout is a permutation of the same bytes, so the global colour census is
  identical for the correct interleave and for two wrong ones. The gate pins scanline and
  quadrant placement instead. The decode was also checked against a live capture of the
  original at 100% colour-class agreement.
* The pictures are read from the player's own directory at runtime, like the tile art.
  Nothing is committed and nothing is substituted.

### Licensing and attribution (2026-11-03)

* **`--licenses` prints the full licensing and attribution record from inside the
  binary.** The release is a single file with no accompanying documents, so a
  recipient holding only the executable had no way to find out what was in it. The
  texts are compiled in from committed sources, so it works with no data directory,
  no network and no SDL present.
* It covers SDL3 (zlib, verbatim), font8x8 (public domain, with provenance), the
  substitute tile art (our own work, and how the cleanroom procedure made it), our
  own Apache-2.0, and a notice stating plainly what the binary does and does not
  contain from the original game — no art, no sound, no world data, but yes to the
  short functional text strings the engine must print.
* **SDL3 was missing from `THIRD-PARTY-LICENSES` entirely**, and every release from
  v0.0.2 through v0.0.7 shipped a statically linked SDL with no entry there. zlib
  does not oblige us to ship anything — its acknowledgment is "appreciated but not
  required" and its third clause binds source distributions, not binaries — so this
  was never a breach. It was a gap by this file's own standard, which exists so that
  provenance is a lookup rather than an archaeology dig.
* The generated header is committed with no build rule, the same discipline as the
  content header, and `make licenses-check` plus a CP0 gate prove it still matches
  its sources. A silently shortened licence list looks exactly like a complete one.

### SDL3 (2026-11-03)

* **The engine now builds against SDL3.** The owner chose to replace SDL2 outright rather than
  carry two backends. SDL3 is what Fedora, Arch and Homebrew actually ship as "SDL2" these days
  (via `sdl2-compat`, an SDL2 API layer over SDL3), upstream has put SDL2 in maintenance, and the
  two features wanted this week — integer scaled presentation and a drawable-size change event —
  are SDL3 API. Release artifacts pin **SDL3 3.4.18** from the official tarball, statically linked,
  in all three build paths (local container, Windows cross container, CI).
* The port was three files and 17 symbols, and two of the changes were the kind that fail quietly.
  **SDL3 defaults textures to linear filtering**, so a port that missed it would still draw and
  still pass every colour-class test while showing smeared 2bpp CGA; nearest-neighbour is now an
  explicit per-texture call that warns if refused. And **`SDL_InitSubSystem` returns `bool` where
  SDL2 returned 0 for success**, which written naively reads every successful init as a failure.
  Also: `SDL_RenderTexture` takes float rectangles, `SDL_CreateRenderer` lost its flags, the
  resize event split into `RESIZED` and `PIXEL_SIZE_CHANGED`, and audio moved wholesale to the
  stream API — which retired a latent wart where the old code queued against a hardcoded device id.
* `core/scale.c` stays. SDL3 has integer logical presentation as a platform mode, and it is
  deliberately not used: the hand-computed fit is what the gate can test with no SDL installed, and
  it owns the below-1:1 policy SDL's mode leaves unspecified.
* `make sdl` now needs SDL3 and says so if it cannot find it. A machine with only SDL2 gets a
  refusal naming the mismatch, because "no SDL" on a box that has SDL2 sends someone to install the
  wrong thing.

### Build honesty (2026-11-03)

* **A binary can now say what it is.** `--version` prints the build target, which SDL
  implementation it linked, whether statically or dynamically, whether it is the shipped
  artifact or a development build, and both the compile-time and the runtime SDL version.
  Having both versions is the point: a binary stamped `sdl2` whose runtime disagrees is holding
  a compatibility layer, and that discrepancy was previously invisible from the running program.
* **`make sdl` now asks what it is linking instead of hoping.** A new probe,
  `engine/tools/sdl_probe.sh`, prefers a static SDL2 prefix (the release shape) and otherwise
  identifies the host library. On Bazzite and Arch that is `sdl2-compat`, the SDL2 API
  implemented over SDL3, and a build against it compiles, runs, and is not what the release
  ships — so the build now says so out loud and stamps the binary to agree. `U2_STRICT_SDL=1`
  turns the notice into a refusal, for a CI job that means to build the real thing.
* **`make test` gained 16 checks over these two things.** `engine/tests/sdl_probe_selftest.sh`
  runs 12 controls against fixtures rather than a live host, so it behaves identically on a
  runner with no SDL installed at all, and two of them exist to police each other (a shim caught
  by path versus a shim caught only by version number). `run_cp0.sh` adds four `--version`
  assertions including a check for the unstamped fallback by name, because the silent version of
  that failure is a binary that compiles fine and can no longer be identified.
* **The CP4 SDL gate prefers `u2-sdl-static` over `u2-sdl`** and prints which it drove. Until now
  the one gate touching the SDL backend exercised an implementation we do not ship.
* **Release artifacts carry their own tag**, and the workflow fails if a built artifact does not
  claim `artifact=release` or does not name the tag it was built from.
* The plan's CP9 milestone was corrected in place: it specified a 640x200 window and a 16-colour
  palette, and the engine ships 320x200 and four colours, because mode 4 never had sixteen.

### Window scaling (2026-11-03)

* **Resizing the window now scales the picture.** It did not, and the reason was three
  separate things rather than one. SDL was already scaling — `SDL_RenderCopy` with a NULL
  destination fills the output rectangle — but nothing re-presented after a resize, because
  the event pump handled only quit and keydown and dropped `SDL_WINDOWEVENT_SIZE_CHANGED`.
  The window kept the old frame until the game happened to draw a new one, which on the title
  menu could be never.
* The fit is now **integer and centred**, so a source pixel is always exactly `s x s` device
  pixels and the letterbox bars take the remainder. This matters more here than in most
  emulators: the art is 2bpp CGA, where a fractional scale makes some pixels 3 device pixels
  wide and some 4, and the dragon's outline visibly wobbles. Below 1:1 the rule changes to
  filling the window, because the alternative to a fractional fit is cropping, and hiding
  part of the screen is worse than squashing it.
* The geometry lives in `engine/src/core/scale.c`, not in the SDL backend, for the same reason
  the palette does: a backend may move pixels and must not decide what they look like. It is
  also pure integer arithmetic with no SDL dependency, so `tests/scale_check.c` gates it in the
  cc-only build with no display, across a sweep of ~52,000 window sizes, checking maximality,
  aspect, centring, containment and the degenerate cases. Four mutants (per-axis scale,
  height-only scale, no centring, crop-instead-of-fill) each turn it red.
* `SDL_WINDOW_ALLOW_HIGHDPI` is now set, so on a scaled desktop the drawable size is what the
  window size claims, and the fit is recomputed from the renderer's output size every frame
  rather than cached from a resize event.

### Fixed after v0.0.5

* **`R` and `W` looked like a crash; they were a menu that never reached the screen.** The
  owner bought a mace in Linda, pressed `R`, and got a window that sat unchanged while the
  game waited for a digit he could not see a menu for. The READY WEAPON menu was being
  printed into a frame nobody had presented, and the presenting loop sits above the command
  handler, so it appeared only after the answer was typed. `W` had it, and so did `M`.
  `seam_key_wait_shown()` is now the documented way to ask the player something, used by
  `R`, `W`, `M`, the yell prompt and every shop. It is deliberately per-site rather than
  folded into the shared wait path — that was tried and hung the title screen — and the
  history now sits on the helper in `seam.h` where the next prompt will find it. A new gate,
  `tests/prompt_gate.py`, asserts from the trace that the question is on screen before the
  read, and was demonstrated red against the real mutation.

### Release engineering (2026-11-02)

* Single-file player binaries: `make sdl-static` (Linux; links only
  libc/libm — SDL dlopens the rest at runtime) and `make sdl-win` (Windows
  x86_64; stock-DLL imports only), both reproducible from build containers
  (`deploy/linuxbuild`, `deploy/winbuild`) that pin SDL2 2.32.8 built from the
  official source.
* `release-builds.yml` builds both and attaches them with SHA256SUMS on a `v*`
  tag; the workflow itself fails if either binary's link stops being static.
* **The first player binaries could not open a window on any desktop.** SDL's
  cmake compiles out any video backend whose dev packages are missing and says
  nothing while doing it, and neither build container installed any, so the
  static `libsdl2.a` contained only `dummy` and `offscreen`. It linked, it was
  genuinely static, and every check in the pipeline passed; a player on Wayland
  saw nothing at all. `--video-drivers` now reports what a binary can actually
  do, both build paths install the X11/Wayland and audio headers, and both
  `deploy/linuxbuild/build.sh` and the release workflow fail if neither `x11` nor
  `wayland` is in the artifact. A startup line (`u2: video: wayland`) and a
  driver list on failure mean the next occurrence diagnoses itself.
* **An SDL build now defaults to the window.** `--renderer=sdl|terminal` picks
  the front end, defaulting to `sdl` in a binary compiled with SDL and terminal
  otherwise, so the downloaded player binary needs no flags and no terminal; the
  cc-only build the test suite drives keeps the text grid. `--sdl` remains an
  alias. Asking a binary for a renderer it was not compiled with is now a refusal
  with a reason, where it used to be silently ignored — which is how "the window
  didn't open" got mistaken for a display problem. `--script` outside
  `--headless` is refused for the same reason: no interactive backend reads it.
* The Windows build had **never linked**, on any machine: mingw declares
  `clock_gettime` and `nanosleep` and its CRT provides neither, so the failure
  was at link and invisible to any host that did not cross-build. Fixed with a
  per-platform clock backend (`src/platform/time_win32.c`). The Windows link also
  dropped `-mwindows`, so the binary is console-subsystem and keeps its stderr —
  under wine, that is the difference between a crash and a diagnosis.
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
* Both player binaries have been played by the owner. The Windows build was run
  under wine on Bazzite Linux (2026-11-02): start, character creation, overworld,
  towns and combat, and it loaded a `PLAYER` record written by the Linux build —
  the first cross-platform save check between two engine binaries, as opposed to
  engine-against-original. Wine is not Windows, so real GPU, audio and filesystem
  behaviour on a real Windows box remain untested.
* The macOS build does not exist yet.
