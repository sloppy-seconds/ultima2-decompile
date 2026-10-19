# sub_2708 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2708..2730  len 0029 B  evidence: seed+reko
# calls: L_0052b3
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2708:
L_002908:
        clc
L_002909:
        mov    0x49,%al
L_00290c:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_00290e:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_002910:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_002912:
        mov    %al,0x1f
L_002915:
        adc    0x6e,%al
L_002919:
        mov    $0x0,%ah
L_00291b:
        .byte 0x8b,0xf8  # forced-kept: gas re-encodes 'mov    %ax,%di' differently
L_00291d:
        mov    %cs:0x2798(%di),%al
L_002922:
        mov    %al,0x23
L_002925:
        inc    %di
L_002926:
        mov    %cs:0x2798(%di),%al
L_00292b:
        mov    %al,0x24
L_00292e:
        call L_0052b3
