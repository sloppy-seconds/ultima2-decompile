# video_flash_variant — one of four fixed-position wrappers onto the wound-flash ring renderer
# name-evidence: the body is `mov $0xA0,%ax ; mov $0x50,%bx ; jmp L_00547f`, the same shape as
#           asm/5255_wound_video_flash (AX=0x90,BX=0x50), asm/525E (0x90,0x60) and asm/5267
#           (0x90,0x40). L_00547f is asm/527F, which loads the ring table at runtime 0x5288 and
#           tail-calls asm/4C1E_video_xor_patch; AX>>2 is the in-segment offset and BX indexes
#           a window of the video segment table at cs:[BX+0x48DC], so each wrapper draws the
#           same ring at a different fixed screen cell — this one is the only variant with a
#           different AX, i.e. a different row within the same segment window. The multi-cell
#           use is OBSERVED: captures/spice86/wound-flash-20261102 frame 00257 shows the
#           identical ring at span offset 2836 (five scanlines above the player's 3237) when
#           the player's attack lands on a creature — the ring marks the hit unit's cell, in
#           both directions (owner, confirmed by frame). Which wrapper the attack path calls is
#           NOT identified: no callers of 525E/5267/5270 appear anywhere in asm/ (the L_00545e
#           mention in asm/2E3D is a je target of a halved routine, not a call). Renamed
#           2026-11-02 from sub_5270.
# provenance: bodies read directly (all four wrappers); the creature-cell ring observed live
#           2026-11-02 in captures/spice86/wound-flash-20261102 (motif scan of a 30 Hz poll).
# confidence: high that this is a fixed-position wrapper of the flash family (bytes); low on
#             which cell it draws and who calls it (open).
# func 5270..5278  len 0009 B  evidence: seed+reko
# calls: L_00547f
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5270:
L_005470:
        mov    $0xa0,%ax
L_005473:
        mov    $0x50,%bx
L_005476:
        jmp L_00547f
L_005478:
        nop
