# sub_514f — mechanical clean (bulk wave); behavior not yet reviewed
# func 514F..5150  len 0002 B  evidence: reko
# notes: *** SELF-MODIFYING CLUSTER (runtime-patched) *** — Phase 1/2 defect:
#        this region is rewritten at runtime; bytes reconstructed AS-IS and
#        byte-proven, but the static decode is NOT the executed logic.
#        Disposition: excluded(selfmod). Do not lift to C (Phase 4 memo).
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_514f:
L_00534f:
        push   %sp
        db 0x00        # tail-pad
