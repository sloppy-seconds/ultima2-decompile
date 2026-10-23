# char_out — BIOS teletype output of AL (INT 10h AH=01h)
# NAME DISPUTED 2026-10-28: the bytes are `push ax ; mov $0x1,%ax ; int $0x10` and nothing
#           else -- 6 bytes, no `ret`, it falls through to asm/4A22_sub_4a22.asm, which
#           zeroes the text cursor at DS:2E/2F and calls L_0053fd. `mov $0x1,%ax` sets
#           AX=0x0001, so AH=00 (set video mode) with AL=01 (320x200 4-col graphics), NOT
#           AH=01 as this header claims and not teletype, which is AH=0E. Read as a unit
#           with 4A22 it is a screen-clear/mode-set prologue: cmd_Z calls it as the first
#           act of drawing the status page (docs/status-screen-z.md § 1).
#           Proposed rename: 4A1C_screen_clear_mode1. Not renamed here because the engine
#           has already built on the wrong name: engine/src/platform/platform.h:13 maps
#           `char_out -> seam_char_out -> renderer->cell`, engine/src/core/vram.h:17 and
#           vram.c:54 describe it as "INT 10h AH=01h teletype", and seam.c's seam_char_out
#           implements that. The blast radius is small today -- seam_char_out has exactly
#           one caller, creation.c:231 padding a name with spaces -- but a seam is CP5's
#           replacement surface, so correcting it is an engine change and needs an owner,
#           not a rename in a docs commit.
# name-evidence: 6-byte wrapper: mov ax,1 + int 10h; tail-called by cmd_Z
# func 4A1C..4A21  len 0006 B  evidence: seed+call+reko
# seams: video_int10
# provenance: live:airport (+59 other harvests), static
#           entry executed in 60 of 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
char_out:
L_004c1c:
        push   %ax
L_004c1d:
        mov    $0x1,%ax
L_004c20:
video_int10:
        int $0x10    # video_int10 seam
