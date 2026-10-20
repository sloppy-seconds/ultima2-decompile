# sub_2423 — overworld passability / travel-mode check, ENTRY ONLY
# name-evidence: live capture. Called as `call 0x2423` from the walk loop with a
#           mode byte in AL ([DS:15] on one arm, [DS:18] on another); returns 0
#           to accept and 0xFF to reject. Accept path runtime 0x2664 masks both
#           coordinates with and 0x3F (the overworld is a torus); reject paths
#           runtime 0x2538 and 0x25FF both `mov al,0xFF; ret`. The 19-food move
#           drain is inline inside this routine at runtime 0x2599 and 0x2626.
# WARNING: the declared range below is far too small. The routine runs to about
#           runtime 0x2680, not 0x242C. Reading only this file makes the
#           function look like it performs no rejection at all, which is exactly
#           how a static pass on 2026-10-21 produced a wrong "no passability"
#           finding that a live capture then disproved. Do not trust this
#           boundary; re-decode 2423..2680 before reasoning about behaviour.
# func 2423..242C  len 000A B  evidence: seed+call+reko
# provenance: live:play-test-live, live:create-test-live
# confidence: low (bytes proven by check_func.py; boundary known wrong)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2423:
L_002623:
        mov    %al,0x29
L_002626:
        mov    0x4a,%al
L_002629:
        cmp    $0x0,%al
L_00262b:
        je L_00268b
