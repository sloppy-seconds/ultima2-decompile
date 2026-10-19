# Phase 3 Implementation Log

Running log for `docs/phase3-plan.md`. One section per checkpoint.

---

## CP0 — Baseline & workspace — done 2026-10-20

Re-verified all §1 invariants before touching anything:

| Check | Result |
| --- | --- |
| `original/ultimaii.exe` md5 | `fe884d5117971073ac8097cc7a6aca25` ✓ (matches plan §1) |
| `bash tools/assemble_all.sh` | `REBUILD BYTE-MATCH: 37344 bytes identical` ✓ |
| `disasm/function-map.tsv` | 1300 lines = header + **1299 functions** ✓ |
| `disasm/functions/*.asm` | 1300 files = 1299 per-function slices + `_prologue.asm` ✓ |
| jwasm availability | `$JWASM` = `tools/jwasm/jwasm` (v2.21, vendored). Smoke test: `.model tiny` source assembled with `-bin -Fo=out.bin` → correct bytes (`mov ax,1; ret` = `b8 01 00 c3`), exit 0 ✓ |

Notes learned at CP0:

* jwasm invocation quirks confirmed empirically: options are **case-sensitive**
  (`-bin -Fo<file>`); a bare `/?` is treated as a filename and errors harmlessly;
  with `-bin` the `end <start>` label must be the first code offset (`.model tiny` +
  `.code` works). Error text goes to stdout **and** a `<name>.err` file next to the
  source — keep invocations inside `tmp/` as the plan says.
* Slice file naming is bare 4-hex-digit segment offset (`disasm/functions/4FDF.asm`),
  which `check_func.py` (CP1) will key on: `<SEG>` argument = same 4-hex form used by
  `function-map.tsv` `start` column.
* `_prologue.asm` carries the MZ header + PSP (seg 0x0000..0x00FF) as `.byte` blobs;
  cleaned work starts at seg 0100.

Workspace: created `docs/phase3-state.md` (this table) and this log. Scratch dir
`tmp/` exists in-project; rebuild outputs go to `/var/tmp` per guardrails.

**Acceptance:** invariants true; both phase-3 docs exist → **met**. Committed
`phase3: CP0 baseline verified (md5, assemble_all byte-match, jwasm smoke test)`.

---

## CP1 — Per-function harness + style guide — done 2026-10-20

**`tools/check_func.py <SEG>`** — assembles ONE function in isolation and
byte-diffs its own range vs `original/`. Mechanics:

* Source: `asm/<SEG>_*.asm` (cleaned) else `disasm/functions/<SEG>.asm`
  (mechanical fallback). Range + evidence from `function-map.tsv`.
* Scaffold: `.code16/.text`, zero-fill `.org` to the file origin, body, then
  `__u2_body_end` symbol; `nm` verifies assembled body length == map range
  length (catches silent short/long bodies that a range-diff could mask).
* Out-of-function targets: every referenced-but-undefined `L_<6hex>` (file
  offset) label is stubbed as a zero-byte `.org t; label:` — below-function
  stubs before the body, above-function stubs after (`.org` only moves
  forward). A reference into the own range without a definition is a hard
  error.
* Dialect normalisation (documented in style guide): `dw`→`.word`; `db`/string
  items in `db`/`.byte` lines expanded to hex byte lists (gas `.byte` takes
  only 1-char strings); comments must be `#` — gas x86 treats `;` as a
  statement separator (found the hard way, first seed failed to assemble).
* Scratch per function in `tmp/check/<SEG>/`.

**Harness self-proof:** ran it over ALL 1299 mechanical slices —
**1299 PASS, 0 FAIL**. One real finding: function `8DCD..8FFF` declares 563 B
but the file ends at 0x91E0 (segment padded past EOF by 32 B); harness clamps
the last function to EOF, same as `assemble_all.sh` implicitly does. Recorded
in style guide rule 9.2.

**`docs/asm-style.md`** — file layout `asm/<SEG>_<name>.asm`; naming
(`cmd_*`, `str_out`, `sub_<seg>` default, `.L<seg>_<meaning>` locals, `L_<6hex>`
externals, `data_<seg>_<kind>`); header template (what-it-does / range /
evidence / confidence / notes); data rules (`db "text",0` + kind comment,
escape rules, high-bit/non-printables stay numeric); forced-`.byte` policy
(restore normal encodings, keep ambiguous ones with a reason); INT-stub seam
(labels `video_int10`/`key_int16`/`clock_int1a`/`dos_int21`/`speaker_tone` at
the int/port site — zero byte cost, Phase 5 replaces); hard rules (no byte may
change, check_func green before commit, assemble_all stays green).

**3 seeded cleaned examples (acceptance):**
* `asm/0133_sub_0133.asm` — straight-line; external `call L_0008ac` stubbed. PASS.
* `asm/2B8F_cmd_A.asm` — inline string: `call L_0051df` + `db "ATTACK--",0`. PASS.
* `asm/0D21_sub_0d21.asm` — 5 far out-of-function jmp targets + named locals. PASS.

`assemble_all.sh` re-checked green after CP1 (mechanical tree untouched).
Committed `phase3: CP1 check_func.py harness (1299/1299 slices + 3 seeds) + asm-style.md`.

---

## CP2 — Pilot: 26 cmd handlers + str_out — done 2026-10-20

**Result: 27/27 `check_func.py` green** (each file in `asm/`), `assemble_all.sh`
still byte-identical.

Two new tools were needed to do this honestly at scale:

* **`tools/preclean.py`** — mechanical transforms from a Phase 2 slice:
  string/zeros/pad `.byte` runs merged into `db` items (printable runs become
  `db "text",0`; label-interleaved runs merged when the inner labels are
  unreferenced corpus-wide); `# forced:` lines restored to instructions ONLY
  after batch-verifying gas reproduces the exact original bytes (catches
  `or %al,%al`→0ac0 vs 08c0, `mov %ax,%di` form choice, `shr %cl,%al`
  stop-trunc length); rel-op forces restored with length-fit checks;
  `stop-trunc` kept as `.byte`.
* **`tools/decode_str.py`** — the keystone discovery of the pilot: Phase 2's
  forced-`.byte` clusters around `call str_out` are objdump desyncs (string
  bytes decoded as instructions). This decoder re-runs objdump per range and,
  at every `call 0x51df`, consumes the raw bytes up to the NUL as `db "..."`
  and RESTARTS decoding after the terminator. Every mis-decode site in the
  pilot resolved into clean code this way (e.g. cmd_G's "ja L_003881 into a
  BCD increment" was really `jmp 0xc33; call str_out; " WEAPON\0"`). Plain
  instructions are byte-verified (same machinery as preclean) and kept as
  `.byte # forced-kept: gas re-encodes ...` where gas would optimize
  disp16→disp8 or pick another form. `jns`/full REL_OPS set matters (missed
  it first, got a silent rel16 widening).

**Per-function log (what was cleaned):**

| fn | file | cleaning |
| --- | --- | --- |
| str_out | `4FDF_str_out.asm` | named entry + `L_0051df` anchor kept (57 external refs); wrapper to 0x53fd documented |
| cmd_A | `2B8F_cmd_A.asm` | CP1 seed: `call str_out` + `db "ATTACK--",0` |
| cmd_B | `2F6F_cmd_B.asm` | "BOARD" inline string |
| cmd_C | `310B_cmd_C.asm` | CAST: hand-re-decoded; slice mis-decode (cmp $0xb890…) → `jmp 0x3353`, ES=0xB800/0xBA00 setup + calls to 0x3339, timed wait via 0x54ca, "PICXXX  " |
| cmd_D | `334D_cmd_D.asm` | DESCEND: mis-decode fixed; NUL+`jmp 0xc33` tails; resume label at 0x3570 documented as defect site |
| cmd_E | `3389_cmd_E.asm` | "ENTER" |
| cmd_F | `35C1_cmd_F.asm` | "FIRE" |
| cmd_G | `363B_cmd_G.asm` | GET: full decode_str re-decode; WEAPON/ARMOUR/CHEST/gold/TRI-LITHIUM paths, BCD increments at [di+0x76]/[di+0x96] now real instructions |
| cmd_H | `3782_cmd_H.asm` | "HYPER WHAT?" + `jmp 0xc33` (slice had add/lahf/d2 garbage) |
| cmd_I | `3794_cmd_I.asm` | 1-byte stop-trunc call, kept `.byte` with warning comment |
| cmd_J | `37DC_cmd_J.asm` | "JUMP...WHEE..." + `jmp 0xc33` |
| cmd_K | `37F1_cmd_K.asm` | 1-byte stop-trunc call |
| cmd_L | `38B0_cmd_L.asm` | LAUNCH: decode_str re-decode of 738 B; rocket/plane flows, direction words + "CMD: " prompts |
| cmd_M | `3B92_cmd_M.asm` | hand-re-decoded: NUL + `call 0x2228` (slice's jl→0x3d90 was a desync artifact; that stale external ref is gone) |
| cmd_N | `3BCE_cmd_N.asm` | "NEGATE TIME" |
| cmd_O | `3C2E_cmd_O.asm` | OFFER: decode_str re-decode; ENILNO/RING quest messages |
| cmd_P | `3DBC_cmd_P.asm` | "PASS" |
| cmd_Q | `3DC7_cmd_Q.asm` | "QUIT OR SAVE GAME." |
| cmd_R | `3E50_cmd_R.asm` | READY WEAPON menu |
| cmd_S | `3F25_cmd_S.asm` | "STEAL DIRECT-" |
| cmd_T | `4050_cmd_T.asm` | "TRANSACT-" |
| cmd_U | `42F1_cmd_U.asm` | "UNLOCK DIRECTION-" |
| cmd_V | `437E_cmd_V.asm` | VIEW + magical-helm variant |
| cmd_W | `43F3_cmd_W.asm` | WEAR ARMOUR menu + error paths |
| cmd_X | `44D4_cmd_X.asm` | X-IT destroy-item paths |
| cmd_Y | `4542_cmd_Y.asm` | "YELL WHAT?" + 0x8d glyph (NUL lands exactly on range end) |
| cmd_Z | `4568_cmd_Z.asm` | tail `call 0x4c1c` |

Every file carries the style-guide header (what/range/evidence/confidence/
notes). Big handlers keep mechanical `L_<addr>` labels as cross-reference
anchors (renamed only where a meaningful name is proven); small ones use the
`cmd_*` entry name + `L_` anchors. INT-stub seams: none of the 27 contain
`int` sites (handlers call out to the wrapper routines), so the seam work
lands in CP4/CP5 functions.

**Known-limitation notes found:**
* gas `.byte "multi-char"` silently emits only the first char — harness
  expands string items to hex itself (never trust raw `db` passthrough).
* `;` is NOT a gas comment (statement separator) — style guide rule.
* cmd_L range ends 0x3d91; the stale `L_003d90` ref existed only in the
  mis-decoded cmd_M slice and is gone from the cleaned tree.

Committed `phase3: CP2 pilot 27/27 green (26 cmd handlers + str_out); preclean.py + decode_str.py`.
- **CP4 wave-1 batch 1** (0100..020F, 25): all check_func green.
- **CP4 wave-1 batch 2** (0222..0375, 25): all check_func green.
- **CP4 wave-1 batch 3** (0389..06D4, 25): all check_func green.
- **CP4 wave-1 batch 4** (06D7..07E6, 25): all check_func green.
- **CP4 wave-1 batch 5** (07ED..08E3, 25): all check_func green.
- **CP4 wave-1 batch 6** (08E6..0976, 25): all check_func green.
- **CP4 wave-1 batch 7** (097C..0A15, 25): all check_func green.
- **CP4 wave-1 batch 8** (0A18..0AD3, 25): all check_func green.
- **CP4 wave-1 batch 9** (0AE1..0BB9, 25): all check_func green.
- **CP4 wave-1 batch 10** (0BBC..0C9A, 25): all check_func green.
- **CP4 wave-1 batch 11** (0C9B..0D64, 25): all check_func green.
- **CP4 wave-1 batch 12** (0D6C..10BC, 25): all check_func green.
- **CP4 wave-1 batch 13** (10BF..156B, 25): all check_func green.
- **CP4 wave-1 batch 14** (156E..17EF, 25): all check_func green.
- **CP4 wave-1 batch 15** (17F0..20D7, 25): all check_func green.
- **CP4 wave-1 batch 16** (20EB..21B6, 25): all check_func green.
- **CP4 wave-1 batch 17** (21BD..22D1, 25): all check_func green.
- **CP4 wave-1 batch 18** (22D4..23E1, 25): all check_func green.
- **CP4 wave-1 batch 19** (23E6..254C, 25): all check_func green.
- **CP4 wave-1 batch 20** (2550..25F4, 25): all check_func green.
- **CP4 wave-1 batch 21** (25FF..2B9B, 25): all check_func green.
- **CP4 wave-1 batch 22** (2BA2..2CF2, 25): all check_func green.
- **CP4 wave-1 batch 23** (2CF6..33C3, 25): all check_func green.
- **CP4 wave-1 batch 24** (33D1..35DD, 25): all check_func green.
- **CP4 wave-1 batch 25** (35EA..3EBB, 25): all check_func green.
