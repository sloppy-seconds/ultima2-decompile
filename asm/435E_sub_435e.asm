# sub_435e — mechanical clean (bulk wave); behavior not yet reviewed
# func 435E..437D  len 0020 B  evidence: seed+reko
# calls: L_000c33
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_435e:
L_00455e:
        stc
L_00455f:
        mov    0x65,%al
L_004562:
        cmc
L_004563:
        sbb    $0x1,%al
L_004565:
        das
L_004566:
        cmc
L_004567:
        mov    %al,0x65
L_00456a:
        mov    0x14,%al
L_00456d:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_00456f:
        mov    $0x0,%bh
L_004571:
        mov    $0x0,%bl
L_004573:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_004575:
        .byte 0x8b,0x9d,0x06,0x00  # forced-kept: gas re-encodes 'mov    0x6(%di),%bx' differently
L_004579:
        mov    %al,(%bx)
L_00457b:
        jmp L_000c33
