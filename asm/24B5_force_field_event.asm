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
#           The tile byte that triggers it is NOT proven; the field renders as an
#           animated white/blue/purple band and no map byte has been matched to it.
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
