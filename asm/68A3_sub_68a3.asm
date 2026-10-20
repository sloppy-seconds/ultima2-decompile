# sub_68a3 — mechanical clean (bulk wave); behavior not yet reviewed
# func 68A3..68BF  len 001D B  evidence: call+reko
# calls: L_004de0
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_68a3:
L_006aa3:
        nop
L_006aa4:
        mov    $0x0,%ah
L_006aa6:
        mov    0x47f,%al
L_006aa9:
        .byte 0x8b,0xe8  # forced-kept: gas re-encodes 'mov    %ax,%bp' differently
L_006aab:
        mov    0x4,%al
L_006aae:
        shl    $1,%ax
L_006ab0:
        shl    $1,%ax
L_006ab2:
        mov    $0x0,%bh
L_006ab4:
        mov    0x5,%bl
L_006ab8:
        shl    $1,%bx
L_006aba:
        shl    $1,%bx
L_006abc:
        call L_004de0
L_006abf:
        ret
