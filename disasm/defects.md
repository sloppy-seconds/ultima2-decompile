# Phase 2 CP5 — Defect verdicts

Ground truth for every verdict: the per-function asm slice (`disasm/functions/`) which
re-assembles byte-identically. "FP" = bytecheck false positive (claim is a legitimate
algebraic form of bytes that ARE in range).

## The six "fabricating" functions (bytecheck-map.tsv)

| Start | Claim | Verdict | Evidence |
| --- | --- | --- | --- |
| 0A5F | stack delta 0x1757 | **true Reko bug** | Slice is a cmp/jne/jmp dispatch chain; Reko's stack model invents a 5975-byte adjustment. Asm correct. Workaround: read asm slice; do not trust Reko's frame math here. |
| 4FA5 | `ax > 0x3800` | **FP — constant folding** | Asm: `add $0x200,%ax; cmp $0x3a00,%ax`. Reko folded 0x3a00-0x200 = 0x3800. Legitimate transform; bytes are in range. |
| 47BD | 0x739 | **FP — negative displacement** | Asm: `add %cl,-0x739(%bp,%di)` (bytes C7 F8 in range). Bytecheck looked for +0x739. NOTE: whole 13-byte region decodes as absurd instructions (`fisttps`, neg disp) — a **data island** inside a seed range; Phase 3 should reclassify. |
| 4815 | 0x739 | **FP — same pattern** | sibling fragment of 47BD, same disposition. |
| 486D | 0x739 | **FP — same pattern** | sibling fragment of 47BD, same disposition. |
| 6999 | `~0x1701` | **FP — complement form** | Reko models a mask as `~0x1701`; the file carries the mask's own bytes. Lowering style, not invention. |

Net: **1 genuine Reko fabrication (0A5F) in 1299 procedures**, not 6. The bytecheck's
absent-from-file test needs the derived-constant caveat; every fab is human-adjudicated here
(the CP6 methodology always required this — the flags were the point, the verdict is CP5's).

## The three Reko procedure failures

| Start | Symptom | Verdict |
| --- | --- | --- |
| 2395 | rewrite failure; no aligned label in linear asm (CP1) | Slice = single `nop` (0x90). A NOP-padding seed, not a real function. Harmless; keep as trivial 1-byte function, no Reko output needed. |
| 35DD | rewrite failure | Same: single `nop` padding seed. Same disposition. |
| 531B | unbounded-recursion SSA exception | Slice: `call str_out` followed by a run of 0x20 (space) string bytes. A string-display site, not a control-flow function; Reko's recursion on the shared routine blows up. Phase 3: treat as code-prefix + string data. |

## Follow-ups recorded (not hidden)

1. Bytecheck v3 (if ever built): whitelist folded/complement/negated forms before flagging fab.
2. Data-island candidates inside seed ranges: 47BD/4815/486D family — CP2 kind said unclassified;
   Phase 3 data-separation pass should absorb them.
3. NOP-padding seeds (2395, 35DD family): consider `kind=nop-pad` in the map for Phase 3.

## 2026-10-28d — the misclassification direction nobody could check until now

The two follow-ups above are the same defect as a class, and the class was invisible: there was
no way to ask "is this byte rendered as the wrong kind?" and get an answer. There is now, in one
direction, and it is `tools/str_out_audit.py`.

The lever is a proven calling convention rather than a heuristic. `call L_0051df` and the bytes
immediately after the return address **are** the message — NUL-terminated, optionally wrapped in
`0x8D`/`0x0D`. That is a property of the executable, so the set of print sites can be enumerated
from `original/ultimaii.exe` alone, with no reference to how `asm/` chose to render anything.
Compare that set against what `strings_atlas.py` reports and the gap is exactly "the game prints
this and `asm/` draws it as instructions".

**Measured: 334 near calls to the printer, 238 of them carrying a printable message, 222
matched, 16 unmatched.** The 16 are in `disasm/str-out-unmatched.tsv` (offsets, lengths and the
owning `asm/` file — no game text, per `AGENTS.md`), and `--check` goes red on drift in either
direction: a new unmatched site, or a listed one that got fixed and left the list stale.

What is in the list is the argument for the gate. Three of the five `ANOS:` era lines, including
one claimed by `asm/3596_show_year_1990` whose declared range swallows a string table. `PASS`,
which several documents reason about while the atlas never once reported it. The title screen's
copyright line. And `asm/5066_print_sex_male`, a file **named after the string it prints**, whose
own string the atlas cannot see — which is the most honest possible demonstration that owner
naming and string extraction were independent processes here.

Two things this does **not** claim. It does not say `asm/` is wrong about the bytes: every one of
those files reassembles byte-identically, and the proof is unaffected. And it does not fix them —
reclassifying a body is a change to a CP0-verified artefact and needs a human decision about how
far to go, so the tool nominates and stops. `--show` prints the text to stdout for whoever
adjudicates.

The reverse direction (a `db` blob that is really code) is still only covered by `redecode.py`
reading the five blob files, and the known instance there is the opposite sign: `redecode.py`
mis-decodes 21 bytes of real code at file `0x27D2` as a printable string. That one is still
open and still needs a length-decoder-based check, not a string heuristic.
