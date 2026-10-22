# not_a_wizard_msg — rejects wizard-only action
# name-evidence: string ' YOU ARE NOT A WIZARD!'
# func 19BA..19D3  len 001A B  evidence: seed+reko
# strings: " YOU ARE NOT A WIZARD!"
# calls: L_0051df (str_out)
# provenance: static
#           entry never appears in ExecutedInstructions of any of the 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
not_a_wizard_msg:
L_001bba:
        call L_0051df
        db " YOU ARE NOT A WIZARD!",0x00        # string
