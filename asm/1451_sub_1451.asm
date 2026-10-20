# sub_1451 — mechanical clean (bulk wave); behavior not yet reviewed
# func 1451..147E  len 002E B  evidence: call+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_1451:
L_001651:
        nop
L_001652:
        .byte 0x8a,0xe0  # forced-kept: gas re-encodes 'mov    %al,%ah' differently
L_001654:
        mov    $0x0,%al
L_001656:
        add    0x472,%ax
L_00165a:
        mov    %ah,0x9
L_00165e:
        mov    0x24,%al
L_001661:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_001663:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_001665:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_001667:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_001669:
        adc    0x23,%al
L_00166d:
        mov    %al,0x8
L_001670:
        mov    $0x0,%bh
L_001672:
        mov    $0x0,%bl
L_001674:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_001676:
        mov    0x8,%bx
L_00167a:
        mov    (%bx,%si),%al
L_00167c:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_00167e:
        ret
