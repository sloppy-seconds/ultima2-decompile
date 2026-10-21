# force_field_event — dungeon force-field damage (ring protects)
# name-evidence: strings 'RING PROTECTS FROM FIELD!' / 'FIELD CAUSES 1000 DAMAGE!'
# func 24B5..251F  len 006B B  evidence: seed+reko
# calls: L_000e62, L_002720, L_0051df (str_out), L_00543e, L_0060f2
# provenance: live:castle-03-live — BOTH branches executed in the 2026-10-21
#           session. The owner walked the tile with no ring (a thief had taken it)
#           and HP went 8842 -> 7842, exactly 1000; after [DS:D6] was set to 1 the
#           protect branch fired with no damage. Previously these strings had only
#           ever been discovered, never observed.
# notes: gate is [DS:D6], the RING slot of the item array at DS:D6+i, tested at
#           file 0x26B8 (`mov al,[ds:d6]; cmp al,0; je <damage>`). Non-zero prints
#           'RING PROTECTS FROM FIELD!' and does nothing else. Zero takes the
#           damage path: clears [DS:19] and [DS:1A] to 0 (file 0x26FE), flashes
#           and sounds, then subtracts with `stc; sbb al,0x10; das` on [DS:51], the
#           high byte of the 4-digit BCD HP at DS:51/52 — that is a clean -1000.
#           If the subtract borrows (HP < 1000) the branch at file 0x271B jumps to
#           the death handler, so this tile kills a weak character outright.
#           The tile byte that triggers it is NOT statically resolvable. The ladder
#           that reaches this routine (asm/248B -> asm/2495 -> asm/24B1 -> here, all
#           inside the passability routine asm/2423) reads NO map tile: it decides on
#           [DS:29] & 0x7f, and asm/24B1 falls through to force_field_event only when
#           ([DS:29] & 0x7f) == 0x2e. [DS:29] is set at the asm/2423 entry from AL,
#           the travel-mode byte [DS:15]/[DS:18] (mode_table_copy asm/5B71 asm/5C49:
#           [DS:15]=[DS:2CB], [DS:18]=[DS:2DE]). MEASURED at the live force-field turn
#           (fight-20261021-castle03 turn 2909: HP_hi 0x88->0x78 = -1000, [DS:D6]=0,
#           [DS:15]=[DS:18]=0x2e). So the trigger is MODE BYTE 0x2e, not a tile byte:
#           0x2e occurs 0 times in mapx00, so it is not a raw grid byte. The tile ->
#           mode 0x2e mapping is produced by the indirect store that fills DS:2CB/DS:2DE
#           (docs/passability-findings.md F3: no direct writer anywhere in the exe), so
#           the map byte cannot be named offline. The animated white/blue/purple render
#           is likewise not in this routine (it only flashes/sounds via L_00543e/L_0060f2).
#           NAMED CAPTURE THAT WOULD SETTLE IT: the backlog four-question passability
#           capture - read DS:2CB/DS:2DE plus the destination tile byte at the instant
#           the mode is 0x2e (or break the indirect store that writes DS:2CB/DS:2DE),
#           which inverts tile -> mode 0x2e. Do NOT guess a byte.
# confidence: high (gate, damage, death branch and both paths proven by bytes,
#           execution and live memory)
force_field_event:
L_0026b5:
        mov    0xd6,%al
L_0026b8:
        cmp    $0x0,%al
L_0026ba:
        je L_0026e0
L_0026bc:
        call L_0051df
        db 0x8d,"RING PROTECTS FROM FIELD!",0x00        # string
L_0026da:
        call L_0060f2
L_0026dd:
        jmp L_002720
L_0026df:
        nop
L_0026e0:
        call L_0051df
        db 0x8d,"FIELD CAUSES 1000 DAMAGE!",0x00        # string
L_0026fe:
        mov    $0x0,%al
L_002700:
        mov    %al,0x19
L_002703:
        mov    %al,0x1a
L_002706:
        call L_00543e
L_002709:
        call L_0060f2
L_00270c:
        call L_00543e
L_00270f:
        mov    0x51,%al
L_002712:
        stc
L_002713:
        cmc
L_002714:
        sbb    $0x10,%al
L_002716:
        das
L_002717:
        cmc
L_002718:
        mov    %al,0x51
L_00271b:
        jb L_002720
L_00271d:
        jmp L_000e62
