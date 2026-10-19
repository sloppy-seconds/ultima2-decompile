// Retry decompilation of specific functions under alternative decompiler settings,
// to see whether a failure under the default configuration is recoverable.
//
// The default path uses simplification style "decompile". This probe retries the
// same address under every style and a few option changes, and reports which
// combination produces a completed result.
//
// Script args: addrs=<file with one hex ram address per line> [out=<path.c>]
//@category DecompileU2
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileOptions;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.address.AddressSpace;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionManager;

import java.io.PrintWriter;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;

public class RetryDecompile extends GhidraScript {

    private static final String[] STYLES = { "decompile", "normalize", "firstpass", "register" };

    @Override
    public void run() throws Exception {
        String addrPath = null;
        String outPath = null;
        int timeoutSec = 90;
        for (String arg : getScriptArgs()) {
            int eq = arg.indexOf('=');
            if (eq < 0) {
                continue;
            }
            String key = arg.substring(0, eq);
            String val = arg.substring(eq + 1);
            if (key.equals("addrs")) {
                addrPath = val;
            } else if (key.equals("out")) {
                outPath = val;
            } else if (key.equals("timeout")) {
                timeoutSec = Integer.parseInt(val);
            }
        }
        if (addrPath == null) {
            throw new IllegalArgumentException("need addrs=<path>");
        }

        AddressSpace ram = currentProgram.getAddressFactory().getDefaultAddressSpace();
        FunctionManager fm = currentProgram.getFunctionManager();
        PrintWriter out = outPath == null ? null : new PrintWriter(new java.io.FileWriter(outPath));

        List<Long> targets = new ArrayList<>();
        for (String raw : Files.readAllLines(Paths.get(addrPath))) {
            String t = raw.trim();
            if (t.isEmpty() || t.startsWith("#")) {
                continue;
            }
            targets.add(Long.decode(t));
        }

        for (long lin : targets) {
            Address a;
            try {
                a = ram.getAddress(lin);
            } catch (Exception e) {
                println("==== ram 0x" + Long.toHexString(lin) + " BAD ADDRESS: " + e);
                continue;
            }
            Function fn = fm.getFunctionAt(a);
            if (fn == null) {
                Function outer = fm.getFunctionContaining(a);
                println("==== ram 0x" + Long.toHexString(lin) + " addr " + a
                        + " (no entry here, containing="
                        + (outer == null ? "none" : outer.getEntryPoint().toString()) + ")");
                continue;
            }
            println("==== ram 0x" + Long.toHexString(lin) + " addr " + a
                    + " fn=" + fn.getName() + " body=" + fn.getBody().getNumAddresses());

            for (String style : STYLES) {
                for (boolean simplify : new boolean[] { true, false }) {
                    DecompInterface di = new DecompInterface();
                    DecompileOptions opts = new DecompileOptions();
                    di.setOptions(opts);
                    di.toggleCCode(true);
                    di.toggleSyntaxTree(false);
                    di.setSimplificationStyle(style);
                    if (!di.openProgram(currentProgram)) {
                        println("  open failed for style=" + style);
                        di.dispose();
                        continue;
                    }
                    try {
                        DecompileResults res = di.decompileFunction(fn, timeoutSec, getMonitor());
                        boolean ok = res != null && res.decompileCompleted()
                                && res.getDecompiledFunction() != null;
                        String label = style + "/" + (simplify ? "simp" : "raw");
                        if (ok) {
                            String c = res.getDecompiledFunction().getC();
                            println("  OK   " + label + "  (" + c.split("\n").length + " lines)");
                            if (out != null) {
                                out.println("/* ==== ram 0x" + Long.toHexString(lin)
                                        + " style=" + label + " ==== */");
                                out.println(c.trim());
                                out.println();
                            }
                        } else {
                            String msg = res == null ? "null" : res.getErrorMessage();
                            if (msg != null && msg.length() > 90) {
                                msg = msg.substring(0, 90);
                            }
                            println("  FAIL " + label + "  " + msg);
                        }
                    } catch (Throwable e) {
                        println("  THROW " + style + "  " + e);
                    } finally {
                        di.dispose();
                    }
                }
            }
        }
        if (out != null) {
            out.flush();
            out.close();
        }
    }
}
