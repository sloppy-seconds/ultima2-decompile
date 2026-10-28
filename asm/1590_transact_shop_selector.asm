# func 1590..1597  len 0008 B  evidence: seed+reko
# transact_shop_selector — the vendor dispatcher cmd_T jumps to: quadrant, then site kind
# name-evidence: read directly, 2026-10-29. This file holds only the first eight bytes of a
#           routine the bulk wave cut into nine tiling fragments; laid end to end in address
#           order (1590, 1598, 159F, 15A2, 15A9, 15AC, 15B4, 15B7, 15BA, 15C8, 15D0, 15D3,
#           15D6, 15DE) they are one two-level switch, and every branch target in it is a
#           shop. The shape, straight off the bytes:
#
#             1590  al = [DS:00] ; cmp 0x20 ; jb 15A2      -- the player's X
#             1598  al = [DS:01] ; cmp 0x20 ; jb 15AC      -- the player's Y
#             159F  jmp 15C8
#             15A2  al = [DS:01] ; cmp 0x20 ; jb 15BA
#             15A9  jmp 15D6
#             15AC  al = [DS:4A] ; cmp 2 ; je 1D1D ; else 1799
#             15BA  al = [DS:4A] ; cmp 2 ; je 1E4F ; else 1AE0
#             15C8  al = [DS:4A] ; cmp 2 ; je 1F75 ; else 1841
#             15D6  al = [DS:4A] ; cmp 2 ; je 15E4 ; else 19AF
#
#           So the shop is chosen by which QUADRANT OF THE SECTOR the player is standing in,
#           and then by whether the site kind is 2 (a town) or not. Eight destinations:
#
#             x>=0x20 y<0x20   town: asm/1D1D armour      else: asm/1799 grocery
#             x< 0x20 y<0x20   town: asm/1E4F weapons    else: asm/1AE0 clue seller
#             x>=0x20 y>=0x20  town: asm/1F75 transport  else: asm/1841 cleric shrine
#             x< 0x20 y>=0x20  town: asm/15E4 pub        else: asm/19AF wizard shoppe
#
#           Three live purchases land on cells of this table, and none of them was seeded
#           knowing it: sector 32 (38,5) -> armour (captures/spice86/armour-buy), sector 22
#           (48,53) -> transport (captures/spice86/shop-window-transport), sector 31 (55,21)
#           -> grocery (captures/spice86/g23-food-live, this dispatcher stopped at asm/17B7).
#           The shipped data corroborates the rest: run over the fifty sign/NPC pairings in
#           tools/shop_access.py, the sign text names the predicted shop wherever the sign
#           names a shop at all — WEAPONS, ARMOURY, TRANSPORT, PUB, CLERGY, ORACLE, SEER,
#           WIZARDRY, DELI, COOK, across six sectors of both kinds.
# name-correction: it was `sub_1590 — behavior not yet reviewed`, and docs/commerce.md § 5
#           carried "the menu-versus-line fork is undecoded" on the strength of that. The fork
#           is not here at all: menu-versus-line is decided upstream at asm/4075, by whether
#           the creature scan at asm/23E6 found a slot. What this file decides is which shop.
# name-correction: an earlier note in asm/15E1 read this dispatcher as requiring
#           "X >= 0x20 AND Y >= 0x20" for the pub. Both tests are `jb` to DIFFERENT targets
#           (15A2 and 15AC), not to one; the pub is the x<0x20, y>=0x20 cell.
# provenance: live:armour-buy, food-buy, g23-armour, g23-tavern, g23-tavern2, play-vnc2,
#           play-vnc2-live; static
#           entry executed in 7 of the harvests that carry a flow dump; derived from
#           ExecutedInstructions. The quadrant test itself is now read, not inferred.
# confidence: high (bytes proven by check_func.py; the whole span read in address order; two
#           live purchases and the shipped sign table agree with the resulting map)
sub_1590:
L_001790:
        nop
L_001791:
        mov    0x0,%al
L_001794:
        cmp    $0x20,%al
L_001796:
        jb L_0017a2
