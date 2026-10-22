# cmd_Y — command handler 'Y': prints "YELL WHAT?" + one high-bit glyph (0x8d)
# func 4542..4550  len 015 B  evidence: seed+reko (jump table cs:0730 entry Y)
# provenance: static
#           entry never appears in ExecutedInstructions of any of the 60 harvests; derived by tools/provenance_from_traces.py
# confidence: medium (0x8d assumed part of the message: NUL lands exactly on
#               the range end and str_out needs the terminator)
cmd_Y:
        call L_0051df          # str_out — prints the inline string below
        db "YELL WHAT?",0x8d,0 # string (0x8d = high-bit glyph, non-printable)
