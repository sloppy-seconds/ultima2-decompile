# melee_damage_pool — add this creature's share to the damage mask at DS:22
# name-evidence: `al := [di+0x177]` (mon_hp), two `rcr $1` (divide by four), then
#   `stc; adc [DS:22],%al` — so DS:22 ACCUMULATES `mon_hp >> 2` plus one per creature
#   that reaches here, rather than being set. That is why the byte is a pool: the
#   creature loop runs this once per attacking slot, and the total is applied later,
#   randomised, by asm/0BDB as `((rand & [DS:22]) & 0x77) + 1`.
#   The tail reads si from [DS:14] and doubles the pool when its low nibble is 6
#   (`cmp $0x6,%bl; jne <store>` else `add %al,%al`), which is the only place in this
#   chain that a site kind changes the damage. [DS:14] is mode_a, so "some site kinds
#   make monsters hit twice as hard" is what the bytes say and what has NOT been
#   confirmed against play — recorded, not interpreted.
# WHY THIS WAS MISSED: CP5 said three times that melee damage was unlocated. The
#   subtract never names DS:51/DS:52 (it goes through DS:22), the per-creature amount
#   is derived from the creature's OWN hit points, and the apply site is a dozen
#   fragments away with a rand call in between.
# open: the measured live figure is 9999 -> 9796 over a town fight. Whether the pool
#   plus the random mask reproduces that has not been checked, and the engine does not
#   implement this chain at all yet.
# func 0B79..0B9A  len 0022 B  evidence: seed+reko
# provenance: static, read 2026-10-27
# confidence: high for the arithmetic; the DS:14 doubling arm is unconfirmed by play
# label: kept as sub_0b79 on purpose — labels are body and CP0 md5s them
sub_0b79:
L_000d79:
        incb   0x21
L_000d7d:
        mov    0x177(%di),%al
L_000d81:
        clc
L_000d82:
        rcr    $1,%al
L_000d84:
        clc
L_000d85:
        rcr    $1,%al
L_000d87:
        stc
L_000d88:
        adc    0x22,%al
L_000d8c:
        mov    $0x0,%bh
L_000d8e:
        mov    0x14,%bl
L_000d92:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_000d94:
        .byte 0x8b,0xde  # forced-kept: gas re-encodes 'mov    %si,%bx' differently
L_000d96:
        cmp    $0x6,%bl
L_000d99:
        jne L_000d9d
