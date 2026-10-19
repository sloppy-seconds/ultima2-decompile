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
