# sub_5120 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5120..5120  len 0001 B  evidence: seed+reko
# notes: *** SELF-MODIFYING CLUSTER (runtime-patched) *** — Phase 1/2 defect:
#        this region is rewritten at runtime; bytes reconstructed AS-IS and
#        byte-proven, but the static decode is NOT the executed logic.
#        Disposition: excluded(selfmod). Do not lift to C (Phase 4 memo).
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5120:
L_005320:
        .byte 0xe8  # forced-kept: stop-trunc call   0x55df
