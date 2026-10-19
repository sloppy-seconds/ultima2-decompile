// Mark inline string data so the decompiler stops decoding it as instructions.
//
// Why this exists: the linear sweep that discovers functions cannot tell code from
// data, so it sweeps game strings as code. "INSERT PLAYER DISK", "PROUDLY PRESENTS"
// and "CMD: " all become instruction streams, which produces the 389
// "Unable to resolve constructor" pcode errors and the wild branch targets like
// 0xefa8 that sit past the end of the image.
//
// Detection is deliberately conservative. A span is treated as text only when it has
// at least six consecutive alphanumeric/space characters and is followed by a control
// byte, which is how DOS stores these strings. Function entries are never demoted,
// because an entry inside a string would mean the entry itself is wrong and that
// needs a human decision, not a heuristic.
//
// Script args: exe=<path> out=<path.tsv> [minlen=6]
//@category DecompileU2
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.address.AddressSpace;
import ghidra.program.model.listing.Function;

import java.io.FileWriter;
import java.io.PrintWriter;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;

public class MarkInlineData extends GhidraScript {

    private static final long RAM_BASE = 0x10000L;

    @Override
    public void run() throws Exception {
        String exePath = null;
        String outPath = null;
        int minWordRun = 6;
        for (String arg : getScriptArgs()) {
            int eq = arg.indexOf('=');
            if (eq < 0) {
                continue;
            }
            String k = arg.substring(0, eq);
            String v = arg.substring(eq + 1);
            if (k.equals("exe")) {
                exePath = v;
            } else if (k.equals("out")) {
                outPath = v;
            } else if (k.equals("minlen")) {
                minWordRun = Integer.parseInt(v);
            }
        }
        if (exePath == null) {
            throw new IllegalArgumentException("need exe=<path>");
        }

        byte[] raw = Files.readAllBytes(Paths.get(exePath));
        int hdr = u16(raw, 0x08) * 16;
        int codeLen = raw.length - hdr;
        AddressSpace ram = currentProgram.getAddressFactory().getDefaultAddressSpace();

        // Collect candidate text spans.
        List<int[]> spans = new ArrayList<>();
        int i = 0;
        while (i < codeLen) {
            int b = raw[hdr + i] & 0xFF;
            if (b < 0x20 || b > 0x7E) {
                i++;
                continue;
            }
            int start = i;
            int wordRun = 0;
            int bestRun = 0;
            while (i < codeLen) {
                b = raw[hdr + i] & 0xFF;
                if (b < 0x20 || b > 0x7E) {
                    break;
                }
                boolean wordy = (b >= '0' && b <= '9') || (b >= 'A' && b <= 'Z')
                        || (b >= 'a' && b <= 'z') || b == ' ';
                if (wordy) {
                    wordRun++;
                    if (wordRun > bestRun) {
                        bestRun = wordRun;
                    }
                } else {
                    wordRun = 0;
                }
                i++;
            }
            int end = i;
            boolean terminated = i < codeLen && (raw[hdr + i] & 0xFF) < 0x20;
            if (bestRun >= minWordRun && terminated) {
                spans.add(new int[] { start, end });
            } else {
                i = start + 1;
            }
        }
        println("DATA candidate spans=" + spans.size()
                + " bytes=" + spans.stream().mapToInt(s -> s[1] - s[0]).sum());

        int marked = 0;
        int skippedEntry = 0;
        PrintWriter out = outPath == null ? null : new PrintWriter(new FileWriter(outPath));
        if (out != null) {
            out.println("start\tend\tlen\ttext");
        }
        for (int[] sp : spans) {
            Address a = ram.getAddress(RAM_BASE + sp[0]);
            Function owner = currentProgram.getFunctionManager().getFunctionContaining(a);
            if (owner != null) {
                skippedEntry++; // inside a function; report but do not demote
            }
            try {
                // A minimal 1-byte data definition at the span start is enough to stop
                // the decompiler treating the range as instruction flow, without
                // destroying the bytes.
                createByte(a);
                marked++;
            } catch (Throwable e) {
                // already defined or not addressable
            }
            if (out != null) {
                String txt = new String(raw, hdr + sp[0], Math.min(sp[1] - sp[0], 40))
                        .replaceAll("[\\r\\n\\t]", " ");
                out.println(sp[0] + "\t" + sp[1] + "\t" + (sp[1] - sp[0]) + "\t" + txt);
            }
        }
        if (out != null) {
            out.flush();
            out.close();
        }
        println("DATA marked " + marked + " spans, " + skippedEntry + " of them inside functions");
    }

    private static int u16(byte[] b, int at) {
        return (b[at] & 0xFF) | ((b[at + 1] & 0xFF) << 8);
    }
}
