# print_byte_bcd — emit AL as two decimal digits, high nibble first
# name-evidence: `mov %al,%ah` then four `shr $1,%al` (a shift-right-by-4), `or $0x30`
#           and emit -- the high nibble as an ASCII digit; then `mov %ah,%al`,
#           `and $0xf`, `or $0x30`, emit -- the low nibble. AX is saved and restored
#           around it, so the caller's AL survives.
# func 53B5..53CF  len 001B B  evidence: seed+call+reko
# calls: L_005203 (emit character) x2
# provenance: static; reached live by the armour quote '0012' (captures/spice86/armour-buy)
# confidence: high -- two nibbles, each masked to ASCII, emitted in that order. This is
#           what settled the DS:27/DS:28 byte-order question in docs/commerce.md § 3:
#           the first byte emitted is the one whose digits appear first.
#
# MERGED 2026-10-23 from the fragments 53B5, 53C5 and 53CE under the owner's split
# ruling. Body lines unchanged and in address order; asm_body_guard.py proves it.
#
# DOUBT: the four `shr $1` is a shift-by-4 written out longhand, which is ordinary for
#   1983 hand-coded x86, but note it shifts through the carry each time and leaves CF in
#   an unspecified state for the caller. Nothing checked has depended on that; do not
#   assume it is clean.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_53b5:
L_0055b5:
        push   %ax
L_0055b6:
        .byte 0x8a,0xe0  # forced-kept: gas re-encodes 'mov    %al,%ah' differently
L_0055b8:
        shr    $1,%al
L_0055ba:
        shr    $1,%al
L_0055bc:
        shr    $1,%al
L_0055be:
        shr    $1,%al
L_0055c0:
        or     $0x30,%al
L_0055c2:
        call L_005203
sub_53c5:
L_0055c5:
        .byte 0x8a,0xc4  # forced-kept: gas re-encodes 'mov    %ah,%al' differently
L_0055c7:
        and    $0xf,%al
L_0055c9:
        or     $0x30,%al
L_0055cb:
        call L_005203
sub_53ce:
L_0055ce:
        pop    %ax
L_0055cf:
        ret
