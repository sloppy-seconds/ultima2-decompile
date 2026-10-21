# Tooling procedures — driving the live game

First entry in this file, created 2026-10-21 because the knowledge below existed
nowhere in the repo and had to be recovered from a sibling project on the owner's
say-so. That is the failure mode this file exists to prevent: procedure that lives
only in someone's memory gets rediscovered expensively, or wrong.

Scope: how to send input to a running Spice86 session, and how to make the arrow
keys work. Reading state is covered by `docs/spice86-capture.md` and
`docs/spice86-live-findings.md`.

## Provenance discipline used here

`AGENTS.md § 0` forbids importing **conclusions about this binary** from sibling
directories, and permits reusing **generic, binary-agnostic tooling**. This page
mixes both, so every line is graded:

| grade | meaning here |
| --- | --- |
| `local:measured` | confirmed against `original/ultimaii.exe` or a live session in this project |
| `local:inferred` | reasoned from a local read, not yet observed |
| `sibling:hypothesis` | came from `~/Projects/ultima2/ai-crawler`, adopted only as something to verify here |

Nothing graded `sibling:hypothesis` may be relied on until it is re-derived
locally. Note that the sibling project addresses its segments differently
(`199F:4F4D`, `0B2A:4542`) from this one (`DS = 0x08BE`), so their numbers are not
transcribable at all — a concrete demonstration of why the isolation rule exists.

## Sending keys to the game window

All of this is generic X11/SDL behaviour. `local:measured` on this host.

1. **The window must be focused.** Use
   `xdotool search --class Spice86` then `xdotool windowactivate --sync <id>`,
   then a global `xdotool key <keysym>`.
   **Never** `xdotool key --window <id>`: that uses XSendEvent, which SDL ignores
   by design. It exits 0 and does nothing, which is the worst possible failure mode.
2. **Discover `DISPLAY` and `XAUTHORITY`, never hardcode them.** The xauth filename
   carries a random suffix (`/run/user/1000/xauth_MtixFQ` today) and changes per
   session. This agent's shell has `DISPLAY` unset while X `:0` is reachable, so
   assuming the environment is inherited will silently fail.
3. **A multi-key command has a timing WINDOW, not a minimum.** Send bursts as one
   invocation, `xdotool key --delay 30 k1 k2`. Per-key invocations add
   process-start jitter. Too tight and the game's key read discards the second
   key; too loose and a direction prompt expires into `PASS`.
   `sibling:hypothesis` on the exact boundaries (drain loop discards pending keys;
   ~2 ms to ~1500 ms works, 0 ms fails, 2000 ms expires). The 30 ms default is
   adopted as a starting value and must be re-measured here before it is trusted.
4. **A send is not a move.** `xdotool` returning 0 means dispatched, not landed.
   The game ignores input during its busy-wait, and a dropped key is
   indistinguishable from a blocked move. Always confirm by reading state.
   This is load-bearing for passability work: never conclude "impassable" from a
   position that did not change without proving the key arrived.
5. **NumLock must be read, not toggled blindly.** `xset` and `numlockx` are both
   absent on this host; python-Xlib `get_keyboard_control().led_mask` works, with
   NumLock at bit 1. A blind toggle is as likely to turn NumLock on as off.
   `local:measured` — NumLock read as off on this machine, matching Xlib.
6. **Never send a confirm key blind.** `sibling:hypothesis`: `Y` is the YELL
   command and takes a text argument, so a `Y` sent when no shop is open starts a
   yell prompt and every later key is eaten as yell text. Not verified here yet,
   but it is cheap to respect: confirm state before sending argument keys.

## Arrow keys and the AL==0 gate

The game maps an extended scancode to a direction character through a four-entry
table, but only when DOS reports a zero character byte.

`local:measured` — confirmed against `original/ultimaii.exe` on 2026-10-21:

```
runtime 0x4F85 (file 0x5185)
  3C 00     cmp al,$0x00
  75 48     jne  $0x4FD1        ; AL != 0 -> skip translation, return ah=0xFF
  ...
runtime 0x4FBB
  mov bx,$0x6
  cmp ah,[bx+0x4f09]            ; the table matches on AH only, never AL
  je  translate
  sub bx,$0x2 / js give_up / loop
translate:
  mov al,[bx+0x4f0a]
```

Scancode table at `CS:0x4F09` (file `0x5109`), four pairs:

```
48 -> 0E    50 -> 19    4D -> 05    4B -> 17
```

`local:measured` corroboration: live captures read `DS:26E..271 = 0E 19 05 17`
across four independent sessions, which is exactly the mapped-char set above.

`sibling:hypothesis`: Spice86 delivers a real arrow as `AX = 0x48E0`, i.e. the
extended prefix `0xE0` in AL where DOS would put `0x00`. **Unverified here.**
The first live use of these tools must test it: send a real arrow unpatched and
confirm nothing moves, patch, confirm it moves.

### The patch

Because the table lookup keys on `AH` alone, the `AL` gate is the only obstacle.
`tools/patch_arrows.py` replaces the two-byte conditional jump at file `0x5187`
with a no-op (`75 48` -> `90 90`), so both `AL=0x00` and `AL=0xE0` reach the
table.

Accepted side effect: with NumLock **on**, numpad 8/4/6/2 arrive as `AL='8'` etc.
with `AH` in `{48,4B,4D,50}` and would be read as arrows. Those scancodes belong
to no letter key, so nothing else is affected, and `spice86_keys.py` forces
NumLock off to remove the case entirely. A tighter gate (accept exactly `0x00`
and `0xE0`) does not fit the 4-byte slot and would require relocating code; that
trade was considered and rejected as more invasive than the problem.

Guards in the tool, all verified 2026-10-21: refuses any path not under `tmp/`,
refuses if the scancode table is not the expected eight bytes, refuses if the gate
bytes are not `3C 00 75 48`, is idempotent, and proves the write by reading it
back. `original/` md5 `fe884d5117971073ac8097cc7a6aca25` unchanged after testing.

## Usage

```sh
# start a windowed run with real arrows working
tools/spice86_start.sh --name walk-test --player tmp/<prev>/player --patch-arrows

# what can it see?
python3 tools/spice86_keys.py --status

# one step east, then confirm by reading state (never trust the send alone)
python3 tools/spice86_keys.py --key Right

# a two-key command, e.g. talk-then-north
python3 tools/spice86_keys.py --burst T Up
```

`--arrows kp` falls back to numpad spelling for a stock binary, which works
unpatched but reintroduces the NumLock problem. Default is `real`.

## Not done yet

- The `0x48E0` claim is unverified. First live run must test it.
- The burst-delay window has not been re-measured on this project's binary.
- No `--patch-arrows` test has been run end-to-end against a live emulator; the
  patcher is proven against a file copy only.
