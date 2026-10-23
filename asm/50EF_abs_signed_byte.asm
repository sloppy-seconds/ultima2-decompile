# abs_signed_byte — |AL| for a signed byte
# name-evidence: `cmp $0x80,%al; jb <return as-is>` — values below 0x80 are
#   returned untouched, so the fall-through path is the negate. Callers use it on
#   the DS:19/DS:1A pursuit deltas from asm/4F36 before comparing against a
#   distance (asm/0AAA uses 3, asm/1040 uses 4), which only makes sense as a
#   magnitude test.
# func 50EF..50F2  len 0004 B  evidence: seed+call+reko
# confidence: high
# label: kept as sub_50ef on purpose — labels are body and CP0 md5s them
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_50ef:
L_0052ef:
        cmp    $0x80,%al
L_0052f1:
        jb L_0052e3
