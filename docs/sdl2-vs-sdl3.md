# SDL2 or SDL3 — an evaluation, and the record of why nobody ever made the choice

**Status: open decision for the owner.** Nothing here is implemented. This document exists
because the question "why SDL2?" could not be answered from the repository, and that turned out
to be the interesting finding rather than a preamble to it.

Grades follow the project convention: **measured** = derived from this tree or an installed
header by a named tool; **observed** = read from a primary source; **inferred** = reasoned, not
proven.

---

## 1. Why this doc exists

While fixing window scaling (2026-11-03) the owner asked why local builds link SDL2 dynamically
when releases link it statically. Chasing that produced two further facts, neither of which was
documented:

1. The SDL2 on this host is **not SDL2**. `make sdl` asks `sdl2-config`, which resolves to
   `sdl2-compat-2.32.74-1.fc44` — a shim that implements the SDL2 API on top of **SDL3**. The
   release binary links real SDL2 **2.32.8** from a pinned tarball. So the binary the owner plays
   and the binary a player downloads are different implementations, not just different linkages.
2. **There is no decision record.** Before this document existed, `grep -rn 'SDL3\|sdl3' docs/
   README* CHANGELOG.md AGENTS.md deploy/` returned exactly one hit, a comment in
   `deploy/winbuild/Containerfile:4`. SDL2 appears
   in `docs/phase4-plan.md:175` as the title of a milestone, "CP9 — SDL2 CGA renderer", which means
   the choice was made when the plan was written and never revisited. SDL3 3.0.0 shipped in January
   2024, well before this project started, so this was never a case of SDL3 not existing.

A choice that was made by default is not wrong, but it should be re-made on purpose once, with the
costs visible. That is what this document is for.

---

## 2. The SDL surface, measured

Not "how much code", but how much of it is actually SDL's problem.

| file | lines | role |
| --- | --- | --- |
| `engine/src/platform/renderer_sdl.c` | 283 | window, renderer, texture upload, text layer |
| `engine/src/platform/input_sdl.c` | 156 | event pump, key translation, signal handling |
| `engine/src/platform/audio_sdl.c` | 105 | PC-speaker tones via SDL audio |
| **total** | **544** | |

`engine/src/main.c` is the only other file mentioning SDL, and only to select a backend and to
refuse `--renderer=sdl` in a build that has no SDL. That refusal is gated (`run_cp0.sh:182`).

**52 distinct `SDL_*` symbols** are used. Measured with `grep -rhno 'SDL_[A-Za-z_]*'
engine/src/platform/*.c | sort -u`, which yields 53 matches, one of them `SDL_SCALE` — our own
macro for the default window scale and not an SDL symbol at all. The distinction is worth keeping
in the text because a count that swallows a false positive is the kind of number that quietly stops
matching the code. Of the 52, **17 need to change for SDL3** and 35 do not; that split is my
reading of the migration guide rather than a tool output, and it is the figure to re-check if this
plan is picked up. The 17 are:

- renderer creation: `SDL_CreateRenderer` (signature), `SDL_RENDERER_ACCELERATED`,
  `SDL_RENDERER_SOFTWARE`
- scaling hint: `SDL_SetHint` with `SDL_HINT_RENDER_SCALE_QUALITY`
- window: `SDL_WINDOW_ALLOW_HIGHDPI`, `SDL_WINDOWEVENT`, `SDL_WINDOWEVENT_SIZE_CHANGED`
- pixels: `SDL_PixelFormat`, `SDL_AllocFormat`, `SDL_FreeFormat`, `SDL_MapRGBA`
- audio: `SDL_OpenAudio`, `SDL_PauseAudio`, `SDL_CloseAudio`, `SDL_QueueAudio`, `SDL_AudioSpec`
- one include: SDL3 requires `<SDL3/SDL_main.h>` in the file holding `main()`

Everything else — window creation, texture create/update, `RenderClear`/`RenderCopy`/
`RenderPresent`, `GetRendererOutputSize`, `PollEvent`, `KEYDOWN`, `Delay`, `GetError`, the video
driver enumeration that backs `--video-drivers`, `InitSubSystem`/`QuitSubSystem` — carries over.

**The seam did its job.** The whole third-party surface is three files behind one vtable, which is
the reason this question is answerable in an afternoon instead than an archaeology project. It is
also the reason the answer does not have to be permanent.

---

## 3. What SDL3 would actually give us

All of this is **observed** from `docs/README-migration.md` in the SDL repository (fetched
2026-11-03), not recalled.

**Integer scaled presentation is a first-class mode.** The migration guide lists
`SDL_RenderSetIntegerScale()` as removed because "this is now explicit with
`SDL_LOGICAL_PRESENTATION_INTEGER_SCALE`", and `SDL_RenderSetLogicalSize()` renamed to
`SDL_SetRenderLogicalPresentation()`. So SDL3 has letterbox-plus-integer-scale as a named mode
rather than something the app computes.

**It also has the event we had to go looking for.** SDL2's `SDL_WINDOWEVENT_SIZE_CHANGED` is
removed in SDL3 in favour of `SDL_EVENT_WINDOW_RESIZED` and `SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED`,
the latter being the drawable-size change that HiDPI scaling produces. That is precisely the
distinction the scaling fix needed.

**Nearest-neighbour becomes explicit and per-texture.** In SDL3 textures default to **linear
filtering**, and `SDL_HINT_RENDER_SCALE_QUALITY` is gone in favour of
`SDL_SetTextureScaleMode(texture, SDL_SCALEMODE_NEAREST)`. Worth noting as a hazard: an SDL3 port
that missed this would ship bilinear-smoothed 2bpp CGA, which is the exact failure the current hint
exists to prevent.

**Real-time window semantics change**, and not in our favour: SDL3 treats `SDL_SetWindowSize()` and
friends as asynchronous requests that should not be assumed to have taken effect until the
matching event arrives.

---

## 4. What we would be leaving behind, and one thing we skipped

**SDL2 is in maintenance.** Upstream's own release notes for the 2.32 line carry a standing
"SDL 3.0 recommended!" notice pointing at SDL3 or sdl2-compat. Latest real SDL2 is **2.32.10**
(1 Sep 2025); we pin **2.32.8**. Latest SDL3 is **3.4.18** (2 Oct 2026), on a roughly monthly
bugfix cadence. The two fixes in 2.32.10 that we would be picking up by moving current are a
PipeWire audio device format correction and a macOS dock issue; nothing touching renderers.

**The thing worth admitting: SDL2 already had integer scaling.** `SDL_RenderSetIntegerScale()` has
been available since SDL 2.0.5 and is present in the header installed on this machine
(`/home/linuxbrew/.linuxbrew/include/SDL2/SDL_render.h:877`), documented as "restricts the logical
viewport to integer values — when a resolution is between two multiples of a logical size, the
viewport size is rounded down to the lower multiple". That is the behaviour `core/scale.c` now
computes by hand.

So the scaling fix duplicated a native feature. Three reasons that is still the right call, and
one where it is not:

- `core/scale.c` is pure integer arithmetic with no SDL dependency, so `tests/scale_check.c` gates
  it in the default cc-only build, on a machine with no SDL and no display. SDL's own integer
  scaling cannot be tested that way, and the CP4 SDL path is skipped entirely when SDL is absent.
- The policy below 1:1 is ours: fill the window rather than clip it. SDL2's integer scale with a
  window smaller than the logical size is documented only as rounding down to the lower multiple,
  which at 0.x means 1:1 and therefore clipping — **inferred**, not observed, and worth a
  measurement if we keep either approach.
- Keeping geometry in `core/` is the existing rule for rendering semantics, and it is what makes
  a backend swap a backend swap.
- **Where it is not the right call:** if we move to SDL3, `SDL_LOGICAL_PRESENTATION_INTEGER_SCALE`
  is the platform's own letterbox and it will interact with the compositor and with fullscreen
  better than a hand-computed rect. At that point `core/scale.c` should be reconsidered rather than
  ported, and the sub-1:1 question settled by measurement.

---

## 5. Options

### A. Stay on SDL2, and make local builds match the release

Pin-bump 2.32.8 → 2.32.10 in the three places that name it. Make `make sdl` prefer the static
prefix and refuse loudly when it is falling back to a host SDL that is really sdl2-compat. Point
the CP4 SDL gate at `u2-sdl-static` when it exists.

*Cost:* small, mostly Makefile and one version bump. *Risk:* we stay on a maintenance line and keep
hand-computing what SDL3 offers as a mode. *Also:* this does not make the host SDL and the release
SDL the same code, only the same major version.

### B. Move the engine to SDL3

Port three files, ~17 symbols, plus the build: `sdl2-config` → SDL3's `sdl3-config`/pkg-config,
the pinned tarball in `release-builds.yml`, `deploy/linuxbuild` and `deploy/winbuild`, and the
`--video-drivers` gate's expectations.

*Cost:* a day of focused work plus a rebuild of the container images, and one genuine behavioural
hazard (linear filtering by default) that must be caught by a gate rather than by eye. *Benefit:*
current upstream; integer presentation and drawable-size events as named API; and **the host and
the release finally agree**, because what Fedora, brew and Arch all ship now is SDL3 plus
sdl2-compat. *Risk:* SDL3 is on a monthly bugfix cadence, so "current" needs a little more tending
than a frozen SDL2 pin did.

### C. Do the build-honesty work now, decide the major version later

The dev-vs-release divergence is **independent** of SDL2 versus SDL3: it is a build-pinning problem,
and option B would not fix it on its own if `make sdl` still grabbed whatever the host had. This
option is A's Makefile and gate work, minus the version bump, plus a `--version` stamp that prints
which SDL implementation and linkage a binary holds.

*Cost:* smallest. *Benefit:* closes the gap the owner actually reported, and makes the remaining
question visible in the binary itself rather than only in a document.

---

## 6. Recommendation

**C now, then B.**

C because the reported defect is "what I test is not what players get", and that is a build-discipline
bug that no SDL major version fixes by itself. It is cheap, it is gated, and it makes the next
decision easier to check.

B rather than A because the ecosystem has already moved: the SDL2 that ships on this machine is a
compatibility layer over SDL3, upstream says so on its own release pages, and the two SDL3 features
we wanted this week — integer logical presentation and a drawable-size change event — are exactly
the things we had to hand-build in SDL2. A keeps us correct and alone; B makes us current and
compatible with what the distros hand out.

The one thing I would not do is A alone. It pins us harder onto the legacy line to fix a problem
that is not about the line.

---

## 7. Independent of the choice, these are true and should be fixed

1. **`make sdl` silently builds against a different SDL than the release.** It should either use
   the pinned static prefix or say in as many words that it is not the shipped artifact.
2. **The CP4 SDL gate runs `./u2-sdl`**, i.e. the dev binary against the host SDL. The one test
   that touches the SDL backend therefore tests an implementation we do not ship, and is skipped
   on a runner with no SDL at all.
3. **Nothing in a binary identifies itself.** `--version` should print the SDL implementation and
   version, static or dynamic, and the build target. Every argument in this document would have
   been a one-line answer with that in place.
4. **`docs/phase4-plan.md` CP9 still specifies "640x200 window" and "16-color palette"**, and the
   shipped renderer is 320x200 and four colours. The milestone drifted from its own plan and the
   plan was never corrected.
