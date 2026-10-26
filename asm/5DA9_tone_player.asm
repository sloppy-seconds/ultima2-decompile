# tone_player — the shared PC-speaker tone routine, gated on the sound flag
# name-evidence: opens with `cmp byte [DS:54D],0 ; je skip` -- a sound-enabled flag -- then saves
#           AX/BX/CX/DX/BP into its own code bytes, does `shr bp,1`, and calls asm/5CB2 and
#           asm/5CD2 (speaker_freq, which latches BX to PIT channel 2 via out 0x42). DX is a
#           repeat count and CX is derived from BP.
# callers: seven, at runtime 0x5E4E, 0x5EBF, 0x5EEA, 0x5F05, 0x5FBA, 0x5FD7 and 0x5FF4 -- so this
#           is the general tone player, not a wound-specific one. The wound loop reaches it through
#           the fixed-parameter wrappers asm/5EAC (AX=0x300, about 1.5 kHz) and asm/5EF2
#           (AX=0x800, about 580 Hz).
# provenance: static
# confidence: medium. The gate, the register saves and the call into the proven speaker_freq seam
#             are all read directly; the exact frequency arithmetic (which of AX/BX becomes the
#             divisor, and what CX does) is inferred and has not been confirmed against a tone
#             heard in a capture.
# note: the declared range 5DA9..5DAF is a fragment boundary; the routine runs to about 0x5E3A.
# func 5DA9..5DAF  len 0007 B  evidence: seed+call+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5da9:
L_005fa9:
        cmpb   $0x0,0x54d
L_005fae:
        je L_005fb3
