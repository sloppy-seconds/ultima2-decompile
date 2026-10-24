# list_header_spells — print the "SPELLS: " list label and fall through
# RENAMED 2026-10-28 from shop_header_spells, owner-approved. The old name asserted a
#   caller that was never found: there is no reference to this routine anywhere in asm/,
#   and docs/commerce.md § 2 puts the actual spells shop catalogue at 19EC/1A05,
#   not here. The only caller demonstrated is the Z status screen, which reaches this
#   address by fall-through (docs/status-screen-z.md § 7, site f49fa). Named for what
#   it does rather than who calls it, so it stays true if a shop caller turns up later.
# name-evidence: string 'SPELLS: '; the only caller demonstrated is the Z status screen
# func 47FA..4805  len 000C B  evidence: seed+reko
# strings: "SPELLS: "
# calls: L_0051df (str_out)
# provenance: live:airport (+11 other harvests), static
#           entry executed in 12 of 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
shop_header_spells:
L_0049fa:
        call L_0051df
        db "SPELLS: ",0x00        # string
