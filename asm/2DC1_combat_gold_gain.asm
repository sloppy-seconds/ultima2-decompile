# combat_gold_gain — monster killed: gold gain
# name-evidence: adds DS:1F into DS:58/59; the GOLD= display site asm/5188 loads
#           [DS:58] then [DS:59] (raw a0 58 00 / 8a 1e 59 00), so 58/59 is gold.
#           The trailing "--EXP.+" string introduces the NEXT operation
#           (asm/2DEE, which writes DS:56/57); it does not describe this one.
#           Renamed from combat_exp_gain on 2026-10-21 for that reason.
# func 2DC1..2DE0  len 0020 B  evidence: seed+reko
# strings: "--EXP.+"
# calls: L_0051df (str_out)
# provenance: live:play-test-live, static
# confidence: medium (write target and display site both byte-proven)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
combat_gold_gain:
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
