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
