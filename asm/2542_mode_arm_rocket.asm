# sub_2542 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2542..2544  len 0003 B  evidence: seed+reko
# calls: L_0027fb
# provenance: static (bytes re-read from original/ultimaii.exe 2026-10-29) + asm/253B's
#           dispatch order. NEVER OBSERVED: no harvest memory dump has [DS:13] == 0x28, so
#           this arm has never run in front of anyone; the reject verdict is read off the
#           target chain (L_0027fb -> L_0027ff), not from a trace.
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
# RENAMED 2026-10-29 from sub_2542, with the behaviour. This is the ROCKET arm of
#           asm/253B's travel-mode dispatch, and it REJECTS EVERY STEP.
#
#           asm/253B compares [DS:13] against 0x28 and falls through here on a match; the
#           single instruction is `jmp L_0027fb`, and L_0027fb is inside asm/25F8: `call
#           L_0027ff ; ret`, where L_0027ff is the reject return (`mov $0xff,%al ; ret`).
#           So a player in rocket mode cannot walk anywhere, and pays no food for trying —
#           which is the real explanation of the stepcost measurement that the rocket costs
#           0. It is not exempt from the charge; it never reaches one.
#
#           This refutes what docs/passability-findings.md F14 and the vehicle handoff both
#           said until today, that 'asm/25F8 is one jmp and accepts everything'. asm/25F8's
#           jmp IS an accept — the FOOT LADDER's default accept, three instructions before
#           the reject return this arm jumps into. Reading the file by its first instruction
#           instead of by who jumps where produced the opposite verdict. Same failure shape
#           as F6 and F10, and the reason the engine now gates both rocket cases.
#
#           Consequence for the engine: the rocket has to be LAUNCHED out of (asm/38B0), and
#           asm/44D4 (X-IT) is how the mode is dropped on the ground. Grade: bytes, and
#           never observed live — no capture has walked in rocket mode.
sub_2542:
L_002742:
        jmp L_0027fb
