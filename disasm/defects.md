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

**Measured: 334 near calls to the printer, 238 of them carrying a printable message, 233
rendered as data by `asm/`, 5 not.** Those 5 are in `disasm/str-out-rendering-gap.tsv` (offsets,
lengths and the owning `asm/` file — no game text, per `AGENTS.md`), and `--check` goes red on
drift in either direction: a new gap, or a listed one that got fixed and left the list stale.

**Update, 2026-10-28e: four of the nine were fixed, and the reason they were open is gone.** The
paragraph below is kept because it is the accurate record of why the tree was left this way, but
its premise no longer holds: `asm_body_guard` now permits a marked body correction
(`# body corrected: DATE -- evidence: ...`), so "the fix is a body edit, which the guard
forbids" stopped being true. Four files were re-cut — `asm/02A3`, `asm/02E6`, `asm/3566` and
`asm/3596`, plus the two halves of the era string in `asm/3577` and `asm/3582` — each verified
by `check_func`, by `str_out_audit --check` and by the whole-binary byte match. What remains is
`asm/3795`, `asm/37F2` and `asm/464E`.

The era table turned out to be worth the grind on its own account. All five `ANOS:` lines are
now visible in `asm/` as data, and the table's real shape came out with them: five entries of
`call str_out / db text / jmp dispatcher` with no padding, whose boundaries the map had cut in
three places, which is why three of the five were invisible and why `asm/3596_show_year_1990`
was named for the second-to-last thing in its own range.

**The 9 are documented, not fixed, and that is a deliberate limit rather than a leftover.** The
only way to make `asm/` render them as data is to replace instruction body lines with `db` lines.
That keeps `assemble_clean.sh` green — the bytes are identical — but `engine/tests/asm_body_guard.py`
builds a canonical stream of every non-comment line in the tree and requires it unchanged from
HEAD, and its docstring is explicit that renaming, merging and splitting are legitimate while
**editing is not**. It has no bless mode, and adding one would put a door in the only guard that
currently cannot be talked into accepting a change. So the atlas grew a second source instead:
`strings_atlas.py` now carries these nine from the calling convention itself, tagged
`source='str-out-contract'` and verified byte-exactly like every other row, and each owning file
carries a `# RENDERING GAP:` header saying so. The presentation is weaker than the evidence, and
that is now visible in both places someone would look.

**The first version of this section said 16 and attributed all of them to `asm/`. That was
wrong, and wrong twice over.** Six of the sixteen were `strings_atlas` failing to extract a
string that `asm/` had rendered perfectly well as `db` — including `MALE` in
`asm/5066_print_sex_male` and `PASS` in `asm/08FF_sub_08ff`, which is the pair this section
built its rhetoric on. The cause was the `exe_anchor` fallback added the same day: it required a
*unique* byte-pattern hit in a wide window and dropped anything ambiguous, and `MALE\0` and
`PASS\0` each occur twice nearby. Fixed by making proximity a tie-breaker rather than a gate
(438 strings now, up from 433, with zero regressions — the first attempt at that fix silently
*lost* four strings a unique wide hit had been anchoring correctly, and the diff against the
previous version is the only reason that was caught instead of shipped).

Of the 11 that remain, roughly eight are genuine classification gaps — a printed message sitting
in a span `asm/` renders as instructions — and the rest are a third thing: a `db` followed by a
`.byte` filler line breaks the atlas's "subtract the byte count from the next label" rule, which
assumes the `db` is the last thing emitted before that label. `asm/334D_cmd_D` and the merged
`asm/4050_cmd_T` are both that shape. Neither is fixed here.

What is in the list is still the argument for the gate. Three of the five `ANOS:` era lines,
including one claimed by `asm/3596_show_year_1990` whose declared range swallows a neighbouring
string — both now fixed, see the update above. `KLIMB`, `IGNITE TORCH`, `SPELL-`. And the fact that
the audit was right about *which offsets* were invisible even while the explanation for why was
wrong twice — the number held, the story did not.

Two things this does **not** claim. It does not say `asm/` is wrong about the bytes: every one of
those files reassembles byte-identically, and the proof is unaffected. And it does not fix them —
reclassifying a body is a change to a CP0-verified artefact and needs a human decision about how
far to go, so the tool nominates and stops. `--show` prints the text to stdout for whoever
adjudicates.

The reverse direction (a `db` blob that is really code) is still only covered by `redecode.py`
reading the five blob files, and the known instance there is the opposite sign: `redecode.py`
mis-decodes 21 bytes of real code at file `0x27D2` as a printable string. That one is still
open and still needs a length-decoder-based check, not a string heuristic.

## 2026-10-28d — a forced-keep byte swallowed a four-byte instruction, and it cost a week

`asm/353A` ends with `.byte 0x8a` marked forced-keep; `asm/353D` opens with `push %ds`. Both are
artefacts of one abandoned decode. The bytes at runtime `353C..353F` are `8a 1e 49 00`, a single
instruction `mov 0x49,%bl` — the sector tens digit. The wave took the opcode, gave up, and the
next fragment re-read the ModRM byte `1e` as `push %ds` and the displacement `49 00` as `dec %cx`.

The cost was concrete: `DS:49` is the era index G14 had been asking "who writes `%di`" about since
the ticket was filed, and the answer was sitting inside the mis-decoded instruction the whole time.
It was found by dumping six bytes and running `objdump` over them, not by a capture.

Two general lessons, both of the "a tool that lies is worse than no tool" family:

* **A forced-keep followed by an implausible instruction stream is one instruction, not two
  facts.** `push %ds` then `dec %cx` then a three-displacement `add` with no matching pop is not a
  shape anyone writes. When gas refuses to re-encode an instruction, the bytes immediately after
  it are the rest of *that* instruction, and the next fragment's opening instruction is the tell.
* **A mis-decode can hide a read rather than erase it.** Every search for `DS:49` reads kept
  finding the seven legitimate sites in `asm/2290`, `22D5`, `2305`, `26B7`, `26CC`, `2708` and
  `cmd_O`, and none of them was this one. The grep was correct and the corpus was wrong, so the
  negative result looked earned. When a byte is *known* to be read somewhere and the sites found
  are all explainable otherwise, suspect the decode before concluding there is no site.

Not fixed in `asm/`, and cannot be: instructions and labels are body, `asm_body_guard` freezes it
and CP0 md5s it. The correct decode is recorded in the two file headers and in
`asm/3546_time_index_message`, which now carries the complete era table. Whether to reopen the
body-freeze for known-wrong decodes is an owner question, and it is a different question from the
seam-label one in `docs/fragment-splits.md` — that one is about merging, this one is about
leaving a known falsehood in the tree.
