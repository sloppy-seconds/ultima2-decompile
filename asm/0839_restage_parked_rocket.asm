# restage_parked_rocket — puts the rocket back on the map at its parked cell
# name-evidence: body reads DS:6A/DS:6B into the target pair DS:23/DS:24, calls the grid
#           pointer L_0052b3, and stamps $0x50 -- which is the rocket tile. mapx41 at the
#           three authored pads (33,3) (38,3) (43,3) is 0x50, and the live grid cell
#           DS:18E6 went 0x50 -> 0x08 the instant the rocket lifted off
#           (captures/spice86/g39-rocket-flight). The engine already pairs them: 0x28 <->
#           0x50, see engine/src/game/overworld.c.
# NAMED 2026-11-03 from a reader/writer sweep of the whole tree. This was a bulk-wave stub
#           headed "behavior not yet reviewed", and it is one of three copies of the same
#           stamp -- here, asm/245a, and the site-exit block of asm/3823_site_floor_down.
#           The entry that reaches THIS one is asm/080D, the 'P' load path: it sets the
#           position from DS:5A/5B, then `mov 0x69,%al ; or %al,%al ; je`, and on the
#           not-taken arm falls here. So this is the routine that makes a rocket parked on
#           a planet reappear when you load a save -- see asm/38B0_cmd_L for the triple's
#           full semantics and for why the launch has to save.
# func 0839..084F  len 0017 B  evidence: seed+reko
# calls: L_0052b3
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0839:
L_000a39:
        mov    0x6a,%al
L_000a3c:
        mov    %al,0x23
L_000a3f:
        mov    0x6b,%al
L_000a42:
        mov    %al,0x24
L_000a45:
        call L_0052b3
L_000a48:
        mov    $0x50,%al
L_000a4a:
        mov    0x6,%bx
L_000a4e:
        mov    %al,(%bx,%si)
