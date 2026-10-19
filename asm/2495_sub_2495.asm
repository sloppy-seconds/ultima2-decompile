# sub_2495 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2495..24B0  len 001C B  evidence: seed+reko
# calls: L_000e62
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2495:
L_002695:
        stc
L_002696:
        mov    0x52,%al
L_002699:
        cmc
L_00269a:
        sbb    $0x5,%al
L_00269c:
        das
L_00269d:
        cmc
L_00269e:
        mov    %al,0x52
L_0026a1:
        mov    0x51,%al
L_0026a4:
        cmc
L_0026a5:
        sbb    $0x0,%al
L_0026a7:
        das
L_0026a8:
        cmc
L_0026a9:
        mov    %al,0x51
L_0026ac:
        jb L_0026b1
L_0026ae:
        jmp L_000e62
