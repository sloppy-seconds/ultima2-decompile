# cmd_M — command handler 'M': prints "MAGIC SPELL READY #", calls sub_2028
#           (spell pick?), stores result at DS:0063, prints "SPELL READY => "
#           plus the value (call sub_508c = numeric out?), returns to dispatcher.
# func 3B92..3BCD  len 060 B  evidence: seed+reko (jump table cs:0730 entry M)
# confidence: medium (flow proven; callee semantics inferred)
# notes: slice mis-decoded 0x3da8 as add+jl (swallowed the call opcode); true
#        read is NUL terminator + call 0x2228. Trailing 0xe8 stop-truncs into
#        next fragment (3BCE).
cmd_M:
        call L_0051df          # str_out — prints the inline string below
        db "MAGIC SPELL READY #",0   # string
        call L_002228
        mov    %al,0x63
        call L_0051df          # str_out — prints the inline string below
        db "SPELL READY => ",0 # string
        mov    0x63,%al
        clc
        adc    $0x24,%al       # ASCII digit bias for numeric out
        call L_00528c
        jmp L_000c33           # return to dispatcher
