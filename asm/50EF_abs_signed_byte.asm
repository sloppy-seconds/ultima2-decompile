# abs_signed_byte — |AL| for a signed byte
# name-evidence: `cmp $0x80,%al; jb <return as-is>` — values below 0x80 are
#   returned untouched, so the fall-through path is the negate. Callers use it on
#   the DS:19/DS:1A pursuit deltas from asm/4F36 before comparing against a
#   distance (asm/0AAA uses 3, asm/1040 uses 4), which only makes sense as a
#   magnitude test.
# provenance: static. Read from the listing and decoded 2026-10-28d; bytes proven by
#           tools/check_func.py. The name is inference from shape plus use, and the use is what
#           makes it safe: the only callers are asm/0AAA and asm/1040, both of which compare the
#           result against a distance (3 and 4), and a signed byte compared against a small
#           positive distance is only meaningful as a magnitude. No harvest has been needed to
#           establish it and none has observed it directly.
# func 50EF..50F2  len 0004 B  evidence: seed+call+reko
# confidence: high
# label: kept as sub_50ef on purpose — labels are body and CP0 md5s them
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_50ef:
L_0052ef:
        cmp    $0x80,%al
L_0052f1:
        jb L_0052e3
