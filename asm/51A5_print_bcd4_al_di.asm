# print_bcd4_al_di — emit four decimal digits: AL as two, then DI as two
# name-evidence: pushes AX, calls the digit printer at runtime 53B5 on AL, then
#           `mov %di,%ax` and calls it again, then pops AX and returns. asm/17B7 loads
#           AL=[DS:27] and DI=[DS:28] before calling here, and the observed output
#           '0200' / '0012' are four digits, so this is the four-digit BCD emitter.
# func 51A5..51AF  len 000B B  evidence: seed+call+reko
# calls: L_0055b5 (print_byte_bcd) x2
# provenance: static; reached live by the armour quote '0012' (captures/spice86/armour-buy)
# confidence: high -- the control flow is six instructions and the byte order it produces
#           agrees with what the game printed.
#
# MERGED 2026-10-23 from the fragments 51A5, 51A9 and 51AE under the owner's split
# ruling. Body lines unchanged and in address order; asm_body_guard.py proves it.
#
# DOUBT: it preserves AX across the two calls but nothing here says what the callers
#   expect in the flags on return. Not checked.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_51a5:
L_0053a5:
        push   %ax
L_0053a6:
        call L_0055b5
sub_51a9:
L_0053a9:
        .byte 0x8b,0xc7  # forced-kept: gas re-encodes 'mov    %di,%ax' differently
L_0053ab:
        call L_0055b5
sub_51ae:
L_0053ae:
        pop    %ax
L_0053af:
        ret
