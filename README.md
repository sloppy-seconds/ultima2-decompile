# Ultima II — Byte-Exact Assembly Reconstruction

[![build-and-checksum](https://github.com/sloppy-seconds/ultima2-decompile/actions/workflows/build.yml/badge.svg)](https://github.com/sloppy-seconds/ultima2-decompile/actions/workflows/build.yml)

A research reverse-engineering of **Ultima II** (Richard Garriott / Origin
Systems, 1982/83): a readable, named, structured x86 real-mode assembly
reconstruction in which **every byte is proven**. The tree in `asm/`
re-assembles to a byte-for-byte identical copy of the target executable —
verified per function and for the whole binary, continuously, in CI.

This is a faithful *reconstruction*, not recovered source: the original 1983
assembly listing, its names and its comments are unrecoverable. What is
offered instead is stronger than trust: mechanical proof. Every one of the
1299 reconstructed functions must re-assemble to exactly its original byte
range (`tools/check_func.py`), and `tools/assemble_clean.sh` rebuilds the
complete 37,344-byte binary from the cleaned tree only and checks it against
the known checksum. The rebuild has been booted and played.

## Target & provenance — read this

* The analyzed binary is the **Ultima II distribution available on the
  Internet Archive** — the DOS software-library item is
  [archive.org/details/msdos_Ultima_II_-_Revenge_of_the_Enchantress_1983](https://archive.org/details/msdos_Ultima_II_-_Revenge_of_the_Enchantress_1983)
  — not a factory-shipped copy. The pack **appears to
  already include community patches**, so "byte-exact" here means byte-exact
  to *this* image:
  `ultimaii.exe`, 37,344 bytes, md5 `fe884d5117971073ac8097cc7a6aca25`.
* **This repository contains no game files.** The original executable, the
  game data, and raw runtime captures are copyrighted and are not
  distributed here (see `.gitignore` — it is enforced by policy, and the git
  history is clean of them). To reproduce or play, supply your own legally
  obtained copy as `original/ultimaii.exe`.
* The reconstructed assembly is a derivative work of the copyrighted binary
  in a symbolic form. It is published for **research, education and
  interoperability** purposes in the tradition of other classic-game
  decompilation projects. If you represent the rights holder and want
  something changed or removed, open an issue — it will be acted on promptly.

## Verify it yourself

Requirements: GNU `as`/`objcopy` (binutils) and `python3`. No other tools
needed; nothing to install.

```bash
# full rebuild from the cleaned tree + checksum verification (works without
# the original — CI mode compares against the known md5):
bash tools/assemble_clean.sh

# with your own original present, it additionally byte-diffs every function:
cp /path/to/your/ultimaii.exe original/ultimaii.exe
bash tools/assemble_clean.sh          # full-tree byte-diff mode
python3 tools/check_func.py 4FDF      # prove one function (str_out)
```

CI runs the rebuild on every push/PR and fails if any byte of the output
deviates from the known checksum. The built binary is deliberately never
uploaded as a CI artifact.

### No toolchain handy? Use the container

The build needs only `binutils` + `python3`. A `Containerfile` is included
(podman or docker — it verifies the checksum during the image build itself):

```bash
podman build -t u2-rebuild .
podman run --rm -v "$PWD/build:/out:Z,U" u2-rebuild   # writes build/u2-clean-rebuild.bin
```

## How to play

We publish source and proofs, never the game — you supply your own legally
obtained copy. The classic workflow: download the original pack, build our
reconstruction, and **copy our binary over the original executable** — they
are byte-identical, and that substitution is the point.

```bash
# 1. Get your own copy of Ultima II from the Internet Archive (see the item
#    linked under Target & provenance) and unzip it into a game folder:
mkdir -p ~/u2 && cd ~/u2
#    download + extract the IA pack here, so the folder holds the game's
#    original executable (ultimaii.exe / ULTIMA2.EXE)

# 2. Build the reconstruction from this repo (no original needed):
cd /path/to/this-repo
bash tools/assemble_clean.sh build/ULTIMA2.EXE
#    -> "CLEAN REBUILD CHECKSUM-MATCH ... md5 OK"

# 3. Copy our binary over the original in your game folder:
cp build/ULTIMA2.EXE ~/u2/

# 4. Run it in a DOS emulator. On Linux, DOSBox Staging is the modern pick:
#    Fedora:  sudo dnf install dosbox-staging
#    Debian/Ubuntu: sudo apt install dosbox-staging
#    Flatpak: flatpak install flathub com.dosbox.DOSBox
dosbox -c 'mount c ~/u2' -c 'c:' -c 'ULTIMA2.EXE'
```

Ultima II is **not** a single-file game. The 37 KB executable is the engine; the
content lives in sidecar files in the same folder — `mapxNN` sector maps,
`monxNN` monster data, `tlkxNN` NPC dialogue, the `pic*` picture files, and the
`player` save. The Internet Archive pack used here holds 94 files totalling about
2.2 MB, and the game reads and rewrites them in place. That is why step 1 extracts
the whole pack rather than fetching one binary, and why our rebuild is dropped
*into* that folder instead of run standalone.

If you run the reconstructed binary and it cannot find its data, it is not broken
— you are in a directory without the sidecar files.

### Optional: the portable C engine (no DOSBox)

`engine/` is a native Linux reimplementation in C11 that runs the same content
without DOS emulation. It is behavioural work in progress, **not** byte-proven —
the asm tree remains the only proven artefact.

```bash
cd engine
make                      # cc only, C11, no third-party dependencies
make test                 # CP0..CP4 acceptance checks
./u2                      # interactive terminal play
make sdl && ./u2-sdl      # SDL2 bitmap front end (needs sdl2-compat)
```

Point it at the extracted pack with `--data-dir ~/u2` so it can find `mapxNN`,
`monxNN`, `tlkxNN` and `player`. See `engine/README.md` for the full flag
contract, including the headless and scripted modes used by the tests.

## Repository layout

| Path | Contents |
| --- | --- |
| `asm/` | the reconstruction: one file per function (`<SEG>_<name>.asm`), data files, headers with evidence + confidence |
| `engine/` | portable C11 reimplementation (Phase 4, in progress) with its own `README.md`, tests and `make` targets |
| `tools/` | our Python/shell toolchain: `check_func.py` (per-function proof), `assemble_clean.sh` (full rebuild), `decode_str.py`, `preclean.py`, `clean_wave.py`, `dialect_masm.py` (MASM/jwasm dual-assembly) |
| `docs/` | phase plans, state files and implementation logs for Phases 1–3 |
| `disasm/` | curated analysis: function map, phase summaries, defect verdicts (no bulky dumps) |
| `AGENTS.md` | project rules: isolation, licensing and commit policy |

Known names so far: the 26 command handlers `cmd_A`..`cmd_Z`, `str_out`
(inline-string display), and OS seam labels (`video_int10`, `key_int16`,
`clock_int1a`, `dos_int21`, `speaker_tone`) marking every hardware/DOS call
site — the replacement surface for a future portable port (Phase 5).

## How this was made

This is an **AI-driven decompilation project**. All three phases — evidence
capture, function-boundary analysis, and the clean byte-exact assembly
reconstruction — were executed by AI coding agents under human direction:
the human set goals, made style and scope decisions at review gates (and
played the rebuilt game for final acceptance); the agents wrote the tooling,
the reconstruction and every verification log.

* **Agent harness:** [pi](https://pi.dev) (coding-agent CLI).
* **Model:** `qwen3.8-flash-next`, served **locally** — no cloud inference.
* **Hardware:** AMD “Strix Halo” (Ryzen AI Max+ 395) with 128 GB unified
  memory, Fedora Linux.
* **Verification principle:** the AI never asked to be trusted. Every claim
  reduces to an exit code: `check_func.py` per function, `assemble_clean.sh`
  for the whole binary, checksum in CI.

### Toolchain (used locally, not vendored)

| Tool | Role here | License |
| --- | --- | --- |
| GNU binutils 2.46 (`objdump`, `as`, `objcopy`) | ground-truth disassembly + the verifying assembler (`.code16`, `--32`) | GPL-3.0 (usage only; no code incorporated) |
| [Spice86](https://github.com/Spice86/spice86) | x86 emulator; dynamic traces (executed-block CFG, memory dumps) that made function boundaries execution-confirmed | GPL-3.0 |
| [Ghidra](https://ghidra-sre.org/) 12.1.4 | static-analysis reference (headless scripts in `tools/ghidra/`) | Apache-2.0 |
| [Reko](https://github.com/uxmal/reko) 0.12.5 | decompiler drafts used only as *naming hints*; the asm slices remained the sole authority for content | GPL-2.0 |
| [JWasm](https://jwasm.github.io) 2.21 | MASM-dialect target assembler for dual-assembly verification (`tools/dialect_masm.py`) | Open Watcom Public License |
| Python 3.14 | our analysis/build tooling in `tools/` | — |

Vendored tool builds (Spice86, Reko, JWasm) are gitignored and re-fetchable;
nothing GPL/OWPL is incorporated into committed source. The reconstruction,
tooling and documentation in this repo are our own authored work.

## Status

* **Phase 1–3: complete and signed off** — evidence capture; function
  boundaries + code/data separation; clean byte-exact ASM reconstruction
  (1283 clean + 3 data + 13 excluded self-modifying = 1299 functions).
  See `disasm/phase3-summary.md`.
* **Phase 4 (in progress): portable C engine** in `engine/` — CP0 through CP4
  green: title flow, character creation, status rendering, saves, and the
  overworld with tile passability, the sector wrap and the food/time model.
  Plan in `docs/phase4-plan.md`, running state in `docs/phase4-state.md`,
  evidence log in `docs/phase4-implementation.md`. Live-emulator findings that
  corrected static readings are in `docs/spice86-live-findings.md`.
* **Phase 5 (planned): portable build** behind the INT/port seams.

## License

The tooling, documentation and our authored reconstruction scaffolding are
**Apache-2.0** (see `LICENSE`). This license does not and cannot grant rights
over the underlying copyrighted game; game assets and the original binary are
not part of this repository.
