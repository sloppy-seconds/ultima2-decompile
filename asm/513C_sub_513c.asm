# sub_513c — mechanical clean (bulk wave); behavior not yet reviewed
# func 513C..513C  len 0001 B  evidence: seed+reko
# notes: *** SELF-MODIFYING CLUSTER (runtime-patched) *** — Phase 1/2 defect:
#        this region is rewritten at runtime; bytes reconstructed AS-IS and
#        byte-proven, but the static decode is NOT the executed logic.
#        Disposition: excluded(selfmod). Do not lift to C (Phase 4 memo).
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_513c:
L_00533c:
        .byte 0xb7  # forced-kept: gas re-encodes 'mov    $0x0,%bh' differently
