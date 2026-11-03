# Options menu (Ctrl-O) — design proposal

Status: **design only, not built.** Owner idea, 2026-11-04. Several decisions below are
explicitly left open for the owner; this doc frames them, it does not make them.

## 1. Why

The engine already has a scatter of "make the game behave a bit differently" surfaces that
were each decided in isolation and none of which has a UI:

- **Enhanced-mode knobs that are launch-only today:** `--enhanced`, `--keep-site-state`,
  `--auto-pass-polls`, and the save policy (`U2_SAVE_POLICY_ENHANCED`). All are argv flags
  read once at startup.
- **A cheat system that is scoped but unbuilt:** `docs/phase4-state.md` § "TODO:
  enhanced-mode cheat codes behind `cmd_Y`" (owner, 2026-10-29) — Doom-style codes typed
  through `Y`, enhanced-only, every cheat announces itself.
- **A graphics-set switch that is proposed but unbuilt:** `docs/ega-graphics.md` (the
  `--ega` flag for the fan pack's 16-colour `PIC*-E` art).

An in-game options menu is the single surface that ties these together instead of three
ad-hoc ones. The owner's framing: a `Ctrl-O` binding that opens a menu to change settings —
enable cheats, switch graphic sets, and so on.

## 2. What already exists to build on

- **Ctrl-key precedent.** `--dev` already binds Ctrl-Q to end a run (`engine/src/main.c`).
  Ctrl-O is the same class of engine-only affordance.
- **A global input seam.** The overworld command loop reads keys through `seam_key_poll`
  (`engine/src/game/overworld.c`); ESC is already special-cased there. A menu key is checked
  above the command dispatcher, not as a `cmd_` letter — the 26 letters are the original's
  space and Ctrl-O is not one of them.
- **No settings model yet.** Everything is argv; there is no `u2_settings` struct. That is
  the main new thing this proposal introduces.

## 3. Decisions to make (owner)

### D-A. Menu vs `cmd_Y` — one surface or two?
Cheats already have a decided home (`cmd_Y`, as a deliberate id-nod). Options:
1. Menu = settings/presentation (graphics, sound, QoL toggles, enhanced knobs); `cmd_Y`
   stays the typed-cheat entry. Two surfaces, different feel.
2. Menu absorbs cheats too; `cmd_Y` reverts to the byte-faithful no-op the original has.
Recommend (1): typed cheat codes and toggle settings are different interactions, and (1)
keeps the owner's `cmd_Y` nostalgia intact. **Needs the owner's call.**

### D-B. Live-switchable vs launch-only
Fidelity mode is documented as "never switched mid-run" (`engine/src/core/ctx.h`). The menu
needs a rule per setting:
- **Safe live:** graphics set, sound on/off, screen scale — pure presentation.
- **Runtime toggles:** cheats (each effect announces itself per the 2026-10-26 rule).
- **Launch-only (show read-only in the menu):** fidelity mode, save policy,
  keep-site-state — structural, flipping them mid-run would corrupt the model the run was
  built on.

### D-C. Persistence — the sharp constraint
Settings must **not** be written into the `player` save record: that record is byte-compatible
with the original and `tools/save_cross_load.py` proves it; adding engine settings would break
that guarantee. Options:
1. Session-only (menu edits override launch flags for this run; reset on relaunch).
2. A sidecar config file (e.g. `u2.cfg` next to the save), separate from the player record.
Recommend: start session-only (1), add a sidecar (2) later if players want it to stick.
**Needs the owner's call on whether it should persist at all.**

### D-D. Hook point and scope of "everywhere"
The menu should open from overworld, dungeon, shops, and creation alike, so the key check
sits above the command dispatcher in the main frame/input loop, not inside one handler.
Confirm the menu is available in original mode too (it changes nothing about the rules, so
it arguably should be) or enhanced-only.

## 4. Recommended first slice (self-contained, gates cleanly)

A `u2_settings` struct on `u2_ctx`, seeded from the launch flags, plus a `Ctrl-O` menu shell
that renders and edits the **already-existing** enhanced knobs (session-only, no save-record
writes). This creates the slot that cheats and graphics later drop into, and needs neither
the EGA pipeline nor the cheat parser to be useful.

Follow-on slices, each independent:
- Graphics-set row — depends on `docs/ega-graphics.md`.
- Cheat row(s) — depends on the `cmd_Y` cheat build and D-A.
- Persistence (sidecar) — depends on D-C.

## 5. Non-goals

- Not a save-game UI, not a key-rebinding UI (out of scope unless the owner wants them).
- Not changing original-mode gameplay. The menu is presentation and enhanced toggles only;
  original mode stays byte-faithful.
