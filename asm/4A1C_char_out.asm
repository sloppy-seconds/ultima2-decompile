# char_out — BIOS teletype output of AL (INT 10h AH=01h)
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
