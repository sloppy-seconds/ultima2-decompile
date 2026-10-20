# combat_exp_gain — monster killed: experience gain
# name-evidence: string '--EXP.+'
# func 2DC1..2DE0  len 0020 B  evidence: seed+reko
# strings: "--EXP.+"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
combat_exp_gain:
L_002fc1:
        clc
L_002fc2:
        mov    0x59,%al
L_002fc5:
        adc    0x1f,%al
L_002fc9:
        daa
L_002fca:
        mov    %al,0x59
L_002fcd:
        mov    0x58,%al
L_002fd0:
        adc    $0x0,%al
L_002fd2:
        daa
L_002fd3:
        mov    %al,0x58
L_002fd6:
        call L_0051df
        db "--EXP.+",0x00        # string
