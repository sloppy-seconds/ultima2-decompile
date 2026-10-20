# sub_5ced — mechanical clean (bulk wave); behavior not yet reviewed
# func 5CED..5D08  len 001C B  evidence: call
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5ced:
L_005eed:
        mov    $0xb6,%al
L_005eef:
        out    %al,$0x43
L_005ef1:
        .byte 0x8b,0xc3  # forced-kept: gas re-encodes 'mov    %bx,%ax' differently
L_005ef3:
        out    %al,$0x42
L_005ef5:
        .byte 0x8a,0xc4  # forced-kept: gas re-encodes 'mov    %ah,%al' differently
L_005ef7:
        out    %al,$0x42
L_005ef9:
        in     $0x61,%al
L_005efb:
        .byte 0x8a,0xe0  # forced-kept: gas re-encodes 'mov    %al,%ah' differently
L_005efd:
        or     $0x3,%al
L_005eff:
        out    %al,$0x61
L_005f01:
        dec    %cx
L_005f02:
        jne L_005f01
L_005f04:
        .byte 0x8a,0xc4  # forced-kept: gas re-encodes 'mov    %ah,%al' differently
L_005f06:
        out    %al,$0x61
L_005f08:
        ret
