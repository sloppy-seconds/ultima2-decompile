# melee_hit_roll — does this creature get a blow in at all
# name-evidence: `call L_005417` (rand_byte), then asm/0B65 sets di from [DS:27]
#   (the slot cursor asm/0B4D staged) and refuses when the roll is negative or when
#   `(rand & 7) < [DS:62]`. So the chance a creature lands anything is 1-in-8
#   scaled by [DS:62], and DS:62 is the only candidate this project has for what a
#   player might call armour or evasion — NOT yet named, because nothing here says
#   what DS:62 is beyond being compared against a 3-bit random value.
# chain: asm/0B5F (the thief's steal attempt, asm/0FCD) -> this roll -> asm/0B71
#   (the (rand & 7) test) -> asm/0B79 (the damage pool) -> asm/0B9D (store the mask)
#   -> asm/0BA0 (site branch) -> asm/0BD1/asm/0BDB (apply it to HP).
# func 0B62..0B64  len 0003 B  evidence: seed+reko
# provenance: static, read 2026-10-27
# confidence: high for the two tests; the meaning of DS:62 is open
# label: kept as sub_0b62 on purpose — labels are body and CP0 md5s them
sub_0b62:
L_000d62:
        call L_005417
