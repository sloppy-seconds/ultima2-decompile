# sub_21b6 — step gate, tile clause: DS:1F == 0x5C is accepted, but only on the path that
#           reaches here, i.e. mon_type < 0x78. Art 0x17; 72 cells in mapx03, 4 in mapx71.
#           What it IS is not established — see asm/2199_creature_step_gate and G29.
# func 21B6..21BC  len 0007 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_21b6:
L_0023b6:
        mov    0x1f,%al
L_0023b9:
        cmp    $0x5c,%al
L_0023bb:
        je L_0023e2
