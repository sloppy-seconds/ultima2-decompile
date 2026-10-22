# open_no_key_fit — OPEN rejects wrong keys
# name-evidence: string 'NO KEYS THAT FIT!'
# func 4345..435A  len 0016 B  evidence: seed+reko
# calls: L_0051df (str_out)
# provenance: static
#           entry never appears in ExecutedInstructions of any of the 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
open_no_key_fit:
L_004545:
        call L_0051df
        db 0x8d,"NO KEYS THAT FIT!",0x00        # string
