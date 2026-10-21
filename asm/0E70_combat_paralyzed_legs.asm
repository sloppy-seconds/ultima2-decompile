# combat_paralyzed_legs — leg-paralysis combat event (magic boots save)
# name-evidence: strings 'LEGS PARALIZED!' / 'SAVED BY MAGICAL BOOTS!'
# func 0E70..0EC1  len 0052 B  evidence: call+reko
# strings: "LEGS PARALIZED!"; "SAVED BY MAGICAL BOOTS!"
# calls: L_004d26, L_0051df (str_out), L_005417, L_0061c3
# provenance: live:castle-03-live — both strings are in the executed print set of
#           the 2026-10-21 sector-00 caster fight, and [DS:26B] was read non-zero
#           (9) mid-fight. Reached only from the dispatch at asm/0AD3.
# notes: gate is [DS:D9], the BOOTS slot of the item array at DS:D6+i, tested at
#           file 0x108D (`cmp byte [ds:d9],0`) INSIDE this function. Without the
#           item the paralysis lands unconditionally; with it the L_005417 roll
#           must be >= 0x40, so boots are a ~75% resist, not immunity. On a
#           failed resist [DS:26B] = rand & 0xF, i.e. 0..15 turns.
# CORRECTION 2026-10-21: the earlier note claiming a [DS:6D] gate at runtime 0x22FD
#           is wrong. A thief took the boots during the session and [DS:D9] fell
#           to 0 while [DS:6D] stayed 1 and the resist stopped firing. [DS:6D] is
#           the save-record slot and does not track theft; [DS:D9] is the live gate.
# confidence: high (gates, roll and effect variable proven by bytes and live memory)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
combat_paralyzed_legs:
L_001070:
        call L_0051df
        db "LEGS PARALIZED!",0x0d,0x00        # string
L_001084:
        call L_004d26
L_001087:
        call L_0061c3
L_00108a:
        call L_004d26
L_00108d:
        .byte 0x80,0x3e,0xd9,0x00,0x00  # forced-kept: gas re-encodes 'cmpb   $0x0,0xd9' differently
L_001092:
        je L_0010b8
L_001094:
        call L_005417
L_001097:
        cmp    $0x40,%al
L_001099:
        jb L_0010b8
L_00109b:
        call L_0051df
        db "SAVED BY MAGICAL BOOTS!",0x8d,0x00        # string
L_0010b7:
        ret
L_0010b8:
        nop
L_0010b9:
        call L_005417
L_0010bc:
        and    $0xf,%al
L_0010be:
        mov    %al,0x26b
L_0010c1:
        ret
