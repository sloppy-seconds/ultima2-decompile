# monster_hp_sea_serpent — spawn arm: assigns monster type 0x2C and HP 64
# name-evidence: `mov $0x2c,%al` stored to [DI+0x197] and stamped into the map cell,
#           then `mov $0x40,%al` stored to [DI+0x177] (monster HP, proven by
#           asm/2E3D_combat_attack_flow). Type 0x2C >> 2 == art 0x0B, named Sea
#           serpent / Sea Monster by bitmap identity, third-party HP 64.
#           NOTE art 0x0B carries a standing dispute (see docs/bestiary.md § 8):
#           tile-art.tsv reads it as a doorway, not a creature. The HP value is not
#           in dispute; what the art depicts is.
# provenance: static, 2026-10-22; extracted by tools/monster_hp_dispatch.py
# confidence: high for the field and the value (bytes)
# label: kept as sub_0daf on purpose — labels are body (CP0)
# func 0DAF..0DC3  len 0015 B  evidence: seed+reko
# calls: L_000daf
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0daf:
L_000faf:
        mov    $0x2c,%al
L_000fb1:
        mov    0x6,%bx
L_000fb5:
        mov    %al,(%bx,%si)
L_000fb7:
        mov    %al,0x197(%di)
L_000fbb:
        mov    $0x40,%al
L_000fbd:
        mov    %al,0x177(%di)
L_000fc1:
        jmp L_000daf
