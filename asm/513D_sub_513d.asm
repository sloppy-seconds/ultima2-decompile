# sub_513d — mechanical clean (bulk wave); behavior not yet reviewed
# func 513D..514A  len 000E B  evidence: reko
# notes: *** SELF-MODIFYING CLUSTER (runtime-patched) *** — Phase 1/2 defect:
#        this region is rewritten at runtime; bytes reconstructed AS-IS and
#        byte-proven, but the static decode is NOT the executed logic.
#        Disposition: excluded(selfmod). Do not lift to C (Phase 4 memo).
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_513d:
L_00533d:
        add    %cl,0x541e(%bp,%si)
L_005341:
        add    %cl,-0x5f05(%bp,%di)
L_005345:
        push   %bx
L_005346:
        add    %cl,(%bp,%si)
L_005348:
        .byte 0xc0,0x75,0x03  # forced-kept: gas re-encodes 'shlb   $0xe8,0x3(%di)' differently
