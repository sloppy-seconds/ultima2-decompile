# offer_only_outdoors_earth — OFFER location guards (outdoors/on earth)
# name-evidence: strings 'ONLY OUTDOORS!' / 'ONLY ON EARTH!'
# func 3DFA..3E4F  len 0056 B  evidence: seed+reko
# calls: L_000c30, L_000c33, L_0024fd, L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
offer_only_outdoors_earth:
L_003ffa:
        mov    0x6d,%al
L_003ffd:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_003fff:
        je L_004017
L_004001:
        call L_0051df
        db 0x8d,"ONLY ON EARTH!",0x00        # string
L_004014:
        jmp L_000c30
L_004017:
        mov    0x13,%al
L_00401a:
        cmp    $0x78,%al
L_00401c:
        jae L_004033
L_00401e:
        call L_0051df
        db 0x8d,"ONLY ON FOOT!",0x00        # string
L_004030:
        jmp L_000c30
L_004033:
        call L_0051df
        db 0x8d,"ONE MOMENT PLEASE!",0x00        # string
L_00404a:
        call L_0024fd
L_00404d:
        jmp L_000c33
