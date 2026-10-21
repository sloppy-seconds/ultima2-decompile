# combat_special_attack_dispatch — picks which monster special attack to run, by
#           monster type
# name-evidence: type compares at file 0xCD7/0xCE1/0xCEB/0xCF5 each followed by a
#           call into asm/0E70, asm/0EC2, asm/0F12 and asm/0F48
# func 0AD3..0ADA  len 0008 B  evidence: seed+reko
# provenance: live:castle-03-live — all four callees appear in the executed print
#           set of the 2026-10-21 sector-00 caster fight.
# notes: reads the type byte from [DI+0x197] (monster record, see asm/0ADB for the
#           call sites) and dispatches:
#             0x34 -> asm/0E70 legs paralysis   (resist: BOOTS, [DS:D9])
#             0x38 -> asm/0EC2 arms paralysis   (resist: CLOAK, [DS:DA])
#             0xF8 -> asm/0F12 magic missile    (NO resist)
#             0x3C -> asm/0F48 sleep spell      (resist: GREEN IDOL, [DS:E4])
#           Types 0x30, 0xF4 and 0xFC were also observed live in the same fight and
#           reach none of these, so they are plain melee attackers. The gate that
#           decides whether a special is attempted at all is asm/0AAA.
# confidence: high (dispatch table proven by bytes; callees proven by execution)
sub_0ad3:
L_000cd3:
        mov    0x197(%di),%al
L_000cd7:
        cmp    $0x34,%al
L_000cd9:
        jne L_000ce1
