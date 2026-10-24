# list_header_items — print the "ITEMS: " list label and fall through
# RENAMED 2026-10-28 from shop_header_items, owner-approved. The old name asserted a
#   caller that was never found: there is no reference to this routine anywhere in asm/.
#   Unlike the other three, no shop counterpart was ever claimed for it — shops sell
#   weapons, armour and spells, and items are only ever sold back — so this label has one
#   known consumer, the Z status screen, which reaches this address by fall-through
#   (docs/status-screen-z.md § 7, site f4a53). Named for what it does.
# name-evidence: string 'ITEMS: '; the only caller demonstrated is the Z status screen
# func 4853..485D  len 000B B  evidence: seed+reko
# strings: "ITEMS: "
# calls: L_0051df (str_out)
# provenance: live:airport (+11 other harvests), static
#           entry executed in 12 of 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
shop_header_items:
L_004a53:
        call L_0051df
        db "ITEMS: ",0x00        # string
