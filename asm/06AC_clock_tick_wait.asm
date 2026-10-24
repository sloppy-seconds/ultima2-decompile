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
# PURPOSE — RESOLVED 2026-10-28d, same day: DS:74 is the game's SPEED SETTING, and this routine
#           is what seeds it. The consumer that was missing is now named and traced.
#           asm/06ED..0710 is a 20-iteration loop (`mov $0x26,%bx` down to 0 in steps of 2) that
#           for each slot computes `(DS:74 - DS:554) * DS:558[i] / DS:554`, clamped to 0 when
#           DS:74 < DS:554, and stores the result at DS:580[i]. So DS:554 is a baseline, DS:558[..]
#           are per-slot multipliers, and DS:580[..] are 20 scaled delay values.
#           The read path is asm/0711_speed_delay_lookup (`mov 0x580(%bx),%bx`), called by
#           FOURTEEN routines as an animation delay or key-wait timeout — asm/6DFD_hyperwarp_flow,
#           asm/6999_space_status, asm/7030_space_collision, asm/38B0_cmd_L and ten more.
#           The clincher is asm/4FB3_speed_rescale_call: **F7 and F8 adjust DS:74 by ±0x200 and
#           then call this same rescaler** (asm/4FA5_speed_faster_f7, asm/4F8E_speed_slower_f8,
#           bounded by DS:554 below and 0x3a00 above). One variable, two writers — a measured
#           seed and a user override — one rescaler, twenty served slots. The startup measurement
#           is the initial value of a control the player can move.
#           What is still open is narrower than "purpose": what each of the 20 slot offsets gates.
#           The mechanism is no longer inferred; the per-slot semantics are.
# MEASURED LIVE 2026-10-28d, captures/spice86/g30-clockcal/: sector 03, maxed character, 45 s
#           idle sampled at ~2 Hz (103 samples). **DS:74 = 0x3A17 (14,871) and DS:550 = 0x8D
#           (141), DS:552 = 0, and all three were STATIC across every sample** — while the idle
#           loop was demonstrably running (food fell 9,593,497 -> 4,350,617, and `incb DS:21`
#           at runtime 08D6 executed). So the window opens at STARTUP and is not re-measured
#           in-world: the value in DS:74 is a one-off left in scratch. That is consistent with
#           tools/u2_edit.py, which independently records DS:74/75 as "live scratch that is not
#           persisted" — it never reaches the save because it is written once, before the world
#           loads.
#           The magnitude supports the calibration reading rather than weakening it: 14,871
#           passes of a 100-iteration delay inside a 20-tick window (~1.10 s) is ~1.35 M
#           passes/s at the emulator's default `--cycles 3000`, which is the right order for
#           `dec ax ; jne` at that budget. A scratch byte left over from boot would not be
#           expected to land there by chance.
#           What this does NOT settle, and what did: nothing re-measures in-world, so DS:74 keeps
#           whatever the startup measurement produced — but it is NOT inert scratch. It is the
#           speed setting, and F7/F8 overwrite it on demand (see PURPOSE above). Note the measured
#           0x3A17 sits 31 above the F7 ceiling of 0x3a00, which is only possible because the
#           clamp guards the key handler's arithmetic and never the startup write.
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
# confidence: high for the bytes, the span and the 20-tick window; medium for PURPOSE (the
#           value is now measured and its magnitude checks out, but nothing has observed the
#           scaled result being used for anything)
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
