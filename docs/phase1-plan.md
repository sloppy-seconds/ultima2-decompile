# Phase 1 Plan — Evidence Capture (dynamic + static tracing)

**Purpose of this document:** a self-contained, autonomous work order. A fresh agent session can
be pointed at this file and execute Phase 1 end to end without further human input, stopping only
at the defined gates. Read all of it before starting.

Phase 1 goal (from `AGENTS.md` §2): produce the evidence base every later phase trusts — a
verified routine entry-point list, the runtime segment map, memory dumps, and seeded decompiler
output (Ghidra + Reko) that has been byte-checked. Phase 1 does **not** produce final assembly or
C; it produces ground truth and drafts.

---

## 0. How to run this plan (resume protocol)

1. **State lives in `docs/phase1-state.md`.** Read it first. It lists every checkpoint with a
   status (`todo` / `in-progress` / `done` / `blocked`) and a one-line result note. Resume at the
   first non-`done` checkpoint.
2. Work checkpoints **in order**. Each has: Goal, Steps, Outputs, **Acceptance criteria** (objective
   and testable), **Test** (the command that proves it), and **On failure**.
3. After finishing a checkpoint, update `docs/phase1-state.md` (status, timestamp, artifact paths,
   the measured numbers) **before** starting the next. This is what makes the run resumable and
   auditable.
3a. Keep a running **implementation log** in `docs/phase1-implementation.md`. For every
   checkpoint record: what you did, the exact commands run, the measured outputs, the decisions
   and reasoning, dead-ends hit, and any deviation from this plan. Write it as you go, not from
   memory at the end. This is a committed deliverable and is what makes the work reviewable and
   reproducible by a human or a later session.
3b. **Commit to git at the end of each completed checkpoint** (see §1A). Commit only
   Apache-2.0-safe files per `AGENTS.md` "Licensing & Commit Policy"; `.gitignore` enforces the
   exclusions — **never `git add -f` an ignored path.**
4. **Gates** (marked 🔒) require a human. At a gate: stop, write a short summary into the state
   file, and contact the user. Do not proceed past a gate autonomously.
5. If a checkpoint cannot be completed after the documented recovery attempts, mark it `blocked`,
   record exactly what failed and the error, and stop. Do not fabricate results to pass a check.

### Hard guardrails (from `AGENTS.md` §0 — non-negotiable)

- Work **only** inside `/var/home/paul/Projects/decompile-u2-v2/`. Never read, list, search, or
  take hints from any sibling directory (`decompile-u2`, `ultima2`, `agents/**`, etc.).
- **Never import prior findings** — entry lists, symbol names, struct layouts, or conclusions from
  any earlier attempt. Every address and name in this phase is regenerated from `original/` and
  `captures/` inside this project.
- External **tools** (Ghidra, Reko, Spice86, objdump, dotnet) are infrastructure and may be invoked
  by path. That is allowed. Reading another project's *analysis* is not.
- Scratch and captures go under `tmp/` (project-local) or `/var/tmp`. **Never `/tmp`** (it is RAM
  on this host).
- Do not write to `references/` (pristine backup). Do not mutate `original/`.
- Nothing copyrighted or license-incompatible is committed (see `AGENTS.md` §0 / `.gitignore`).

---

## 1. Invariants and reference facts

### Paths
- Project root: `/var/home/paul/Projects/decompile-u2-v2`
- Working binary: `original/ultimaii.exe` (37,344 bytes; Internet Archive pack, may carry
  community patches — this is the ground truth for *this* project).
- Pristine backup: `references/ultima2/` (read-only; restore only).
- Runtime capture: `captures/spice86/spice86-cfg.json`, `spice86-functions.json`,
  `live-ds-4f4d.bin`.
- Tool wiring: `source tools/env.sh` (sets `GHIDRA_HOME`, `SPICE86_DLL`, `REKO_DLL`,
  `DOTNET_ROLL_FORWARD`).

### Address mapping (verified — use this, do not re-derive)
All four notations below name the **same byte**; the offset field is shared.

| Notation | Form | To file offset |
| --- | --- | --- |
| Runtime CFG block | `017D:XXXX` | `XXXX + 0x200` |
| Ghidra address | `1000:XXXX` | `XXXX + 0x200` |
| Reko address | `0800:XXXX` | `XXXX + 0x200` |
| `objdump -b binary` | prints file offset | as-is |

- **Game code segment in the runtime CFG is `017D`.** Filter out `0A29`/`F000` (BIOS/ROM).
- The `entries=` file for `DecompileMz.java` takes **one hex offset per line** (the `XXXX`),
  optionally `XXXX label`. The script maps it to Ghidra ram as `0x10000 + XXXX`. Do **not**
  include the segment or the `0x200` bias in that file.
- Reko `.dcproject` `<procedure>` addresses use the `0800:XXXX` form.

### Tools (all smoke-tested working)
- Ghidra 12.1.4 at `$GHIDRA_HOME` (needs JDK 21+; system JDK 25 is fine). Scripts in
  `tools/ghidra/` (generic, binary-agnostic — see `docs/ghidra-scripts.md`).
- Reko 0.12.5 at `$REKO_DLL` (`tools/reko/reko.dll`). Run via `dotnet`, never `reko.exe`.
- Spice86 at `$SPICE86_DLL` (`tools/spice86/Spice86.dll`). Capture procedure in
  `docs/spice86-capture.md`.
- `objdump` (GNU binutils) for the byte check.

### Key facts about this binary (from `docs/` and `captures/README.md`)
- Command handlers are reached by `jmp *bx` through a **26-entry word jump table** indexed by
  `(key - 'A') * 2`, and return via `jmp` to a shared exit — never `call`/`ret`. Static call-edge
  reachability is blind to them; entry points must be supplied.
- The runtime `DS` is `0x08BE`; the file's initialising immediate at file `0x0300` is `0x0741`
  (patched at load by the MZ relocation fixup). Runtime-captured bytes differ from file bytes
  wherever a relocation fixup applies — expect this near the entry point; it is not an error.
- Strings are inline: the display routine takes its argument as the bytes right after the `call`,
  so code and data interleave. Linear disassembly from the wrong byte decodes text as code.

---

## 1A. Git workflow

The repo is Apache-2.0 and holds only our authored work (see `AGENTS.md` "Licensing & Commit
Policy"). Game binaries, GPL tool builds, raw captures, and full decompiler dumps are gitignored.

- **First run only:** if `git rev-parse --is-inside-work-tree` fails, `git init`, set a local
  identity if none exists (`git config user.name` / `user.email`), then make the initial commit of
  the existing authored files (`AGENTS.md`, `docs/`, `tools/*.py`, `tools/ghidra/`, `tools/env.sh`,
  `tools/*/README.md`, `LICENSE`, `.gitignore`). Verify with `git status --ignored` that
  `original/`, `references/`, `tools/spice86/`, `tools/reko/`, `decompiled/` are ignored before
  the first commit.
- **Per checkpoint:** stage the checkpoint's committed deliverables (curated `disasm/` notes,
  `docs/` updates, the state file, the implementation log) and commit with a message of the form
  `phase1: CP<n> <short result>` (e.g. `phase1: CP1 entry-points extracted (796 blocks -> 612 unique)`).
- **Never** commit ignored paths; if a step seems to require it, stop and ask (§7).
- One commit per checkpoint keeps history auditable and resumable.

## 1B. Autonomy & escalation policy

Work autonomously and keep moving. Use judgment; do not stop to ask about things this plan already
answers or that a competent engineer would simply decide. Escalate **only** in these cases:

- A 🔒 **gate** is reached (CP6, CP7).
- A checkpoint is genuinely **blocked** after the documented recovery attempts (tool won't run,
  required input missing, an address can't be located without guessing).
- A decision would **change the plan's scope or approach**, touch a path outside the project, or
  commit something the licensing policy forbids.
- An acceptance criterion is met only by loosening the criterion (that is the user's call, not
  yours).

For everything else: **decide, do it, and record the decision + reasoning in the implementation
log.** Reasonable choices (dedup rules, sampling selection, file naming within the specified
outputs, retry counts within limits) are yours to make — note them and continue. Do not ask
permission for routine steps, and do not spin for a long time re-trying the same failing approach;
after two distinct recovery attempts, mark `blocked` and escalate with specifics.

---

## 2. Inputs already available (do not regenerate)

- `captures/spice86/spice86-cfg.json` — 845 blocks, 796 in game code segment, execution-confirmed
  entry addresses. Schema: each block has `entry` (`017D:XXXX`), `pred`, `succ` (block ids),
  `asm` (`HEX|disasm`), `dead`, `incomplete`.
- `captures/spice86/spice86-functions.json` — 83 functions with call counts.
- `captures/spice86/live-ds-4f4d.bin` — 4 KB data-segment dump from `DS:0000`.

---

## 3. Checkpoints

### CP0 — Environment & isolation verification
**Goal:** confirm every tool runs and the workspace is clean before any analysis.
**Steps:**
```bash
cd /var/home/paul/Projects/decompile-u2-v2
source tools/env.sh
test -x "$GHIDRA_HOME/support/analyzeHeadless" && echo ghidra-ok
dotnet "$REKO_DLL" --version
dotnet "$SPICE86_DLL" --help >/dev/null 2>&1 && echo spice86-ok
objdump --version | head -1
# Git: initialise on first run and confirm the copyright/GPL exclusions are ignored.
git rev-parse --is-inside-work-tree 2>/dev/null || git init
git status --ignored --short | grep -E '^!! (original|references|tools/spice86|tools/reko)/' >/dev/null \
  && echo "ignore-policy-ok" || echo "CHECK .gitignore"
```
**Outputs:** a git repo with an initial commit of the existing authored files (see §1A).
**Acceptance:** all four tools respond; `original/ultimaii.exe` is 37,344 bytes; `captures/`
files present; `git status --ignored` shows `original/`, `references/`, `tools/spice86/`,
`tools/reko/` ignored; initial commit exists.
**Test:** `wc -c < original/ultimaii.exe` == 37344; the four tool commands exit 0.
**On failure:** if a tool is missing, re-run its vendored install per `docs/reko-install.md` /
`tools/spice86/README.md`; if Ghidra fails on Java, check `java -version` (needs 21+). Mark
`blocked` and stop if a tool cannot be made to run.

---

### CP1 — Extract entry points from the runtime CFG
**Goal:** produce the authoritative, deduped entry-point list from executed blocks.
**Steps:**
1. Parse `captures/spice86/spice86-cfg.json`. Keep blocks whose `entry` segment is `017D`.
2. Extract the `XXXX` offset (the part after the colon). Drop blocks flagged `dead` **only if**
   they have no live predecessors — otherwise keep them (dead ≠ not-an-entry).
3. Deduplicate and sort ascending. Write `disasm/entry-points.txt`, one hex `XXXX` per line
   (4 hex digits, no `0x`, no segment), optionally `XXXX  # block=<id>`.
4. Write `disasm/entry-points.md` documenting: source file, filter rule, count, and the mapping
   table from §1.
**Outputs:** `disasm/entry-points.txt`, `disasm/entry-points.md`.
**Acceptance:**
- Line count of `entry-points.txt` is within a few of the 796 code blocks (dedup may reduce it).
- Spot-check: for 3 random entries, `objdump -d -b binary -m i8086 --start-address=0x<XXXX+200>
  --stop-address=0x<XXXX+200+6> original/ultimaii.exe` yields a plausible instruction start
  (not mid-string). Record the three checks in `entry-points.md`.
**Test:** `wc -l disasm/entry-points.txt`; the three objdump spot-checks printed and sane.
**On failure:** if counts are wildly off, re-read `captures/README.md` limits (197 blocks marked
dead; some blocks are non-code). Do not pad the list.

---

### CP2 — Derive the command jump table
**Goal:** independently locate the 26-entry command-handler table and cross-check CP1.
**Steps:**
1. In `original/ultimaii.exe`, locate the 26-entry word table indexed by `(key-'A')*2`
   (see `docs/decompiling.md` "Supplying entry points"). Each entry is a `cs:` offset.
2. Convert each entry to a file offset (`+0x200`) and to the `XXXX` entries-file form.
3. Write `disasm/jump-table.txt` (one `XXXX handler=<letter>` per line).
4. Verify each jump-table target is present in `disasm/entry-points.txt` (or explain the gap).
**Outputs:** `disasm/jump-table.txt`.
**Acceptance:** exactly 26 entries; each target's bytes at `XXXX+0x200` disassemble as a
plausible routine start; ≥24 of 26 appear in `entry-points.txt`.
**Test:** `wc -l disasm/jump-table.txt` == 26; per-entry objdump check; overlap count vs CP1.
**On failure:** if the table is not cleanly found, do not guess addresses — record the search
method and mark `blocked` for human review. This is a finding, not a tooling task.

---

### CP3 — Segment map and memory-dump inventory
**Goal:** record the runtime segment map and the captured data segment.
**Steps:**
1. From `captures/README.md` and the CFG, write `disasm/segment-map.md`: runtime `CS=0x017D`,
   `DS=0x08BE`, the `0x0741`→`0x08BE` relocation note, and the `+0x200` file mapping.
2. Inventory `live-ds-4f4d.bin`: size, and a short hexdump of the first 64 bytes with any obvious
   structure noted (do not over-interpret; that is Phase 3).
**Outputs:** `disasm/segment-map.md`.
**Acceptance:** segment values match `captures/README.md`; the relocation caveat is stated.
**Test:** values cross-checked against `captures/README.md` text.
**On failure:** if a live re-capture is needed, follow `docs/spice86-capture.md` (copies from
`references/` into `tmp/<timestamp>/`); never run in `original/` or `references/`.

---

### CP4 — Seeded Ghidra decompilation
**Goal:** produce Ghidra pseudo-C for the real entry points, with inline data marked.
**Steps:**
```bash
source tools/env.sh
WORK=$(mktemp -d /var/tmp/u2-ghidra.XXXXXX); mkdir -p "$WORK/proj"
mkdir -p decompiled/ghidra
"$GHIDRA_HOME/support/analyzeHeadless" "$WORK/proj" u2 -deleteProject \
  -import original/ultimaii.exe \
  -scriptPath tools/ghidra \
  -postScript MarkInlineData.java exe=original/ultimaii.exe out=/var/tmp/inline.tsv minlen=6 \
  -postScript DecompileMz.java exe=original/ultimaii.exe \
      entries=disasm/entry-points.txt \
      out=decompiled/ghidra/ultimaii.c index=decompiled/ghidra/ultimaii-functions.tsv
```
(If a single invocation does not honour two `-postScript` args, run MarkInlineData first to a
saved project, then DecompileMz against it; verify both scripts' log lines appear.)
Then, for functions the index marks `failed`, run `RetryDecompile.java` on those addresses and
merge any recovered bodies.
**Outputs:** `decompiled/ghidra/ultimaii.c`, `decompiled/ghidra/ultimaii-functions.tsv`,
`decompiled/ghidra/retry-recovered.c` (if any).
**Acceptance:**
- `ultimaii-functions.tsv` has a row for (nearly) every entry in `entry-points.txt`.
- `decompile_status=ok` count ≥ 60% of rows; the rest are explicitly `failed` (not silently
  missing).
- No `Exception`/`COMPILATION error` in the run log.
**Test:** `cut -f5 decompiled/ghidra/ultimaii-functions.tsv | sort | uniq -c`;
`wc -l` of the tsv vs `entry-points.txt`.
**On failure:** a `Cannot properly adjust input varnodes` failure is expected for some functions
(see `docs/ghidra-scripts.md`); recover via RetryDecompile and record the residual failure count.
Do not treat dropped register assignments as success — that is caught in CP6.

---

### CP5 — Seeded Reko decompilation
**Goal:** produce Reko pseudo-C for the same entry points (second opinion + DS-relative IR).
**Steps:**
1. Build `decompiled/reko/ultimaii.dcproject` with `<arch>x86-real-16</arch>`,
   `<platform>ms-dos</platform>`, absolute `location`/`srcDir`/`asmDir`, and one
   `<procedure><address>0800:XXXX</address><decompile>true</decompile></procedure>` per entry in
   `entry-points.txt`. Do **not** use `--entry` (inert on this binary) and do **not** use
   `--heuristic shingle` (crashes SSA).
2. Run:
```bash
source tools/env.sh
dotnet "$REKO_DLL" decompile decompiled/reko/ultimaii.dcproject --time-limit 1800
```
3. Output lands in a `<name>.reko/` directory **next to the input binary** — locate and move/copy
   the produced `.c`/`.asm` into `decompiled/reko/`.
**Outputs:** `decompiled/reko/ultimaii.dcproject`, Reko `.c`/`.asm` under `decompiled/reko/`.
**Acceptance:** Reko emits ≥1 `.c` per seeded procedure (bodies may be wrong — checked in CP6);
the run completes without an SSA crash.
**Test:** count `.c` files / `define` blocks in Reko output vs entry count.
**On failure:** if Reko emits nothing, check the `.reko` dir location (next to input) and that
`arch`/`platform` are elements not attributes. See `docs/reko-install.md`.

---

### CP6 — Byte-check verification (the gate that matters) 🔒
**Goal:** confirm decompiler claims against the actual bytes. Nothing from CP4/CP5 is trusted
until this passes.
**Steps:**
1. For a stratified sample (≥15 functions, plus **all** jump-table handlers from CP2), for each
   function: `objdump -D -b binary -m i8086 --start-address=0x<XXXX+200>
   --stop-address=0x<end+200> original/ultimaii.exe`.
2. Confirm every constant and memory operand the decompiler asserted appears in that disassembly.
   Flag any asserted constant not present in the claimed range.
3. Write `disasm/bytecheck-report.md`: per sampled function — entry, verdict
   (`verified` / `mismatch` / `unverified`), and the specific mismatches.
**Outputs:** `disasm/bytecheck-report.md`.
**Acceptance:** every sampled function is `verified` or has its mismatches explicitly listed;
zero unflagged mismatches. Any `mismatch` is annotated with the likely cause (inline string,
relocation fixup, boundary drift).
**Test:** the report exists and has a verdict line per sampled function.
🔒 **Gate:** present the bytecheck summary to the user before sign-off. Do not self-certify.
**On failure:** mismatches traced to wrong entry boundaries feed back into CP1/CP2 corrections.

---

### CP7 — Function inventory and Phase 1 sign-off
**Goal:** consolidate Phase 1 outputs into a single machine-readable inventory.
**Steps:**
1. Produce `disasm/functions.tsv`: `entry  size_bytes  ghidra_status  reko_status  bytecheck
   confidence  source` (source = cfg | jump-table | both).
2. Update `docs/phase1-state.md`: all checkpoints `done`, final counts, artifact paths.
3. Write a short `disasm/phase1-summary.md`: what was captured, coverage numbers, known gaps
   (paths the single CFG playthrough never reached), and what Phase 2 must resolve.
**Outputs:** `disasm/functions.tsv`, `disasm/phase1-summary.md`.
**Acceptance:** see §4 global criteria.
🔒 **Gate:** human reviews `phase1-summary.md` and authorises Phase 2.

---

## 4. Global acceptance criteria (Phase 1 "done")

Phase 1 is complete only when **all** hold:
1. `disasm/entry-points.txt` exists, is CFG-derived, deduped, and spot-check verified (CP1).
2. `disasm/jump-table.txt` has 26 cross-checked command handlers (CP2).
3. `disasm/segment-map.md` records CS/DS and the relocation caveat (CP3).
4. Seeded Ghidra output exists with ≥60% decompiled and all failures logged (CP4).
5. Seeded Reko output exists for the same entries (CP5).
6. `disasm/bytecheck-report.md` shows zero unflagged mismatches on the sample + all handlers
   (CP6), **human-approved**.
7. `disasm/functions.tsv` + `phase1-summary.md` written, state file all-`done` (CP7).
8. Every artifact was produced from `original/` + `captures/` only; no sibling-directory findings
   were imported (self-attest in `phase1-summary.md`).

---

## 5. Testing strategy (how each claim is proven)

- **Byte check is the arbiter.** `objdump -D -b binary -m i8086` over the exact file range is the
  only ground truth. A decompiler body that asserts a constant absent from its range is wrong.
- **Cross-tool agreement** (Ghidra vs Reko vs CFG) raises confidence but is not proof; the bytes
  are proof.
- **Coverage honesty:** entry-to-next-entry spans tile the range by construction and always report
  100% — never cite that as coverage. Report *decompiled-and-verified* counts only.
- **Determinism:** each checkpoint's Test command is re-runnable and should reproduce its number.

---

## 6. Known limits to record, not hide

- The CFG is **one playthrough** (~2,438 instruction records over ~10,000 code bytes). Code never
  executed is absent; absence is not evidence of non-code. Phase 2 may need a broader re-capture
  via `docs/spice86-capture.md`.
- 197 CFG blocks are marked `dead`; some are real code on un-taken paths.
- The binary may carry community patches (Internet Archive provenance) — a byte-match here is
  against this pack, not the pristine 1983 release.

---

## 7. Definition of "stop and ask the user"

Stop and contact the user when: a 🔒 gate is reached; a checkpoint is `blocked` after documented
recovery; a jump-table or entry cannot be located without guessing; or anything would require
touching a path outside the project. Never resolve a blocker by consulting a sibling directory.
