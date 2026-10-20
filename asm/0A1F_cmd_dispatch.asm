# cmd_dispatch — command-letter jump-table dispatcher (A-Z -> handler)
# name-evidence: Phase 2 jump-table.md: sbb al,'A'; add al,al; mov bx,cs:[si+0x730]; jmp bx
# confidence: low (bytes proven by check_func.py)
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
