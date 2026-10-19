# sub_154e — mechanical clean (bulk wave); behavior not yet reviewed
# func 154E..155C  len 000F B  evidence: seed+call+reko
# calls: L_001764
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_154e:
L_00174e:
        nop
L_00174f:
        push   %es
L_001750:
        mov    $0x0,%ah
L_001752:
        .byte 0x8b,0xf0  # forced-kept: gas re-encodes 'mov    %ax,%si' differently
L_001754:
        mov    0x476,%di
L_001758:
        push   %ds
L_001759:
        pop    %es
L_00175a:
        jmp L_001764
L_00175c:
        nop
