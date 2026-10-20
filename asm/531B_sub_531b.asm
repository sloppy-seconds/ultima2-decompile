# sub_531b — mechanical clean (bulk wave); behavior not yet reviewed
# func 531B..5342  len 0028 B  evidence: seed+reko
# calls: L_00514d, L_0051df (str_out), L_00550f
# notes: string-display site (defects.md): call str_out + inline string; Reko
#        failed here on recursion (string site, not control flow). Decoded
#        cleanly here as code-prefix + string. Disposition: clean (documented).
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_531b:
L_00551b:
        call L_0051df
        db 0x0d,"               WRONG DISK",0x00        # string
L_005539:
        call L_00514d
L_00553c:
        cmp    $0xff1b,%ax
L_00553f:
        jne L_005539
L_005541:
        jmp L_00550f
