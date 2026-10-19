# sub_2744 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2744..2775  len 0032 B  evidence: seed+reko
# calls: L_0052b3
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2744:
L_002944:
        mov    $0x8,%al
L_002946:
        mov    %al,0x6f
L_002949:
        incb   0x6e
L_00294d:
        incb   0x6e
L_002951:
        mov    0x6e,%al
L_002954:
        and    $0x7,%al
L_002956:
        mov    %al,0x6e
L_002959:
        clc
L_00295a:
        adc    0x1f,%al
L_00295e:
        mov    $0x0,%ah
L_002960:
        .byte 0x8b,0xf8  # forced-kept: gas re-encodes 'mov    %ax,%di' differently
L_002962:
        mov    %cs:0x2798(%di),%al
L_002967:
        mov    %al,0x23
L_00296a:
        inc    %di
L_00296b:
        mov    %cs:0x2798(%di),%al
L_002970:
        mov    %al,0x24
L_002973:
        call L_0052b3
