# sub_5de6 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5DE6..5DEF  len 000A B  evidence: seed+reko
# calls: L_005ed2
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5de6:
L_005fe6:
        mov    %cs:0x5da7,%bx
L_005feb:
        .byte 0x8b,0xcd  # forced-kept: gas re-encodes 'mov    %bp,%cx' differently
L_005fed:
        call L_005ed2
