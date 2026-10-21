# combat_paralyzed_arms — arm-paralysis combat event (magic cloak save)
# name-evidence: strings 'ARMS PARALIZED!' / 'SAVED BY MAGICAL CLOAK'
# func 0EC2..0F11  len 0050 B  evidence: call+reko
# strings: "ARMS PARALIZED!"; "SAVED BY MAGICAL CLOAK"
# calls: L_004d26, L_0051df (str_out), L_005417, L_0061c3
# provenance: live:castle-03-live — both strings executed in the 2026-10-21
#           sector-00 caster fight. Reached only from the dispatch at asm/0AD3.
# notes: gate is [DS:DA], the CLOAK slot of the item array at DS:D6+i, tested at
#           file 0x10DF (`mov al,[ds:da]; or al,al; je ...`). Without the cloak the
#           paralysis lands unconditionally; with it the L_005417 roll must be
#           >= 0x40, so a cloak is a ~75% resist, not immunity. On a failed resist
#           [DS:26C] = rand & 0xF, i.e. 0..15 turns. Arms and legs are separate
#           counters with separate items, so a character can be paralysed in one
#           and free in the other.
# confidence: high (gate, roll and effect variable proven by bytes and live memory)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
combat_paralyzed_arms:
L_0010c2:
        call L_0051df
        db "ARMS PARALIZED!",0x0d,0x00        # string
L_0010d6:
        call L_004d26
L_0010d9:
        call L_0061c3
L_0010dc:
        call L_004d26
L_0010df:
        mov    0xda,%al
L_0010e2:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_0010e4:
        je L_001109
L_0010e6:
        call L_005417
L_0010e9:
        cmp    $0x40,%al
L_0010eb:
        jb L_001109
L_0010ed:
        call L_0051df
        db "SAVED BY MAGICAL CLOAK",0x8d,0x00        # string
L_001108:
        ret
L_001109:
        call L_005417
L_00110c:
        and    $0xf,%al
L_00110e:
        mov    %al,0x26c
L_001111:
        ret
