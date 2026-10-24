# sign_of_al — AL := -1 / 0 / +1 according to the sign of AL
# name-evidence: `cmp $0x0,%al ; je L_0052e3` (zero returns 0), `jns L_0052e1`
#           (positive falls to `mov $0x1,%al ; ret`), the fall-through is
#           `mov $0xff,%al ; ret`. Three exits, three values, no other state touched.
# CALLERS: asm/4F11_monster_step_vector (twice, on the scaled pursuit delta),
#           asm/152E, asm/10A7, asm/10BC, asm/15E1_tavern_menu.
# NOT: a torus wrap. `docs/contract-creature-tick.md` said asm/50D8 "applies a torus
#           wrap"; it does not, and the torus behaviour lives in the `add al,al` pair
#           in its caller. Corrected 2026-10-28.
# func 50D8..50DB  len 0004 B  evidence: seed+call+reko
# provenance: static, decoded 2026-10-28
# confidence: high (four bytes to the first exit, and every exit is a `ret`)
# label: kept as sub_50d8 on purpose — labels are body and CP0 md5s them
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_50d8:
L_0052d8:
        cmp    $0x0,%al
L_0052da:
        je L_0052e3
