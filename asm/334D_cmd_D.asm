# cmd_D — command handler 'D' (DESCEND): prints "DESCEND", gates on the SITE KIND
#         at DS:4A; 4 (tower) and 5 (dungeon) pass, anything else prints "-WHAT?" and re-reads
# CORRECTION 2026-10-29, and the inline `# key byte` on the first instruction is stale — left
#         in place because body lines are frozen (AGENTS.md § 3), so the correction lives here.
#         DS:4A is not a key byte. It is the site kind, proven many times over (0 world map, 1
#         village, 2 town, 3 castle, 4 tower, 5 dungeon), and `cmp $4`/`cmp $5` is therefore
#         "DESCEND only works inside a tower or a dungeon", which is what DESCEND means. The
#         second gate, `[DS:14] & 0x20`, is the cell feature: the sector-24 tower's grid uses
#         0x20 for the down-ladder cell the player was standing on, and DS:14 is the tile under
#         the player.
# EXECUTED 2026-10-29 (captures/spice86/d12-ladder-ds25): in the sector-24 tower, standing on a
#         0x20 cell at (5,5) with DS:4A = 4, pressing D printed `CMD: DESCEND` and put the player
#         back on the world map at the gate cell (24,40) with DS:25 = 0xFF. That makes cmd_D one
#         of the two handlers that had never run in any harvest; the frame is `c-cmdD-descend.png`.
#         It is still NOT implemented in the engine (a NULL slot), which is an honest gap rather
#         than a stub: the marker rule asks for a marker only when a handler is implemented but
#         unproven, and this is the other way round.
# func 334D..3380  len 052 B  evidence: seed+reko (jump table cs:0730 entry D)
# provenance: live:d12-ladder-ds25; static
#           entry executed in 1 of 187 harvests; confirmed by the capture of 2026-10-29, which is
#           the first time cmd_D appeared in ExecutedInstructions in any harvest.
# confidence: high (structure read off the bytes; both gates and the outcome observed live
#         2026-10-29; the two resume sites at 0x3570 are still a Phase 2 mis-align)
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
