# tavern_menu — tavern buy/drink menu
# name-evidence: strings 'WELCOME TO THE PUB!' / 'HERE, HAVE A STRONG ONE!'
# func 15E1..16BC  len 00DC B  evidence: seed+reko; re-cut 2026-10-25
# strings: "WELCOME TO THE PUB!"; "HERE, HAVE A STRONG ONE!"; "TIP HOW MUCH? "; "THE BARKEEP SAYS:"
# note: the chatter/hint table this used to contain is now asm/16BD_barkeep_chatter_hints.asm
# note: TWO ENTRIES, and only the second one is the pub. The declared start 15E1 is a 3-byte
#           `jmp 0x19AF` trampoline; the pub menu itself begins at 15E4 with a NOP and the
#           "WELCOME TO THE PUB!,\r1-BUY, 2-TIP --- " string. asm/15D6 chooses between them on
#           the site kind: DS:4A == 2 (a town) falls through to 15E4 and gets the pub, anything
#           else takes the trampoline. So the name is right for the body and wrong for the entry
#           point -- a caller that lands on 15E1 never sees a pub at all.
# note: the whole door to this routine, measured live 2026-10-26 in sector 82. cmd_T must aim at
#           a cell holding 0x68 (asm/409F); the vendor dispatcher at asm/1590 then requires the
#           PLAYER at X >= 0x20 AND Y >= 0x20 -- both tests are `jb 15ba`, so a low X or a low Y
#           diverts to the other catalogue, which is the weapons shoppe and was seen on screen
#           from (11,52) -- and only then does asm/15D6's site-kind test pick pub or trampoline.
#           The pub itself was NOT reached: at both qualifying markers tried, (11,52) and (51,49),
#           the aim answered `FUNNY.. NO RESPONSE?`, which is the ray failing to find a
#           transacting NPC, not a wrong branch. That is what is still open.
# calls: L_000c33, L_00175d, L_001886, L_001baf, L_002228, L_002252, L_0051df (str_out), L_0052d8 (+1 more)
# provenance: static
#           entry never appears in ExecutedInstructions of any of the 142 harvests that carry a
#           flow dump (the earlier "60 harvests" line predates the corpus growth). The vendor
#           dispatcher upstream of it HAS been observed -- 1590/1591/1594/1596 appear in
#           ExecutedInstructions per asm/4050_cmd_T's header -- so the door is live and this
#           threshold is the part still unseen.
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
tavern_menu:
L_0017e1:
        jmp L_001baf
L_0017e4:
        .byte 0x90  # forced-kept: gas re-encodes 'nop' differently
L_0017e5:
        call L_0051df
        db "WELCOME TO THE PUB!",0x0d,"1-BUY, 2-TIP --- ",0x00        # string
L_00180e:
        call L_002228
L_001811:
        .byte 0x3c,0x01  # forced-kept: gas re-encodes 'cmp    $0x1,%al' differently
L_001813:
        je L_00181c
L_001815:
        .byte 0x3c,0x02  # forced-kept: gas re-encodes 'cmp    $0x2,%al' differently
L_001817:
        je L_001851
L_001819:
        jmp L_000c33
L_00181c:
        .byte 0x90  # forced-kept: gas re-encodes 'nop' differently
L_00181d:
        .byte 0xb0,0x05  # forced-kept: gas re-encodes 'mov    $0x5,%al' differently
L_00181f:
        .byte 0xa2,0x28,0x00  # forced-kept: gas re-encodes 'mov    %al,0x28' differently
L_001822:
        .byte 0xb0,0x00  # forced-kept: gas re-encodes 'mov    $0x0,%al' differently
L_001824:
        .byte 0xa2,0x27,0x00  # forced-kept: gas re-encodes 'mov    %al,0x27' differently
L_001827:
        call L_002252
L_00182a:
        call L_0051df
        db "HERE, HAVE A STRONG ONE!",0x0d,0x00        # string
L_001847:
        call L_005417
L_00184a:
        .byte 0x24,0x03  # forced-kept: gas re-encodes 'and    $0x3,%al' differently
L_00184c:
        .byte 0xb0,0x01  # forced-kept: gas re-encodes 'mov    $0x1,%al' differently
L_00184e:
        jmp L_001886
L_001850:
        .byte 0x90  # forced-kept: gas re-encodes 'nop' differently
L_001851:
        .byte 0x90  # forced-kept: gas re-encodes 'nop' differently
L_001852:
        call L_0051df
        db "TIP HOW MUCH? ",0x00        # string
L_001864:
        call L_002228
L_001867:
        .byte 0xa2,0x25,0x00  # forced-kept: gas re-encodes 'mov    %al,0x25' differently
L_00186a:
        .byte 0xa2,0x28,0x00  # forced-kept: gas re-encodes 'mov    %al,0x28' differently
L_00186d:
        .byte 0xb0,0x00  # forced-kept: gas re-encodes 'mov    $0x0,%al' differently
L_00186f:
        .byte 0xa2,0x27,0x00  # forced-kept: gas re-encodes 'mov    %al,0x27' differently
L_001872:
        call L_002252
L_001875:
        call L_005417
L_001878:
        call L_0052d8
L_00187b:
        .byte 0xf8  # forced-kept: gas re-encodes 'clc' differently
L_00187c:
        .byte 0x12,0x06,0x25,0x00  # forced-kept: gas re-encodes 'adc    0x25,%al' differently
L_001880:
        .byte 0x3c,0x0a  # forced-kept: gas re-encodes 'cmp    $0xa,%al' differently
L_001882:
        jb L_001886
L_001884:
        .byte 0xb0,0x00  # forced-kept: gas re-encodes 'mov    $0x0,%al' differently
L_001886:
        .byte 0x90  # forced-kept: gas re-encodes 'nop' differently
L_001887:
        .byte 0xa2,0x25,0x00  # forced-kept: gas re-encodes 'mov    %al,0x25' differently
L_00188a:
        call L_0051df
        db "THE BARKEEP SAYS:",0x0d,0x00        # string
L_0018a0:
        .byte 0xa0,0x25,0x00  # forced-kept: gas re-encodes 'mov    0x25,%al' differently
L_0018a3:
        .byte 0xb4,0x00  # forced-kept: gas re-encodes 'mov    $0x0,%ah' differently
L_0018a5:
        .byte 0x8b,0xf0  # forced-kept: gas re-encodes 'mov    %ax,%si' differently
L_0018a7:
        .byte 0x46  # forced-kept: gas re-encodes 'inc    %si' differently
L_0018a8:
        .byte 0x2e,0x8d,0x06,0xbc,0x16  # forced-kept: gas re-encodes 'lea    %cs:0x16bc,%ax' differently
L_0018ad:
        .byte 0xa3,0x27,0x00  # forced-kept: gas re-encodes 'mov    %ax,0x27' differently
L_0018b0:
        .byte 0xb7,0x00  # forced-kept: gas re-encodes 'mov    $0x0,%bh' differently
L_0018b2:
        .byte 0xb3,0x00  # forced-kept: gas re-encodes 'mov    $0x0,%bl' differently
L_0018b4:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0018b6:
        call L_00175d
L_0018b9:
        jmp L_000c33
L_0018bc:
        .byte 0x00  # the cursor seed: asm/155D's walker skips this NUL to land on entry 0 at 0x16BD
# body corrected: 2026-10-25 -- evidence: this file now ends at runtime 0x16BC. The bytes from
#           0x16BD to 0x1798 are ten NUL-separated strings (bar chatter and the hint table),
#           and they live in asm/16BD_barkeep_chatter_hints.asm. The old decode rendered them
#           as instructions, which is why the tail of this file was full of forced-kept .byte
#           lines that were not code. No byte moved; the split is byte-neutral and
#           tools/assemble_clean.sh proves it.
