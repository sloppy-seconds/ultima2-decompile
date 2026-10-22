# combat_sleep_spell — sleep-spell combat event (idol save)
# name-evidence: strings 'SLEEP SPELL!' / 'SAVED BY IDOL!'
# corroboration 2026-10-22: third-party bestiary names the caster Balron, and the
#   codex DOS bitmap for Balron is pixel-identical to our art 0x0F (see
#   bestiary/bestiary.tsv). Both sources give "puts enemies to sleep (range 2)".
#   External claim, agrees with the strings; it is not proof and changes no name.
# func 0F48..0F8D  len 0046 B  evidence: call+reko
# strings: "SLEEP SPELL!"; "SAVED BY IDOL!"
# calls: L_004d26, L_0051df (str_out), L_005417, L_0061c3
# provenance: live:castle-03-live — both strings executed in the 2026-10-21
#           sector-00 caster fight; [DS:26D] was read non-zero (8) live.
#           Reached only from the dispatch at asm/0AD3.
# notes: gate is [DS:E4], the GREEN IDOL slot of the item array at DS:D6+i, tested
#           at file 0x1162 (`mov al,[ds:e4]; or al,al; je ...`). Without the idol
#           sleep lands unconditionally; with it the L_005417 roll must be >= 0x40,
#           so an idol is a ~75% resist, not immunity. On a failed resist
#           [DS:26D] = rand & 0xF, i.e. 0..15 turns.
# confidence: high (gate, roll and effect variable proven by bytes and live memory)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
combat_sleep_spell:
L_001148:
        call L_0051df
        db "SLEEP SPELL!",0x0d,0x00        # string
L_001159:
        call L_004d26
L_00115c:
        call L_0061c3
L_00115f:
        call L_004d26
L_001162:
        mov    0xe4,%al
L_001165:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_001167:
        je L_001184
L_001169:
        call L_005417
L_00116c:
        cmp    $0x40,%al
L_00116e:
        jb L_001184
L_001170:
        call L_0051df
        db "SAVED BY IDOL!",0x8d,0x00        # string
L_001183:
        ret
L_001184:
        nop
L_001185:
        call L_005417
L_001188:
        and    $0xf,%al
L_00118a:
        mov    %al,0x26d
L_00118d:
        ret
