# sub_218b — the no-move tail: all three candidates refused, or the accepted candidate is the
#           player's own cell (asm/2213 arrives here). DS:4A == 0 -> asm/2195 -> next slot;
#           DS:4A != 0 -> asm/1040_minax_proximity_check (docs/monster-spawn.md § 13).
# func 218B..2191  len 0007 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_218b:
L_00238b:
        mov    0x4a,%al
L_00238e:
        cmp    $0x0,%al
L_002390:
        je L_002395
