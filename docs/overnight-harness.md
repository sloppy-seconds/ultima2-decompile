# Overnight task queue — generic harness: binary overlap probe + profile inventory

Autonomous queue for a fresh agent running unattended. Every task here is chosen
because it needs **no owner interaction and no new files**: all inputs already exist
inside this project. If a task turns out to need anything else, pass it with a reason
rather than improvising.

Standing context: `AGENTS.md` (hard law), `docs/harness-portability.md` (the design
report this queue serves), `docs/phase4-state.md` (checkpoint table, backlog, gate
log).

> **This queue is about METHOD, not about Ultima II.** The point is to build tooling
> that survives moving to a second target. A tool that only works because this
> project already has a function map has failed the brief.

---

## Rules of engagement

1. **Prove or pass.** Nothing may be asserted without a byte citation, a captured
   frame, or a recorded run. If evidence is insufficient, write what was found and
   exactly what is missing into the progress report, mark the task PASSED, and move
   on. A passed task with a clear reason is a success; a guessed mechanism is a
   failure.
2. **Never read outside this project root.** This is `AGENTS.md` § 0 and it bites
   harder here than anywhere else: the subject is *another game*. **Do not search the
   filesystem, the internet, or any sibling directory for an Ultima III binary, a
   crack, a shareware pack, or a prior attempt.** If a task needs a file this project
   does not have, that task is BLOCKED — say so and stop. Do not go and get it.
3. **Never write to `original/` or `references/`.** They are read-only inputs here.
   The overlap tool reads bytes and writes nothing into those trees.
4. **No emulator launches.** Everything is offline static analysis.
5. **`make -C engine test` must be green at every commit.** If anything under `asm/`
   is touched — and it should not be — `bash tools/assemble_clean.sh` must still
   print `CLEAN REBUILD BYTE-MATCH: 37344 bytes identical`, and remember that in
   `asm/` only the filename and `#` comment lines may change: **labels are body**.
6. **Demonstrate every new gate failing before trusting it pass.** Invert one
   expectation or feed one known-bad input, confirm red, restore. `AGENTS.md` § 5.
   A gate that cannot go red is worse than no gate; this queue has already been
   bitten by exactly that, twice.
7. **Never edit a file with a script; never heredoc a non-trivial script.** Use the
   edit tool; write scripts to files, syntax-check them, run the file.
8. **Scratch goes to `/var/tmp`, never `/tmp`** (tmpfs here; it takes RAM from the
   model).
9. **Commit in logical units**, reason in the message. Grade every claim:
   `observed` / `measured` / `inferred` / `recalled`.
10. **The contamination rule applies to you.** `docs/harness-portability.md` is
    method-only: no addresses, no DS layouts, no record formats, no symbol names from
    this binary may be written into it. If a learning is method, add one line to its
    feedback log in the same commit (`AGENTS.md` § 3 makes this an obligation). If
    the learning is a conclusion about this game, it belongs in `asm/` or the
    findings doc, never there.

---

## Tier A — the overlap probe. Do this first.

### H1 — `tools/func_overlap.py`: measure shared code between two DOS binaries

**Why.** `docs/harness-portability.md` § 8 probe 1. The whole plan for a second
target rests on an unmeasured assumption: that a contemporary game may share code
with this one. That is cheap to test and it changes the plan either way, so measure
it instead of assuming it.

**The blocker that is not a blocker.** The *comparison* against another game needs a
second game, which this project does not have. The **tool** does not: the pack
already ships several unrelated DOS executables that make excellent controls. Build
and validate the tool tonight; the comparison is a ten-minute job once the owner
supplies a binary.

**Hard requirement — the tool must be generic.** It may not depend on
`disasm/function-map.tsv`, on this executable's name, on the `+0x200` file bias, or
on any knowledge of this game's layout. It takes two paths to two binaries and
nothing else. If it needs a pre-existing function map, it has failed the brief,
because the second target will not have one.

**Deliverable.** A tool that, given two MZ executables, reports a normalised
shared-code measure and the addresses of the shared regions. Boundary discovery is
your choice (linear sweep, basic-block starts, call-target seeds, aligned n-grams),
but state in the tool's header what method you picked and what it cannot see.

**Calibration — mandatory, and it is the actual deliverable.** The tool must
self-validate against these four in-project pairs, and must fail loudly if any
expectation is wrong:

| pair | expected | what it proves |
| --- | --- | --- |
| `original/ultimaii.exe` vs itself | ~100% | sanity |
| `original/ultimaii.exe` vs `original/updated/ultimaii.exe` | very high, **not** 100% | normalisation tolerates a patched build of the same program (both are 37,344 B — the patch is size-preserving, so this is a real test of normalisation, not of length) |
| `original/ultimaii.exe` vs `original/updated/u2ega.exe` | near zero | a true negative control: unrelated DOS code must not match |
| `original/ultimaii.exe` vs `original/CHOICE.EXE` | near zero, and the tool must **notice** this one is not a DOS image | `CHOICE.EXE` carries an MZ header but is PE32. A tool that reports a confident number for a non-DOS image is lying. Detect and refuse, or detect and warn — do not silently proceed. |

Ship this as `--selftest` so CI can run it, and make it SKIP cleanly (exit 0) when
the gitignored binaries are absent, exactly like `tools/cfg_printed.py --selftest`
does. **Then prove the selftest can fail**: perturb one expectation, confirm red,
restore.

**Known trap.** Do not compare raw bytes across the two files and call it overlap —
relocation, self-modifying code and MZ fixups make identical code look different and
different code look identical. `captures/README.md` documents the relocation caveat
for this binary; assume the same class of problem generally and say in the header
what you normalise away.

---

## Tier B — inventory only. Measure the refactor; do not perform it.

### H2 — profile inventory and a draft profile file

`docs/harness-portability.md` § 4 proposes a generic harness driven by one
declarative profile per target. Before anyone refactors, we need the honest size of
the job.

**Deliverable, and it is deliberately read-only with respect to the tools:**

1. `profiles/ultima2.draft.json` — a draft profile containing every piece of game
   knowledge currently embedded in tool code, laid out per the § 4 schema
   (`artifact`, `addressing`, `fields`, `oracles`, `seeds`, `video`, `turn_model`,
   `invariants`). Values must be copied from working code, not invented.
2. A per-tool table listing every hardcoded game constant: file, what it hardcodes,
   which profile section it belongs to.

**Do not change any tool.** The refactor is a separate, owner-scheduled job — it
touches every observer tool against a tree that currently passes everything, and it
is not appropriate for unattended work. This task produces the measurement that
makes it safe.

**Note on prior estimates.** An earlier audit grepped for named constants and found
about seven tools with embedded offsets. That **under-counts**: field offsets also
hide inside bare slicing literals like `head[0x53:0x56]`, which no grep for a named
constant catches. Your table is the corrected number; expect it to be larger and say
so.

---

## Tier C — only if H1 and H2 are done or passed

### H3 — feed the result back into the design report

If H1 produced a working, calibrated tool: add one line to
`docs/harness-portability.md` § 6 feedback log about what the calibration revealed
(especially if a control pair behaved unexpectedly — that is the most valuable
outcome possible here), and update § 8 probe 1 to record that the tool exists and
what it is waiting on.

If H1 revealed that the generic requirement is harder than § 4 assumed, **write
that down as a limitation rather than quietly narrowing the tool to fit this game.**
A tool that only works here is a finding about the plan, not a success.

---

## Explicitly blocked — do not attempt

* **H4 — the actual Ultima III comparison.** BLOCKED, needs owner input: a Ultima III
  DOS executable placed inside this project at a path the owner names. Nothing in
  this project matches `*u3*`, `*ultima*iii*` or `*exodus*`, and per rule 2 you must
  not go looking. Record the exact command line to run once the file arrives, so the
  owner can do it in one step.
* Any refactoring of existing tools to read the profile.
* Anything requiring the owner to drive the game: the dungeon geometry decode, the
  `A`–`Z` dungeon byte decode, the five-question passability capture, CP5 ticket C5.
* Starting CP5, CP6 or CP7 implementation. Combat is owner-gated; the acceptance
  spec already exists and its controls ship in `engine/tests/`.

---

## Progress report

Write to `docs/overnight-harness-report.md` as you go, not at the end: one section
per task with status (`DONE`, `PASSED — reason`, `BLOCKED — what is needed`), the
evidence used, and the commit hash if anything landed. If the run dies partway, the
file should still say where it got to.
