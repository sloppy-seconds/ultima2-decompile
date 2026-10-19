# sub_0d21 — 4-way test chain on AL (rotate-right + carry probes), dispatches
#            to one of five far targets# exact semantics unknown
# func 0D21..0D43  len 035 B  evidence: seed+reko
# confidence: low (structure proven, meaning of the AL bits not yet)
sub_0d21:
        clc
        rcr    $1,%al
        jae    .L0d21_probe2
        jmp    L_000fd4
.L0d21_probe2:
        clc
        rcr    $1,%al
        jae    .L0d21_probe3
        jmp    L_000fcb
.L0d21_probe3:
        clc
        rcr    $1,%al
        jae    .L0d21_probe4
        jmp    L_000fce
.L0d21_probe4:
        clc
        rcr    $1,%al
        jae    .L0d21_default
        jmp    L_000fd1
.L0d21_default:
        jmp    L_001050
