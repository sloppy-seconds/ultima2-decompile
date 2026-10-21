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
# RE-DECODED 2026-10-21 (file 0x2623..0x287F, runtime 0x2423..0x2680, 286 instrs):
#           This routine contains NO read of the target map tile. Its only
#           map_tile_ptr call is at runtime 0x2466 and it WRITES 0x50 into the
#           cell at (DS:6A,DS:6B). The real gate is a mode ladder at runtime
#           0x25C0..0x25F6 on DS:29 & 0x7F: rejects 0x00 and 0x08, accepts
#           0x22/0x24/0x26/0x28/0x2A/0x2C/0x2E/0x38 and anything below 0x16,
#           rejects anything else >= 0x16, and diverts 0x60 to the stamp path.
#           A first ladder at runtime 0x253B compares DS:13 against
#           0x28/0x26/0x24/0x22, but DS:13 is the player stamp (0x78 on foot in
#           every in-world capture), so none of those arms are taken on foot.
#           Full write-up: docs/passability-findings.md
# REFUTED 2026-10-21 by live measurement (docs/passability-findings.md F10):
#           the destination TILE BYTE. A patched live run loaded TEST at (20,20)
#           in sector 20 and walked: (20,20)->(20,19) onto tile 0x08 MOVED,
#           (20,19)->(20,18) onto 0x08 MOVED, (20,18)->(20,17) onto 0x00 BLOCKED.
#           So 0x08 is PASSABLE - the engine's u2_tile_passable() was right and
#           the mountain is NOT 0x08. If DS:29 were the tile byte the ladder
#           would have rejected 0x08 twice; it did not. DS:29 afterwards read
#           0x1C, a value this ladder rejects, while the character had just
#           moved freely - confirming DS:29 is shared scratch, not an input.
#           Therefore this ladder is NOT the tile passability gate. It is real
#           code, transcribed correctly, deciding something else.
#           What survives: water 0x00 blocks (now proven live three times), and
#           the tile decision must be made upstream by whatever fills
#           DS:2CB/DS:2DE - the only surviving candidate from F3.
# provenance: live:create-test-live, live:play-test-live, re-decoded
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
