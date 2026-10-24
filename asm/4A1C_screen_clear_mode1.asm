# screen_clear_mode1 — INT 10h AH=00 AL=01: set 320x200 graphics, then fall through
# RENAMED 2026-10-28 from char_out, owner-approved. The bytes are `push ax ; mov $0x1,%ax ;
#           int $0x10` and nothing else -- 6 bytes, no `ret`, so it falls through to
#           asm/4A22_sub_4a22.asm, which zeroes the text cursor at DS:2E/2F and calls the
#           cursor setter at 0x53FD. `mov $0x1,%ax` sets AX=0x0001, so AH=00 (set video
#           mode) with AL=01 (320x200 4-col graphics), NOT AH=01 as the old header claimed
#           and not teletype, which on a real BIOS is AH=0E. Read as a unit with 4A22 it is
#           a screen-clear/mode-set prologue: cmd_Z calls it as the first act of drawing the
#           status page (docs/status-screen-z.md § 1).
#           The engine had built on the wrong name, and the fix is documentation, not
#           behaviour: `seam_char_out` (engine/src/core/seam.c) is a real primitive -- one
#           glyph at the cursor, no CR handling, no margin policy -- but the INT 10h AH=0E
#           teletype site it was said to stand in for has never been located in this binary,
#           so the seam is engine-authored and no longer cites this address. The owner
#           approved the rename and the minimal fix: the seam stays, the false provenance goes.
# name-evidence: 6-byte wrapper: mov ax,1 + int 10h, no ret; tail-called by cmd_Z and
#           followed by the cursor zero at asm/4A22_sub_4a22.asm
# func 4A1C..4A21  len 0006 B  evidence: seed+call+reko
# seams: video_int10
# provenance: live:airport (+59 other harvests), static
#           entry executed in 60 of 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# label: kept as char_out on purpose -- labels are body and CP0 md5s them; the name in the
#           filename is the discovered one, this line is only a cross-reference anchor.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
char_out:
L_004c1c:
        push   %ax
L_004c1d:
        mov    $0x1,%ax
L_004c20:
video_int10:
        int $0x10    # video_int10 seam
