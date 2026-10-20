# sub_152e — mechanical clean (bulk wave); behavior not yet reviewed
# func 152E..154D  len 0020 B  evidence: call+reko
# calls: L_0052d8
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_152e:
L_00172e:
        nop
L_00172f:
        mov    0x0,%al
L_001732:
        stc
L_001733:
        cmc
L_001734:
        sbb    0x137(%di),%al
L_001738:
        call L_0052d8
L_00173b:
        mov    %al,0x19
L_00173e:
        mov    0x1,%al
L_001741:
        stc
L_001742:
        cmc
L_001743:
        sbb    0x157(%di),%al
L_001747:
        call L_0052d8
L_00174a:
        mov    %al,0x1a
L_00174d:
        ret
