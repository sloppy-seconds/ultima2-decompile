# Passability re-decode — findings

Date: 2026-10-21. Method: one contiguous linear decode of the whole passability
routine plus the walk-loop and mode-writer regions, then a raw byte scan of the
exe for writers of the mode bytes, then a re-read of every existing capture.
Supersedes the passability paragraphs in
`docs/phase4-implementation.md § CP4b` and its `RETRACTION` subsection: both
were partly right and both were missing the same piece.

Artefacts: `disasm/tile-art.tsv` (art-entry descriptions),
`tools/tile_atlas.py` (renderer), `tmp/tiles/` (PNGs, gitignored).

---

## F1 — the passability routine does not read the target tile

Decoded span: file `0x2623..0x287F` = runtime `0x2423..0x2680`, 605 bytes,
286 instructions. This is the full routine, not the `2423..242C` stub that
`asm/2423` declares.

There is exactly **one** call to `map_tile_ptr` (`call $0x52b3`) in the whole
span, at file `0x2666` (runtime `0x2466`). Its result is not tested. The
sequence around it is a **write**:

```
265A  mov [0x6a],al        ; DS:6A = x
265D  mov [0x23],al        ; map_tile_ptr x argument
2660  mov al,[0x6b]        ; DS:6B = y
2663  mov [0x24],al        ; map_tile_ptr y argument
2666  call $0x52b3         ; DS:6 -> tile cell
2669  mov al,$0x50
266F  mov [bx+si],al       ; store 0x50 into the cell
```

So the retracted claim "asm/2423 never reads a tile" was **correct about the
bytes**. The retraction was also correct that steps are rejected. Both were
right about their own evidence and neither found where the two meet.

## F2 — a second decision ladder, previously unread

At file `0x27C0..0x27F6` (runtime `0x25C0..0x25F6`), reached after the inline
BCD `-19` food drain on `DS:53..55`:

```
27C0  mov al,[0x29]
27C3  and al,$0x7f
27C5  cmp al,$0x60 ; jne 27CC
27C9      jmp $0x2877          ; mode 0x60 -> the 0x50 stamp path
27CC  cmp al,$0x00 ; je  $0x27ff   ; REJECT
27D0  cmp al,$0x08
27D2  je  $0x27ff                  ; REJECT
27D4  cmp al,$0x22 ; je $0x2804    ; ACCEPT
27D8  cmp al,$0x24 ; je $0x2804
27DC  cmp al,$0x26 ; je $0x2804
27E0  cmp al,$0x28 ; je $0x2804
27E4  cmp al,$0x2A ; je $0x2804
27E8  cmp al,$0x2C ; je $0x2804
27EC  cmp al,$0x2E ; je $0x2804
27F0  cmp al,$0x38 ; je $0x2804
27F4  cmp al,$0x16 ; jae $0x27ff   ; REJECT
27F8  jmp $0x2804                  ; ACCEPT
```

Accept target `0x2804` -> runtime `0x2604` -> `0x2664` (mask both coordinates
with `0x3F`, return 0). Reject target `0x27FF` -> runtime `0x25FF`
(`mov al,$0xff; ret`).

The ladder branches on `DS:29 & 0x7F` only. No tile value participates.

## F3 — where the mode byte comes from

The walk-loop arms load the argument at runtime `0x0962` (`mov al,[0x15]`) and
`0x09AF` (`mov al,[0x18]`), then `call 0x2423`.

Raw scan of the exe for direct writers (`mov [x],al` = `A2`, `mov [x],ax` = `A3`,
`mov byte [x],imm` = `C6 06`):

| byte | direct writers (runtime) |
| --- | --- |
| `DS:15` | `0x5B7A`, `0x5C52`, `0x6054` |
| `DS:18` | `0x5B86`, `0x5C5E` |
| `DS:29` | `0x20B7`, `0x2423`, `0x54E8`, `0x5A7A` |
| `DS:13` | ten sites, incl. `0x2699`, `0x26A2` |

The two `5Bxx/5Cxx` blocks are a table copy, runtime `0x5B71..0x5B92`:

```
mov al,[0x2df] ; mov [0x14],al
mov al,[0x2cb] ; mov [0x15],al     ; DS:15 <- DS:2CB
mov al,[0x2f3] ; mov [0x16],al
mov al,[0x2de] ; mov [0x18],al     ; DS:18 <- DS:2DE
mov al,[0x2e0] ; mov [0x17],al
mov al,[0x13]  ; mov [0x2df],al    ; DS:2DF <- DS:13
```

**`DS:2CB`, `DS:2DE`, `DS:2E0`, `DS:2F3` have no direct writers anywhere in the
exe.** They are table entries filled by an indirect store or a block read, and
that is where the tile dependence has to enter. The static route ends here:
finding an indexed writer by byte pattern alone is guesswork.

Note `DS:29` has four writers, so it is shared scratch, not a dedicated mode
slot. Calling it "the travel mode" in `state.h` is not supported.

## F4 — DS:13 is the player stamp, not terrain

`DS:13 = 0x78` in every in-world sample: `create-test-live`, `play-test-live`,
`baseline-fight`, and all 151 turns of the `vga-test` recording. In
`create-test-live` the player stood on tile `0x0C` while `DS:13 = 0x78`. So
`DS:13` is the sprite stamped into the map, not the terrain under it, and the
`0x28/0x26/0x24/0x22` arms of the first ladder are never taken on foot.

## F5 — create-test-live is a clean controlled experiment

Same session, same character, `DS:49/4A = 2/0` unchanged, `DS:13 = 0x78`
throughout. The east step onto tile `0x00` was rejected with
`--INVALID MOVE!`; five south steps onto `0x0C` were accepted, and the final
snapshot is at `(20,25)`. The only input that differed was the tile byte.
**The decision is tile-dependent and provably not `DS:13`-dependent.**

## F6 — tool defect: redecode.py swallows code as a string

`tools/redecode.py` printed 21 bytes at file `0x27D2..0x27E6` as
`STR 't+<"t,<$t(<&t$<(t <*t'`. They are real code: `74 2B 3C 22 74 2C 3C 24 ...`
is `je rel8` / `cmp al,imm8` pairs, and the `je` displacements are what produce
the accept and reject targets in F2. The printable-run heuristic fired inside a
code region.

Consequence: any `STR` line in `disasm/redecoded/*.txt` that sits inside a known
code span must be re-checked before its output is cited. This is the same class
of failure as `cfg_printed.py` reading discovered blocks — a tool returning a
plausible answer to the wrong question.

## F7 — the fight recording cannot settle this

In the 151-turn `vga-test` recording `DS:00` spans only `4..9` and `DS:01` is
constant at `11`. Those were not the overworld position during that session.
Tile under player across the whole recording is only `{0x08, 0x0C}`.

---

## Next step

The static route is exhausted for the tile question. One breakpoint capture
closes it: break at runtime `0x2423`, dump `AL, DS:13, DS:15, DS:18, DS:29,
DS:2CB, DS:2DE` and the target cell tile, on one accepted and one rejected step.
If `DS:2CB`/`DS:2DE` differ between the two, the table is terrain-indexed and F3
completes. If they do not, the reject comes from the `call 0x2575` return value
and the search moves into the `DS:580` dispatch.
