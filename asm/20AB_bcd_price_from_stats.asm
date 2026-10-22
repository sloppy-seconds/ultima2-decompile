# bcd_price_from_stats — derives a BCD amount into DS:27/28 from int + charisma
# name-evidence: seeds the price pair DS:27/28 AND a second pair DS:29/2A to 0004,
#           derives a loop count from the bit length of [DS:50]+[DS:4E] (int + cha),
#           then runs a swap-and-add BCD sequence DI times, leaving the result in
#           DS:27/28 -- the same operand pair asm/51A5 prints and asm/2052 charges.
#           Three inbound callers: 17B2 (the tavern food quote), 1869_cleric_shrine,
#           19D7_magic_shop_menu. All three are places a price is quoted.
# func 20AB..2121  len 0077 B  evidence: seed+call+reko
# provenance: static, 2026-10-23. NOT validated against a live price -- see DOUBT.
# confidence: high on the instruction-level mechanics (bytes + a step-by-step
#           simulation); LOW on whether this is what produced the observed 0200.
#
# MERGED 2026-10-23 from the fragments 20AB, 20CF, 20D7, 20EB and 2121, per
# docs/g22-split-proposal.md § 2 with the owner's approval. 20AB is the only inbound
# call target in the range and 2121 is the terminating `ret`. Body lines unchanged and
# in address order; engine/tests/asm_body_guard.py proves it.
#
# HOW IT WORKS (observed, and simulated step by step)
#   20AB  clc; adc $0x8,%al ; mov %al,[DS:20]     DS:20 = caller_AL + 8 + CF
#         [DS:27],[DS:29] = 0 ; [DS:28],[DS:2A] = 4      two BCD pairs, both 0004
#         mov al,[DS:50] ; adc al,[DS:4E]         AL = int + cha + CF
#   20CF  inc %si ; clc ; rcr $1,%al ; or %al,%al ; jne
#         SI = number of right shifts to reach zero = the BIT LENGTH of int+cha
#   20D7  mov al,[DS:20]     (reads the OLD DS:20, before the next line overwrites it)
#         mov %bl,[DS:20]    DS:20 = bit length
#         stc; cmc; sbb [DS:20],%al; cmc          AL = (caller_AL+8+CF) - bitlength
#         mov $0,%ah ; mov %ax,%di                DI = loop count
#   20EB  loop, DI times:
#           al = [DS:2A] + [DS:28], das
#           [DS:2A] = old [DS:28] ; [DS:28] = al
#           al = [DS:29] + [DS:27] + CF, das
#           [DS:29] = old [DS:27] ; [DS:27] = al
#         dec %di ; jne
#   2121  ret
#
#   The loop is NOT multiply-by-repeated-addition, which is what a first reading
#   called it. Each pair takes the other pair's old value while the first receives
#   the sum, so the two pairs walk a Fibonacci sequence seeded 4,4:
#       DS:27/28 after DI iterations = 4, 8, 12, 20, 32, 52, 84, 136, 220, 356, 576, 932 ...
#   Simulated for the tavern call (caller_AL=3) on a maxed character (int=cha=0x40,
#   BCD 0x40+0x40=0x80, bit length 8): DI = 11-8 = 3 -> DS:27/28 = 0020.
#   A character with int=cha=0 gets DI = 10 -> 0576. **Higher int+cha means a LOWER
#   number.** The owner confirms on 2026-10-23 that charisma affecting costs is known
#   game behaviour, which is the strongest support this reading has; it is corroboration
#   of direction, not proof of the arithmetic.
#
# DOUBT -- read this before citing the routine, and note two retractions inside it
#   * RETRACTED (same day, twice): this routine was first described as deriving its
#     count from `popcount(int + cha)` and as a "multiply by repeated addition".
#     Both were wrong. The shift loop counts shifts, not set bits, and the loop is a
#     Fibonacci walk, not a multiply. The first simulation of it also had DAA
#     subtracting 6 instead of adding, which produced plausible nonsense (01A6 where
#     the answer is 0012) -- a good illustration of why a model must be checked
#     against a hand-computed case before it is quoted.
#   * THE MODEL DOES NOT REPRODUCE THE OBSERVED PRICE. The vendor/tavern quote seen
#     live printed 0200 (docs/commerce.md § 3). This routine, called from asm/17B2
#     with AL=3 on a maxed character, yields 0020 -- the same digits, transposed
#     across the two bytes. Either the byte order of the (DS:27, DS:28) pair is the
#     other way round from what asm/2052's pairing implies, or the live quote did not
#     come through this path, or caller_AL was not 3. **None of these is settled and
#     the discrepancy is left open deliberately.** Do not describe this routine as
#     "the price formula" until it reproduces a number the game actually printed.
#   * Which of DS:27 / DS:28 is the high byte is inferred from asm/2052 subtracting
#     DS:28 from DS:59 and DS:27 from DS:58. It is consistent everywhere checked, but
#     the transposition above is exactly the symptom that inference would produce if
#     it were backwards.
#   * If DI computes to 0 the loop's `dec %di ; jne` wraps to 0xFFFF and runs 65536
#     times. Reachable in principle (caller_AL+8+CF == bitlength) and never observed.
#     Untested; do not assume the original guarded it.
#   * int and cha are read as raw BCD bytes and added with `adc`, not with `daa`, so
#     the sum is a binary add of two packed-decimal bytes. For 0x40+0x40 that is 0x80,
#     which happens to be a valid BCD byte; for 0x99+0x99 it is 0x32 with carry, which
#     is not. Whether that is a deliberate quirk or a sloppy add is unknown, and it
#     changes the curve for high stats.
#   * Six instructions in here are `forced-kept` byte sequences -- the vendored
#     assembler re-encodes those movs differently, so the listing stores the original
#     machine words and the mnemonics are our reading. check_func.py proves the bytes
#     round-trip, not the disassembly.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_20ab:
L_0022ab:
        nop
L_0022ac:
        clc
L_0022ad:
        adc    $0x8,%al
L_0022af:
        mov    %al,0x20
L_0022b2:
        mov    $0x0,%al
L_0022b4:
        mov    %al,0x27
L_0022b7:
        mov    %al,0x29
L_0022ba:
        mov    $0x4,%al
L_0022bc:
        mov    %al,0x28
L_0022bf:
        mov    %al,0x2a
L_0022c2:
        mov    0x50,%al
L_0022c5:
        adc    0x4e,%al
L_0022c9:
        mov    $0x0,%bh
L_0022cb:
        mov    $0x0,%bl
L_0022cd:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
sub_20cf:
L_0022cf:
        inc    %si
L_0022d0:
        clc
L_0022d1:
        rcr    $1,%al
L_0022d3:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_0022d5:
        jne L_0022cf
sub_20d7:
L_0022d7:
        mov    0x20,%al
L_0022da:
        .byte 0x8b,0xde  # forced-kept: gas re-encodes 'mov    %si,%bx' differently
L_0022dc:
        mov    %bl,0x20
L_0022e0:
        stc
L_0022e1:
        cmc
L_0022e2:
        sbb    0x20,%al
L_0022e6:
        cmc
L_0022e7:
        mov    $0x0,%ah
L_0022e9:
        .byte 0x8b,0xf8  # forced-kept: gas re-encodes 'mov    %ax,%di' differently
sub_20eb:
L_0022eb:
        clc
L_0022ec:
        mov    0x2a,%al
L_0022ef:
        adc    0x28,%al
L_0022f3:
        daa
L_0022f4:
        mov    $0x0,%bh
L_0022f6:
        mov    0x28,%bl
L_0022fa:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_0022fc:
        .byte 0x8b,0xde  # forced-kept: gas re-encodes 'mov    %si,%bx' differently
L_0022fe:
        mov    %bl,0x2a
L_002302:
        mov    %al,0x28
L_002305:
        mov    0x29,%al
L_002308:
        adc    0x27,%al
L_00230c:
        daa
L_00230d:
        mov    $0x0,%bh
L_00230f:
        mov    0x27,%bl
L_002313:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_002315:
        .byte 0x8b,0xde  # forced-kept: gas re-encodes 'mov    %si,%bx' differently
L_002317:
        mov    %bl,0x29
L_00231b:
        mov    %al,0x27
L_00231e:
        dec    %di
L_00231f:
        jne L_0022eb
sub_2121:
L_002321:
        ret
