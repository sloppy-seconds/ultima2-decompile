# print_sex_male — prints 'MALE' for character display
# name-evidence: string 'MALE'
# func 5066..506D  len 0008 B  evidence: seed+reko
# strings: "MALE"
# calls: L_0051df (str_out)
# provenance: live:airport (+11 other harvests), static
#           entry executed in 12 of 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
print_sex_male:
L_005266:
        call L_0051df
        db "MALE",0x00        # string
