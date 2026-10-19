# sub_53b5 — mechanical clean (bulk wave); behavior not yet reviewed
# func 53B5..53C4  len 0010 B  evidence: seed+call+reko
# calls: L_005203
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_53b5:
L_0055b5:
        push   %ax
L_0055b6:
        .byte 0x8a,0xe0  # forced-kept: gas re-encodes 'mov    %al,%ah' differently
L_0055b8:
        shr    $1,%al
L_0055ba:
        shr    $1,%al
L_0055bc:
        shr    $1,%al
L_0055be:
        shr    $1,%al
L_0055c0:
        or     $0x30,%al
L_0055c2:
        call L_005203
