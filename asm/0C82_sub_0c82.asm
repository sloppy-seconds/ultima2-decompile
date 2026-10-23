# sub_0c82 — mechanical clean (bulk wave); behavior not yet reviewed
# part of: the death tail, asm/0C62..0C99 — see asm/0C62_death.asm. This fragment
#   is the three newlines (db 0x8d,0x8d,0x8d) that clear the log so the
#   announcement lands on its own.
# func 0C82..0C88  len 0007 B  evidence: seed+reko
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0c82:
L_000e82:
        call L_0051df
        db 0x8d,0x8d,0x8d,0x00        # string
