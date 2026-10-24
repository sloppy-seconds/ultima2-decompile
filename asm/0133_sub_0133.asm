# sub_0133 — zero DS:239, then call the 20-tick clock window
# name-evidence: `mov $0x0,%al ; mov %al,0x239 ; call L_0008ac`, and L_0008ac is
#           asm/06AC_clock_tick_wait.
# NOT A FUNCTION ENTRY, and that is the finding: there is no `call` or `jmp` to runtime 0133
#           anywhere in the exe — it is reached by FALLTHROUGH from the `call` at runtime 0130.
#           The clean wave cut a contiguous routine at ~0100..0150 into one-instruction files
#           and invented a boundary here. The startup prologue above it reads the BIOS tick at
#           ES:006C into DS:23F..244 (the RNG seed `docs/spice86-live-findings.md` records),
#           and the code after asm/013B scales the clock window's pass count.
# provenance: static, decoded 2026-10-28d; executed in 136 of 136 harvested ExecutedInstructions
# confidence: high for the bytes and the fallthrough; the enclosing routine is unnamed
# label: kept as sub_0133 on purpose — labels are body and CP0 md5s them
# func 0133..013A  len 008 B  evidence: seed+reko
sub_0133:
        mov    $0x0,%al
        mov    %al,0x239
        call L_0008ac
