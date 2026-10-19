# sub_5e0f — mechanical clean (bulk wave); behavior not yet reviewed
# func 5E0F..5E18  len 000A B  evidence: seed+reko
# calls: L_005ed2
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5e0f:
L_00600f:
        mov    %cs:0x5da7,%bx
L_006014:
        .byte 0x8b,0xcd  # forced-kept: gas re-encodes 'mov    %bp,%cx' differently
L_006016:
        call L_005ed2
