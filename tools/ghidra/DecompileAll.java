// Export every decompiled function of the current program to one C-like file plus
// an index of entry points, so the whole binary can be read and grepped offline.
//
// Script args: out=<path.c> index=<path.tsv> [timeout=<seconds>] [base=<hex>]
//@category DecompileU2
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionIterator;

import java.io.FileWriter;
import java.io.PrintWriter;

public class DecompileAll extends GhidraScript {

    @Override
    public void run() throws Exception {
        String outPath = null;
        String indexPath = null;
        int timeout = 60;
        for (String arg : getScriptArgs()) {
            int eq = arg.indexOf('=');
            if (eq < 0) {
                continue;
            }
            String key = arg.substring(0, eq);
            String val = arg.substring(eq + 1);
            if (key.equals("out")) {
                outPath = val;
            } else if (key.equals("index")) {
                indexPath = val;
            } else if (key.equals("timeout")) {
                timeout = Integer.parseInt(val);
            }
        }
        if (outPath == null) {
            throw new IllegalArgumentException("missing out=<path>");
        }

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
            idx.println("entry\tname\tsignature\tbody_bytes\tdecompile_status");
        }

        out.println("// target  : " + currentProgram.getName());
        out.println("// language: " + currentProgram.getLanguageID());
        out.println("// compiler: " + currentProgram.getCompilerSpec().getCompilerSpecID());
        out.println("// symbols : " + (currentProgram.getSymbolTable().getNumSymbols()));
        out.println();

        int total = 0;
        int failed = 0;
        FunctionIterator it = currentProgram.getFunctionManager().getFunctions(true);
        while (it.hasNext()) {
            if (monitor.isCancelled()) {
                break;
            }
            Function fn = it.next();
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

            String entry = fn.getEntryPoint().toString();
            String name = fn.getName();
            long bodyBytes = fn.getBody().getNumAddresses();

            out.println("/* ===== " + entry + "  " + name + "  (" + bodyBytes + " bytes) ===== */");
            out.println(code.trim());
            out.println();

            if (idx != null) {
                idx.println(entry + "\t" + name + "\t"
                        + fn.getPrototypeString(false, false).replaceAll("\\s+", " ") + "\t"
                        + bodyBytes + "\t" + status);
            }
        }

        out.flush();
        out.close();
        di.dispose();
        if (idx != null) {
            idx.flush();
            idx.close();
        }
        println("DECOMPILED functions=" + total + " failed=" + failed + " out=" + outPath);
    }
}
