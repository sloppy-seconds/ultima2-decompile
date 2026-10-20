# sub_4be0 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4BE0..4C1D  len 003E B  evidence: call+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4be0:
L_004de0:
        push   %ax
L_004de1:
        push   %bx
L_004de2:
        push   %bp
L_004de3:
        push   %cx
L_004de4:
        push   %di
L_004de5:
        push   %es
L_004de6:
        add    0x4bf,%ax
L_004dea:
        shr    $1,%ax
L_004dec:
        shr    $1,%ax
L_004dee:
        .byte 0x8b,0xf8  # forced-kept: gas re-encodes 'mov    %ax,%di' differently
L_004df0:
        mov    %cs:0x48d4(%bp),%cl
L_004df5:
        add    0x4c1,%bx
L_004df9:
        shl    $1,%bx
L_004dfb:
        mov    %cs:0x48dc(%bx),%ax
L_004e00:
        mov    %ax,%es
L_004e02:
        mov    %cl,%es:(%di)
L_004e05:
        mov    %cl,%es:0x50(%di)
L_004e09:
        mov    %cs:0x48de(%bx),%ax
L_004e0e:
        mov    %ax,%es
L_004e10:
        mov    %cl,%es:(%di)
L_004e13:
        mov    %cl,%es:0x50(%di)
L_004e17:
        pop    %es
L_004e18:
        pop    %di
L_004e19:
        pop    %cx
L_004e1a:
        pop    %bp
L_004e1b:
        pop    %bx
L_004e1c:
        pop    %ax
L_004e1d:
        ret
