# sub_5112 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5112..511F  len 000E B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5112:
L_005312:
        add    %cl,0x521e(%bp,%si)
L_005316:
        add    %cl,-0x5f05(%bp,%di)
L_00531a:
        push   %cx
L_00531b:
        add    %cl,(%bp,%si)
L_00531d:
        .byte 0xc0,0x75,0x03  # forced-kept: gas re-encodes 'shlb   $0xe8,0x3(%di)' differently
