# apply_hp_damage — subtract a randomised share of the damage mask at DS:22 from HP
# name-evidence: the entry is asm/0BD1 (`if [DS:22] == 0 -> redraw and return`), then
#   asm/0BD8 `call L_005417` (rand_byte), then THIS fragment: `al := al AND [DS:22]`,
#   `al := al AND 0x77`, `al := al + 1`, `[DS:22] := al`, then the house BCD idiom
#   (`stc; cmc; sbb [DS:22],[DS:52]; das; cmc`) on DS:52 and a second `sbb $0x0` on
#   DS:51, then `jae L_000e62` — the death handler this project named on 2026-10-27.
# THE FORMULA, stated exactly, because the first draft of this header got it wrong and
#   said `[DS:22] & 0x77 + 1`: the damage actually taken is
#
#       ((rand_byte() & [DS:22]) & 0x77) + 1
#
#   so DS:22 is a MASK or CAP the attacker sets, not the amount, and the amount is
#   random up to it. A fixed-amount reading would have made every fight in the engine
#   deterministic in a way the original is not. The zero test one fragment earlier is
#   what makes a zero mask mean "no damage at all" rather than "damage of 1".
# WHY THIS MATTERS: CP5 spent two sessions saying "melee damage is not located". It is
#   here, and it was missed twice for the same reason: the search looked for a subtract
#   naming DS:51/DS:52, and this loads the operand from DS:22 first, and the rand call
#   sits between the entry test and the mask, so the chain does not read as a damage
#   site at a glance.
#   The producer of DS:22 on the melee path is still the open half: asm/0F12 (magic
#   missile) writes it, asm/38B0_cmd_L writes it five times, and asm/0B9D writes it
#   inside the creature loop before the site branch at asm/0BA0. What sets the mask for
#   the plain melee types named in asm/0AD3's header is not yet traced.
# falls-through-to: asm/0C02, which sends a site to the status tick (asm/0C1F) and the
#   world map to the H.P. redraw (asm/0C1C). So the counters tick on the damage path,
#   not on a timer — see asm/0C1F.
# func 0BDB..0C01  len 0027 B  evidence: seed+reko
# provenance: static, read 2026-10-27. Not derived by tools/provenance_from_traces.py.
# confidence: high for the arithmetic and the death branch (bytes); medium for the role
#   of DS:22 as the damage mask (the producers are only partly traced)
# label: kept as sub_0bdb on purpose — labels are body and CP0 md5s them
sub_0bdb:
L_000ddb:
        and    0x22,%al
L_000ddf:
        and    $0x77,%al
L_000de1:
        clc
L_000de2:
        adc    $0x1,%al
L_000de4:
        mov    %al,0x22
L_000de7:
        stc
L_000de8:
        mov    0x52,%al
L_000deb:
        cmc
L_000dec:
        sbb    0x22,%al
L_000df0:
        das
L_000df1:
        cmc
L_000df2:
        mov    %al,0x52
L_000df5:
        mov    0x51,%al
L_000df8:
        cmc
L_000df9:
        sbb    $0x0,%al
L_000dfb:
        das
L_000dfc:
        cmc
L_000dfd:
        mov    %al,0x51
L_000e00:
        jae L_000e62
