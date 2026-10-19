# sub_5b98 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5B98..5BC1  len 002A B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5b98:
L_005d98:
        stc
L_005d99:
        mov    0x1,%al
L_005d9c:
        cmc
L_005d9d:
        sbb    $0x5,%al
L_005d9f:
        cmc
L_005da0:
        and    $0x3f,%al
L_005da2:
        mov    %al,0x3
L_005da5:
        stc
L_005da6:
        mov    0x0,%al
L_005da9:
        cmc
L_005daa:
        sbb    $0x9,%al
L_005dac:
        cmc
L_005dad:
        and    $0x3f,%al
L_005daf:
        mov    %al,0x2
L_005db2:
        mov    $0x0,%al
L_005db4:
        mov    %al,0x5
L_005db7:
        mov    %al,0x4
L_005dba:
        mov    $0x0,%ah
L_005dbc:
        .byte 0x8b,0xf0  # forced-kept: gas re-encodes 'mov    %ax,%si' differently
L_005dbe:
        mov    $0x0,%ah
L_005dc0:
        .byte 0x8b,0xf8  # forced-kept: gas re-encodes 'mov    %ax,%di' differently
