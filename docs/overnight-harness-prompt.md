# Overnight agent prompt — generic harness: overlap probe + profile inventory

Paste this to a fresh agent to start the queue:

---

You are running an unattended overnight task queue for the Ultima II decompilation
project at `/var/home/paul/Projects/decompile-u2-v2`. The owner is asleep. There is
no one to ask.

**Read first, in this order:**

1. `AGENTS.md` (project root) — isolation, licensing, script rules, evidence
   discipline. Hard law. Especially: this project reads and writes only inside its
   own root; `original/` and `references/` are never written; scratch goes to
   `/var/tmp`, never `/tmp`; in `asm/` only the filename and `#` comment lines may
   change, because **labels are body**.
2. `docs/overnight-harness.md` — **this is your work order.** Tasks H1–H3, the rules
   of engagement, and what is explicitly blocked.
3. `docs/harness-portability.md` — the design report this queue serves. § 4 is the
   proposed architecture, § 8 the probe list, § 6 the feedback log you may append to.
4. `docs/phase4-state.md` — checkpoint table, backlog, gate log.

**The contract (overrides everything else):**

1. **Prove or pass.** Every claim needs a byte citation, a captured frame, or a
   recorded run. If the evidence is insufficient, do NOT guess. Mark the task
   PASSED, write what you found and what is missing into
   `docs/overnight-harness-report.md`, and move on.
2. **Never read outside the project root — and this matters more here than usual.**
   The subject of this queue is *another game*. Do not search the filesystem, the
   internet, or any sibling directory for an Ultima III binary, a pack, or a prior
   attempt. If a task needs a file this project does not have, it is BLOCKED: record
   the exact command to run once the owner supplies it, and stop.
3. **No emulator launches.** All work is offline static analysis of bytes already on
   disk.
4. **`make -C engine test` must be green at every commit that touches code, tooling or
   anything a gate reads**; documentation-only commits may skip it (`AGENTS.md` § 3).
   `asm/` should not need
   touching at all.
5. **Demonstrate every new gate failing before you trust it passing.** Invert one
   expectation, confirm red, restore, and put the result in the report. Two gates in
   this project have already shipped unable to fail; do not add a third.
6. **Never edit a file with a script. Never heredoc a non-trivial script.** Use the
   edit tool; write scripts to files, syntax-check them, run the file.
7. **The contamination rule.** `docs/harness-portability.md` is method-only — no
   addresses, DS layouts, record formats or symbol names from this binary. Method
   learnings go in its § 6 feedback log in the same commit; game conclusions go in
   `asm/` or the findings doc.
8. **Stop rather than invent work.** When H1–H3 are DONE/PASSED/BLOCKED, finish the
   report and return. Do not refactor tools, do not start CP5/CP6/CP7, do not attempt
   the dungeon byte decode.

**Start with H1.** Build `tools/func_overlap.py`: given two MZ executables, report a
normalised shared-code measure. It must be **generic** — no dependency on this
project's function map, executable name, or the `+0x200` file bias. A tool that only
works because this game is already mapped has failed the brief, because the second
target will not be mapped.

**The comparison against another game is blocked; the tool is not.** The pack already
ships unrelated DOS executables that serve as controls, and calibrating against them
is the real deliverable:

* `original/ultimaii.exe` vs itself → ~100%
* `original/ultimaii.exe` vs `original/updated/ultimaii.exe` → very high but **not**
  100%; both are 37,344 bytes, so this tests normalisation, not length
* `original/ultimaii.exe` vs `original/updated/u2ega.exe` → near zero (true negative)
* `original/ultimaii.exe` vs `original/CHOICE.EXE` → near zero, **and the tool must
  notice this one is PE32 behind an MZ header and refuse or warn rather than print a
  confident number**

Ship it as `--selftest`, SKIP cleanly when the gitignored binaries are absent so CI
stays honest, and then prove the selftest can fail.

**Then H2, inventory only.** Produce `profiles/ultima2.draft.json` plus a per-tool
table of every hardcoded game constant. **Do not change any tool** — the refactor is
owner-scheduled. Note in your output that the earlier audit under-counted, because
offsets hide in bare slicing literals like `head[0x53:0x56]`, not only in named
constants.

**Three traps from earlier sessions, so you do not repeat them:**

* A probe that caches the 4 KB map grid at startup produces **stale tile labels**;
  the map mutates during play. Re-read per sample.
* Check **filename casing and radix** before trusting an identification. A `%02d`
  format against hex-named PNGs produced a wrong tile byte that was committed and
  then corrected. Observed monster-type lists in this project are **decimal**.
* The BIOS video mode is physical `0x449` (`0040:0049`). Multiplying the whole
  address by 16 reads unrelated RAM and reported mode 30 instead of 4.

If you are genuinely blocked on a decision that is the owner's, use
`contact_supervisor` with `reason: "need_decision"` and stay alive for the reply —
but prefer PASSED or BLOCKED with a reason over blocking, since the owner is asleep.

**Write `docs/overnight-harness-report.md` as you go**, one section per task with
status `DONE` / `PASSED — reason` / `BLOCKED — what is needed`, the evidence used,
and the commit hash. If your run dies partway, that file must still say where you
got to.

Begin.
