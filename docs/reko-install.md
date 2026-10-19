# Installing and using Reko

Reko is the second decompiler. It is used alongside Ghidra because it models x86 segments as
first-class IR, which makes data-segment accesses readable, and because it decompiled
functions Ghidra failed on.

Reko's output is not ground truth. See `decompiling.md` for the failure modes and the byte
check that must be applied to anything taken from it.

## Install

Prebuilt binaries need no build toolchain. Reko is **vendored into this project** at
`tools/reko/` (gitignored and re-fetchable — same standalone rationale as `tools/spice86/`).
From the project root:

```bash
mkdir -p tools/reko
curl -sL -o /var/tmp/reko.zip \
  'https://github.com/uxmal/reko/releases/download/version-0.12.5/CmdLine-0.12.5-x64-418d3538ee.zip'
python3 -c "import zipfile; zipfile.ZipFile('/var/tmp/reko.zip').extractall('tools/reko')"
export DOTNET_ROLL_FORWARD=Major
dotnet tools/reko/reko.dll --version
```

Expected output:

```
Reko decompiler version 0.12.5.0 (git:418d3538ee)
```

Note the `-L` on `curl`: the GitHub download URL redirects to a CDN, and without it the file
comes down as 0 bytes. Reko's decompiler output goes under `decompiled/`; the vendored tool
itself stays out of version control.

### Prerequisites

- `dotnet` on `PATH`. The release targets .NET 8 or 9. On a .NET 10 runtime,
  `DOTNET_ROLL_FORWARD=Major` is required or the tool refuses to start.
- `curl` and Python 3 for the download and extract step.

### Two traps in the install

**`file` reports the zip as `data`, not as a zip archive.** The archive contains PE/.NET
content and the magic sniff misclassifies it. The bytes do start `PK\x03\x04`, so both
`unzip` and Python's `zipfile` handle it fine. Do not conclude the download is corrupt
because `file` is confused.

**Do not invoke `reko.exe`.** It is a Windows apphost and fails on Linux with
`System.BadImageFormatException: Bad IL format`. Always run `dotnet tools/reko/reko.dll`.

### Pinning the version

The asset filename embeds a commit hash (`418d3538ee`), so it changes with every release.
Check the current asset list rather than trusting this document's URL indefinitely:

```bash
curl -s https://api.github.com/repos/uxmal/reko/releases/latest | \
  python3 -c "import json,sys; d=json.load(sys.stdin); print(d['tag_name']); \
[print(' ', a['name']) for a in d['assets'] if 'CmdLine' in a['name']]"
```

## The project file

Reko is driven by a `.dcproject` XML file. This is the part most likely to waste time, because
a malformed project loads and then silently decompiles nothing.

```xml
<?xml version="1.0" encoding="utf-8"?>
<project xmlns="http://schemata.jklnet.org/Reko/v5">
  <arch>x86-real-16</arch>
  <platform>ms-dos</platform>
  <input>
    <location>/abs/path/to/ultimaii.exe</location>
    <srcDir>/abs/path/to/decompiled/reko</srcDir>
    <asmDir>/abs/path/to/decompiled/reko</asmDir>
    <user>
      <procedure><address>0800:0C9C</address><decompile>true</decompile></procedure>
      <procedure><address>0800:4FDF</address><decompile>true</decompile></procedure>
    </user>
  </input>
</project>
```

Requirements that are not obvious from the error messages:

- **`arch` and `platform` are elements, not attributes.** Writing `<input arch="...">` produces
  a project that loads and decompiles nothing.
- **Paths must be absolute.** `srcDir` and `asmDir` are resolved relative to the working
  directory, not the project file.
- **`x86-real-16` and `ms-dos` are the correct values for this binary.** It is a 16-bit real
  mode DOS MZ executable.
- **Addresses are `0800:XXXX`.** The conversion to a file offset is `XXXX + 0x200`.

### Seeding procedures

The `<procedure>` list is the reliable way to tell Reko where code starts.

**The `--entry` command-line option does not work on this binary.** It is accepted and the run
completes, but it emits only Reko's own entry point and ignores the address given. See
"Running" below for the test that shows this.

Use the runtime-captured block addresses from `captures/spice86/spice86-cfg.json` as the seed
list. Those are execution-confirmed entry points, which is stronger evidence than either
decompiler's automatic discovery. Filter to blocks whose segment label is `017D`, convert the
offset to the `0800:` form, and emit one `<procedure>` element per block.

Static reachability cannot find these. The command handlers are entered by `jmp *%bx` through
a jump table and return with `jmp` to a shared exit, never by `call`/`ret`, so call-edge
analysis is blind to them.

## Running

```bash
export DOTNET_ROLL_FORWARD=Major
cd decompiled/reko          # output lands next to the input file, see below
dotnet "$PWD/../../tools/reko/reko.dll" decompile /abs/path/to/ultimaii.exe \
    --time-limit 1800
```

`--time-limit` is in seconds. Without it a large binary can run for a very long time, and a
run that appears hung is often just unbounded.

### Where the output goes

**There is no output-directory option.** `decompile --help` has no `-o`, no `--output-dir`,
and passing `-o` fails with `unrecognized option -o`. Reko creates a directory named
`<inputbasename>.reko/` **next to the input file** and writes everything there:

```
ultimaii.reko/
  ultimaii_10AC.c        one .c per procedure
  ultimaii_0800.asm
  ultimaii_PSP.asm
  ultimaii.h
  ultimaii_10AC.dis
```

This is why a run can print every phase completing, `Rewriting procedures to high-level
language. [Done]`, and appear to produce nothing. The run succeeded. Look for the `.reko`
directory beside the binary, not in the working directory.

The `references/ultima2/ultimaii.reko/` directory in this project is output in exactly that
shape, from an earlier run. It is not a Reko configuration directory.

### The `--entry` option does not work on this binary

`--entry <address>` is listed in `decompile --help`, so it exists. **On this MZ file it does
not do what it appears to.** Verified by running it:

```bash
dotnet tools/reko/reko.dll decompile ultimaii.exe --entry 0800:0C9C --time-limit 90
```

The run completes all phases and emits exactly one procedure, `// 10AC:0000`. The requested
entry is not among the output. Reko loaded the image at segment `10AC` and ignored the
supplied address, falling back to its own notion of the entry point. Trying `10AC:0C9C` gives
the same single `10AC:0000` procedure.

Do not rely on `--entry`. **Seed procedures through the `.dcproject` `<procedure>` list**, as
described above. Treat any claim that `--entry` is silently ignored as confirmed for this
binary, and re-test it if the Reko version changes.

### Do not use the shingle heuristic

**`--heuristic shingle` triggers a defect in the static-single-assignment pass and crashes.**
Do not pass it when seeding procedures.

The other available heuristic is `calls-respect-abi`, which assumes calls follow the platform
ABI. On this binary that assumption is wrong in an interesting way: the command handlers are
not called at all, they are reached by `jmp *%bx`, so an ABI-respecting call analysis will not
see them regardless of the flag.

## Measuring the result

**Count statements, not `define` occurrences.** A procedure can appear in the output with a
`define` line and still have an empty or trivial body. The meaningful measure is how many
procedures have real bodies and how many statements they contain.

Before trusting any derived coverage number, print the parse count. A parser that silently
matches a fraction of the input and exits 0 is the standard failure mode for this step.

Two things that look like coverage and are not:

- **Entry-to-next-entry spans tile the whole range by construction** and therefore always
  report 100 percent. That is not a measurement.
- **Reachability from call edges cannot see indirect entry.** Any coverage claim must account
  for `jmp *%bx`.

## Known Reko failure modes on this binary

Recorded so they are not mistaken for correct output.

**It lifts whatever it is pointed at, including non-code.**

- Pointed at 256 bytes of zero padding, it produced a 265-line procedure of
  `bx[si] = bx[si] + al`, which is what `00 00` decodes to.
- Pointed at a word table with the repeating pattern `1e ba 23 b8 23 ba 28 b8 ...`, it
  produced five procedures. Any byte pair decodes as *some* 8086 instruction, so a table
  becomes code with no diagnostic.

**Procedure boundaries drift.** Reko can start on a routine tail and run through padding into
the next routine. One documented case claims `bx = 0x0800` and `dx = 0x0100` for a span whose
bytes contain neither value.

**It never expresses uncertainty.** Nothing in the output distinguishes a confident lift from a
lift over data. Every procedure looks equally authoritative.

## Checking Reko output against the bytes

For any claim taken from Reko, disassemble the range it claims to cover:

```bash
objdump -D -b binary -m i8086 \
    --start-address=0x<file_offset> --stop-address=0x<end> \
    original/ultimaii.exe
```

Confirm every constant and memory operand Reko asserted actually appears there. Both
decompilers have been caught asserting constants that are not in their claimed range.

Two cautions:

- **Linear disassembly is alignment-dependent.** Disassembling from the wrong byte walks
  through inline string data and decodes text as instructions. Start from a known entry.
- **Strings are inline.** The display routine takes its argument as the bytes immediately
  following the `call`, so code and data interleave.

A large `DS` displacement in Reko output is a hint to look, not a verdict. Base-plus-index
expressions are truncated to 16 bits and can legitimately print large values.

## Where Reko is better than Ghidra

- Segments are first-class in the IR, so `DS`-relative accesses appear as `ds->*[offset]`
  rather than being folded into a flat address.
- It decompiled functions Ghidra failed on.
- Higher procedure count on this binary.

Neither tool finds the real entry points. Supply them.
