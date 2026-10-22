# cmd_T — TRANSACT: aim a ray one cell from the player and see whether it will deal
# name-evidence: prints 'TRANSACT-' then the direction; calls the cursor initialiser at
#           runtime 23E6; rejects via the shared printer asm/40A6 ('FUNNY, NO RESPONSE!');
#           on success tail-jumps to runtime 1590, the vendor dispatcher. Corroboration:
#           1590/1591/1594/1596 all appear in ExecutedInstructions of
#           captures/spice86/food-buy, and the shop opened live on 2026-10-23
#           (captures/spice86/armour-buy).
# func 4050..40A5  len 0056 B  evidence: seed+call+reko
# strings: "TRANSACT-"
# calls: L_0051df (str_out), L_0025e6 (cursor init + slot scan seed), L_0055f4 (emit),
#        L_0052b3 (map_tile_ptr) x2
# provenance: live:armour-buy, food-buy; static
# confidence: high for the control flow (linear disassembly of the whole span agrees with
#           the per-fragment bytes); see DOUBT for what the two paths actually match on.
#
# MERGED 2026-10-23 from 13 fragments (4050, 405D, 405E, 4060, 4063, 406E, 4075, 407C,
# 407F, 4081, 4085, 409F, 40A3) under the owner's split ruling, on the evidence of
# tools/fragment_splits.py plus a linear disassembly of the whole span. Body lines are
# unchanged and in address order; engine/tests/asm_body_guard.py proves it.
#
# HOW IT WORKS (observed)
#   4050  str_out "TRANSACT-"
#   4060  call 23E6        -- the seed. asm/23E6 does:
#                              DS:23 = DS:00 + DS:19      cursor = player_x + delta_x
#                              DS:24 = DS:01 + DS:1A      cursor = player_y + delta_y
#                              DI = 31                    top creature slot
#                            so DS:19/1A IS the direction delta, the cursor is one delta
#                            step from the player, and DI starts a downward scan of the
#                            32 creature slots.
#   4063  [DS:20] = BL ; emit 0x8D
#   406E  reject if site kind [DS:4A] == 0
#   4075  if BL != 0 -> 40C0   CREATURE path: checks [DI+0x1D7] (flag array) and
#                              [DI+0x197] (type array, compared against 0x6C)
#         if BL == 0 -> fall through  MAP-TILE path, i.e. the scan exhausted its slots
#   407C  map_tile_ptr(cursor) ; js 4085 skips the next test when the tile has its high
#         bit set
#   4081  reject unless the cell == 0x7C
#   4085  cursor += delta ; map_tile_ptr(cursor) again
#   409F  reject unless that cell == 0x68
#   40A3  jmp 1590        SUCCESS -- the vendor dispatcher
#
# DOUBT -- read this before citing it
#   * The two paths match on DIFFERENT namespaces and that is the trap here. 0x68 and
#     0x7C are **map grid cell values**; 0x6C is a **creature type byte** read from
#     [DI+0x197]. An earlier pass on 2026-10-23 wrote "0x68 is the Merchant type" and was
#     wrong -- it conflated the two. What is measured about 0x68 is a strong coincidence
#     and still not an identity: in mapx31 the byte 0x68 occurs at exactly the seven
#     monx31 Merchant spawn cells (7/7), which says the map marks where a transactor
#     stands, not that 0x68 means Merchant in general. Do not generalise it to other
#     sectors without checking.
#   * Which path a live talk takes is NOT established. The creature path is entered when
#     BL != 0 and BL is the low byte of DI, which asm/23E6 sets to 31 -- so on the face of
#     it the creature path is always taken and the map-tile path is dead code. It plainly
#     is not dead, because the armour shop opened. So something between 23E6 and 4075
#     changes DI (a scan loop that decrements it, almost certainly in the 2402..241E
#     fragments), and **that loop has not been read**. Until it is, the sentence above
#     beginning "if BL != 0" describes the branches, not the runtime behaviour.
#   * The delta DS:19/1A read (1,1) in every live sample taken so far -- after T,Up,
#     T,Down, T,Left, T,Right AND after five movement keys that demonstrably moved the
#     player. So whatever writes the delta from a direction is none of what has been
#     sampled, and the ray was aiming diagonally down-right in every one of those tests.
#     Candidate writers not yet examined: asm/0B0F, asm/1086, asm/10AA, asm/10BF,
#     asm/152E. This is the open item, and it is static.
#   * Four exits, all tail jumps (1590, 0A33, 4209, 4249) and no `ret`. That is normal for
#     this game's command handlers -- see the same finding for 19D7's handlers in
#     docs/g22-split-proposal.md -- but it means the routine never returns to its caller,
#     so anything that expected a return value is not getting one.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
cmd_T:
        call L_0051df          # str_out — prints the inline string below
        db "TRANSACT-",0       # string
sub_405d:
L_00425d:
        .byte 0xe8  # forced-kept: stop-trunc call   0x2562
sub_405e:
L_00425e:
        .byte 0x02,0xe3  # forced-kept: gas re-encodes 'add    %bl,%ah' differently
sub_4060:
L_004260:
        call L_0025e6
sub_4063:
L_004263:
        .byte 0x8b,0xdf  # forced-kept: gas re-encodes 'mov    %di,%bx' differently
L_004265:
        mov    %bl,0x20
L_004269:
        mov    $0x8d,%al
L_00426b:
        call L_0055f4
sub_406e:
L_00426e:
        mov    0x4a,%al
L_004271:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_004273:
        je L_0042a6
sub_4075:
L_004275:
        .byte 0x8b,0xdf  # forced-kept: gas re-encodes 'mov    %di,%bx' differently
L_004277:
        cmp    $0x0,%bl
L_00427a:
        jne L_0042c0
sub_407c:
L_00427c:
        call L_0052b3
sub_407f:
L_00427f:
        js L_004285
sub_4081:
L_004281:
        cmp    $0x7c,%al
L_004283:
        jne L_0042a6
sub_4085:
L_004285:
        nop
L_004286:
        clc
L_004287:
        mov    0x23,%al
L_00428a:
        adc    0x19,%al
L_00428e:
        mov    %al,0x23
L_004291:
        clc
L_004292:
        mov    0x24,%al
L_004295:
        adc    0x1a,%al
L_004299:
        mov    %al,0x24
L_00429c:
        call L_0052b3
sub_409f:
L_00429f:
        cmp    $0x68,%al
L_0042a1:
        jne L_0042a6
sub_40a3:
L_0042a3:
        jmp L_001790
