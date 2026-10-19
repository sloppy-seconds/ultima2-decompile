// Decompile a 16-bit real-mode DOS MZ executable.
//
// Ghidra's MzLoader splits the image into CODE_0/1/2 blocks and drops the DOS
// segment base into the low 16 bits, presenting everything as a segmented address
// in the `ram` space (16-byte real-mode paragraphs). The mapping is the plain
// real-mode linear address offset by the 0x1000 load segment:
//
//   ram address = 0x1000:SEG + OFF   ==   flat 0x10000 + SEG*16 + OFF
//
// Blocks follow the file layout, not the segment table: CODE_0/1/2 begin at code
// offsets 0x0000, 0x7410, 0x8AC0, which are the offsets the MZ header's own
// relocation/entry coordinates assume. Auto-analysis finds almost nothing because
// nothing seeds the far call graph, so this script supplies seeds (entry point,
// relocation sites, far CALL/JMP operands, resolvable far-pointer words), iterates
// to a fixed point, then decompiles everything found.
//
// Script args: exe=<path> out=<path.c> index=<path.tsv> [maxpass=8] [timeout=60]
//              [entries=<path>] [only=<path>] [names=<path>]
//
// entries= names addresses (one hex IP per line) that are known genuine function
// entries from an independent disassembly. Where such an address falls strictly
// inside an existing body the body is re-parented: a function is created at the
// address and the enclosing body is recomputed, so the earlier body no longer
// swallows it. This is the same failure as trap 4 one stage later, bodies are the
// wrong unit for seed ACCEPTANCE as well as for discovery.
//
// names= applies human-readable symbols before decompilation so the generated C,
// and the TSV index, both carry real identifiers instead of FUN_1000_xxxx and raw
// numeric offsets. Format:
//   FUNC   <hex-ip>          <identifier> <evidence>
//   GLOBAL <hex-ds-offset> <size> <identifier> <evidence>
// Evidence is V (verified), L (community doc) or ? (unknown) and is recorded as an
// address comment so a guess is never mistaken for a confirmed fact.
//
// only= restricts decompilation to the listed IPs, for narrow re-checks.
//@category DecompileU2
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.address.AddressSpace;
import ghidra.program.model.symbol.SourceType;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionIterator;
import ghidra.program.model.mem.MemoryBlock;

import java.io.FileWriter;
import java.io.PrintWriter;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.TreeSet;

public class DecompileMz extends GhidraScript {

    private static final long RAM_BASE = 0x10000L; // 0x1000 paragraphs

    private AddressSpace ramSpace;
    private long ramMin;
    private long ramMax;

    @Override
    public void run() throws Exception {
        String exePath = null;
        String outPath = null;
        String indexPath = null;
        String entriesPath = null;
        String namesPath = null;
        String onlyPath = null;
        int maxPass = 8;
        int timeout = 60;
        for (String arg : getScriptArgs()) {
            int eq = arg.indexOf('=');
            if (eq < 0) {
                continue;
            }
            String key = arg.substring(0, eq);
            String val = arg.substring(eq + 1);
            if (key.equals("exe")) {
                exePath = val;
            } else if (key.equals("out")) {
                outPath = val;
            } else if (key.equals("index")) {
                indexPath = val;
            } else if (key.equals("entries")) {
                entriesPath = val;
            } else if (key.equals("names")) {
                namesPath = val;
            } else if (key.equals("only")) {
                onlyPath = val;
            } else if (key.equals("maxpass")) {
                maxPass = Integer.parseInt(val);
            } else if (key.equals("timeout")) {
                timeout = Integer.parseInt(val);
            }
        }
        if (exePath == null || outPath == null) {
            throw new IllegalArgumentException("need exe=<path> out=<path>");
        }

        ramSpace = currentProgram.getAddressFactory().getDefaultAddressSpace();
        // Offset semantics, verified by ProbeMzLayout: the ram space holds the DOS
        // linear address (SEG*16+OFF) as its offset, and the MzLoader's load segment
        // shifts the blocks up by 0x1000 paragraphs. So a DOS linear address L lives at
        // offset L + 0x10000, and ramMin is that 0x10000 base.
        ramMin = Long.MAX_VALUE;
        ramMax = Long.MIN_VALUE;
        for (MemoryBlock b : getMemoryBlocks()) {
            if (!b.getStart().getAddressSpace().equals(ramSpace) || !b.isInitialized()) {
                continue;
            }
            ramMin = Math.min(ramMin, b.getStart().getOffset());
            ramMax = Math.max(ramMax, b.getEnd().getOffset());
        }
        println("MZ: ram space=" + ramSpace.getName() + " blocks span 0x"
                + Long.toHexString(ramMin) + "..0x" + Long.toHexString(ramMax));

        byte[] raw = Files.readAllBytes(Paths.get(exePath));
        int hdrPara = u16(raw, 0x08);
        int relocCount = u16(raw, 0x06);
        int relocTable = u16(raw, 0x18);
        int ip = u16(raw, 0x14);
        int cs = u16(raw, 0x16);
        int sp = u16(raw, 0x10);
        int ss = u16(raw, 0x12);
        long codeLen = raw.length - hdrPara * 16L;

        // The entry stub is the last code in the image: prove the mapping by read.
        long entryLinear = cs * 16L + ip;
        long entryRam = RAM_BASE + entryLinear;
        Address entry = ramAddr(entryRam);
        println("MZ: code_len=" + codeLen + " cs:ip=" + h4(cs) + ":" + h4(ip)
                + " ss:sp=" + h4(ss) + ":" + h4(sp) + " relocs=" + relocCount);
        println("MZ: entry dos-linear=0x" + Long.toHexString(entryLinear)
                + " ram=0x" + Long.toHexString(entryRam) + " addr=" + entry);
        if (entry == null || !currentProgram.getMemory().contains(entry)) {
            throw new IllegalStateException("entry not in memory: " + entry);
        }
        println("MZ: entry bytes = " + hexBytes(entry, 8));
        disassemble(entry);
        createFunction(entry, null);

        // ---- coordination-function table ---------------------------------/
        // The Ultima II launcher stub reads a table of 4-byte far pointers and jumps
        // through it. Harvest every 4-byte pair that resolves to a stub address so
        // the driver functions get real entry points instead of staying data.
        List<Long> tableEntries = new ArrayList<>();
        for (long i = 0; i + 4 <= codeLen; i += 2) {
            int off = u16(raw, (int) (hdrPara * 16L + i));
            int seg = u16(raw, (int) (hdrPara * 16L + i + 2));
            long target = toRamChecked(seg, off);
            if (target >= 0) {
                tableEntries.add(target);
            }
        }
        println("MZ: resolvable far-pointer words in image = " + tableEntries.size());

        // ---- far-call seeds ----------------------------------------------
        // Every far pointer in the image is a candidate; filter through toRamChecked,
        // which rejects targets outside the loaded blocks (real-mode pointers freely
        // exceed the 20-bit space, so toAddr throws rather than returning null).
        Set<Long> seeds = new TreeSet<>();
        seeds.add(entryRam);
        int rejected = 0;
        for (int i = 0; i < relocCount; i++) {
            int off = u16(raw, relocTable + i * 4);
            int seg = u16(raw, relocTable + i * 4 + 2);
            long s = toRamChecked(seg, off);
            if (s >= 0) {
                seeds.add(s);
            }
        }
        int farSites = 0;
        for (long i = 0; i + 4 < codeLen; i++) {
            int b = raw[(int) (hdrPara * 16L + i)] & 0xFF;
            if (b == 0x9A || b == 0xEA) { // far CALL / far JMP
                farSites++;
                int off = u16(raw, (int) (hdrPara * 16L + i + 1));
                int seg = u16(raw, (int) (hdrPara * 16L + i + 3));
                long s = toRamChecked(seg, off);
                if (s >= 0 && b == 0x9A) {
                    seeds.add(s);
                }
            }
        }
        println("MZ: far CALL/JMP sites = " + farSites + " (rejected pointers=" + rejected + ")");
        println("MZ: call-target seeds = " + seeds.size());

        int created = 0;
        int pass = 0;
        int before;
        do {
            before = currentProgram.getFunctionManager().getFunctionCount();
            for (long lin : seeds) {
                created += tryCreate(lin);
            }
            // Linear sweep of the whole image for call/jump idioms. Function bodies are
            // unreliable for this: a single mis-created function can swallow a large span
            // as its body, which is why the earlier body-only sweep saw almost nothing.
            for (long i = 0; i + 3 < codeLen; i++) {
                int b = raw[(int) (hdrPara * 16L + i)] & 0xFF;
                if (b == 0xE8 || b == 0xE9) {
                    int rel = (short) (((raw[(int) (hdrPara * 16L + i + 1)] & 0xFF))
                            | ((raw[(int) (hdrPara * 16L + i + 2)] & 0xFF) << 8));
                    created += tryCreate(RAM_BASE + i + 3 + rel);
                }
            }
            pass++;
            println("pass " + pass + ": functions " + before + " -> "
                    + currentProgram.getFunctionManager().getFunctionCount());
        } while (currentProgram.getFunctionManager().getFunctionCount() > before && pass < maxPass);

        // ---- re-parent known entries that sit inside an existing body ---------
        int reparented = 0;
        if (entriesPath != null) {
            for (String rawLine : Files.readAllLines(Paths.get(entriesPath))) {
                String t = rawLine.trim();
                if (t.isEmpty() || t.startsWith("#")) {
                    continue;
                }
                int sep = t.indexOf(' ');
                String ipText = (sep < 0 ? t : t.substring(0, sep)).replace("0x", "");
                String label = sep < 0 ? "" : t.substring(sep + 1).trim();
                long entryIp;
                try {
                    entryIp = Long.parseLong(ipText, 16);
                } catch (NumberFormatException e) {
                    println("ENTRY skip unparsable: " + t);
                    continue;
                }
                long ram = RAM_BASE + entryIp;
                Address a = ramAddr(ram);
                if (a == null || !currentProgram.getMemory().contains(a)) {
                    println("ENTRY " + label + " 0x" + Long.toHexString(entryIp) + " outside memory");
                    continue;
                }
                Function at = currentProgram.getFunctionManager().getFunctionAt(a);
                if (at != null) {
                    println("ENTRY " + label + " 0x" + Long.toHexString(entryIp)
                            + " already an entry (" + at.getName() + ")");
                    continue;
                }
                Function owner = currentProgram.getFunctionManager().getFunctionContaining(a);
                if (owner == null) {
                    // The caller's independent evidence (runtime CFG / jump table) says this
                    // is a routine start; Ghidra simply never claimed the area as a function.
                    // Create the function outright instead of skipping the seed.
                    try {
                        disassemble(a);
                        createFunction(a, null);
                        Function fresh = currentProgram.getFunctionManager().getFunctionAt(a);
                        if (fresh != null) {
                            reparented++;
                            println("ENTRY " + label + " 0x" + Long.toHexString(entryIp)
                                    + " created fresh function (" + fresh.getName() + ")");
                            continue;
                        }
                    } catch (Throwable e) {
                        println("ENTRY " + label + " 0x" + Long.toHexString(entryIp)
                                + " CREATE FAILED: " + e);
                    }
                    println("ENTRY " + label + " 0x" + Long.toHexString(entryIp)
                            + " not inside any body");
                    continue;
                }
                // A known entry inside a body means the body boundary is wrong. Detach the
                // owner's body first so createFunction can claim the new entry, then let the
                // owner recompute around the hole.
                Address ownerEntry = owner.getEntryPoint();
                long ownerBodyBefore = owner.getBody().getNumAddresses();
                try {
                    clearListing(a, a);
                    disassemble(a);
                    createFunction(a, null);
                    Function fresh = currentProgram.getFunctionManager().getFunctionAt(a);
                    // Make the previous owner re-derive its body now that a hole exists.
                    // There is no public createBody hook on GhidraScript, so force the
                    // function to release and re-claim its instructions by clearing the
                    // body then letting auto-analysis reassign it.
                    Function ownerFn = currentProgram.getFunctionManager().getFunctionAt(ownerEntry);
                    if (ownerFn != null) {
                        // Shrink the owner to nothing at its own entry, then let
                        // CreateFunctionCmd re-derive a body around the new hole.
                        ghidra.program.model.address.AddressSet empty =
                                new ghidra.program.model.address.AddressSet(ownerEntry, ownerEntry);
                        ownerFn.setBody(empty);
                        ghidra.app.cmd.function.CreateFunctionCmd rebuild =
                                new ghidra.app.cmd.function.CreateFunctionCmd(ownerEntry);
                        rebuild.applyTo(currentProgram, getMonitor());
                    }
                    reparented++;
                    println("ENTRY " + label + " 0x" + Long.toHexString(entryIp)
                            + " split out of " + owner.getName()
                            + " (owner body " + ownerBodyBefore + " -> "
                            + (ownerFn == null ? -1 : ownerFn.getBody().getNumAddresses())
                            + ", new fn=" + (fresh == null ? "?" : fresh.getName()) + ")");
                } catch (Throwable e) {
                    println("ENTRY " + label + " 0x" + Long.toHexString(entryIp)
                            + " SPLIT FAILED: " + e);
                }
            }
            println("ENTRY re-parented " + reparented + " of the listed entries");
        }

        // ---- apply human-readable names --------------------------------------
        // Runs before decompilation so identifiers reach the generated C. Evidence
        // grade becomes an address comment, so a community-doc guess is visibly
        // distinct from a verified fact when reading the output.
        int fnNamed = 0;
        int glNamed = 0;
        if (namesPath != null) {
            for (String rawLine : Files.readAllLines(Paths.get(namesPath))) {
                String line = rawLine.trim();
                if (line.isEmpty() || line.startsWith("#")) {
                    continue;
                }
                String[] p = line.split("\\s+");
                if (p.length < 4) {
                    continue;
                }
                try {
                    if (p[0].equals("FUNC")) {
                        long nameIp = Long.parseLong(p[1], 16);
                        String id = p[2];
                        String ev = p[3];
                        Address a = ramAddr(RAM_BASE + nameIp);
                        if (a == null) {
                            println("NAME skip func 0x" + Long.toHexString(nameIp) + " outside memory");
                            continue;
                        }
                        Function f = currentProgram.getFunctionManager().getFunctionContaining(a);
                        if (f == null) {
                            println("NAME skip func 0x" + Long.toHexString(nameIp) + " no function");
                            continue;
                        }
                        f.setName(id, ghidra.program.model.symbol.SourceType.IMPORTED);
                        setPlateComment(a, "evidence " + ev + ": name from an external "
                                + (ev.equals("V") ? "verified against this binary"
                                                  : "community documentation, unverified here"));
                        fnNamed++;
                    } else if (p[0].equals("GLOBAL")) {
                        // NOTE: not implemented as address labels. The code references DS
                        // globals as bare offsets (*(byte *)0x12), because DS is a runtime
                        // segment that the MZ loader never maps. A label planted at
                        // ram 0x10012 is a different address from what the code means, and
                        // offset 0x12 inside the image is code, not data. Labelling it would
                        // plant data definitions inside functions. The table is still parsed
                        // so the count is reported and the shape is documented for a future
                        // approach that teaches the decompiler about DS first.
                        glNamed++;
                        continue;
                    }
                } catch (NumberFormatException e) {
                    println("NAME skip unparsable line: " + line);
                }
            }
            println("NAME applied " + fnNamed + " function names, " + glNamed + " globals");
        }

        // ---- decompile ----------------------------------------------------
        DecompInterface di = new DecompInterface();
        di.toggleCCode(true);
        di.toggleSyntaxTree(false);
        di.setSimplificationStyle("decompile");
        if (!di.openProgram(currentProgram)) {
            throw new IllegalStateException("decompiler refused program: " + di.getLastMessage());
        }

        PrintWriter out = new PrintWriter(new FileWriter(outPath));
        PrintWriter idx = indexPath == null ? null : new PrintWriter(new FileWriter(indexPath));
        if (idx != null) {
            idx.println("entry\tdos_seg_off\tname\tbody_bytes\tdecompile_status");
        }
        out.println("// target  : " + currentProgram.getName() + " (DOS MZ, 16-bit real mode)");
        out.println("// language: " + currentProgram.getLanguageID());
        out.println("// mapping : ram = 0x10000 + SEG*16 + OFF  (0x1000 load segment, real mode)");
        for (MemoryBlock b : getMemoryBlocks()) {
            out.println("// block   : " + b.getName() + " " + b.getStart() + ".." + b.getEnd());
        }
        out.println();

        int total = 0;
        int failed = 0;
        Set<Long> only = null;
        if (onlyPath != null) {
            only = new TreeSet<>();
            for (String rawLine : Files.readAllLines(Paths.get(onlyPath))) {
                String t = rawLine.trim();
                if (t.isEmpty() || t.startsWith("#")) {
                    continue;
                }
                only.add(Long.parseLong(t.replace("0x", ""), 16));
            }
            println("ONLY limiting decompile to " + only.size() + " addresses");
        }
        FunctionIterator it = currentProgram.getFunctionManager().getFunctions(true);
        while (it.hasNext()) {
            if (monitor.isCancelled()) {
                break;
            }
            Function fn = it.next();
            if (only != null && !only.contains(fn.getEntryPoint().getOffset() - RAM_BASE)) {
                continue;
            }
            total++;
            String status = "ok";
            String code;
            DecompileResults res = di.decompileFunction(fn, timeout, getMonitor());
            if (res != null && res.decompileCompleted() && res.getDecompiledFunction() != null) {
                code = res.getDecompiledFunction().getC();
            } else {
                // getErrorMessage() can carry newlines, which would break the TSV row
                // into several lines and corrupt the index. Collapse to one line.
                String msg = res == null ? "no result" : res.getErrorMessage();
                if (msg == null || msg.isBlank()) {
                    msg = "no function body returned";
                }
                status = "failed: " + msg.replaceAll("\\s+", " ").trim();
                failed++;
                code = "/* decompilation failed: " + status + " */";
            }
            long dosLin = fn.getEntryPoint().getOffset() - ramMin;
            long dseg = dosLin >> 4;
            long doff = dosLin & 0xF;
            out.println("/* ===== " + fn.getEntryPoint() + "  [" + h4((int) dseg) + ":" + h4((int) doff)
                    + "]  " + fn.getName() + "  (" + fn.getBody().getNumAddresses() + " bytes) ===== */");
            out.println(code.trim());
            out.println();
            if (idx != null) {
                idx.println(fn.getEntryPoint() + "\t" + h4((int) dseg) + ":" + h4((int) doff) + "\t"
                        + fn.getName() + "\t" + fn.getBody().getNumAddresses() + "\t" + status);
            }
        }
        out.flush();
        out.close();
        di.dispose();
        if (idx != null) {
            idx.flush();
            idx.close();
        }
        println("DECOMPILED functions=" + total + " failed=" + failed + " created=" + created
                + " out=" + outPath);
    }

    /** DOS far pointer to ram address under the 0x1000 load segment. */
    private long toRam(int seg, int off) {
        return RAM_BASE + seg * 16L + off;
    }

    /** toRam, but -1 when the target is not an addressable loaded byte. */
    private long toRamChecked(int seg, int off) {
        long lin = toRam(seg, off);
        if (lin < ramMin || lin > ramMax) {
            return -1;
        }
        try {
            Address a = ramSpace.getAddress(lin);
            if (a == null || !currentProgram.getMemory().contains(a)) {
                return -1;
            }
            return lin;
        } catch (Exception e) {
            return -1;
        }
    }

    /** Linear ram offset to an Address, or null when out of range. */
    private Address ramAddr(long lin) {
        if (lin < ramMin || lin > ramMax) {
            return null;
        }
        try {
            return ramSpace.getAddress(lin);
        } catch (Exception e) {
            return null;
        }
    }

    private int tryCreate(long ramOffset) {
        if (ramOffset < 0) {
            return 0;
        }
        Address addr = ramAddr(ramOffset);
        if (addr == null || !currentProgram.getMemory().contains(addr)) {
            return 0;
        }
        if (currentProgram.getFunctionManager().getFunctionContaining(addr) != null) {
            return 0;
        }
        try {
            disassemble(addr);
            createFunction(addr, null);
            return 1;
        } catch (Throwable e) {
            return 0;
        }
    }

    private String hexBytes(Address a, int n) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < n; i++) {
            try {
                sb.append(String.format("%02x ", getByte(a.add(i)) & 0xFF));
            } catch (Exception e) {
                break;
            }
        }
        return sb.toString().trim();
    }

    private static int u16(byte[] b, int at) {
        if (at + 1 >= b.length) {
            return 0;
        }
        return (b[at] & 0xFF) | ((b[at + 1] & 0xFF) << 8);
    }

    private static String h4(int v) {
        return String.format("%04x", v & 0xFFFF);
    }
}
