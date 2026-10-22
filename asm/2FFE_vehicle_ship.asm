# vehicle_ship — SHIP vehicle message branch
# name-evidence: string ' SHIP' + crew text
# func 2FFE..3034  len 0037 B  evidence: seed+reko
# strings: " SHIP"
# calls: L_0051df (str_out)
# provenance: static
#           entry never appears in ExecutedInstructions of any of the 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
vehicle_ship:
L_0031fe:
        call L_0051df
        db " SHIP",0x8d,"THE CREW OF THIS SHIP",0x8d,"WILL NOT LET YOU BOARD!",0x00        # string
