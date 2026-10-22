# AGENTS.md — Linux-Native DOS Game Decompilation & Byte-Matching Pipeline

This document defines the rules, isolation policy, and evidence discipline for AI
agents (and human collaborators) reverse engineering early 16-bit real-mode DOS
binaries (e.g., *Ultima II*) into assembly, re-engineering into C, and verifying
exact byte-for-byte fidelity.

> **Executable work orders:** Phase 1 (evidence capture), Phase 2 (function boundaries,
> code/data separation, per-function asm corpus) and Phase 3 (clean byte-exact ASM
> reconstruction, MASM dialect via jwasm target) are **complete and signed off** — see
> `disasm/phase1-summary.md`, `disasm/phase2-summary.md` and `disasm/phase3-summary.md`.
> Phase 4 (portable C engine reimplementation from the asm/ tree) is `docs/phase4-plan.md`;
> the live task queue is `docs/phase4-state.md` and the running log is
> `docs/phase4-implementation.md`. To start a fresh agent, read
> `docs/handoff-2026-10-22.md` first, then `docs/phase4-state.md`. Superseded handoffs and
> completed overnight queues live under `docs/archive/` — historical record, not entry
> points.

> **What this file is.** Rules and orientation only. It does not contain source
> code, tool listings, or reference material — those live in the files named
> here. Anything that quotes a file will drift from it and then lie.

---

## 0. Project Scope & Isolation (READ FIRST — HARD RULE)

**This project is standalone. The only directory an agent may read, write, search, list, or reason from is this project root and everything beneath it:**

```
/var/home/paul/Projects/decompile-u2-v2/
```

### Absolute prohibitions

* **NEVER read, list, search, open, or reference anything outside the path above.** This includes parent directories, sibling projects, and any other checkout of the same game.
* **NEVER use `..`, absolute paths outside the project root, or `find`/`grep`/`ls` that escapes the project root.** All paths in commands and code are relative to the project root or absolute under it.
* **NEVER make decisions, take hints, copy code, compare output, or infer intent from any other directory.** In particular these sibling directories are OFF LIMITS and are NOT the source of truth:
  * `/var/home/paul/Projects/decompile-u2` (the older v1 — a different, unrelated attempt)
  * `/var/home/paul/Projects/ultima2`
  * `/var/home/paul/Projects/agents/**` and every other folder under `/var/home/paul/Projects/`
* Do not "check a sister/previous version for reference." If information appears to be missing from this project, it is missing — treat it as an open question for the user, not something to go find elsewhere.

### In-project exception: the read-only backup

* `references/ultima2/` is a **pristine, read-only backup** of the original game files, kept inside this project in case the working copy in `original/` is ever damaged.
* It is part of this project, so reading it is allowed — but it is a **fallback, not a workspace**. Treat it as immutable: **never write to, edit, rename, or delete anything under `references/`.**
* The working copy is `original/`. Use `references/ultima2/` only to restore a damaged file from `original/`, and only with the user's approval.

### External tool binaries (allowed)

The isolation rule is about **data and decisions**, not about refusing to use installed software. Analysis tools may be invoked by path as infrastructure, exactly like `dotnet` or `objdump` on `PATH`:

* **Vendored in-project:** Spice86 (`tools/spice86/`) and Reko (`tools/reko/`) — self-contained builds, gitignored.
* **Referenced by path:** Ghidra lives outside the project (`GHIDRA_HOME`, default `/var/home/paul/Projects/ghidra-12.1.4`). It is Apache-2.0 and too large to vendor, so it is the one external-tool path exception. `source tools/env.sh` wires it up.

Running a tool binary is fine. What the rule forbids is importing **prior findings** — earlier attempts at decompiling Ultima II (entry-point lists, symbol names, struct layouts, conclusions) from a sibling directory such as `decompile-u2` or `ultima2`. Generic, binary-agnostic tooling is safe to reuse; anything that encodes a *conclusion about this binary* must be regenerated from `original/` and `captures/` inside this project. Never browse a sister directory to "check how they did it."

### Why this rule exists

A previous agent read a sibling directory and made decisions based on it, which corrupted this project's work. Each project here is independent. Cross-contamination between `decompile-u2`, `decompile-u2-v2`, and `ultima2` has caused real confusion. Isolation is not optional.

### If you genuinely need something outside the project

Stop and ask the user, naming the exact path and why. Do not go look on your own.

### Provenance of the original files (important for byte-matching)

* The game files in `original/` (and the backup in `references/ultima2/`) were downloaded from the **Internet Archive**, not from a factory-shipped distribution.
* The pack **appears to already have community patches applied**. So these files may **not be 100% the original shipped binary**.
* This is accepted and expected — it is not a defect to chase. Treat the bytes in `original/ultimaii.exe` as the ground truth for *this* project, while remembering that a byte-for-byte "match" here means matching this patched pack, not necessarily Garriott's pristine 1983 release.
* Do **not** go hunting the internet or other directories for a "more original" binary to diff against. If a discrepancy looks patch-related, note it and move on; raise it with the user only if it blocks the task.

### Licensing & Commit Policy (Apache-2.0)

This project's own work is licensed **Apache-2.0** (see `LICENSE`). To avoid copyright
infringement and GPL/AGPL license contamination, **anything not compatible with Apache-2.0 must
never be committed to git.** The `.gitignore` enforces this; do not work around it.

* **Never commit — copyrighted game assets:** `original/` and `references/` hold the Ultima II
  binaries and data, which are not ours to redistribute. Users supply their own copy. These are
  gitignored; never `git add -f` them.
* **Never commit — GPL / incompatible tool builds:** `tools/spice86/` (GPL) and `tools/reko/`
  (GPL-2.0) are vendored, re-fetchable builds, not our source. Ghidra is Apache-2.0 but lives
  outside the repo. No AGPL-licensed code may be introduced anywhere in this project.
* **Never commit — bulky derived dumps:** raw runtime captures (`captures/spice86/*.bin`,
  `*.json`) and full decompiler output (`decompiled/`) are regenerable working artefacts derived
  from the copyrighted binary; keep them on disk, out of git.
* **Commit freely — our own authored work:** `AGENTS.md`, `docs/`, `tools/*.py`,
  `tools/ghidra/*.java`, `tools/env.sh`, the per-tool `README.md` files, and curated analysis
  notes we write (`disasm/*.md|tsv|txt`, reports, summaries). Small factual findings (addresses,
  sizes, verdicts) expressed in our own prose are fine; verbatim copyrighted blobs and GPL
  binaries are not.
* When in doubt about whether an artefact is safe to commit, **do not commit it and ask the user.**

---

## 1. Domain Context: Compiler & Tool Selection

*Ultima II* was hand-coded in 6502 assembly for Apple II and ported to x86 MS-DOS
as **pure assembly** — there is no C compiler output in the original binary.

* Strict byte-for-byte matching therefore targets an **assembler** (JWasm, MASM
  dialect), which is what Phase 3 did and what CI verifies.
* The C engine in `engine/` is a **reimplementation**, not a byte-matching
  exercise: behavioural fidelity argued from the asm tree and confirmed by
  testing and playthroughs. It is not byte-proven and never will be.
* For mid-to-late DOS era titles compiled from C (Ultima IV/V and later), the
  historical compiler itself becomes the target. That does not apply here.

## 2. Pipeline and Current Reality

| phase | state | artefact |
| --- | --- | --- |
| 1 evidence capture | done | `captures/`, `disasm/phase1-summary.md` |
| 2 boundaries + code/data split | done | `disasm/phase2-summary.md` |
| 3 byte-exact asm reconstruction | done, CI-verified | `asm/`, `disasm/phase3-summary.md` |
| 4 portable C engine | **in progress** | `engine/`, `docs/phase4-state.md` |
| 5 portable build behind INT/port seams | planned | — |

Verification, in two independent layers:

* **the proof** — `bash tools/assemble_clean.sh` rebuilds the whole binary from
  `asm/` and checks it against the known md5; `python3 tools/check_func.py <SEG>`
  proves one function. CI workflow `asm-checksum` runs this on every push and
  must never be red.
* **the engine** — `make -C engine && make -C engine test` runs CP0..CP4
  acceptance tests. CI workflow `engine-tests`. The two workflows are separate
  on purpose: engine work-in-progress must not look like a regression in the
  reconstruction proof.

## 3. Working Rules

* **`asm/` is the one lookup table for address → behaviour. There is no second
  one.** The filename carries the discovered name (`asm/0936_walk_loop.asm`) and
  the header carries `# name-evidence:`, `# provenance:` and `# confidence:`.
  Do not create flow tables, address cheat-sheets or symbol indexes in `docs/`
  or `disasm/` that duplicate this — two hand-maintained copies always drift and
  a stale index is worse than none. Any derived view must be *generated* by a
  tool, never kept by hand.
* **Look it up before you investigate it.** Start with
  `ls asm/ | grep -i <word>` and read the header. If it is already named, the
  work is done and re-deriving it from raw disassembly is a process failure.
  Then **spot-check one cited byte or instruction** to prove the entry still
  holds before trusting the rest of it.
* **When a session learns or corrects an address→behaviour fact, the same commit
  renames the `asm/` file and writes the header.** Not a follow-up, not a
  backlog item. If no file covers the address yet, record it in the owning
  function's header and say so.
* **In `asm/`, only the filename and `#` comment lines may change. Labels are body.**
  A discovered name goes into the filename and the header; the `sub_xxxx:` label line
  stays exactly as it was. `engine/tests/run_cp0.sh` md5s every non-`#` line, both
  across a rename and on a modified file, so editing a label fails CP0. **This is the
  most frequently repeated mistake against this tree** — the instinct is that renaming
  `sub_2cd8:` to `keys_add_two:` alongside the file is tidier, and it is forbidden.
  Note it in the header instead (`# label: kept as ... on purpose`). Changing a label
  at all is a change to a CP0 invariant, not a naming detail: stop and ask.
* **A wrong name is worse than no name.** If bytes contradict an existing name,
  add a `# NAME DISPUTED:` line in the same commit and propose the rename;
  do not silently rename on your own inference.
* **Third-party data is a hypothesis the bytes get to veto.** `bestiary/` attaches
  community creature names to art indices, and it does so by measured bitmap
  identity — but the *name* itself comes from a wiki, not from this binary, and never
  will. Keep the two grades apart in anything you write, do not promote a third-party
  name into an `asm/` filename, and keep `bestiary/cache/` away from anyone drawing
  substitute art; it holds the originals in more variants than `original/` does.

* **The cleanroom wall separates the implementer from the originals, and an answer key is a
  breach just like a screenshot is.** `docs/tile-art-spec.md` is the only document someone
  drawing substitute art may read. It may carry **intent** (what a tile must communicate) but
  never a **trace** (pixel coordinates, measured densities, periods, component sizes) — a trace
  lets the original be reproduced without looking at it. Evidence and the bands fitted to it
  live in `docs/tile-art-evidence.md` and `tools/tile_rules.py`, both listed as forbidden in the
  spec's § 2. The gate is run **against** finished art and never handed to whoever makes it. If
  you are doing a redraw, you must not read either file. The whole procedure, the
  verification chain, the build history and the controls that failed are written down in
  `docs/cleanroom-procedure.md`.
* **`docs/needs-gameplay.md` is the capture worklist, and every blocked-on-play
  question belongs on it with a who-can-do-it verdict.** When a finding is recorded
  as inferred-but-never-observed, or a question is closed as needing a live session,
  the same commit adds or ticks an item there. Two rules come with it. First,
  **"needs gameplay" is not "needs the owner"** — say which, because the difference is
  a scripted afternoon against waiting on a diary appointment, and the project had
  conflated them until a "owner must walk" label survived on items an agent could
  drive. Second, **an item is only closed by a named capture directory**, never by a
  belief about how the game works.
* **`docs/harness-portability.md` is a live design report, and updating it is a
  same-commit obligation.** When a finding would change how a *generic* DOS
  decompilation harness should be built — an ISA idiom that broke a detector, a tool
  that returned a plausible wrong answer, a gate that could not fail, or a question
  only play could settle — the commit that records the finding also adds a line to
  that report's feedback log (§ 6). Most of these arrive disguised as ordinary bug
  fixes, which is exactly why they get missed. **Method transfers; conclusions do
  not.** That report must never contain addresses, DS layouts, record formats or
  symbol names from this binary — it is the boundary between what a future project
  may inherit and what it must re-derive from its own bytes. If a line only makes
  sense for this game, it belongs in `asm/` or the findings doc instead.

* **Never run the game in place.** The game rewrites its own `player` file.
  `tools/spice86_start.sh` copies pristine `references/ultima2/` into a fresh
  timestamped dir under `tmp/` for every launch. Scratch and logs go to
  `/var/tmp`, never `/tmp` (which is tmpfs here and takes RAM from the model).
* **Never edit a file with a script.** Use the edit tool. A `str.replace` that
  does not match returns the string unchanged and exits 0, so a no-op and a
  success are indistinguishable. Same trap as `sed -i` with a pattern that
  misses.
* **Never heredoc a non-trivial script.** Write the file, syntax-check it, run
  the file.
* **Ask before capturing, and never block for minutes.** Long foreground captures
  swallow the owner's queued messages. Run detached and check between turns.
* **`make test` must be green at every commit that can break something.** Run it when a
  commit touches engine source, `asm/`, `engine/tests/`, tooling, or anything a gate reads.
  **Skip it for documentation-only commits** — prose in `docs/`, `AGENTS.md`, `LICENSE`,
  `THIRD-PARTY-LICENSES`. Running the suite there buys nothing and costs a couple of minutes
  per commit; the rule exists to catch regressions, not to certify spelling. If a docs change
  describes a gate or a tool, verify the commands it claims still work instead of running the
  suite — a documented command that has silently stopped working is the real defect.
  Baseline moves (CP2 evidence) still need owner approval and a named reason in the gate log
  in `docs/phase4-state.md`.
* **Spice86 polling:** the memory API sustains ~250 req/s (`tools/poll_probe.py`).
  The old 3 Hz limit belonged to the windowed CFG view model, not to reads.

## 4. Repository Layout

| path | contents | git |
| --- | --- | --- |
| `asm/` | the reconstruction: one file per function (`<ADDR>_<name>.asm`), headers carry evidence, confidence and provenance | tracked |
| `engine/` | portable C11 engine (Phase 4), own `README.md`, tests, `make` targets | tracked |
| `engine/assets/tiles/cleanroom/` | original substitute tile art, created under cleanroom protocol; `PROVENANCE.md` is the legal record and travels with it. Never a reproduction of the game's art. The implementer's only legal input is `docs/tile-art-spec.md`; the evidence and the gate's bands live in `docs/tile-art-evidence.md` and `tools/tile_rules.py` and are forbidden to them. **The full procedure, verification chain and recorded failures are in `docs/cleanroom-procedure.md` — read it before commissioning or performing a redraw.** | tracked |
| `tools/` | our authored Python/shell toolchain: `check_func.py`, `assemble_clean.sh`, `decode_str.py`, `dialect_masm.py`, `xref_provenance.py`, `cfg_printed.py`, `bcd_census.py`, `provenance_from_traces.py`, `reject_trap.py`, `vga_screen.py`, `map_render.py`, `map_viewer.py`, `tile_review.py`, `tile_rules.py`, `turn_recorder.py`, `vga_ring.py`, `poll_probe.py`, `screenshot_diff.py`, `spice86_{start,stop}.sh` | tracked |
| `docs/` | phase plans, state, implementation logs, live-capture findings, `harness-portability.md` (the generic-harness design report; method only, never conclusions), and `needs-gameplay.md` (the capture worklist with who-can-do-it verdicts) | tracked |
| `disasm/` | curated analysis: phase summaries, function maps, verdicts | tracked |
| `bestiary/` | third-party creature data joined to our tile table by bitmap identity. `bestiary.tsv` and `matches.md` are our own derived facts; `cache/` and `view.html` hold copyrighted art rips in seven platform variants. Read `docs/bestiary.md` before using it, and note the cleanroom entries. | `cache/` and `view.html` **gitignored** |
| `captures/` | runtime captures and screenshots | **gitignored** |
| `original/` | working copy of the game files — the executable **plus** its sidecar content (`mapxNN` sector maps, `monxNN` monster data, `tlkxNN` NPC dialogue, `pic*` pictures, the `player` save). Ultima II is not a single-file game: the 37 KB exe is the engine and the pack is ~94 files, about 2.2 MB | **gitignored** |
| `references/` | pristine read-only backup | **gitignored** |
| `decompiled/` | bulk decompiler output, regenerable | **gitignored** |
| `tmp/` | per-launch game copies | **gitignored** |
| `build/` | build output | **gitignored** |

Known names in `asm/` include the 26 command handlers `cmd_A`..`cmd_Z`,
`str_out`, and OS seam labels (`video_int10`, `key_int16`, `dos_int21`,
`speaker_tone`) marking hardware/DOS call sites — the replacement surface for
the engine.

> **`captures/spice86/spice86-cfg.json` is the authoritative source for routine entry points.** This game's command handlers are reached by `jmp *%bx` through a jump table, not `call`/`ret`, so Ghidra and Reko cannot discover them statically. Blocks in the runtime CFG were actually executed — use their start addresses (segment `017D`, `file_offset = offset + 0x200`) as the seed list for both decompilers. See `captures/README.md` for the schema, address mapping, and the relocation caveat (runtime bytes differ from file bytes wherever an MZ fixup applies).
>
> **Correction, 2026-10-21: CFG *blocks* are not proof of execution.** `spice86dumpCfgBlocks.json` lists **discovered** blocks — Spice86 statically expands branch successors — so a block can appear without ever having run. It reported `MINAX IS DEAD!!`, `RING PROTECTS FROM FIELD!` and `FIELD CAUSES 1000 DAMAGE!` for a session that met none of them. The authority for "this ran" is `ExecutedInstructions` inside `spice86dumpExecutionFlow.json` (a list of `{Offset, Segment, Linear}` dicts). Use block entries as a seed list, which is what they are good for, but never as evidence that code executed. See `tools/cfg_printed.py`, which gets this right.

## 5. Evidence Discipline (READ BEFORE ASSERTING ANYTHING)

Grade every claim, and say which grade you are asserting:

| grade | meaning |
| --- | --- |
| **observed** | a byte, memory value, or CFG block read from the binary or a live session |
| **measured** | derived from observations by a tool, with the tool and inputs named |
| **inferred** | reasoned from a partial read — a listing, a name, a plausible pattern |
| **recalled** | the owner's memory of playing the original |

### An owner observation outranks an agent inference

When the owner reports what they saw or did — "I was paralyzed", "the staff is
gone", "it went back to the splash", "it was a green gem" — that is **data**, and
it outranks anything inferred here. Every such conflict so far has resolved with
the agent wrong, not the owner: the green gem (a hex miscount, not a wrong table),
the post-creation splash (the engine had shortcutted a real program restart), the
stolen staff (later proven by bytes), and mountains blocking on foot.

So on conflict: re-check your own measurement first. Do not conclude the owner
misremembered until you have disproven your own reading, and if you still
disagree, **say so explicitly and name the evidence** — never quietly overwrite a
reported observation with an inference.

A recalled detail is also worth chasing when there is no conflict yet. On
2026-10-22 the owner recalled stats wrapping to 0 above 99; the bytes agreed
(1-byte packed decimal, no ceiling guard on any add site) and the recollection
opened up a general property of the save format that no agent had thought to look
for. Treat "I remember it did X" as a pointer at a place to measure.

### Bytes outrank everyone, including the owner

Recalled design intent is a hypothesis to test, not a conclusion. Where bytes
disagree with a recollection, record the disagreement rather than picking a side
silently.

### Derive; do not eyeball

* Compute indices and offsets in code. Splitting a hex string by eye invented a
  false discrepancy that wasted a session.
* Read a whole function before describing it. `asm/2423` declares a 10-byte range
  for a routine running to about `0x2680`; the truncated read produced a
  retracted finding.
* List the existing corpus before harvesting runtime data. Paralysis, theft and
  combat functions were already named on disk while a capture was run to look for
  them.

### A tool that lies is worse than no tool

Validate any new analysis tool against a **negative control** — a case where the
answer is known to be *no* — before citing its output. `cfg_printed.py` reported a
Minax fight that never happened because it read discovered blocks instead of
executed ones; the pre-fight harvest, used as a control, exposed it immediately.
`bcd_census.py`'s first draft under-counted guards by 3× because it looked for
`cmp`/`test` and the real subtract idiom is `cmc; sbb; das; cmc` — the second `cmc`
re-exposes the borrow in CF for a following `jb`, so a cmp-based detector reports a
guarded site as unguarded. Both mistakes produced a *plausible* wrong number rather
than an error, which is the dangerous shape. Prefer failing loudly to returning a
plausible default, and make unproven numbers say so in the comment next to them.

### A gate that cannot go red is worse than a tool that lies

A checker that returns a wrong answer is bad; a checker that returns a wrong
**verdict** is worse, because everything downstream treats it as fact. So:
**demonstrate a gate failing before you trust it passing.** The test is cheap —
invert one expectation, or feed one known-bad input, confirm the gate goes red,
restore. Two minutes that would have caught both of these:

* `engine/tests/run_cp5.sh` carried an unconditional `exit 0` on the branch taken
  while `combat.c` was absent, which swallowed every failure before it. The CP5
  gate printed `FAIL` and still reported `PASS` to CI — and since that branch was
  the only one ever taken, the gate had never once been capable of failing.
* The same script asserted its controls in a comment instead of running them, so
  the one property that mattered — that the spec rejects a boolean-immunity
  implementation — had no proof behind it once the throwaway models in `/var/tmp`
  disappeared. Controls now ship as fixtures
  (`engine/tests/combat_model_{faithful,boolean_wrong}.c`) and run on every
  `make test`.

Prefer a gate that fails loudly on its own misconfiguration over one that reports
success when it checked nothing. A skip is fine; a skip that can hide a failure is
not.

