# External reference — the 2000 unofficial Windows port

Status: **quarantined, not mined**. Added by the owner on 2026-10-29 into
`references/win/`, gitignored by the blanket `references/` rule.

This is **not** the DOS binary and not evidence about it. It is a third party's
1999-2000 **rewrite** of Ultima II as a native Win32 program, plus a set of
third-party planet map files. Both halves are hypothesis-grade at best, and one of
them is worse than that — see § 4.

## 1. Provenance

| | |
| --- | --- |
| Product | "Windows Native Ultima II", version 1.01 |
| Author | John Alderson (`alderson@iserv.net`), signs the binary as `Aldersoft` |
| Dated | executable 2000-01-09 17:39; readme changelog: 1.0 released 2000-01-01, 1.01 on 2000-01-09 |
| Upstream URL in readme | `http://www.iserv.net/~alderson` (not checked, almost certainly dead) |
| Copyright lines | game `1983, 1989 by Lord British and Origin`; executable `2000 by John Alderson` |
| Obtained | by the owner, provenance outside the pack is **not well known** — that is the whole reason this file exists |
| Contents | `Ultima2.exe` (301056 B), `Windows Readme.txt`, `Font.txt`, 8 `MAPGnn`, 3 `MONGnn`, 2 `TLKGnn`, and `WinUltima2.zip` (the same 16 files, verified byte-identical: exe md5 `2d2924347dce5b237f6e7e4ede0e9511` in both) |

The readme is unambiguous about what it is: *"an early eighties game brought to its
knees by a quick and dirty port to Windows"*, it *"uses all of the same data files"*,
it installs by unzipping **into an existing Ultima II directory** beside
`ultimaii.exe` (the DOS one), and *"You MUST own a legal copy of Ultima II to play
this game, it uses the data and I do not and can not provide it."*

## 2. Rewrite, not recompilation — the evidence

The question asked was whether the exe might be a recompile of the DOS code. It is
not, and four independent things say so:

* **It is a PE32 Win32 GUI binary for i386.** The DOS original is a 16-bit real-mode
  `.EXE`. There is no shared object format, no shared calling convention, no shared
  runtime.
* **It is MFC.** The binary carries `CBitmap`, `CMapPtrToPtr`, `CMapStringToPtr`,
  `CCommonDialog`, `UCThreadData` and the Microsoft Visual C++ runtime library, and
  imports `user32`/`GDI32`/`comdlg32`/`comctl32`/`shell32`. A 1983 hand-written
  assembly game contains no C++ classes.
* **It draws with GDI, not the DOS video seam.** `CreateDIBitmap`, `CreateBitmap`,
  `ColorMap%d` — and the readme's own future plans say *"I hope to resolve the
  performance issues with a DirectDraw version at some time"*, i.e. no DirectDraw
  yet in 1.01.
* **The author states the divergences himself** (§ 3). Nobody who had reproduced the
  original's arithmetic would write that paragraph.

So the machine code encodes one person's interpretation of Ultima II, compiled by a
C++ compiler seventeen years after the fact.

## 3. The author's own list of places where it disagrees with the original

Quoted or paraphrased from `Windows Readme.txt`. This is the most useful thing in
the pack, because it is a third party telling us in advance where his version is not
comparable:

| his words | what it means for us |
| --- | --- |
| *"the way the DOS program did random numbers and mixed number formats (it's a long story), this proved to be very difficult at times to get 100% accurate, so there are some differences in some of the calculations"* | He could not reproduce the BCD/RNG behaviour. Our own BCD work (`tools/bcd_census.py`, the `cmc; sbb; das; cmc` idiom) is exactly the thing he gave up on. |
| *"most notably the outer space system... your ship can now drift to adjacent sectors after a while"* | Space is a **changed design**, not a port. Nothing here may be read as evidence about CP7. |
| *"I have tried to preserve the original 'feel'... as much as was convenient"* | Self-declared approximation. |
| *"there is also no sound"* | The PC-speaker seam is simply absent, so it says nothing about our `speaker_tone` sites. |
| *"Dungeons (and outer space) may look slightly different"* | Consistent with dungeons being parked (§ AGENTS.md § 3). |

## 4. The MAPG set — third-party *content*, and the sharper hazard

The readme: *"The zip file includes the missing planet maps. Special thanks to Mike
Marcelais, The Moonstone Dragon for making these available."*

So the `MAPGnn`/`MONGnn`/`TLKGnn` files are **not Alderson's and not Origin's** —
they are a community archivist's data, bundled because his copy lacked them.

**Format.** They are the bare grid with the trailer stripped, which is consistent
with `docs/map-format.md`:

| | ours | his |
| --- | --- | --- |
| sector map | `mapxNN` 4224 B = 4096 grid + `0x1A` marker at `0x1000` + 127 B trailer | `MAPGNN` 4096 B, no trailer |
| monster data | `monxNN` 384 B | `MONGNN` 256 B |
| talk data | `tlkxNN` 384 B | `TLKGNN` 256 B |

**Content: different maps.** Measured against `original/mapxNN[0:4096]`, bytes equal:

| pair | equal | note |
| --- | --- | --- |
| MAPG45 / mapx45 | 67% | same 7 distinct tile values, near-identical distribution — closest to a match |
| MAPG15 / mapx15 | 64% | |
| MAPG10 / mapx10 | 55% | |
| MAPG40 / mapx40 | 46% | |
| MAPG20 / mapx20 | 31% | |
| MAPG32 / mapx32 | 27% | |
| MAPG41 / mapx41 | 11% | 32 distinct values vs our 45 — a different map, not a re-encoding |
| MAPG30 / mapx30 | 9% | values `{0,4,8,16,24}` vs our `{0,4,8,12,16,36}` |

**This is the trap.** The files sit in `references/`, they are genuine Ultima II
data, they use our exact tile encoding, and they came from a respected archivist. A
diff of `mapx30` against `MAPG30` produces 91% mismatch and invites the conclusion
"our sector-grid decode is wrong." It is not wrong. The bytes differ because they
are **different maps**. Anyone who reaches for these files to check a map-format
finding must first state which of the two is the shipped content — and the answer is
always `original/`.

## 5. What is actually missing from our corpus

Worth recording because his pack does **not** fill it. Per G44 (`docs/save-format.md`
§ 10) the sector tens digit is the world: 0 Earth, 1-9 planets, `0x0A` deep space.

| world | our `mapx` | his `MAPG` |
| --- | --- | --- |
| 0 Earth | `00`, `03` | — |
| 1 | `10`, `11`, `15` | `10`, `15` |
| 2 | `20`-`25` | `20` |
| 3 | `30`-`35` | `30`, `32` |
| 4 | `40`, `41`, `44`, `45` | `40`, `41`, `45` |
| **5-9** | **none** | **none** |

Worlds 5 through 9 have no map data in either pack. Our 33 sectors are complete
relative to what he supplied, and the real gap is nine worlds deep. That is a
corpus fact about CP7 (space travel), not a defect to chase in this binary — the
shipped content simply does not describe those planets' terrain.

## 6. Standing rules

1. **`Ultima2.exe` is never a source of truth about `original/ultimaii.exe`.** No
   decode, address, struct, table or behaviour may be justified by it. If a claim
   about visible behaviour is taken from here it is graded `inferred` and needs a
   capture, same as any other guess. It is the same class as `references/ultima3/`:
   a hypothesis generator, and a *more* dangerous one, because it claims to be the
   same game, reads the same data files, and prints in our own voice (`AH! YES! A
   %s`, `A LEVEL %.2d %s %s %s`).
2. **The MAPG/MONG/TLKG files are never diffed against `mapx`/`monx`/`tlkx` as if
   they were a second copy of the shipped content.** They are substitute data. They
   may be cited as a second *format* sample only, with this file's § 4 divergence
   table attached.
3. **Nothing in `references/win/` is committed.** It is copyrighted game content plus
   a copyrighted third-party executable. The blanket `references/` gitignore already
   covers it; do not `git add -f`.
4. **Do not delete it either.** The hazard is an agent reading it without knowing what
   it is, and this file is the fix. A bare `references/win/` with no note is the
   dangerous state, not a present-and-documented one.

If anything generic about harness design comes out of this (as opposed to conclusions
about Ultima II), it goes to `docs/harness-portability.md` as method only.
