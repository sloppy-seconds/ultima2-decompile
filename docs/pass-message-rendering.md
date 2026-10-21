# Why `PASS` and other transient messages never appear

Investigated 2026-10-21. This is a **negative-result note**: its value is the list
of things that are provably not the cause, so nobody re-chases them.

## Symptom

Ultima II text drawn onto an already-displayed screen never appears under
Spice86: `PASS`, combat misses, vendor transactions, conversation lines.
Initial paints are fine - splash, world, status band, `CMD:` all render.

DOSBox-X shows the same executable correctly: `CMD: PASS` appears, lingers, and
scrolls up as new lines push it. So the game does produce the text and a correct
emulator displays it.

## The load-bearing fact

The message band is **at its resting value at every frame boundary**, and when it
does change it holds the new value for exactly one frame.

Measured with write-time instrumentation inside `VideoMemory.WriteValue`, hashing
the message band on every band write, alongside a band hash at each published
frame:

```
DBGVID bandhash CHANGED 44A91FE7 -> 024BE82D  window=34
DBGVID bandhash CHANGED 024BE82D -> 44A91FE7  window=0
```

That pair repeats once per `P` press. `window=0` on the return means the band
reverted on the very next frame. Every `bandwrite` line reported
`spanningFrameBoundary=False`.

Corroborated independently, without instrumentation: comparing the bottom band
(y=160..199) of real published screenshots taken via the MCP `screenshot` tool
gave **0 px differ** across every captured frame, while the world area above it
differed by 3112 and 1600 px. Two methods, same answer, so this is not an
instrumentation artifact.

**Consequence: any fix inside the render pipeline is provably useless.** The
content is not in VRAM when a frame is rendered, so no amount of frame-skip,
handoff, or publish-logic change can surface it.

## The static finding

`asm/3DBC_cmd_P.asm` is the entire `P` handler:

```
cmd_P:
        call L_0051df          # str_out - prints the inline string below
        db "PASS",0        # string
```

Eight bytes. **There is no delay, no wait, and no retrace synchronisation in the
PASS path.** It prints and falls straight through into the following code.

So the on-screen lifetime of `PASS` is not governed by any wait the game
performs. It is governed entirely by how long the subsequent turn processing and
redraw take. Under Spice86 that is one frame (~14 ms at the measured 70 fps).
Under DOSBox-X the same code leaves the line up long enough to read, which means
the difference is in the **redraw cadence downstream of the handler**, not in
anything the handler does.

This also retires the framing of the bug as "a wait that isn't waiting". There
was never a wait here to collapse.

## Hypotheses tested and killed

Each was killed by an experiment or by code, not by intuition. Recorded because
five of them looked sound.

| hypothesis | killed by |
| --- | --- |
| Frame skipping drops the update | forcing `isDirty = true` in `BeginFrame` so no frame is ever skipped - no change |
| A `CompleteFrame` guard can catch a late write | same test; no effect. Also unsound: publishing there emits an already-rendered back buffer |
| The single-slot UI handoff discards intermediate frames | raising `ScreenRefreshHz` from 60 to 240, above the measured 70 fps publish rate - no change |
| The emulator outruns the display | measured publish rate ~70 frames/s, i.e. ~1.17x real time; and the 240 Hz test covers it |
| CGA writes bypass dirty tracking | one `VideoMemory`; all four write modes call `WriteValue`, which sets `_hasChanged`; a write-time counter confirmed ~50k epochs per 60 frames once its filter was fixed |
| Hardware scroll via CRTC start address is ignored | `Renderer` latches `ScreenStartAddress` at `BeginFrame` |
| The message band is pushed below the visible region | `ScreenRows` 24 x 8 = 192 lines, renderer draws 200, so the BIOS model is *smaller* than the drawable area, not larger |
| The game never writes the text | write-time band hashing shows it does, briefly |

## Instrumentation caveats, so the numbers are read correctly

Two artifacts occurred and are worth knowing about.

1. **A wrong offset filter produced a false "writes bypass `WriteValue`"
   result.** The counter initially gated on `offset >= 0x4000`. `offset` is
   relative to `MiscellaneousGraphicsRegister.BaseAddress`, which is `0xB8000`
   for CGA colour, so the mode-4 framebuffer is offsets `0x0000..0x3FFF` and the
   filter excluded all of it. The counter read a suspiciously round 32768 and
   then `+0` forever. Inverting to `offset < 0x4000` made it move immediately.
   Any future probe must use `GraphicVideoMemorySegment = 0xA000` and remember
   the base is mode-dependent.
2. **Frame-boundary band hashes and write-time band hashes hash different
   representations** - one the published pixel buffer, one raw VRAM via a
   hand-written mode-4 row formula. They were only ever compared within their own
   family. Do not compare across families.

Also: HTTP memory reads pause the CPU, so a rate measured across them is
deflated. An early "0.63x real time" figure was wrong for exactly this reason;
the frame counter's 70 fps is the trustworthy number.

## What is still open

The question is now narrow and different from the one we started with: **what
determines how long the message band holds its new content before the redraw,
and why is that one frame under Spice86 but readable under DOSBox-X?**

Since `cmd_P` contains no timing, the answer is in the code that runs after the
command handler returns - the turn tick, the scroll, and the next `CMD:` prompt.
Useful next steps, in order:

1. Read the main loop after command dispatch: `asm/087D_cmd_prompt.asm` and the
   turn/scroll path, looking for anything that paces the redraw - a retrace wait,
   a speaker tone, a poll loop, or a dependency on input latency.
2. Compare emulated frames-per-turn between Spice86 and DOSBox-X. If DOSBox shows
   the line for, say, 20 frames and Spice86 for 1, the difference is how much
   work happens between the print and the redraw, not a broken wait.
3. Consider whether the correct emulator behaviour is to **publish on band
   change** rather than only on frame boundaries - i.e. treat a message-band
   write as an immediate publish. That is a design question for upstream, not a
   bug fix, and it would need the `spanningFrameBoundary` data to justify it.

## Static follow-up: there is no wait anywhere in the PASS path

Followed the handler and its BIOS usage on 2026-10-21. This retires the
"collapsed wait" framing entirely.

**The game uses exactly three INT 10h functions**, one call site each:

| `AH` | meaning | where |
| --- | --- | --- |
| `00h` | set mode | one of `4A3E`/`4A46`/`4A4E`/`5025`/`503D` |
| `02h` | **set cursor position** | `asm/51FD_str_out_core.asm` |
| `06h` | **scroll up window** | one site |

`str_out_core` is only the cursor half: it loads `DH=row`, `DL=col` from
`DS:2F`/`DS:2E`, `CX=1`, `BH=0`, `AH=02h`, `INT 10h`. The measured cursor was
`(5, 23)` - the **last row of the 24-row BIOS model**, which is where a scroll
onto the bottom row lands.

**INT 16h is used at exactly one site**, `asm/4F4D_key_poll.asm`: `AH=01h`, the
*non-blocking* keystroke check, with 23 call sites. There is no blocking
`AH=00h` wait in the PASS path.

**No `INT 1Ah` exists**, and `0x40:6C` (BIOS tick counter) is read only at
startup in `asm/0100_sub_0100.asm` as the RNG seed. So there is no timer read
that could be pacing a message.

Conclusion: the earlier candidate list - keyboard busy-wait, tick-counter poll,
retrace wait - is **statically dead**. Nothing in this path waits on anything.

**Spice86 does implement `AH=06h`**: `VgaBios.cs:885` maps `0x06 -> ScrollPageUp`,
through `VgaFunctionality.VerifyScroll` to `Scroll()`. `Scroll` for `lines > 0`
does `MoveChars` then `ClearCharacters` on the vacated row, and a
`GraphicalMoveChars` path exists, so the implementation is mode-aware rather
than naively text-only.

### The remaining candidate

`AH=06h` scroll-up in **graphics mode 4**, with the cursor on the last row of a
24-row model while the renderer draws 25 rows. If the scroll window coordinates
(`CL`/`CH`/`DL`/`DH`, `AL`=lines, `BH`=attribute) that the game passes are
interpreted against a row count that disagrees with what is drawn, the scrolled
line can be cleared or land off the hashed band - which matches the measured
A->B->A `window=0` signature.

Next measurement, now pointed at one specific call rather than the whole
pipeline: log the `AH=06h` parameters every time `P` is pressed, and compare
against the same call captured under DOSBox-X. That is a single narrow probe.

## State of the tree

All instrumentation was removed and verified by reading the lines back. Branch
`fix/video-frame-skip-drops-updates` in `~/Projects/ai/spice86` is identical to
`master` at `6f27fcd`, nothing uncommitted. The `CompleteFrame` guard tried
during this investigation was dropped, since this note shows it cannot help.
