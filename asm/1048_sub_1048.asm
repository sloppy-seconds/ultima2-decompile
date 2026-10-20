# sub_1048 — mechanical clean (bulk wave); behavior not yet reviewed
# func 1048..106C  len 0025 B  evidence: seed+reko
# calls: L_00118e, L_0052ef
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_1048:
L_001248:
        mov    0x137(%di),%al
L_00124c:
        stc
L_00124d:
        cmc
L_00124e:
        sbb    0x0,%al
L_001252:
        call L_0052ef
L_001255:
        cmp    $0x4,%al
L_001257:
        jae L_00126d
L_001259:
        mov    0x157(%di),%al
L_00125d:
        stc
L_00125e:
        cmc
L_00125f:
        sbb    0x1,%al
L_001263:
        call L_0052ef
L_001266:
        cmp    $0x4,%al
L_001268:
        jae L_00126d
L_00126a:
        call L_00118e
