# sub_5126 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5126..5128  len 0003 B  evidence: seed+reko
# calls: L_0055d9
# notes: *** SELF-MODIFYING CLUSTER (runtime-patched) *** — Phase 1/2 defect:
#        this region is rewritten at runtime; bytes reconstructed AS-IS and
#        byte-proven, but the static decode is NOT the executed logic.
#        Disposition: excluded(selfmod). Do not lift to C (Phase 4 memo).
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5126:
L_005326:
        call L_0055d9
