# clock_tick_wait — wait out 20 BIOS clock ticks, counting how many busy-delay passes fit
# name-evidence: `mov $0x0,%ah ; int $0x1a` is INT 1Ah AH=0000h = read the PC BIOS free-running
#           timer tick (CX:DX = ticks since midnight, AL = midnight rollover count). Three
#           such reads, a `cmp $0x14,%dx` (20) gate on the elapsed low tick, and a
#           `mov $0x64,%ax ; dec %ax ; jne` 100-iteration busy delay whose pass count is
#           accumulated into DS:74 by `addw $0x1,0x74`. Named for the mechanism, which is
#           observed; what the count is FOR is inferred, see PURPOSE below.
# REAL FUNCTION SPAN: runtime 06AC..06EC (file 08AC..08EC), 65 bytes, one `ret`. The clean
#           wave cut it into ELEVEN files — asm/06AC, 06B0, 06BE, 06C2, 06C6, 06CC, 06D0,
#           06D4, 06D7, 06DA, 06EC — and `disasm/fragment-splits.tsv` only nominates the
#           tail six of them (06CC..06EC, graded probable). Read in address order:
#             06AC  mov $0x0,%ah / int $0x1a     read tick
#             06B0  mov %cx,0x552 / mov %dx,0x550 / movw $0x0,0x74   save it, clear counter
#             06BE  mov $0x0,%ah / int $0x1a     poll A
#             06C2  cmp $0x0,%al / jne 06AC      rollover -> restart from scratch
#             06C6  cmp 0x550,%dx / je 06BE      tick has not moved -> poll again
#             06CC  mov $0x0,%ah / int $0x1a     poll B (the measured loop)
#             06D0  cmp $0x0,%al / jne 06AC      rollover -> restart
#             06D4  mov $0x64,%ax                100
#             06D7  dec %ax / jne 06D7           busy delay
#             06DA  addw $0x1,0x74 / sub 0x550,%dx / sub 0x552,%cx / cmp $0x14,%dx / jb 06CC
#             06EC  ret
#           On return DS:74 holds how many 100-iteration passes elapsed in the 20-tick window,
#           and DS:550/DS:552 the tick the window started at.
# PURPOSE (inferred, and it is the interesting part): the counter is consumed by the code
#           immediately after the `ret` — asm/06ED sets `%bx = 0x26` and asm/06F0 does
#           `mov 0x74,%ax ; sub 0x554,%ax ; jae ...` then `mulw 0x558(%bx) ; divw 0x554`.
#           A pass count measured against a fixed wall-clock window, fed into a multiply and a
#           divide, is a **machine-speed measurement**: the game is calibrating its own delays
#           to how fast this CPU is. That is 1983 practice and it explains why the number is
#           scaled rather than used. Not proven; nobody has dumped DS:74 live.
# WHY THIS MATTERS TO T2: `docs/spice86-live-findings.md` recorded "there is no INT 1Ah
#           anywhere in the corpus" as the reason the auto-PASS timeout must be a poll count.
#           That sentence is false and was corrected 2026-10-28d — see
#           `docs/phase4-state.md § Resume notes`. The PASS conclusion survived; the evidence
#           for it did not, and this routine is why.
# reached from: runtime 0133 and 07ED (`call L_0008ac`), plus the internal branches above.
#           asm/0133 has no `call` or `jmp` to it anywhere: it is reached by FALLTHROUGH from
#           the `call` at runtime 0130, which is another split of the same kind.
# provenance: static, decoded 2026-10-28d from original/ultimaii.exe file 0x08AC..0x08EC,
#           byte-aligned instruction by instruction; execution counts from the 136 harvested
#           ExecutedInstructions sets (all three int sites execute in 136/136)
# confidence: high for the bytes, the span and the 20-tick window; low for PURPOSE
# label: kept as sub_06ac on purpose — labels are body and CP0 md5s them
# func 06AC..06AF  len 0004 B  evidence: seed+call+reko
# seams: clock_int1a
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_06ac:
L_0008ac:
        mov    $0x0,%ah
L_0008ae:
clock_int1a:
        int $0x1a    # clock_int1a seam
