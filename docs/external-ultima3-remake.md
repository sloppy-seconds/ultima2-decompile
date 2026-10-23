# External reference — the Ultima III TypeScript remake

Status: **cloned, surveyed, licence position settled, not yet mined**. Added by the
owner on 2026-10-24.

This is **not** Ultima II and not evidence about this binary. What it can supply is
*engineering method*, and now also, because it is MIT, quotable and portable source.

## 1. Provenance

| | |
| --- | --- |
| Upstream | <https://github.com/synthwave-pixel/ultima3> |
| Fork of | `beastie/ultima3` — Leon McNeill ("Beastie") of LairWare's Ultima III for Mac |
| Commit cloned | `72c70b864ffaced8baced51842b8881f071767f1` (`Thu Oct 15 2026`, "Note v1.0.63 in the changelog") |
| Cloned | 2026-10-24 into `references/ultima3/`, 55 MB, gitignored (`.gitignore`, explicit entry) |
| Shape | `web/` TypeScript (browser + PWA), `desktop/` Electron, `mobile/` Android, `Lairware/` the original Objective-C/C Mac sources |
| Playable | <https://synthwave-pixel.github.io/ultima3> |

## 2. The licence line — what MIT covers and what it explicitly does not

`LICENSE` is MIT, "Copyright (c) 2025 Leon McNeill". MIT is one-way compatible with
our Apache-2.0: we may copy, modify, merge and redistribute the **code**, and the
only condition is that the copyright notice and permission notice travel with all
copies or substantial portions. It is provided without warranty and with no
liability, and it grants **no trademark rights**.

The carve-out is stated by the author and it is the whole boundary:

> The code is under the MIT License (see LICENSE), as LairWare released it. The
> game's name, maps, music and other assets are Origin Systems'...
> — upstream README, "License"

> However, certain non-code assets (such as the project name, music, maps, etc)
> were not originally created by me. These assets are included under the assumption
> that copyright will no longer be actively enforced due to their age (40+ years)...
> I'm not claiming any copyright on the Ultima franchise name, NPC names, the
> specific maps found in this game, etc. This license just refers to everything
> else here.
> — Leon McNeill, LairWare README (reproduced in the upstream README)

That is a *good-faith non-claim by him*, not a licence to us. So:

| in the clone | licence | ours to use? |
| --- | --- | --- |
| `web/src/**.ts`, `web/tests/**`, `web/tools/**`, `Lairware/Sources/**`, `desktop/`, `mobile/` | MIT © 2025 Leon McNeill | **Yes** — copy, port, adapt, with attribution |
| `web/public/graphics`, `sounds`, `music`, `images`, `web/art/**`, `promo/`, `screenshots/` | Origin Systems / LairWare / Denis Loubet box art; included on his good-faith assumption | **No.** Never commit, never trace, never describe for redraw |
| `web/public/data/resources.json` (maps, monsters, talk, combat, strings) | extracted LairWare game data — content, not code | **No.** It is U3 content and it is not ours |
| `web/art/fonts/` (IM FELL English) | SIL Open Font License | Usable under OFL terms, but we have no font need |

### Procedure when we take code

MIT's only teeth are the notice. So, per ported file:

1. Header comment at the top of our file:
   `/* Derived from synthwave-pixel/ultima3 web/src/game/turn.ts (MIT, © 2025
   Leon McNeill), commit 72c70b8, ported to C on <date>. */` — and say what changed,
   the way the `font8x8` entry already does.
2. A section in `THIRD-PARTY-LICENSES` (the file exists for exactly this, and its
   own preamble says it records every third-party work that ships inside the repo)
   with author, source URL, commit, licence text and modifications.
3. Quoting a snippet in `docs/` or a commit message needs the same one-line
   attribution. Nothing else is required — no approval, no share-alike, and unlike
   `tools/spice86/` (GPL) and `tools/reko/` (GPL-2.0) this is the first third-party
   source in this project that could legally be committed at all if we ever wanted to.

## 3. What we think it is a useful reference for

Ranked by how directly it maps onto an open ticket. Each row is *method*; the
conclusions belong to U3 and die in this file (`AGENTS.md`: method transfers,
conclusions do not).

| our problem | their solved version | note |
| --- | --- | --- |
| **W9 — a CP5 gate that plays a fight headlessly** | `web/tools/sim/fuzz.ts`: seeded headless play, random party vs random roaming monster, random keys, invariants asserted after every key, and a failure prints the arguments that replay it | Closest thing in the wild to what `run_cp5.sh` needs. Also the pattern for the agent-drivable half of `docs/needs-gameplay.md`. |
| **W9 — driving the game the way a player does** | `web/src/game/autocombat.ts` + `tests/autocombat.test.ts`: auto-combat is a pure *key generator* over the real input path, not a shortcut into game internals | Our scripted attack should emit keys into the command loop, never call `u2_combat_attack()` directly, or the gate tests the model and not the game. |
| **No display, no keyboard in an agent shell** | `FakeIO` in `web/tests/helpers.ts` — the whole game runs behind a fake input/output seam | We have the output half (`SDL_VIDEODRIVER=dummy`); this is the input half of the same design. |
| **W6b — a creature turn that is mostly a no-op** | `web/src/game/turn.ts`: the end-of-turn routine, with the per-creature step delegated to `moveMonsters` | Same decomposition our loop needs: `for each creature: take a turn`, turn ≠ step. |
| **W6 / W4 — decide direction vs may-I-enter** | `web/src/game/monsters.ts`: `getMonsterDirection()` separated from `monsterCanEnter(terrain, monsterType)` | The decide/permit split our occupancy test and pursuit rule want, kept apart from the commit of the move. |
| **Scripted play + screenshots as a loop** | `web/tools/pilot/bot.js`, `pilot/shots.mjs` | Compare against `tools/spice86_type.py` + `spice86_screenshot.py` before writing anything new in `tools/`. |
| **CP11 enhanced mode** | README's whole stance: twelve period tile sets plus a "Standard" experience, "all of it configurable in the game's Pause menu", "not a single data file touched" | Faithfulness as a runtime setting rather than a fork — which is what `--auto-pass-polls` and `--enhanced` are reaching for. |
| **Save-format compatibility while modernising** | `web/src/game/io.ts`, `web/tools/saves/showcase.ts` | They keep the original record format and layer new state beside it; same constraint as our byte-compatible `PLAYER`. |
| **Commissioning art (process only)** | `web/docs/figure-art-spec.md`, `second-pass-brief.md`, `snake-brief.md`, `dungeon-sheet.md`, `scene-images.md` | Readable **as brief-writing process** by whoever writes our briefs. See § 4 — never handed to the artist. |
| **6502-era Apple II lineage** | LairWare's own note: "Some of the logic was originally gleaned through examining the Apple II version's 6502 assembly code. You can find comments throughout the source referring to memory locations in this version." | Interesting as a *third-party reading of Apple II Ultima*, same grade as `docs/u2-game-meta-analysis.md`: a hypothesis source. But it is U3's Apple II code, not U2's, so its transfer value to our bytes is family convention and nothing more. |

## 4. Two hazards, unchanged by the licence

1. **The cleanroom wall is not affected by MIT.** The art, the art briefs,
   `resources.json` and the tile-set sheets are derivative Ultima content. Anyone
   performing or commissioning substitute art for this project is forbidden them,
   exactly as they are forbidden `bestiary/cache/` and the U1 Unity project
   (`docs/cleanroom-procedure.md`). Reading a *brief* is a breach in the same way a
   screenshot is. MIT on the code does not launder the art.
2. **Its combat shape is the wrong shape for us.** Ultima III has a separate party
   combat mode with its own screen and turn order. Ultima II has been proven not to:
   combat is one line of the `CMD:` log in the continuous world view, with no mode
   switch and no leaves-combat state (owner ruling, screen-proven,
   `docs/spice86-live-findings.md` § 14). Borrow the harness, not the encounter
   design. If a U3 concept appears in `engine/` it needs a byte citation from `asm/`,
   never a citation from here.

## 5. Standing rule

Third-party data is a hypothesis the bytes get to veto (`AGENTS.md` § 5). Anything
adopted from this repo goes in with an `asm/` citation, or with the word *guess* and
what would settle it — plus the MIT attribution of § 2 if code actually moved. A
lesson that is generic to any DOS decompilation harness goes to
`docs/harness-portability.md` as method only; a conclusion about Ultima II stays in
`asm/` or the findings doc.
