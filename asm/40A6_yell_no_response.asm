# yell_no_response — YELL at nothing useful
# NAME DISPUTED: this printer is NOT specific to YELL. Three separate guards in the
#           same neighbourhood all branch here: asm/406E tests [DS:4A] (site kind)
#           against zero, asm/4081 tests a byte against 0x7C, and asm/409F tests a
#           byte against 0x68 -- which is the Merchant type in the street-NPC table
#           (docs/bestiary.md, tools/shop_access.py). Observed on 2026-10-23 printing
#           after `CMD: TRANSACT-NORTH`, i.e. reached from the TRANSACT command, not
#           YELL. Reading: it is the shared "the ray did not land on something that
#           will deal with you" message for the directional commands, and the
#           0x68 guard is the one that decides whether a creature transacts.
#           Which guard belongs to which command is INFERRED from adjacency, not
#           proven; the printer itself is proven shared by observation.
#           Proposed rename: `no_response_ray` or `transact_no_response`.
# name-evidence: string 'FUNNY, NO RESPONSE!' in cmd_Y chain
# func 40A6..40BC  len 0017 B  evidence: seed+reko
# strings: "FUNNY, NO RESPONSE!"
# calls: L_0051df (str_out)
# provenance: live:airport (+1 other harvests), static
#           entry executed in 2 of 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
yell_no_response:
L_0042a6:
        call L_0051df
        db "FUNNY, NO RESPONSE!",0x00        # string
