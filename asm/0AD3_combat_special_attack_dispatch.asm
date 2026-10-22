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
# CONFLICT, open (2026-10-22): this dispatch reads [DI+0x197] as a monster *type*,
#   and docs/spice86-live-findings.md also records [DI+0x197] as the slot's
#   active/sentinel byte where 0x40 means EMPTY (cmp [DI+0x197],0x40 at 0x2C2D).
#   The same document concludes "the thief is monster type 0x40" from a cmp against
#   0x40 at file 0x1244. Both cannot hold: if 0x40 is the empty sentinel then that
#   steal loop is skipping empty slots and the thief's type is unknown. Note the
#   third field [DI+0x1B7], the sprite stamped into the map cell, ALSO folds to the
#   right art under >>2 on four measured values (0x60 Guard, 0xF0 Fighter, 0xF8
#   Wizard, 0xFC Thief), as do four 0x197 values here. Unresolved; needs one live
#   slot with both fields dumped (docs/needs-gameplay.md G18). Do not encode either
#   reading into the engine until it is settled.
sub_0ad3:
L_000cd3:
        mov    0x197(%di),%al
L_000cd7:
        cmp    $0x34,%al
L_000cd9:
        jne L_000ce1
