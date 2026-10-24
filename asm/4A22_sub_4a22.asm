# sub_4a22 — zero the text cursor at DS:2E/2F, then call the cursor setter
# cross-ref 2026-10-28: asm/4A1C_screen_clear_mode1.asm has no `ret` and falls through here, so
#           the two are one screen-clear prologue (docs/status-screen-z.md § 1). The filename
#           stays as the bulk-wave sub_4a22: the owner approved the 4A1C rename only.
# func 4A22..4A2E  len 000D B  evidence: seed+reko
# calls: L_0053fd
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4a22:
L_004c22:
        movb   $0x0,0x2e
L_004c27:
        movb   $0x0,0x2f
L_004c2c:
        call L_0053fd
