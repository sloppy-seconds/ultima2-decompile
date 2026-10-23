# sub_0c89 — mechanical clean (bulk wave); behavior not yet reviewed
# part of: the death tail, asm/0C62..0C99 — see asm/0C62_death.asm. This fragment
#   calls L_00527a (asm/507A), which walks DS:36 to a NUL: the character's name.
#   Screen-proven by the announcement itself in
#   captures/spice86/cp5-weak-fight/death1.png.
# func 0C89..0C8B  len 0003 B  evidence: seed+reko
# calls: L_00527a
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0c89:
L_000e89:
        call L_00527a
