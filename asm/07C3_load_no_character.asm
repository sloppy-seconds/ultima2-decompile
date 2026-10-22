# load_no_character — reports no saved character on disk
# name-evidence: string 'NO CHARACTER ON DISK'
# func 07C3..07DA  len 0018 B  evidence: seed+reko
# strings: "NO CHARACTER ON DISK"
# calls: L_0051df (str_out)
# provenance: live:edge-test (+1 other harvests), static
#           entry executed in 2 of 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
load_no_character:
L_0009c3:
        call L_0051df
        db "NO CHARACTER ON DISK",0x00        # string
