# print_sex_female — prints 'FEMALE' for character display
# name-evidence: string 'FEMALE'
# func 506F..5079  len 000B B  evidence: seed+reko
# strings: "FEMALE"
# calls: L_0051df (str_out)
# provenance: static
#           entry never appears in ExecutedInstructions of any of the 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
print_sex_female:
L_00526f:
        call L_0051df
        db "FEMALE",0x00        # string
L_005279:
        .byte 0xc3  # forced-kept: gas re-encodes 'ret' differently
