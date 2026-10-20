# AGENTS.md — Linux-Native DOS Game Decompilation & Byte-Matching Pipeline

This document defines the high-level architecture, compiler selection, automated diffing tools, testing strategies, and execution protocols for AI agents (and human collaborators) reverse engineering early 16-bit real-mode DOS binaries (e.g., *Ultima II*) into assembly, re-engineering into C where appropriate, and verifying exact byte-for-byte fidelity.

> **Executable work orders:** Phase 1 (evidence capture), Phase 2 (function boundaries,
> code/data separation, per-function asm corpus) and Phase 3 (clean byte-exact ASM
> reconstruction, MASM dialect via jwasm target) are **complete and signed off** — see
> `disasm/phase1-summary.md`, `disasm/phase2-summary.md` and `disasm/phase3-summary.md`.
> Phase 4 (portable C engine reimplementation from the asm/ tree) is `docs/phase4-plan.md`;
> to start a fresh agent on it, paste `docs/phase4-kickoff.md`. The earlier per-function
> C-lift draft (`docs/phase4-draft-c-lift.md`) is superseded by the engine route.

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

## 1. Important Domain Context: Compiler & Tool Selection

When working on early 16-bit DOS games (early-to-mid 1980s vs late 80s/90s), choosing the right compilation target is critical:

### A. Assembly (`.asm`) vs. High-Level C
* **Early DOS Era (e.g., *Ultima II*, 1982/1983):** *Ultima II* was originally hand-coded in **6502 assembly** for Apple II by Richard Garriott and later ported to x86 MS-DOS via **pure assembly**. There is **no C compiler output in the original binary**. 
  * *Strategy:* For strict byte-for-byte matching on pure assembly games, the primary decompilation target **must be an assembler** (`MASM` or `NASM`).
  * *Secondary Lift:* Higher-level C logic can be generated for portability/readability, but matching binary opcodes byte-for-byte against the original binary requires matching MASM/JWasm output.
* **Mid-to-Late DOS Era (e.g., *Ultima IV/V*, *Alone in the Dark*):** Games compiled from C sources (e.g., Borland Turbo C, MSC 4.0/5.1).
  * *Strategy:* Matching compilation requires recreating C functions and targeting the historical C compiler.

### B. Compiler / Assembler Matrix for Linux Host Environments

| Target Type | Toolchain | Linux Integration Strategy | Suitability for Byte-Matching |
| :--- | :--- | :--- | :--- |
| **Pure Assembly (Original)** | **MASM 4.0/5.0** or **JWasm** | Run MASM via `dosemu2` / `JWasm` natively on Linux. | **Highest** for early DOS games (*Ultima I-III*). |
| **Ported Assembly** | **NASM** | Native Linux executable. | High, provided segment/alignment directives match original. |
| **Historical C Code** | **Turbo C 2.0 / 3.0** | Run inside `dosemu2` or `DOSBox-Staging` via CLI scripts. | Mandatory for 100% C-matching on Borland-compiled games. |
| **Modern C Cross-Compile** | **Open Watcom (`wcl`)** | Native 16-bit x86 target (`wcl -m[s\|c\|l] -2 -386`) on Linux. | Excellent for functional ports, but won't match Turbo C opcodes. |

---

## 2. High-Level Pipeline Architecture

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│ Phase 1: Static & Dynamic Tracing (Spice86 + Ghidra / Reko)                      │
│ - Capture CFG, ES/DS segment maps, memory dumps, function signatures.           │
└────────────────────────┬─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│ Phase 2: Ground-Truth Assembly Extraction (`.asm`)                               │
│ - Disassemble to MASM/NASM syntax; achieve 100% byte match via `jwasm` / `nasm`. │
└────────────────────────┬─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│ Phase 3: Pseudo-C Lifting & Struct Recovery                                     │
│ - Convert assembly routines to readable 16-bit C (far/near pointers, structs).    │
└────────────────────────┬─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│ Phase 4: Automated Linux-Native Byte-Matching Loop                               │
│ - Compile -> Slice Opcode Bytes -> Run `bindiff.py` -> Feed diff to AI Agent.    │
└──────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Automated Binary Diffing & Verification Setup

### A. Python Automated Function/Binary Matcher (`tools/bindiff.py`)

Save this script in `tools/bindiff.py` to compare compiled function byte slices against original binary offsets.

```python
#!/usr/bin/env python3
import sys
import argparse
from typing import Tuple

def load_bytes(filepath: str, offset: int, length: int) -> bytes:
    with open(filepath, 'rb') as f:
        f.seek(offset)
        return f.read(length)

def compare_slices(orig_file: str, orig_offset: int, 
                   built_file: str, built_offset: int, 
                   length: int) -> Tuple[bool, float, list]:
    orig_bytes = load_bytes(orig_file, orig_offset, length)
    built_bytes = load_bytes(built_file, built_offset, length)
    
    matches = 0
    diff_report = []
    
    for idx, (b1, b2) in enumerate(zip(orig_bytes, built_bytes)):
        if b1 == b2:
            matches += 1
        else:
            diff_report.append(
                f"  +0x{idx:04X} ({idx:04d}): Orig 0x{b1:02X} <---> Built 0x{b2:02X}"
            )
            
    match_percentage = (matches / float(length)) * 100.0 if length > 0 else 100.0
    return (matches == length), match_percentage, diff_report

def main():
    parser = argparse.ArgumentParser(description="16-Bit DOS Byte-Matching Verifier")
    parser.add_argument("--orig", required=True, help="Path to original executable")
    parser.add_argument("--orig-offset", type=lambda x: int(x, 0), required=True)
    parser.add_argument("--built", required=True, help="Path to compiled build artifact")
    parser.add_argument("--built-offset", type=lambda x: int(x, 0), default=0)
    parser.add_argument("--len", type=lambda x: int(x, 0), required=True, help="Function length in bytes")
    
    args = parser.parse_args()
    
    is_match, percent, diffs = compare_slices(
        args.orig, args.orig_offset, args.built, args.built_offset, args.len
    )
    
    print(f"=== BYTE-MATCH VERIFICATION ===")
    print(f"Match Level: {percent:.2f}% ({'MATCH SUCCESS' if is_match else 'MATCH FAILURE'})")
    
    if not is_match:
        print("\nDiscrepancies Found:")
        for line in diffs[:20]: # Print first 20 diffs
            print(line)
        if len(diffs) > 20:
            print(f"  ... and {len(diffs) - 20} more diffs.")
        sys.exit(1)
    else:
        print("Opcode bytes match identically.")
        sys.exit(0)

if __name__ == "__main__":
    main()
```

---

## 4. Linux-Native Verification & Test Runner

### A. Makefile Protocol (`Makefile`)

The Makefile integrates `dosemu2` (or `JWasm` / `Open Watcom`) natively on a Linux host to build and test function matches automatically.

```makefile
# Environment configuration
ORIG_BIN = original/ULTIMA2.EXE
BUILD_DIR = build
TOOLS_DIR = tools

# Function Verification Targets
# Example: Testing main video init routine (Length 0x4A bytes at offset 0x0120)
FUNC_OFFSET = 0x0120
FUNC_LEN = 0x004A

.PHONY: all clean verify_asm verify_c

all: verify_asm

# 1. Assemble ground-truth ASM using JWasm (Linux Native MASM-compatible)
$(BUILD_DIR)/engine_asm.obj: disasm/engine.asm
	@mkdir -p $(BUILD_DIR)
	jwasm -bin -fo=$(BUILD_DIR)/engine_asm.bin disasm/engine.asm

# 2. Compile candidate C code using Open Watcom 16-bit real-mode cross compiler
$(BUILD_DIR)/engine_c.bin: src/engine.c
	@mkdir -p $(BUILD_DIR)
	wcl -ms -1 -s -zp1 -o -s -fe=$(BUILD_DIR)/engine_c.bin src/engine.c

# 3. Verify ASM disassembly matches target original binary slice
verify_asm: $(BUILD_DIR)/engine_asm.obj
	python3 $(TOOLS_DIR)/bindiff.py \
		--orig $(ORIG_BIN) --orig-offset $(FUNC_OFFSET) \
		--built $(BUILD_DIR)/engine_asm.bin --built-offset 0x00 \
		--len $(FUNC_LEN)

# 4. Verify C Decompiled matching
verify_c: $(BUILD_DIR)/engine_c.bin
	python3 $(TOOLS_DIR)/bindiff.py \
		--orig $(ORIG_BIN) --orig-offset $(FUNC_OFFSET) \
		--built $(BUILD_DIR)/engine_c.bin --built-offset 0x00 \
		--len $(FUNC_LEN)

clean:
	rm -rf $(BUILD_DIR)/*
```

---

## 5. Automated AI Agent Prompt Guidelines

When feeding assembly diffs back into an AI agent during **Phase 4**, enforce these exact guidelines:

```
[SYSTEM PROMPT FOR RE MATCHING AGENT]
You are a 16-bit x86 reverse engineering agent working on Linux.
Your goal is to adjust C/ASM source code to produce identical machine code bytes.

Rules for byte-matching iteration:
1. Stack Frames: Check if target expects standard BP prologue ('push bp; mov bp, sp').
2. Pointer Types: Ensure pointers are explicitly declared 'far' or 'near' based on segment overrides in diffs.
3. Variable Sizes: Remember in 16-bit Real Mode: 'sizeof(int) == 2', 'sizeof(long) == 4', 'sizeof(near*) == 2', 'sizeof(far*) == 4'.
4. Register Allocation: If the diff shows 'MOV AX, [SI]' vs 'MOV AX, [BX]', adjust local variable declaration order or register keyword hints.
```

---

## 6. Project Directory Layout

```
/var/home/paul/Projects/decompile-u2-v2/
├── original/               # WORKING COPY of the original DOS game files (read/write)
│   └── ultimaii.exe        # Original DOS binary (Internet Archive pack, may carry community patches)
├── references/
│   └── ultima2/            # PRISTINE read-only backup of original/ — restore only, never edit
├── docs/                   # Project documentation (decompiling.md, spice86-capture.md)
├── captures/               # Runtime capture artefacts from Spice86 (ground-truth evidence)
│   └── spice86/
│       ├── spice86-cfg.json        # Runtime CFG: 845 basic blocks, real executed entry points
│       ├── spice86-functions.json  # 83 discovered functions with call counts
│       └── live-ds-4f4d.bin        # 4 KB data-segment dump (DS:0000 onward)
├── disasm/
│   ├── main.asm            # Ground truth assembly (MASM syntax)
│   └── engine.asm
├── src/
│   ├── main.c              # Lifted C sources
│   └── engine.c
├── tools/
│   ├── env.sh              # source to wire GHIDRA_HOME / SPICE86_DLL / REKO_DLL
│   ├── bindiff.py          # Python byte comparison script
│   ├── parse_spice_trace.py# Spice86 JSON trace parser
│   ├── ghidra/             # Ghidra headless scripts (DecompileMz/All, MarkInlineData, RetryDecompile; Apache-2.0, generic tooling)
│   ├── spice86/            # Vendored self-contained Spice86 linux-x64 build (gitignored; see its README)
│   └── reko/               # Vendored Reko 0.12.5 decompiler, reko.dll (gitignored; see docs/reko-install.md)
├── build/                  # Generated binary artifacts
├── Makefile                # Linux-native build & test pipeline
└── AGENTS.md               # Pipeline instructions & standards
```

> Note: `original/` is the working copy agents operate on. `references/ultima2/` is an immutable safety copy of the same files — see Section 0.

> **`captures/spice86/spice86-cfg.json` is the authoritative source for routine entry points.** This game's command handlers are reached by `jmp *%bx` through a jump table, not `call`/`ret`, so Ghidra and Reko cannot discover them statically. Blocks in the runtime CFG were actually executed — use their start addresses (segment `017D`, `file_offset = offset + 0x200`) as the seed list for both decompilers. See `captures/README.md` for the schema, address mapping, and the relocation caveat (runtime bytes differ from file bytes wherever an MZ fixup applies).
