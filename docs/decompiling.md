# Decompiling with Ghidra and Reko

How to get pseudo-C out of `original/ultimaii.exe` with both decompilers, and what
each one gets wrong. Neither is sufficient alone, and neither one's output should be trusted
without the byte check described at the end.

## The address spaces, before anything else

This is the single largest source of wrong results. There are three numbering schemes in play
and they differ by constant offsets.

| Source | Notation | To file offset |
| --- | --- | --- |
| The executable itself | file offset | as-is |
| Ghidra | `1000:XXXX` | `XXXX + 0x200` |
| Reko | `0800:XXXX` | `XXXX + 0x200` |
| `objdump -D -b binary` | prints file offsets | add nothing |
| **`asm/` filename prefix** | **runtime offset** | **`XXXX + 0x200`** |
| **`L_XXXX` label inside `asm/`** | **file offset** | **add nothing** |

**Read that last pair again, because it is a trap.** A single `asm/` file mixes two bases:
the **filename is a runtime offset** and the **`L_xxxx` labels in its body are file
offsets**, exactly `0x200` apart. `asm/1799_tavern_food_price.asm` declares runtime
`0x1799`, and its first label is `L_001999`. Proven 2026-10-22 against the bytes: the
string `THE FOOD HERE COSTS` sits at exe file offset `0x199D`, which is `L_00199a` (the
3-byte `call`) plus 3 — inside that file, as expected.

The practical failure, which happened the day this was written: mapping a runtime string
address to its owning function by nearest-preceding **filename** is correct, but comparing
it against **labels**, or comparing a file offset against a filename, silently shifts every
result by `0x200` and attributes strings to the wrong routine. When in doubt, convert to
file offsets and stay there.

**Ghidra's `1000:5eac` and Reko's `0800:5eac` name the same byte.** Both convert to file
`0x60ac`. Verified on the bytes: file `0x60ac` is `50 53 51 52`, which is `push ax` /
`push bx` / `push cx` / `push dx`, and Reko's body for that address begins with four
`sp -= 2` operations.

Checked on a second address so this is not a one-off coincidence. Ghidra `FUN_1000_0100`
maps to file `0x300`, which is `b8 41 07 8e d8 05`, i.e. `mov ax,0x0741` / `mov ax,ds` /
`add ax,0x...`, a plausible program start. Reading `0x5eac` with no bias at all gives
`36 00 59 5b 58 c3`, which is not a valid instruction sequence, so the `+0x200` bias is
required rather than optional.

Do not apply a further `-0x600` or `+0x800` when comparing the two tools' output. A
comparison that comes out suspiciously clean, like zero matches out of forty-six, is almost
always an offset bug rather than a real finding.

`objdump` reports file offsets already. Adding the bias to something `objdump` printed is a
double-count and lands 512 bytes away from the intended instruction.

## Ghidra

### Requirements

- A Ghidra installation. `source tools/env.sh` sets `GHIDRA_HOME` (default
  `/var/home/paul/Projects/ghidra-12.1.4`). Ghidra is Apache-2.0 and too large to vendor, so it
  is referenced by path — the one external-tool exception to the isolation rule.
- Java on `PATH`. Ghidra 12.1.4 needs JDK 21+ with no upper bound; the system JDK 25 works.
- The analysis is headless, so no GUI is needed.
- The headless scripts live in `tools/ghidra/` (generic, binary-agnostic tooling). See
  `ghidra-scripts.md` for the full guide to `DecompileMz.java`, `DecompileAll.java`,
  `MarkInlineData.java` and `RetryDecompile.java`.

### Running it

```bash
source tools/env.sh
WORK=$(mktemp -d /var/tmp/u2-ghidra.XXXXXX)
mkdir -p "$WORK/proj"

"$GHIDRA_HOME/support/analyzeHeadless" "$WORK/proj" u2 \
    -deleteProject \
    -import original/ultimaii.exe \
    -scriptPath tools/ghidra \
    -postScript DecompileMz.java \
    exe=original/ultimaii.exe out=/var/tmp/ghidra.c index=/var/tmp/ghidra.tsv
```

`DecompileMz.java` self-seeds the launcher jump-table stub, so it finds far more than plain
auto-analysis (which sees only the entry point). For the complete, correct function set, seed
the runtime-captured entry points from `captures/spice86/spice86-cfg.json` and mark inline data
first — see `ghidra-scripts.md` and "Supplying entry points" below.

Notes on the invocation:

- `analyzeHeadless` will not create the project directory. `mkdir -p` it first.
- `-deleteProject` keeps the throwaway project from accumulating.
- Keep the working directory under `/var/tmp`, not `/tmp`. On this machine `/tmp` is a tmpfs,
  so Ghidra's temporary files would be taken from RAM.
- The script arguments (`out=`, `index=`) are passed positionally after the script name.

### Importing as MZ

Ghidra imports the DOS MZ file and lays it out in real mode. The resulting blocks, as reported
in the output header:

```
CODE_0   1000:0000..1000:740f
CODE_1   1741:0000..1741:16af
CODE_2   18ac:0000..18ac:051f
HEADER   HEADER::00000000..HEADER::000001ff
```

The `HEADER` block is the 512-byte MZ header. **`getMinAddress()` returns into HEADER space**,
so using it as the base of the code range silently shifts everything. This is a trap that
produces plausible-looking output at the wrong addresses.

### What Ghidra gets wrong

Three failure modes, all confirmed against the bytes:

**1. A large fraction of functions fail to decompile.** The characteristic error is
`Low-level Error: Cannot properly adjust input varnodes`. On this binary, 53 of 210 functions
failed that way.

**2. It drops register assignments.** A routine whose bytes are

```
50 53 51 52          push ax / push bx / push cx / push dx
b8 00 03             mov ax,0x300
bb 00 10             mov bx,0x1000
b9 02 00             mov cx,0x0002
ba 00 02             mov dx,0x0200
bd 08 00             mov bp,0x0008
e8 e7 fe             call ...
```

decompiles to a body containing only the call and a return. All five immediate constants are
gone. 23 of 116 parseable functions on this binary have no hex constants at all in their
bodies. That is information loss, not a formatting difference.

**3. Function boundaries do not match the real entry points.** Of 46 addresses known to be
routine starts, only 7 were Ghidra function starts.

### Function index

The index file is tab-separated:

```
entry           dos_seg_off  name             body_bytes  decompile_status
1000:5eac       05ea:000c    FUN_1000_5eac    27          ok
```

Filter on `decompile_status` to separate the failures from the successes rather than
guessing from the C.

## Reko

### Requirements

- A Reko build. **Vendored in this project** at `tools/reko/reko.dll` (see `reko-install.md`
  for install/provenance).
- `dotnet` on `PATH`, with `DOTNET_ROLL_FORWARD=Major` if running a .NET 8 or 9 build on a
  newer runtime.

### The project file

Reko is driven by a `.dcproject` XML file. The minimum working shape for this binary:

```xml
<?xml version="1.0" encoding="utf-8"?>
<project xmlns="http://schemata.jklnet.org/Reko/v5">
  <arch>x86-real-16</arch>
  <platform>ms-dos</platform>
  <input>
    <location>/abs/path/to/ultimaii.exe</location>
    <srcDir>/abs/path/to/output</srcDir>
    <asmDir>/abs/path/to/output</asmDir>
    <user>
      <procedure><address>0800:0C9C</address><decompile>true</decompile></procedure>
      <procedure><address>0800:4FDF</address><decompile>true</decompile></procedure>
    </procedure>
    </user>
  </input>
</project>
```

`arch` and `platform` are **elements, not attributes**. Getting this wrong produces a project
that loads and then decompiles nothing.

### Running it

```bash
export DOTNET_ROLL_FORWARD=Major
dotnet tools/reko/reko.dll decompile myproject.dcproject --time-limit 1800
```

### Two things that do not work the way you would expect

**The `--entry` command-line option is inert.** In Reko 0.12.5 it does not seed procedures.
Seeding must be done through the `<procedure>` elements in the project file. A run that
"uses --entry" and produces nothing is not a bug in your invocation.

**The `shingle` heuristic triggers an SSA defect.** Do not pass `--heuristic shingle` when
seeding procedures. It crashes in the static-single-assignment pass.

### What Reko gets wrong

**1. It lifts whatever it is pointed at, including non-code.** Two confirmed cases:

- Pointed at 256 bytes of zero padding, it produced a 265-line procedure of
  `bx[si] = bx[si] + al`, which is what `00 00` decodes to.
- Pointed at a word table with the repeating pattern `1e ba 23 b8 23 ba 28 b8 ...`, it
  produced five procedures. Any byte pair decodes as *some* 8086 instruction, so a table
  becomes code with no diagnostic.

**2. Procedure boundaries drift.** Reko starts a procedure on a routine *tail* and runs
through padding into the next routine. Example: `fn0800_5E83` covers

```
5E83: 80 fb f0     cmp bl,0xf0
5E86: 75 ee        jne ...
5E88: c3           ret
5E89: 00 * 12      padding
5E95: 80 3e ...    <- a different routine begins here
```

Reko's body for that span claims `bx = 0x0800` and `dx = 0x0100`. **Neither value appears
anywhere in those bytes.** Of 46 known routine starts, 11 were Reko procedure starts.

**3. It never expresses uncertainty.** There is no marker in the output distinguishing a
confident lift from a lift over data. Every procedure looks equally authoritative.

### Where Reko is better than Ghidra

Reko models x86 segments as first-class IR, so `DS`-relative accesses appear as
`ds->*[offset]` rather than being folded into a flat address. That is what makes the data
segment readable at all. It also decompiled all 53 functions Ghidra failed on, and its
procedure count on this binary was 370 against Ghidra's 199.

## Which tool for what

| Need | Use |
| --- | --- |
| Coverage of functions Ghidra fails on | Reko |
| Readable `DS`-relative memory operands | Reko |
| A second opinion on a Reko body | Ghidra, if it decompiled |
| Function boundaries | **neither**, see below |
| Constants and operands | verify against `objdump`, always |

**Neither decompiler finds the real entry points on this binary.** The command handlers are
reached by `jmp *%bx` through a jump table and return with `jmp` to a shared exit, never by
`call`/`ret`. Reachability analysis that follows call edges cannot see them at all. Entry
points have to be supplied from outside, and the jump table is the reliable source.

## Supplying entry points

The command dispatch is a 26-entry word table indexed by `(key - 'A') * 2`, giving the exact
start of every command handler. Those addresses are the best available seeds for both tools,
and both tools should be re-run with them rather than with whatever their automatic discovery
produced.

When seeding, note that the table holds `cs:` offsets. Convert to file offsets by adding
`0x200` before cross-checking with `objdump`.

## The byte check, which is the part that matters

Neither tool's output is evidence. The bytes are. For any claim taken from a decompiler:

```bash
objdump -D -b binary -m i8086 \
    --start-address=0x<file_offset> --stop-address=0x<end> \
    original/ultimaii.exe
```

Then confirm that every constant and memory operand the decompiler asserted actually appears
in that disassembly. Both tools have been caught asserting constants that are not in the
range they claim to cover.

Two cautions when doing this:

- **Linear disassembly is alignment-dependent.** Disassembly from the wrong byte walks through
  inline string data and decodes text as instructions. Disassemble from a known entry point.
- **Strings are inline.** This game's display routine takes its argument as the bytes
  immediately following the `call`, so code and data interleave. A routine's real extent ends
  after the last inline string, and disassembly that crosses a string boundary is out of step.

## Output layout

Keep the two tools' output separate, since their addresses use different segment labels for
the same bytes:

```
decompiled/
  ghidra/
    ultimaii.c              raw decompiler output
    ultimaii-functions.tsv  index with decompile_status
  reko/
    ultimaii.c
    ultimaii.dcproject      the project that produced it
```

Do not merge them into one file. Cross-referencing between tools is a comparison task, and it
needs both originals intact.

## Known-bad results, so they are not rediscovered

- A comparison reporting **zero matches** between two address sets is usually an offset bug.
  Print one known element from each set and confirm they name the same byte before trusting
  any derived number.
- A decompiler body that is one repeated instruction is padding or a table.
- A procedure whose body contains a `DS` displacement above roughly `0x2000` deserves a look,
  but a large displacement alone is not proof of an error: base-plus-index expressions are
  truncated to 16 bits and can legitimately print large.
- Entry-to-next-entry spans tile the whole range by construction and therefore always report
  100 percent coverage. That is not a coverage measurement.
