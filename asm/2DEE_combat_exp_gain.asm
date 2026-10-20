# combat_exp_gain — monster killed: experience gain
# name-evidence: adds DS:1F into DS:56/57; the EXP.= display site asm/5167 loads
#           [DS:56] then [DS:57] (raw a0 56 00 / 8a 1e 57 00), so 56/57 is exp.
#           Amount added by asm/2DE4 is (rand & 3) + 1, i.e. 1..4 per kill.
#           Renamed from sub_2dee on 2026-10-21; the previous asm/2DC1 label
#           claimed this role while writing the gold pair.
# func 2DEE..2E05  len 0018 B  evidence: seed+reko
# calls: L_00543e
# provenance: live:play-test-live, static
# confidence: medium (write target and display site both byte-proven)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
combat_exp_gain:
L_002fee:
        clc
L_002fef:
        mov    0x57,%al
L_002ff2:
        adc    0x1f,%al
L_002ff6:
        daa
L_002ff7:
        mov    %al,0x57
L_002ffa:
        mov    0x56,%al
L_002ffd:
        adc    $0x0,%al
L_002fff:
        daa
L_003000:
        mov    %al,0x56
L_003003:
        call L_00543e
