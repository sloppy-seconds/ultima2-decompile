# apply_hp_damage — subtract the damage byte at DS:22 from HP, then branch on site
# name-evidence: `al := ([DS:22] & 0x77) + 1`, then the house BCD idiom
#   (`stc; cmc; sbb [DS:22],[DS:52]; das; cmc`) on DS:52 and a second `sbb $0x0`
#   on DS:51, then `jae L_000e62` — the death handler this project named on
#   2026-10-27. A subtract whose underflow is death, driven by a scratch byte the
#   specials accumulate into: this is where the game actually hurts the player.
#   asm/0C09 is the sibling arm and writes DS:22 itself before subtracting.
# WHY THIS MATTERS: CP5 spent two sessions saying "melee damage is not located".
#   It is here, and the reason it was missed twice is that the search looked for a
#   subtract against DS:51/DS:52 and this loads the operand from DS:22 first, so no
#   `sbb` names the HP byte directly. The damage magnitude is
#   `([DS:22] & 0x77) + 1`, i.e. 1..118 in packed decimal, NOT a flat byte.
#   The producer of DS:22 on this path is still the open half: asm/0F12 (magic
#   missile) accumulates into DS:20/21/22 per ticket C4, and the plain melee types
#   named in asm/0AD3's header have yet to be traced to a write here.
# falls-through-to: asm/0C02, which sends a site to the status tick (asm/0C1F) and
#   the world map to the H.P. redraw (asm/0C1C). So the counters tick on the damage
#   path, not on a timer — see asm/0C1F.
# func 0BDB..0C01  len 0027 B  evidence: seed+reko
# provenance: static, read 2026-10-27. Not derived by tools/provenance_from_traces.py.
# confidence: high for the arithmetic and the death branch (bytes); medium for the
#   role of DS:22 as the damage operand (the producers are only partly traced)
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
