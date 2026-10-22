# monster_hp_subtract — second HP decrement site: HP -= the damage byte at [DS:1F]
# name-evidence: `stc; mov 0x177(%di),%al; cmc; sbb 0x1F,%al; cmc; jae L_002ea4`,
#           falling through to asm/2C26_monster_hp_set on a hit. Same BCD-guard idiom
#           as asm/2E3D_combat_attack_flow (which subtracts [DS:20]); here the damage
#           source is [DS:1F], so this is a different damage route onto the same field.
#           [DS:1F] is now traced: asm/3606 sets it to `rand | 0x20`, i.e. 32..63,
#           immediately before asm/3611_monster_damage_apply jumps here. So this site
#           deals a random 32-63 to a slot chosen by [DS:20]. What selects the slot
#           and why that magnitude is not established.
#           Reached by `jmp L_002e19` from asm/3611, which is the one routine found
#           that is aware of the site kind (`cmpb $0x4,[DS:4A]`, tower). That makes
#           asm/3611 the best remaining lead for how town and tower NPCs take damage,
#           since no spawn arm assigns them HP at all.
# provenance: static, 2026-10-22
# confidence: low (bytes proven by check_func.py; the caller's role is inferred)
# label: kept as sub_2c19 on purpose — labels are body (CP0)
# func 2C19..2C25  len 000D B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2c19:
L_002e19:
        stc
L_002e1a:
        mov    0x177(%di),%al
L_002e1e:
        cmc
L_002e1f:
        sbb    0x1f,%al
L_002e23:
        cmc
L_002e24:
        jae L_002ea4
