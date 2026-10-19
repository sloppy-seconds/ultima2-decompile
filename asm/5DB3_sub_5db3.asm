# sub_5db3 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5DB3..5DCC  len 001A B  evidence: seed+reko
# calls: L_005eb2
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5db3:
L_005fb3:
        push   %ax
L_005fb4:
        push   %bx
L_005fb5:
        push   %cx
L_005fb6:
        push   %dx
L_005fb7:
        push   %bp
L_005fb8:
        shr    $1,%bp
L_005fba:
        mov    %ax,%cs:0x5da1
L_005fbe:
        mov    %bx,%cs:0x5da3
L_005fc3:
        mov    %cx,%cs:0x5da5
L_005fc8:
        .byte 0x8b,0xd8  # forced-kept: gas re-encodes 'mov    %ax,%bx' differently
L_005fca:
        call L_005eb2
