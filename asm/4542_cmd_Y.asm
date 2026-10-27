# cmd_Y — command handler 'Y': prints "YELL WHAT?" + one high-bit glyph (0x8d)
# func 4542..4550  len 015 B  evidence: seed+reko (jump table cs:0730 entry Y)
# provenance: live:cmd-letters-20261025; static
#           entry executed in 3 of 167 harvests; confirmed by the capture of 2026-10-25, which
#           also showed what the four-line body cannot say: after `YELL WHAT?` the command loop
#           does NOT return to the prompt -- later letters accumulated as text on the CMD line
#           and never dispatched. Was recorded as never executed against a 60-harvest corpus.
#           NOTE the fall-through into asm/4551 is still unresolved; executed is not understood.
# confidence: medium (0x8d assumed part of the message: NUL lands exactly on
#               the range end and str_out needs the terminator)
cmd_Y:
        call L_0051df          # str_out — prints the inline string below
        db "YELL WHAT?",0x8d,0 # string (0x8d = high-bit glyph, non-printable)
