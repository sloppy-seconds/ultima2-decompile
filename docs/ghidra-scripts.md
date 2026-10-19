# Ghidra scripts

Four Ghidra `GhidraScript` classes that drive headless decompilation of a 16-bit real-mode
DOS MZ executable.

**These are tooling, not findings.** They contain no addresses, no entry points, and no symbol
names for any specific binary. Every address list is supplied as an external file argument, so
this project must generate its own. Do not import entry or naming lists from any other
project; build them from `captures/spice86/spice86-cfg.json` and from this binary's own
disassembly.

## Prerequisites

- A Ghidra installation. Set `GHIDRA_HOME` to its root, the directory containing
  `support/analyzeHeadless`.
- Java on `PATH`.
- No GUI needed; everything runs headless.

## Compiling them standalone

Ghidra runs these itself, but they can be type-checked outside Ghidra to confirm they match the
installed API. The classes live in the Feature jars, not the Framework jars, so the classpath
has to cover the whole tree:

```bash
GHIDRA=/path/to/ghidra-12.1.4
CP=$(find "$GHIDRA/Ghidra" -name '*.jar' | tr '\n' ':')
cd tools/ghidra
for f in *.java; do
  javac -nowarn -cp "$CP" -d /var/tmp/javac-out "$f" && echo "ok $f" || echo "FAIL $f"
done
```

A classpath built only from `Ghidra/Framework` fails with `package ghidra.app.decompiler does
not exist`, which looks like a broken script and is not. Verified against Ghidra 12.1.4 with
195 jars on the classpath; all four scripts compile.

## Running a script

```bash
WORK=$(mktemp -d /var/tmp/u2-ghidra.XXXXXX)
mkdir -p "$WORK/proj"

"$GHIDRA_HOME/support/analyzeHeadless" "$WORK/proj" u2 \
    -deleteProject \
    -import original/ultimaii.exe \
    -scriptPath tools/ghidra \
    -postScript DecompileMz.java \
    exe=original/ultimaii.exe out=/var/tmp/ghidra.c index=/var/tmp/ghidra.tsv
```

Notes on the invocation:

- `analyzeHeadless` will not create the project directory. `mkdir -p` it first.
- `-deleteProject` stops throwaway projects accumulating.
- Script arguments are positional, after the script name, in `key=value` form.
- Keep the working directory under `/var/tmp`, not `/tmp`. On this machine `/tmp` is a tmpfs,
  so Ghidra's temporary files would be taken from RAM.

## The scripts

### `DecompileMz.java`

The main driver. Decompiles a 16-bit real-mode MZ executable and writes one C-like file plus a
TSV index.

Arguments:

| Arg | Meaning |
| --- | --- |
| `exe=<path>` | the MZ file |
| `out=<path>` | output C file |
| `index=<path>` | TSV index of entry points and decompile status |
| `entries=<path>` | optional, one hex IP per line, see below |
| `only=<path>` | optional, restrict to listed addresses |
| `names=<path>` | optional, identifier substitutions applied to output |
| `timeout=<sec>` | optional per-function decompile timeout |
| `base=<hex>` | optional address base override |

**Why the script exists at all.** Ghidra's `MzLoader` splits the image into `CODE_0/1/2`
blocks and drops the DOS segment base into the low 16 bits, presenting addresses in the `ram`
space as real-mode linear offsets shifted by the load segment:

```
ram address = 0x10000 + SEG*16 + OFF
```

Auto-analysis finds almost nothing on this kind of file, so entry points have to be supplied.

**Offset semantics are the trap.** `getMinAddress()` returns into the `HEADER` space, not the
code space, so using it as the base of the code range silently shifts everything. The script
derives the real bounds by iterating `getMemoryBlocks()` and taking the min and max offsets of
initialised blocks in the `ram` space. Block boundaries are computed at runtime, not hardcoded.

### `DecompileAll.java`

Exports every decompiled function of the currently loaded program to one C file plus an index,
so the whole binary can be read and grepped offline.

Arguments: `out=<path.c>`, `index=<path.tsv>`, optional `timeout=<seconds>`, `base=<hex>`.

Use this when the project is already imported and you just want the dump. Use `DecompileMz.java`
for a one-shot import-and-decompile.

### `MarkInlineData.java`

Marks inline string data so the decompiler stops decoding it as instructions.

This game's display routine takes its argument as the bytes immediately following the `call`,
so code and data interleave. A linear sweep turns game strings into instruction streams, which
produces large numbers of `Unable to resolve constructor` pcode errors and branch targets past
the end of the image.

Arguments: `exe=<path>`, `out=<path.tsv>`, optional `minlen=6`.

The detection is deliberately conservative and generic: a span is treated as text only when it
has at least six consecutive alphanumeric or space characters and is followed by a control
byte, which is how DOS stores these strings. **Function entries are never demoted.** An entry
inside a string means the entry itself is wrong, and that needs a human decision rather than a
heuristic.

### `RetryDecompile.java`

Retries decompilation of specific functions under alternative decompiler settings, to see
whether a failure under the default configuration is recoverable. The default path uses
simplification style `decompile`; this tries every style plus a few option changes and reports
which combination completes.

Arguments: `addrs=<file with one hex ram address per line>`, optional `out=<path.c>`.

Use it on the functions the index marks as failed. A failure under defaults is not necessarily
a permanent failure.

## What this project must supply

The scripts are inert without address lists, and those lists are findings. Generate them from
inside this project:

**Entry points.** The runtime capture is the best source. `captures/spice86/spice86-cfg.json`
contains 796 code-segment blocks whose start addresses were actually executed. Filter to the
game's code segment, convert to the offset form the script expects, and write one address per
line. Static reachability cannot produce these: the command handlers are entered by
`jmp *%bx` through a jump table and return with `jmp` to a shared exit, never by `call`/`ret`.

**The jump table.** A 26-entry word table indexed by `(key - 'A') * 2` gives the exact start of
every command handler. Locate it in `original/ultimaii.exe` and emit the entries yourself.

**Names and globals.** Only after the semantics are established from this binary. Naming is the
most contaminated artefact type, because a name is a claim.

## Address spaces

The scripts report `1000:XXXX`. The conversion to a file offset is `XXXX + 0x200`, which is the
MZ header's own relocation base (`0x20` paragraphs). Reko's `0800:XXXX` uses the same number
for the same byte. See `decompiling.md`.

## Reading the index

Tab-separated:

```
entry           dos_seg_off  name             body_bytes  decompile_status
1000:5eac       05ea:000c    FUN_1000_5eac    27          ok
```

Filter on `decompile_status` to separate failures from successes rather than guessing from the
C. A function can appear in the output with a body that dropped its register assignments, so
`ok` does not mean complete.

## Known Ghidra failure modes

Recorded so they are not mistaken for correct output.

- **A large fraction of functions fail to decompile**, typically with
  `Low-level Error: Cannot properly adjust input varnodes`. `RetryDecompile.java` recovers some.
- **Register assignments can be dropped.** A routine whose bytes are four pushes followed by
  five `mov reg,imm` can decompile to a body containing only the call and a return, with all
  five immediates gone. Verify constants against the disassembly.
- **Function boundaries do not match the real entry points** unless you supply them.
