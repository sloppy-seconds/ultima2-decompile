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

## The vendored build now carries our fix for this (2026-10-21)

Everything in the next section stays true of **stock upstream**, and is kept because it
explains a failure mode worth knowing. But the build in `tools/spice86/` is now built
from source and patched, so `local-mcp_screenshot` **works** here.

| Field | Value |
| --- | --- |
| Upstream | `https://github.com/OpenRakis/Spice86` (not `pcj/Spice86`; older notes here named the wrong org) |
| Base commit | `6f27fcde79a1d095ab62a8ca0dffce533613bdcd` |
| Local patches | `0b3ae43` - screenshot returns base64 via `ImageContentBlock.FromBytes`; `350f5a3` - graphics-mode scroll copied zero pixels and blanked the rows |
| Patch branch | `~/Projects/ai/spice86` @ `8af7f5f`, branch `combined/screenshot-and-scroll` (both fixes merged, with tests) |
| Binary MD5 | `fec0a93f644bd056f5c14fcf93f8f0a3` |
| Built from | `~/Projects/ai/spice86`, `dotnet publish -c Release -r linux-x64 --self-contained true` |
| Superseded | `130a5afc4631f6a03da5b07289a85d92` (screenshot fix only, still carried the scroll bug) and `7cd72fff632e63f9ba5f40e1f41d5a51` (stock). Both deleted. |

The scroll patch matters for capture work, not just play: until it was applied the emulator
silently destroyed every message the game printed, so any screenshot taken after a `PASS`, a
combat result or a shop transaction showed the wrong text. Verify a build with
`/var/tmp/u2-verify.py <dll> <tag>`, which checks both patches in one run.

The previous vendored build had been copied out of a sibling project, which is what the
isolation rule forbids; this one is built from a clone this workflow owns. Full patch
detail is in `tools/spice86/LOCAL_PATCHES.md` (untracked, it lives in the build dir) and
the summary above is the tracked record.

**The bug, in one line:** `Data = pngBytes` assigned raw bytes to a property the SDK
documents as base64, so the PNG went through a UTF-8 text decode and every byte >= 0x80
became U+FFFD - including the `0x89` that opens every PNG. Lossy, so unrecoverable.

`tools/spice86_common.sh` now honours `U2V2_SPICE86_DLL` to point at a different build
without editing, which is how the A/B test above was run.

## `local-mcp_screenshot` is broken upstream, and the frame is unrecoverable

**Measured 2026-07-21 by calling the emulator's MCP endpoint directly at
`http://127.0.0.1:20181/mcp`, bypassing the pi adapter entirely.**

The tool returns a PNG, but Spice86 **decodes the PNG bytes as UTF-8 text**
before serialising them into the JSON `data` field. Observed response fragment:

```
"data":"\uFFFDPNG\r\n\u001A\n\u0000\u0000\u0000\rIHDR..."
```

The PNG magic is `89 50 4E 47 0D 0A 1A 0A`. The first byte, `0x89`, is not valid
UTF-8 on its own, so it arrives as U+FFFD. Every byte >= 0x80 is destroyed the
same way, and a deflate-compressed PNG is mostly such bytes.

Consequences:

* pi's `Invalid Base64 string` error is **correct** - it is rejecting garbage.
  The bug is in Spice86, not the adapter. Do not go looking for the fault in pi.
* The image **cannot be recovered** from the response. U+FFFD is lossy; there is
  no re-encoding that gets the bytes back. Verified: scanning the raw response
  for the PNG magic and IEND markers finds neither.
* The MCP endpoint is `/mcp` (not `/`, `/sse`, `/message`, `/tools`), and the
  tool name over the wire is `screenshot`, not `local-mcp_screenshot`.
* The plain HTTP API on 20180 has **no** frame or screenshot endpoint. Its full
  advertised list is memory byte/range, status, status/pause, status/unpause.

So the only ways to see the screen are (a) decode video memory ourselves, or
(b) capture the window with a real screen tool. See below.

## Capturing the screen instead

`read_video_state_detailed` over MCP is reliable and is the right way to learn
the mode: it reported `BiosVideoMode 4`, 320x200, 2bpp, `MemoryModel Cga`,
`StartSegment 47104` (= 0xB800), `BufferSize 64000`.

Decoding `0xB800:0` by hand (16000 bytes, 4 px/byte, leftmost in bits 7:6) gave
**legible text** - `CMD:` reads correctly - and visible tile motifs, but the
vertical order was wrong. Real CGA mode-4 interleaving
`off = (y AND 3)*4000 + (y SHR 2)*80` and plain linear both produced nearly
identical scrambled output, so the row mapping is not the remaining problem;
the likely cause is sampling between the game's staging write and its flush.
This is unresolved.

The untried alternative is a real capture tool: `spectacle`, `import`
(ImageMagick) and `ffmpeg` are all installed, and **capture needs only a mapped
window, not focus**. `xdotool search` for the window id plus `import -window
<id>` should work on an XWayland window even though synthetic focus does not.


**Measured 2026-10-21, and it overrides everything below this section.**

## Which input path actually works on this host

**Correction, same day.** The paragraph below blamed the absence of a window
manager. That was wrong and is kept only as a warning about diagnosing from one
symptom. This host runs **KDE Plasma on Wayland** (`kwin_wayland --socket
wayland-0 --xwayland-display :0`), so a compositor absolutely exists. The real
cause is Wayland: **XWayland refuses synthetic focus and activation**, so
`xdotool windowfocus --sync` sets a property and returns 0 while KWin never hands
the real focus to SDL. Every layer reports success; the input goes nowhere.

Separately, **capture does not need focus, only a mapped window** - so
`xdotool search` for the window id plus `import -window <id>` (ImageMagick is
installed, as are `spectacle` and `ffmpeg`) can grab the emulator frame even
under XWayland. It was input that was blocked, not output.

There is **no Xvfb, Xephyr, Xvnc, Xnest or weston** on this host, and Bazzite is
rpm-ostree immutable so installing one needs a reboot. `podman` is available and
`fedora:44` is cached locally, which is the route to a real virtual display — and
that route is now built: `deploy/spice86-novnc/` runs the emulator inside a container
with its own Xvfb, x11vnc and noVNC, so a headed capture needs nothing from the host.
`tools/vnc/` is the older, engine-only variant of the same idea.

---

**Original (partly wrong) note:**

`xdotool` does **not** deliver keys to Spice86 on this machine. The chain that
fools you: `xdotool search --class Spice86` finds the window, `windowfocus
--sync` sets X input focus and reports success, and `xdotool key` exits 0. None
of it works. Keys vanish silently. Every layer reports success.

The working path is the emulator's own MCP: `local-mcp_send_keyboard_key` with
`{key, isPressed}`, called twice for down then up. It needs no window manager,
no focus, and no display at all. That is almost certainly why the sibling project
mentions `MCP send_keyboard_key` alongside xdotool.

Two more live findings about driving the emulator:

* **HTTP memory reads pause the CPU.** The log shows `Pause requested by thread
  '.NET TP Worker': GET /api/memory/...`. Reads still return correct data and
  the emulator reports `isPaused: false` shortly after, but a read is not a free
  peek — sequence accordingly when timing matters.
* **`/api/status` is the state endpoint** (`isPaused`, `cycles`, `cs`, `ip`).
  Sampling `cs:ip` twice is the quickest proof the guest is alive: the game was
  caught at `017D:4FD3`, which is the no-translation exit of the key handler.

`tools/spice86_keys.py` is therefore **not usable on this host as written**. It
correctly reports `window: NOT FOUND` / focus failures rather than pretending,
but the underlying approach needs a window manager. Either run under a WM, or
add an MCP transport. Do not assume the xdotool path works just because the tool
exits 0.

## Sending keys to the game window

The rules below are generic X11/SDL behaviour and remain true wherever a WM
exists; they were confirmed here only in the negative.

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
