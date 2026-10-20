# Phase 3 Summary — Clean Byte-Exact ASM Reconstruction

Status: **built, awaiting owner sign-off (CP6 🔒)**. Date: 2026-10-20.
Plan: `docs/phase3-plan.md`. Log: `docs/phase3-implementation.md`.
State: `docs/phase3-state.md`.

## What this is

A readable, named, structured assembly reconstruction of `original/ultimaii.exe`
(37,344 B, md5 `fe884d5117971073ac8097cc7a6aca25`) in which **every byte is
proven**: each function in `asm/` re-assembles in isolation to exactly its
original byte range (`tools/check_func.py <SEG>`, exit 0), and the whole tree
rebuilds the whole binary byte-identically (`tools/assemble_clean.sh`).

This is a faithful reconstruction, not recovered source: names, comments and
macros of the 1983 listing are unrecoverable (stated per plan §6).

## Disposition counts (sum = 1299 ✓)

| Disposition | Count | Meaning |
| --- | --- | --- |
| clean | 1283 | reconstructed + header-commented, individually byte-proven |
| data | 3 | 47BD/4815/486D data islands (`asm/<SEG>_data_mixed.asm`) |
| excluded (selfmod) | 13 | seg 0x5120–0x5151 runtime-patched cluster, reconstructed as-is with loud notes |
| deferred | 0 | — |

Every `clean` function passes `check_func.py`; no deferred bytes exist.

## Verifiability statement

* `bash tools/assemble_all.sh` — mechanical Phase 2 oracle: byte-identical
  (held green at every checkpoint).
* `bash tools/assemble_clean.sh` — **full binary from the cleaned tree only:
  1299/1299 cleaned files used, 0 mechanical fallbacks, 37,344 B identical.**
* `python3 tools/check_func.py <SEG>` — per-function proof (1299/1299 green).
* Deferred/mechanical bytes: none hidden; the only non-cleaned content is the
  MZ/PSP prologue blob (mechanical by design) and the 16 data/excluded
  dispositions above, each labeled in its file.

## Dialect (jwasm / MASM)

`tools/dialect_masm.py` transpiles cleaned files to MASM and dual-verifies.
Plan sample: **50/50 dual-match**; wider 200-sample: **197/200**. Honest
deviations: one direction-bit form choice (`sub %sp,%sp`), two objdump
data-decode artifacts the transpiler refuses to approximate. jwasm quirks
worked around (bare `[num]` immediates, `-bin` leading-pad strip, line-length
limit) — details in the CP5 log section.

## Wave stats

* Pilot (CP2): 26 `cmd_*` handlers + `str_out`, hand-polished with meaningful
  labels and re-decoded mis-decode sites.
* Wave 1 (CP4): 1052 majority-execution-confirmed functions.
* Wave 2 (CP5): 218 remaining functions.
* INT/port seams (`video_int10`/`key_int16`/`clock_int1a`/`dos_int21`/
  `speaker_tone`) auto-labeled at every int/port site (zero byte cost).
* Tools built: `check_func.py`, `preclean.py`, `decode_str.py` (str_out-aware
  re-decode — fixed the Phase 2 mis-decode class), `clean_wave.py`,
  `dialect_masm.py`, `assemble_clean.sh`.

## Phase 4 / 5 handoff

* Phase 4 (C lifting, `docs/phase4-draft-c-lift.md`): lift from the cleaned
  `asm/` tree (byte-honest, strings decoded, seams marked), using Reko drafts
  only for naming hints. Exclude the 13 selfmod functions; treat the 3 data
  islands as data. `sub_*` names are placeholders — rename during lifting as
  behavior becomes evident (owner directive: honest names, improve in passes).
* Phase 5 (portable build): the seam labels are the replacement surface —
  `video_int10`, `key_int16`, `clock_int1a`, `dos_int21`, `speaker_tone`.
* Known limits carried from Phases 1–2: community-patch provenance of the
  binary; 5,218 B unclassified (wave-2 re-decodes absorbed them into functions
  but kind uncertainty remains for pure-data stretches); byte-identity ≠
  original source.
