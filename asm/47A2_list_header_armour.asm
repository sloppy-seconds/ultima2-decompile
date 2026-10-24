# list_header_armour — print the "ARMOUR: " list label and fall through
# RENAMED 2026-10-28 from shop_header_armour, owner-approved. The old name asserted a
#   caller that was never found: there is no reference to this routine anywhere in asm/,
#   and docs/commerce.md § 2 puts the actual armour shop catalogue at 1D39/1D56,
#   not here. The only caller demonstrated is the Z status screen, which reaches this
#   address by fall-through (docs/status-screen-z.md § 7, site f49a2). Named for what
#   it does rather than who calls it, so it stays true if a shop caller turns up later.
# name-evidence: string 'ARMOUR: '; the only caller demonstrated is the Z status screen
# func 47A2..47AD  len 000C B  evidence: seed+reko
# strings: "ARMOUR: "
# calls: L_0051df (str_out)
# provenance: live:airport (+11 other harvests), static
#           entry executed in 12 of 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
shop_header_armour:
L_0049a2:
        call L_0051df
        db "ARMOUR: ",0x00        # string
