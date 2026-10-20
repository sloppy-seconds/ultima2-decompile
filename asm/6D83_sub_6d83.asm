# sub_6d83 — mechanical clean (bulk wave); behavior not yet reviewed
# func 6D83..6DFC  len 007A B  evidence: call+reko
# calls: L_004d76
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_6d83:
L_006f83:
        mov    0x47b,%al
L_006f86:
        mov    %al,0x479
L_006f89:
        mov    0x47c,%al
L_006f8c:
        stc
L_006f8d:
        cmc
L_006f8e:
        sbb    $0x3,%al
L_006f90:
        cmc
L_006f91:
        mov    %al,0x47a
L_006f94:
        call L_004d76
L_006f97:
        incb   0x47a
L_006f9b:
        call L_004d76
L_006f9e:
        incb   0x47a
L_006fa2:
        call L_004d76
L_006fa5:
        incb   0x47a
L_006fa9:
        call L_004d76
L_006fac:
        incb   0x47a
L_006fb0:
        call L_004d76
L_006fb3:
        incb   0x47a
L_006fb7:
        call L_004d76
L_006fba:
        incb   0x47a
L_006fbe:
        call L_004d76
L_006fc1:
        mov    0x47b,%al
L_006fc4:
        stc
L_006fc5:
        cmc
L_006fc6:
        sbb    $0x3,%al
L_006fc8:
        cmc
L_006fc9:
        mov    %al,0x479
L_006fcc:
        mov    0x47c,%al
L_006fcf:
        mov    %al,0x47a
L_006fd2:
        call L_004d76
L_006fd5:
        incb   0x479
L_006fd9:
        call L_004d76
L_006fdc:
        incb   0x479
L_006fe0:
        call L_004d76
L_006fe3:
        incb   0x479
L_006fe7:
        incb   0x479
L_006feb:
        call L_004d76
L_006fee:
        incb   0x479
L_006ff2:
        call L_004d76
L_006ff5:
        incb   0x479
L_006ff9:
        call L_004d76
L_006ffc:
        ret
