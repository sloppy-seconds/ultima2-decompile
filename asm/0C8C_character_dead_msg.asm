# character_dead_msg — announces a character death
# part of: the death tail, asm/0C62..0C99 — see asm/0C62_death.asm. This is its
#   last fragment; the name arrives already printed by asm/0C89, which is why the
#   string carries its own leading space and no name of its own.
# name-evidence: string ' IS DEAD!'
# func 0C8C..0C99  len 000E B  evidence: seed+reko
# strings: " IS DEAD!"
# calls: L_0051df (str_out)
# provenance: static for the bytes; the announcement has been SEEN on screen but has
#           never been traced. Two independent frames now: captures/spice86/cp5-weak-
#           fight/death1.png ('G23MAX IS DEAD!', the path named in asm/0C62_death) and
#           captures/spice86/g39-rocket-flight/frames/023.png ('REDTHEPIRATE IS DEAD!' after
#           a rocket landed on water, H.P./FOOD/EXP/GOLD all 0000). A third rocket death on
#           forest at 15:44 on 2026-11-03 was read from live DS (DS:51..59 zeroed) but its
#           frame postdates the harvested trace, so it is not traced either.
#           The 'entry never appears in ExecutedInstructions' line that used to sit here is
#           still true and is NOT excused by the fall-through: a trace records every
#           executed offset regardless of how control arrived, so if any harvest had run
#           the death tail this entry would have shown. None has. Proof here is two screens
#           and a memory readback, which is the right grade for visible behaviour but is
#           not a trace.
# confidence: high (bytes plus two screens from two different death paths)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
character_dead_msg:
L_000e8c:
        call L_0051df
        db " IS DEAD!",0x8d,0x00        # string
