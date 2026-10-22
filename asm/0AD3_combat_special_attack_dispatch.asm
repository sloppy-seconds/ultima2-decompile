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
# RESOLVED 2026-10-22 (was: CONFLICT, open): [DI+0x197] is the monster TYPE and 0x40
#   is the EMPTY sentinel -- it is not the thief. The spawn arms store type and HP
#   together (asm/0D4F_monster_hp_orc, asm/0D6F_monster_hp_thief_daemon,
#   asm/0DAF_monster_hp_sea_serpent,
#   asm/0DC4_monster_hp_fighter_frigate_devil_wizard_balron) and the thief's arm sets
#   type 0xFC with HP 0x20 (32), matching art 0x3F (Thief, by bitmap identity) and the
#   third-party HP for Thief (32). 0x40 appears in none of the nine arms. So the
#   `cmp $0x40` at file 0x1244 in asm/0FCD_combat_thief_steal is skipping empty slots,
#   and the claim "the thief is monster type 0x40" in
#   docs/spice86-live-findings.md is wrong and should be corrected there.
#   RETRACTED 2026-10-22 (same day): [DI+0x1B7] is NOT a sprite. A live read of all 32
#   slots shows it holds a small kind index (0x08/0x0C), which is what the spawn guards
#   compare against (cmp $0x8,%al). The arms write [DI+0x197] and the map cell from the
#   same immediate; they do not write 0x1B7. So the "eight agreements across two fields"
#   claimed here was really four agreements from one field relabelled, and they are
#   arithmetic only -- no arm contains a shift, so >>2 is a hypothesis about the renderer,
#   not a proven transform. See docs/needs-gameplay.md G18 and docs/bestiary.md § 7.
sub_0ad3:
L_000cd3:
        mov    0x197(%di),%al
L_000cd7:
        cmp    $0x34,%al
L_000cd9:
        jne L_000ce1
