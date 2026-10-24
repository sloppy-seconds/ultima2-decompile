# list_header_weapons — print the "WEAPONS: " list label and fall through
# RENAMED 2026-10-28 from shop_header_weapons, owner-approved. The old name asserted a
#   caller that was never found: there is no reference to this routine anywhere in asm/,
#   and docs/commerce.md § 2 puts the actual weapons shop catalogue at runtime 1E69/1E81,
#   not here. The only caller demonstrated is the Z status screen, which reaches this
#   address by fall-through (docs/status-screen-z.md § 7, site f4948). Named for what it
#   does rather than who calls it, so it stays true if a shop caller turns up later.
# name-evidence: string 'WEAPONS: '; the only caller demonstrated is the Z status screen
# func 4748..4754  len 000D B  evidence: seed+reko
# strings: "WEAPONS: "
# calls: L_0051df (str_out)
# provenance: live:airport (+11 other harvests), static
#           entry executed in 12 of 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
shop_header_weapons:
L_004948:
        call L_0051df
        db "WEAPONS: ",0x00        # string
