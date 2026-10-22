# cmd_H — command handler 'H': prints "HYPER WHAT?" then returns to the
#           dispatcher. Trailing 0xe8 stop-truncs into the next fragment (3794).
# func 3782..3793  len 018 B  evidence: seed+reko (jump table cs:0730 entry H)
# provenance: static
#           entry never appears in ExecutedInstructions of any of the 60 harvests; derived by tools/provenance_from_traces.py
# confidence: high
cmd_H:
        call L_0051df          # str_out — prints the inline string below
        db "HYPER WHAT?",0     # string
        jmp L_000c33           # return to dispatcher
