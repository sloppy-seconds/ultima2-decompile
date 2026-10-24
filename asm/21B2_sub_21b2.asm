# sub_21b2 — step gate, species clause 3: mon_type >= 0x78 jumps to asm/21BD and therefore
#           SKIPS the 0x5C clause in asm/21B6. AL is still mon_type. The range 0x78..0xFC is
#           arts 0x1E..0x3F: the solid/letter block plus the four NPC classes Fighter, Cleric,
#           Wizard and Thief. This is the only clause that splits species on the tile ladder.
# func 21B2..21B5  len 0004 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_21b2:
L_0023b2:
        cmp    $0x78,%al
L_0023b4:
        jae L_0023bd
