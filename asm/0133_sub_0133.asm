# sub_0133 — stores 0 to DS:0239, then calls sub_008ac
# func 0133..013A  len 008 B  evidence: seed+reko
# confidence: low (byte-level read only)
sub_0133:
        mov    $0x0,%al
        mov    %al,0x239
        call L_0008ac
