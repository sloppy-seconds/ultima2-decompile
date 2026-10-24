// Seed function entry points in a raw 6502 image from a list of addresses, then
// leave decompilation to DecompileAll.java run afterwards.
//
// A raw Apple II BIN has no symbol table and no discoverable entry point, so Ghidra's
// auto-analysis finds zero functions. The seeds come from scanning for JSR/JMP absolute
// targets (tools/apple2_image.py plus a short scan; see docs/apple2-reference.md). That
// scan is byte-granular, so a few seeds land inside an operand and become junk functions;
// they are cheap to prune later and are strictly better than analysing nothing.
//
// Script args: seeds=<path> [verbose]
//@category DecompileU2
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionManager;

import java.io.BufferedReader;
import java.io.FileReader;

public class Seed6502 extends GhidraScript {

    @Override
    public void run() throws Exception {
        String seedsPath = null;
        for (String arg : getScriptArgs()) {
            if (arg.startsWith("seeds=")) {
                seedsPath = arg.substring(6);
            }
        }
        if (seedsPath == null) {
            throw new IllegalArgumentException("missing seeds=<path>");
        }

        FunctionManager fm = currentProgram.getFunctionManager();
        int created = 0, skipped = 0, bad = 0;
        try (BufferedReader br = new BufferedReader(new FileReader(seedsPath))) {
            String line;
            while ((line = br.readLine()) != null) {
                line = line.trim();
                if (line.isEmpty()) {
                    continue;
                }
                long v = Long.parseLong(line.replace("$", ""), 16);
                Address addr = toAddr(v);
                if (currentProgram.getMemory().getBlock(addr) == null) {
                    bad++;
                    continue;
                }
                Function existing = fm.getFunctionAt(addr);
                if (existing != null) {
                    skipped++;
                    continue;
                }
                try {
                    createFunction(addr, null);
                    created++;
                } catch (Exception e) {
                    bad++;
                }
            }
        }
        println("SEEDED created=" + created + " existing=" + skipped + " bad=" + bad);
    }
}
