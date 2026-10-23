# character_dead_msg — announces a character death
# part of: the death tail, asm/0C62..0C99 — see asm/0C62_death.asm. This is its
#   last fragment; the name arrives already printed by asm/0C89, which is why the
#   string carries its own leading space and no name of its own.
# name-evidence: string ' IS DEAD!'
# func 0C8C..0C99  len 000E B  evidence: seed+reko
# strings: " IS DEAD!"
# calls: L_0051df (str_out)
# provenance: static
#           entry never appears in ExecutedInstructions of any of the 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
character_dead_msg:
L_000e8c:
        call L_0051df
        db " IS DEAD!",0x8d,0x00        # string
