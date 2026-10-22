# read_decimal_digit — block until the player types one digit 0..9, echo it, return it
# name-evidence: seven inbound callers (15E1_tavern_menu, 1869_cleric_shrine,
#           19D7_magic_shop_menu, 3B92_cmd_M, 3C2E_cmd_O, 3E9F_sub_3e9f,
#           43F3_cmd_W) -- every one of them a "HOW MANY?"/"YOUR INTEREST?" style
#           prompt. The body polls a key read, rejects anything outside '0'..'9',
#           converts by subtracting 0x30, echoes the digit, and returns.
# func 2028..2051  len 002A B  evidence: seed+call+reko
# calls: L_00514d (key read), L_0055f4 (emit character)
# provenance: static; reached in the 2026-10-23 armour purchase
#           (captures/spice86/armour-buy), where the menu answer was `1`
# confidence: high that it reads and echoes one decimal digit; see DOUBT below for
#           the return convention and the 0x8D echo.
#
# MERGED 2026-10-23 from the fragments 2028, 202C, 2031, 2035, 2039, 2048 and 204D,
# per docs/g22-split-proposal.md § 2 with the owner's approval. 2028 is the only
# inbound call target in the range and 2051 is the terminating `ret` -- one of only
# three `ret`s in the whole span 19D7..2140. Body lines unchanged and in address
# order; engine/tests/asm_body_guard.py proves it.
#
# HOW IT WORKS (observed)
#   2028  call L_00514d          read a key
#   202C  cmp $0xff,%ah; jne 2028   AH==0xFF means "a key was there"; else retry
#   2031  cmp $0x30,%al; jb  2028   below '0' -> retry
#   2035  cmp $0x39,%al; ja  2028   above '9' -> retry
#   2039  stc; cmc; sbb $0x30,%al; cmc   AL = digit value (carry cleared the long way)
#         mov $0,%ah ; mov %ax,%di       DI = digit
#         clc ; adc $0x30,%al            put the ASCII form back
#         call L_0055f4                  echo the digit
#   2048  mov $0x8d,%al ; call L_0055f4  echo 0x8D
#   204D  mov %di,%ax ; cmp $0,%al ; ret return with AL = digit, ZF set if it was 0
#
# DOUBT -- read this before citing the routine
#   * The retry loop rejects non-digits by jumping back to 2028, which re-reads the
#     key. Whether a rejected key is CONSUMED or left in the typeahead ring is not
#     established here, and it matters: if it is left, a stray key would be re-read
#     by whatever runs next. Not tested.
#   * The 0x8D echo at 2048 is unexplained. 0x8D is a message control byte
#     elsewhere in this binary (docs/needs-gameplay.md G0 notes messages carry
#     0x0D/0x8D on both ends), and emitting it as a character right after the digit
#     looks like a cursor or attribute effect rather than text. It might also be
#     what produces the trailing marker seen in captured prints. Inferred, not known.
#   * Two instructions here are `forced-kept` byte sequences (2040, 204D): the
#     vendored assembler re-encodes `mov %ax,%di` and `mov %di,%ax` to different
#     bytes, so the listing stores the original machine words and the mnemonics are
#     our reading of them. check_func.py proves the BYTES round-trip. It does not
#     prove the mnemonics are the intended disassembly -- though for a two-byte mov
#     between registers there is little room for it to be wrong.
#   * `stc; cmc` (and the matching `cmc` after the sbb) is a carry-clear written the
#     long way round, the same idiom asm/2052 uses. It is harmless and it is what the
#     bytes say; do not "simplify" it to clc, because the trailing cmc also leaves CF
#     in a specific state for the caller and that has not been checked.
#   * The return convention (AL = digit, DI = digit, ZF from cmp $0) is read from the
#     last three instructions. No caller was stepped through to confirm which of the
#     three it actually uses.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2028:
L_002228:
        nop
L_002229:
        call L_00514d
sub_202c:
L_00222c:
        cmp    $0xff,%ah
L_00222f:
        jne L_002228
sub_2031:
L_002231:
        cmp    $0x30,%al
L_002233:
        jb L_002228
sub_2035:
L_002235:
        cmp    $0x39,%al
L_002237:
        ja L_002228
sub_2039:
L_002239:
        stc
L_00223a:
        cmc
L_00223b:
        sbb    $0x30,%al
L_00223d:
        cmc
L_00223e:
        mov    $0x0,%ah
L_002240:
        .byte 0x8b,0xf8  # forced-kept: gas re-encodes 'mov    %ax,%di' differently
L_002242:
        clc
L_002243:
        adc    $0x30,%al
L_002245:
        call L_0055f4
sub_2048:
L_002248:
        mov    $0x8d,%al
L_00224a:
        call L_0055f4
sub_204d:
L_00224d:
        .byte 0x8b,0xc7  # forced-kept: gas re-encodes 'mov    %di,%ax' differently
L_00224f:
        cmp    $0x0,%al
L_002251:
        ret
