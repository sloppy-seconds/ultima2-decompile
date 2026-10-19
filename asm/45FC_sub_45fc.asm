# sub_45fc — mechanical clean (bulk wave); behavior not yet reviewed
# func 45FC..4609  len 000E B  evidence: reko
# calls: L_0053eb
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_45fc:
L_0047fc:
        add    %dh,-0x74ff(%bp,%di)
L_004800:
        sti
L_004801:
        mov    $0x0,%bh
L_004803:
        mov    $0x4,%bl
L_004805:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_004807:
        call L_0053eb
