# EGA graphics (`--ega`) — design proposal

Status: **design only, not built.** Owner idea, 2026-11-04. This is intended as an interim
launch flag that `docs/options-menu.md` can later replace with a graphics-set switch.
Implementation plan: `docs/ega-graphics-plan.md`.

## 1. What the assets are

The fan pack's Galaxy/EGA patch (`original/updated/`) ships 16-colour versions of the
original CGA screens alongside the CGA ones:

| CGA (original) | EGA (patch) | CGA size | EGA size |
| --- | --- | --- | --- |
| `picout` | `PICOUT-E` | 16384 | 64000 |
| `pictwn` | `PICTWN-E` | 16384 | 64000 |
| `picdng` | `PICDNG-E` | 16384 | 64000 |
| `picdra` | `PICDRA-E` | 16512 | 64000 |
| `picmin` | `PICMIN-E` | 16384 | 64000 |
| `picspa` | `PICSPA-E` | 16384 | 64000 |
| — (castle) | `PICCAS-E` | — | 64000 |

The CGA files are 320×200 at 2bpp planar (4 colours); `pic.c` already unpacks them
(planar-to-linear, 16000 bytes into the frame). The `-E` files are **64000 = 320×200×1
byte**, which strongly implies a **linear, one-palette-index-per-pixel** image at EGA's
16-colour depth — i.e. no planar decode, just a palette map. That is a hypothesis to
confirm, not an established fact (see § 4 spike).

`u2ega.exe`, `cgapatch.exe`, `dngpatch.exe` in `updated/` are the patchers that swap these
in for the original game; we do not run them, we would read the files directly.

## 2. Legal posture — already solved by the existing model

The EGA art is Origin's (recoloured by the patch), so it is **never committed** — same rule
as all original art (`AGENTS.md` licensing section; the cleanroom wall). But the engine
already loads original art **from the user's own copy at runtime** (`u2_tiles_extract`,
CP0 prints "art source: original tiles extracted from the user's copy"). Enhanced mode
would read `updated/PIC*-E` from the player's `--data-dir` the same way. The committed
**cleanroom** substitute art (`engine/assets/tiles/cleanroom/`) stays the fallback when the
user's copy has no EGA files. No new copyright exposure; the cleanroom gate still applies
to anything we ship.

## 3. The real work (this is a pipeline change, not a toggle)

The engine's frame stores **one CGA index per pixel (4 colours) end to end** — frame,
renderer, and palette all assume it. EGA is 16 colours, so:

1. **Colour-depth pipeline.** A 16-colour path through `core/frame`, the renderer(s), and
   the palette. This is the bulk of the effort and touches the display seam broadly.
2. **A `PIC*-E` loader.** Likely simple if the linear-index hypothesis holds (read 64000
   bytes, map through the EGA palette); needs confirming.
3. **A tile-atlas source for EGA.** The engine extracts the CGA tile atlas from
   `ultimaii.exe`; the EGA tiles live in the `PIC*-E` files instead, a different source and
   layout. This is the least-understood piece.
4. **The `--ega` flag itself.** Small: a mode on `u2_ctx` (parallel to `fidelity`), read at
   launch, selecting the EGA art path when the files are present and falling back to CGA /
   cleanroom when not.

## 4. Recommended first step: a format spike (no engine change)

Before committing to the pipeline work, a throwaway script should confirm the `PIC*-E` byte
layout: is it linear 1-byte-index, or 4-plane EGA planar? Render one `PICOUT-E` to a PNG
both ways and look at it. This decides whether the loader is trivial (linear) or needs a
planar unpack like `pic.c`. Cheap, and it de-risks the whole proposal.

## 5. Relationship to the options menu

`--ega` is deliberately a launch flag so it can exist **before** the options menu. When
`docs/options-menu.md` lands, the graphics choice becomes a live-switchable row (graphics
is presentation, safe to change mid-run — see that doc's D-B) and `--ega` becomes its
default seed, exactly like the other enhanced knobs. So `--ega` is the interim and the menu
row is the end state; building `--ega` first does not create throwaway work, because the
underlying 16-colour pipeline is the same either way.

## 6. Open questions (owner)

- Is 16-colour EGA the target, or is the goal "use whatever richer art the user's patch
  provides" (which could later include the EGA dungeon/space variants individually)?
- Does `--ega` require `--enhanced`, or is it an independent art axis available in both
  modes? (It changes no rules, so it could be mode-independent.)
- Fallback when the user's copy has CGA but no `PIC*-E`: silently use CGA, or tell the
  player the EGA set is missing (consistent with the missing-planet-maps sign idea in
  `docs/planet-maps-galaxy-patch.md` § 5)?
