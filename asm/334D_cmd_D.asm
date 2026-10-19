# cmd_D — command handler 'D' (DESCEND): prints "DESCEND", reads the key byte
#         at DS:004A; keys 4/5 pass, anything else prints "-WHAT?" and re-reads
# func 334D..3380  len 052 B  evidence: seed+reko (jump table cs:0730 entry D)
# confidence: medium (structure read; key-code meaning of 4/5 not proven)
# notes: 0x356d..0x356f are unreached filler bytes (not a jmp: displacement
#        underflows); two je sites resume at 0x3570 mid-mis-decode (Phase 2
#        mis-align class). Original bytes there: e9 c0 d6.
cmd_D:
        call L_0051df          # str_out — prints the inline string below
        db "DESCEND",0         # string
        mov    0x4a,%al        # key byte
        cmp    $0x5,%al
        je     .Lcmd_d_dir_ok
        cmp    $0x4,%al
        je     .Lcmd_d_dir_ok
.Lcmd_d_retry:
        call L_0051df          # str_out — prints the inline string below
        db "-WHAT?",0          # string (NUL at 0x356c)
        db 0xe9,0xc0,0xd6      # data: unreached filler before resume target
.Lcmd_d_dir_ok:
        mov    0x14,%al
        and    $0x20,%al
        je     .Lcmd_d_retry
        mov    0x4a,%al
        cmp    $0x4,%al
        jne    L_003581
        jmp    L_003a23
