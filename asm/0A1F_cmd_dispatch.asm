# cmd_dispatch — command-letter jump-table dispatcher (A-Z -> handler)
# name-evidence: Phase 2 jump-table.md: sbb al,'A'; add al,al; mov bx,cs:[si+0x730]; jmp bx
#           The body is exactly that sequence, and it is the ONLY route to the 26
#           command handlers, so every cmd_* function below is reached through this
#           six-instruction stub by `jmp *%bx` rather than by call/ret.
# func 0A1F..0A2F  len 0011 B  evidence: seed+reko
# provenance: live:airport (+26 other harvests), static
#           entry executed in 27 of 60 harvests; derived by
#           tools/provenance_from_traces.py
# confidence: high (whole 17-byte body read; range matches disasm/function-map.tsv
#           exactly and is byte-proven by tools/check_func.py 0A1F)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0a1f:
L_000c1f:
        stc
L_000c20:
        cmc
L_000c21:
        sbb    $0x41,%al
L_000c23:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_000c25:
        mov    $0x0,%ah
L_000c27:
        .byte 0x8b,0xf0  # forced-kept: gas re-encodes 'mov    %ax,%si' differently
L_000c29:
        mov    %cs:0x730(%si),%bx
L_000c2e:
        jmp    *%bx
