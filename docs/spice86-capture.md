# Running Ultima II in Spice86 to capture data

How to start the game under emulation and read its live memory. Everything referenced here
lives inside this project directory.

## What you need

| Item | Path |
| --- | --- |
| Game binary and data (source) | `references/ultima2/` |
| `ultimaii.exe` | `references/ultima2/ultimaii.exe` (37,344 bytes) |
| Blank player disk | `references/ultima2/player` (384 bytes) |
| Map, monster, dialog, picture data | `references/ultima2/mapx*`, `monx*`, `tlkx*`, `pic*`, `monsters` |

Gameplay mutates files (the game rewrites `player`), so the run always copies from the pristine
`references/ultima2/` backup into a fresh, timestamped scratch directory under the project's
`tmp/` folder. Nothing is ever run in place.

External requirements:

- `dotnet` on `PATH`, .NET 8 or newer (the vendored build is self-contained .NET 10, but the
  `dotnet Spice86.dll` invocation below uses the host `dotnet`).
- A Spice86 build. **Vendored in this project** at `tools/spice86/` — set
  `SPICE86_DLL="$PWD/tools/spice86/Spice86.dll"` from the project root. See `tools/spice86/README.md`
  for provenance.
- A graphical session. Spice86 draws a window, so it needs `DISPLAY` or `WAYLAND_DISPLAY`.

## The blank player disk matters

`references/ultima2/player` is 384 bytes, all zero except the byte `0x1a` at offset `0x100`.
That exact content is what makes the game accept a new character. Any other content and it
prints `NOT A BLANK PLAYER DISK` and refuses to start.

The game writes progress back into the `player` file in its working directory. **Always copy
the data into a fresh scratch directory and run there.** The launch below copies from the
pristine `references/ultima2/` backup into `tmp/<timestamp>/`, so neither the backup nor the
`original/` working copy is ever mutated.

## Launch

```bash
# Fresh, timestamped scratch dir inside the project, sourced from the pristine backup.
RUN="tmp/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RUN"
cp references/ultima2/ultimaii.exe references/ultima2/player "$RUN"/
cp references/ultima2/mapx* references/ultima2/monx* "$RUN"/
cp references/ultima2/tlkx* references/ultima2/pic* references/ultima2/monsters "$RUN"/

cd "$RUN"
export DOTNET_ROLL_FORWARD=Major
dotnet "$SPICE86_DLL" \
    -e ultimaii.exe \
    --HttpApiPort 20180 \
    --McpHttpPort 20181 \
    --AllowIvtAddress0 \
    --Cycles 3000
```

`tmp/` here is the project-local scratch folder (disk-backed), created fresh per run and named
by timestamp so runs never collide and each is reproducible from the backup. It is **not** the
system `/tmp`, which on this machine is a tmpfs — do not use `/tmp` for run directories or
captures, because every byte written there is taken from RAM.

### Why each flag

| Flag | Reason |
| --- | --- |
| `-e ultimaii.exe` | the entry executable, relative to the working directory |
| `--HttpApiPort 20180` | the read API used for capture, see below |
| `--McpHttpPort 20181` | the MCP server, which is the only way to write memory |
| `--AllowIvtAddress0` | required, see below |
| `--Cycles 3000` | approximates the 1983 machine the game calibrates itself against |

**`--AllowIvtAddress0` is not optional.** The game does not install an INT 0 handler, so the
divide-error vector still points at `0:0`. Spice86 refuses to jump there and stops with
`Interrupt vector 0x00 points to 0:0 (uninitialized)`. That message reads like a crash and is
not one. It is the emulator being cautious about a real program's loose initialisation.

`DOTNET_ROLL_FORWARD=Major` lets a .NET 8 or 9 build run on a .NET 10 runtime.

### Display environment

A shell that was not started from the desktop session does not inherit the display
environment. Set it explicitly:

```bash
export WAYLAND_DISPLAY=wayland-0
export DISPLAY=:0
export XAUTHORITY=/run/user/1000/xauth_<your-file>
export XDG_RUNTIME_DIR=/run/user/1000
```

Find the right values for your session with `ls /run/user/1000/` and `ls /tmp/.X11-unix/`.
Wayland first is preferable, since the compositor may prefer it for the Avalonia window.

### Ports

A killed Spice86 process can leave its previous port bound for a while, and the defaults
20000 and 8081 are often taken. Probe for free ports before launching rather than assuming.

## Reading memory: the HTTP API

The API is **read-only**. It answers two shapes of request.

### Status

```bash
curl -s http://127.0.0.1:20180/api/status
```

Reports `CS` and `IP` plus the cycle count. It does **not** report `DS`, so you must know the
data segment in advance.

### Memory

```bash
curl -s http://127.0.0.1:20180/api/memory/<physical>/range/<length>
```

The path takes a **physical address**, so compute it yourself:

```
physical = segment * 16 + offset
```

The response is JSON with a `values` array of byte integers, not a raw binary body:

```json
{"values": [138, 190, 0, 4, ...]}
```

### The data segment

For this game, once the main body is running, **`DS = 0x08BE`**. Confirmed by the player name
appearing at `DS:0x36`.

To dump the whole data segment:

```bash
curl -s "http://127.0.0.1:20180/api/memory/$((0x08BE * 16))/range/65536"
```

A 512-byte window covers the player record and globals. The monster arrays sit above that
window, so a full 64 KiB read is needed for them.

## Writing memory: the MCP server

The HTTP API cannot write. Setting a value, which is how you construct a test scenario, goes
through the MCP endpoint at `--McpHttpPort`, using the `write_memory` tool with arguments
`segment`, `offset` and `data` as a hex string.

This is the only reliable way to build a controlled before-and-after: write a known value,
take an action, read the result.

## Capture pattern that actually works

The game prints text far faster than it can be read from the window, and clears it quickly.
Reading the screen is not a dependable capture method. Two approaches that are:

**1. Diff around one action.** Snapshot, perform exactly one in-game action, snapshot again,
diff. The bytes that changed are the state that action touched.

**2. Read constants out of the binary.** For anything the game only ever displays, extract it
from `references/ultima2/ultimaii.exe` directly. Scanning for printable ASCII runs of five or
more bytes recovers the whole text table.

Save the captures inside the current run directory (under `tmp/<timestamp>/`) and name them by
cycle count so a later run can be lined up against them:

```bash
curl -s "http://127.0.0.1:20180/api/memory/$((0x08BE * 16))/range/512" \
  | python3 -c "import json,sys,datetime; d=json.load(sys.stdin); \
open('u2-snap-%d.bin'%datetime.datetime.now().timestamp(),'wb').write(bytes(d['values']))"
```

## Useful offsets, once you have a dump

The player record starts at `DS:0x36`, so a save-file offset `i` corresponds to `DS:0x36 + i`.
The low page holds live state that the save file does not.

| DS offset | Meaning |
| --- | --- |
| `0x00`, `0x01` | player x, y. **Not in the save file.** |
| `0x13` | player tile id |
| `0x19`, `0x1A` | direction delta x, y |
| `0x46`, `0x47`, `0x48` | gender, class, race |
| `0x4B`..`0x50` | strength, agility, stamina, charisma, wisdom, intelligence |
| `0x51`, `0x52` | hit points |
| `0x53`, `0x54` | provisions |
| `0x58`, `0x59` | gold |
| `0x61`, `0x62`, `0x63` | readied weapon, worn armour, readied spell |
| `0x64`, `0x65`, `0x66` | torches, keys, tools |
| `0x76` | weapons array, 10 slots |
| `0x96` | armour array, 7 slots |
| `0xB6` | magic array |
| `0xD6` | items array |
| `0x137` | monster **x**, stride 1, 32 slots — see the correction below |
| `0x157` | monster **y**, stride 1 |
| `0x197` | monster **kind**, stride 1 — drives loot and behaviour; the reward switch branches on `0x60`/`0xFC`/`0xF0`/`0xF8` |
| `0x1B7` | monster **tile**, stride 1 — the byte stamped into the sector map for appearance |
| `0x1900` | town map base |

### Counters are packed decimal, not binary

Every stat and currency field is BCD. A byte of `0x99` means 99, not 153. Two-byte fields
store the **hundreds byte first**: `0x99 0x97` is 9997.

```python
def bcd(v):
    return (v >> 4) * 10 + (v & 0x0F)

def bcd16(lo, hi):
    return bcd(lo) * 100 + bcd(hi)
```

Reading these as binary is the most common way to get a wrong number out of a correct dump.

## Reading the save file

A player file is 384 bytes and is the same record as `DS:0x36` onward, so it decodes with the
same offsets minus `0x36`:

```python
b = open("player", "rb").read()
name = b[0:16].split(b"\0")[0].decode("latin1")
world, map_id = b[0x13], b[0x14]
hp   = bcd16(b[0x1b], b[0x1c])
food = bcd16(b[0x1d], b[0x1e])
gold = bcd16(b[0x22], b[0x23])
```

`map_id` values: 0 overworld, 1 village, 2 town, 3 castle, 4 tower, 5 dungeon.

Position is **not** in the save file. It lives only in the zero page at `DS:0x00` and `DS:0x01`,
so a loaded character is placed by the map loader rather than restored to a saved spot.

## Gotchas

- **Never run in place.** Copy from `references/ultima2/` into a fresh `tmp/<timestamp>/` and run there; the game rewrites `player` in its working directory.
- **System `/tmp` is RAM.** Use the project-local `tmp/` (or `/var/tmp`) for run directories and captures.
- **The API is read-only.** Writes need the MCP endpoint.
- **`DS` is not reported by the API.** Hardcode `0x08BE` or find it before reading.
- **Physical, not logical, addresses.** Multiply the segment by 16 yourself.
- **BCD everywhere.** Binary reads give plausible-looking wrong values.
- **`--AllowIvtAddress0` or it stops** with a message that looks like a crash.
