#!/usr/bin/env python3
"""extractor.py — turn the user's own copy of the game into engine headers.

Phase 4 rule: the engine ships zero game content. Every string the engine
displays is pulled at build time from a copy the user owns, into
engine/build/gen_content.h, which is gitignored. Nothing this script writes is
ever committed, and nothing it writes belongs in git history.

Two sources, in priority order:

  exe  --exe PATH (default: <repo>/original/ultimaii.exe when present).
         The real bytes, located inside the function range named by the
         manifest, so a community-patched build that shifted a string is still
         read correctly rather than silently mismatched.
  asm  the documented fallback (docs/phase4-plan.md CP1): the `db "...",0x00`
         lines of our own byte-proven asm/ tree. Used when no exe is present,
         e.g. a fresh clone or CI.

The manifest is (symbol, asm file, which string in that file). Offsets and
names are facts about the binary and ours to publish; the bytes at them are
not. `--check` regenerates and compares, so a stale header fails the build.

Usage:
  extractor.py [-o engine/build/gen_content.h] [--exe PATH] [--source auto|exe|asm]
  extractor.py --emit text      # SYMBOL<TAB>value per line, for test scripts
  extractor.py --check          # fail if the written header is not current
"""
import argparse
import hashlib
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ENGINE = os.path.abspath(os.path.join(HERE, "..", ".."))
REPO = os.path.abspath(os.path.join(ENGINE, ".."))

# The known-good image (AGENTS.md, disasm/phase3-summary.md). A mismatch is a
# warning, not an error: original/ may carry community patches.
EXPECTED_MD5 = "fe884d5117971073ac8097cc7a6aca25"
FILE_BIAS = 0x200          # runtime segment offset -> file offset

# (symbol, asm file, locator)
#   locator = int index into the file's `db "...",0x00` lines  -> both sources work
#   locator = ("run", file_offset)                            -> exe only
# The "run" form is needed for strings that sit inside the regions Phase 3
# reconstructed as mis-decoded code (asm/02A3, asm/02E6): their bytes are
# proven but not written as db lines, so the documented asm fallback cannot
# recover them. Without an exe those entries come out empty and the engine
# skips the line; see engine/tests/run_cp1.sh, which asserts accordingly.
# CP1 scope: the presentation intro, the title/menu screen, and the 'D' poem.
MANIFEST = [
    ("U2_S_INTRO_ORIGIN",      "014B_sub_014b.asm", 0),
    ("U2_S_INTRO_PROUDLY",     "015E_sub_015e.asm", 0),
    ("U2_S_INTRO_PART",        "018D_sub_018d.asm", 0),
    ("U2_S_INTRO_BESTSELLER",  "01A1_sub_01a1.asm", 0),
    ("U2_S_INTRO_GENRE",       "01C4_sub_01c4.asm", 0),
    ("U2_S_INTRO_AUTHOR",      "01EA_sub_01ea.asm", 0),
    ("U2_S_TITLE_GAME",        "0246_sub_0246.asm", 0),
    ("U2_S_TITLE_REVENGE",     "025E_sub_025e.asm", 0),
    ("U2_S_TITLE_OF_THE",      "0273_sub_0273.asm", 0),
    ("U2_S_TITLE_ENCHANTRESS", "0288_sub_0288.asm", 0),
    ("U2_S_TITLE_COPYRIGHT",   "02A3_sub_02a3.asm", ("run", 0x04AD)),
    ("U2_S_TITLE_AND_ORIGIN",  "02CC_sub_02cc.asm", 0),
    ("U2_S_TITLE_TYPE",        "02E6_sub_02e6.asm", ("run", 0x04F0)),
    ("U2_S_MENU_DEMO",         "02F8_sub_02f8.asm", 0),
    ("U2_S_MENU_PLAY",         "031F_sub_031f.asm", 0),
    ("U2_S_MENU_CREATE",       "034B_sub_034b.asm", 0),
    ("U2_S_MENU_CHOICE",       "0375_sub_0375.asm", 0),
    ("U2_S_POEM_1A",           "03AC_sub_03ac.asm", 0),
    ("U2_S_POEM_1B",           "03AC_sub_03ac.asm", 1),
    ("U2_S_POEM_2A",           "03AC_sub_03ac.asm", 2),
    ("U2_S_POEM_2B",           "03AC_sub_03ac.asm", 3),
    ("U2_S_POEM_3A",           "03AC_sub_03ac.asm", 4),
    ("U2_S_POEM_3B",           "03AC_sub_03ac.asm", 5),
    ("U2_S_POEM_4A",           "03AC_sub_03ac.asm", 6),
    ("U2_S_POEM_4B",           "03AC_sub_03ac.asm", 7),
    ("U2_S_POEM_5A",           "03AC_sub_03ac.asm", 8),
    ("U2_S_POEM_5B",           "03AC_sub_03ac.asm", 9),
    ("U2_S_POEM_6A",           "03AC_sub_03ac.asm", 10),
    ("U2_S_POEM_6B",           "03AC_sub_03ac.asm", 11),
    # CP3: character creation and the status line. Every "run" offset below is a
    # string inside a region Phase 3 reconstructed as mis-decoded code, so the
    # asm fallback cannot recover it; the offsets come from the STR lines in
    # disasm/redecoded/5400_sub_5400.txt, which is our own decode.
    ("U2_S_CREATE_BLANK",      "5400_sub_5400.asm", ("run", 0x5615, 28)),
    # asm/0764 (file 0x0964): 'P' reads the player record and, only when the
    # name byte is zero, prints this and waits for ESC. Offset is the '(' — the
    # preceding byte belongs to the jump that skips the prompt on the first pass.
    ("U2_S_DISK_PLAYER",       "0764_sub_0764.asm", ("run", 0x0979, 20)),
    ("U2_S_CREATE_NOTBLANK1",  "5400_sub_5400.asm", ("run", 0x566B)),
    ("U2_S_CREATE_NOTBLANK2",  "5400_sub_5400.asm", ("run", 0x5689)),
    ("U2_S_CREATE_GENERATION", "5400_sub_5400.asm", ("run", 0x569E)),
    # The running total does NOT follow the GENERATION heading. asm/56C8 prints
    # this line and asm/5C85 addresses the value at column 33 row 2, which is
    # where this string's trailing ": " leaves the cursor. The db listing splits
    # the run at 0x56C8 ("INTS LEFT...") because the preceding bytes decode as
    # code, so the locator is the true start found in the binary.
    ("U2_S_CREATE_POINTS",     "5400_sub_5400.asm", ("run", 0x56C6)),
    ("U2_S_CREATE_FORM",       "5400_sub_5400.asm", ("run", 0x56F4)),
    ("U2_S_SEX_MALE",          "5400_sub_5400.asm", ("run", 0x595B)),
    ("U2_S_SEX_FEMALE",        "5400_sub_5400.asm", ("run", 0x5988)),
    ("U2_S_RACE_HUMAN",        "5400_sub_5400.asm", ("run", 0x59C9)),
    ("U2_S_RACE_ELF",          "5400_sub_5400.asm", ("run", 0x59F7)),
    ("U2_S_RACE_DWARF",        "5400_sub_5400.asm", ("run", 0x5A23)),
    ("U2_S_RACE_HOBBIT",       "5400_sub_5400.asm", ("run", 0x5A54)),
    ("U2_S_CLASS_FIGHTER",     "5400_sub_5400.asm", ("run", 0x5A9E)),
    ("U2_S_CLASS_CLERIC",      "5400_sub_5400.asm", ("run", 0x5ACE)),
    ("U2_S_CLASS_WIZARD",      "5400_sub_5400.asm", ("run", 0x5AFD)),
    ("U2_S_CLASS_THIEF",       "5400_sub_5400.asm", ("run", 0x5B2F)),
    ("U2_S_CREATE_TOPLAY",     "5400_sub_5400.asm", ("run", 0x5C1F)),
    ("U2_S_CREATE_PROGMSTR",   "5400_sub_5400.asm", ("run", 0x5C43)),
    ("U2_S_STATUS_HP",         "50F9_show_hitpoints.asm", 0),
    ("U2_S_STATUS_FOOD",       "5129_sub_5129.asm", 0),
    ("U2_S_STATUS_EXP",        "5154_sub_5154.asm", 0),
    ("U2_S_STATUS_GOLD",       "5175_sub_5175.asm", 0),
    # The CMD prompt and the four direction words. The prompt is its own
    # routine (asm/087D); the direction words are standalone strings in the
    # movement arms (asm/0955/097C/09A3/09C9 — the echo sites named in
    # docs/phase4-implementation.md § CP4 "The movement model"). The CP4b
    # status band needs all five as content, not engine-typed text.
    ("U2_S_CMD_PROMPT",        "087D_cmd_prompt.asm", 0),
    ("U2_S_DIR_NORTH",         "0955_sub_0955.asm", 0),
    ("U2_S_DIR_SOUTH",         "097C_sub_097c.asm", 0),
    ("U2_S_DIR_WEST",          "09A3_sub_09a3.asm", 0),
    ("U2_S_DIR_EAST",          "09C9_sub_09c9.asm", 0),
    # The Q save flow (asm/3DC7 cmd_Q + the location guards asm/3DE4/3DFA).
    # The split attributed none of these as db lines (the prompt's line ends
    # ",0" not ",0x00"), so all five use run locators at their file addresses,
    # verified against the raw bytes. Note each guard string is preceded by a
    # 0x8d line-marker byte (the same high-bit convention as the tlkx files),
    # so the string starts one byte after the call: 0x3FCA, 0x3FE8, 0x4005,
    # 0x4022, 0x4037.
    ("U2_S_Q_PROMPT",          "3DC7_cmd_Q.asm", ("run", 0x3FCA, 18)),
    ("U2_S_Q_OUTDOORS",        "3DE4_offer_only_outdoors.asm", ("run", 0x3FE8, 14)),
    ("U2_S_Q_EARTH",           "3DFA_offer_only_outdoors_earth.asm", ("run", 0x4005, 14)),
    ("U2_S_Q_FOOT",            "3DFA_offer_only_outdoors_earth.asm", ("run", 0x4022, 13)),
    ("U2_S_Q_MOMENT",          "3DFA_offer_only_outdoors_earth.asm", ("run", 0x4037, 18)),
    # The PASS echo. The walk loop prints it from an inline string in the code
    # stream (call at file 0x0B45, bytes "PASS\0" at 0x0B48), which is the same
    # shape as the direction words; the split attributes it to no db line, so
    # it uses a run locator verified against the raw bytes.
    ("U2_S_PASS",              "0940_sub_0940.asm", ("run", 0x0B48, 4)),
    # Rejected move. asm/0A02 is a whole routine whose only content is the
    # str_out call plus its inline string, so the db-index locator is exact and
    # needs no hand-checked file offset.
    ("U2_S_INVALID_MOVE",      "0A02_invalid_move_msg.asm", 0),
    # CP5 C3 — the movement reject a paralysed character gets. asm/2520 tests DS:26B inside
    # the passability routine and, if set, prints this and takes the same reject return
    # (runtime 0x2538) an impassable tile uses. The db line carries a trailing 0x0d newline
    # glyph, which puts it outside DB_RE, so this is a run locator; the engine emits the
    # newline itself, as it does for --INVALID MOVE!.
    ("U2_S_MOVE_PARALYZED",    "2527_sub_2527.asm", ("run", 0x272A, 12, "--PARALIZED!")),
    # The Z status screen's labels (docs/status-screen-z.md § 7). Each is the inline string
    # of a str_out call inside the handler, so the offsets are the call site plus three.
    # Four of these files were named "shop_header_*" by the bulk wave on a caller that was
    # never found; they are now list_header_* (see the headers). The Z screen is the only
    # consumer demonstrated anywhere. The three run locators are the strings whose db
    # lines DB_RE cannot see: "A LEVEL " carries a leading 0x8d newline glyph, and the
    # SPELL- / bare-dash labels sit on multi-string db lines.
    ("U2_S_Z_A_LEVEL",         "4580_level_gain_msg.asm", ("run", 0x4784, 8, "A LEVEL ")),
    ("U2_S_Z_WEAPON",          "45C4_status_weapon.asm", 0),
    ("U2_S_Z_TORCHES",         "45E9_status_torches.asm", 0),
    ("U2_S_Z_ARMOUR",          "460A_status_armour.asm", 0),
    ("U2_S_Z_KEYS",            "462F_status_keys.asm", 0),
    ("U2_S_Z_SPELL",           "464D_sub_464d.asm",       ("exe_only", 0x4850, 6, "SPELL-")),
    ("U2_S_Z_TOOLS",           "466F_status_tools.asm", 0),
    ("U2_S_Z_WEAPONS_LIST",    "4748_list_header_weapons.asm", 0),
    ("U2_S_Z_ARMOUR_LIST",     "47A2_list_header_armour.asm", 0),
    ("U2_S_Z_SPELLS_LIST",     "47FA_list_header_spells.asm", 0),
    ("U2_S_Z_ITEMS_LIST",      "4853_list_header_items.asm", 0),
    # The list separators. The plural is a literal S and the dash is separate, because the
    # item loop prints the S for everything except index 3 (BOOTS) and the dash always.
    ("U2_S_Z_PLURAL_DASH",     "4771_sub_4771.asm", 0),
    ("U2_S_Z_PLURAL_S",        "4881_sub_4881.asm", 0),
    # The bare dash the item loop prints after the plural S is deliberately NOT extracted.
    # It is punctuation, not content — the same class as the space and the digits, which the
    # engine also emits as literals — and the asm tree holds it as `.byte` fragments, so an
    # extraction would either die in CI or need an exe-only hole for a hyphen.
    # The creation tail (asm/5400 end). Both strings print before the tail calls
    # the program-startup routine, which is why finishing creation lands on the
    # splash rather than the menu. They are stored as byte lists in the listing
    # (`db 0x49,0x4e,...`) rather than quoted strings, so the db-index locator
    # cannot see them and these use verified run offsets: the disassembler
    # mis-split "TO PLAY ULTIMA ][" into data fragments, so the true starts were
    # taken from the binary itself.
    ("U2_S_TO_PLAY",           "5400_sub_5400.asm", ("run", 0x5C1F, 17)),
    ("U2_S_INSERT_PROGRAM",    "5400_sub_5400.asm", ("run", 0x5C43, 21)),
    # CP5 W3 — the attack command's own words. Offsets verified against the exe on
    # 2026-10-23; each also names the asm file that documents it, so the provenance
    # is readable even where the fallback cannot reach (see the DB_RE note).
    ("U2_S_ATTACK",            "2B8F_cmd_A.asm", 0),
    ("U2_S_HIT",               "2BEC_combat_hit_msg.asm", 0),
    ("U2_S_MISS",              "2E09_combat_miss_msg.asm", 0),
    ("U2_S_PARALYZED",         "2BAD_sub_2bad.asm", 0),
    # `db 0x8d,"KILLED--GOLD+"` — the leading glyph byte puts it outside the asm
    # fallback, so it is exe-only, like the title strings above.
    ("U2_S_KILLED",            "2E3D_combat_attack_flow.asm", ("run", 0x2FA6, 13, "KILLED--GOLD+")),
    ("U2_S_EXP_PLUS",          "2E3D_combat_attack_flow.asm", 1),
    # CP5 W8 — the death tail. asm/0C8C writes `db " IS DEAD!",0x8d,0x00`, and the
    # trailing 0x8d (the game's newline glyph, which char_print masks to CR) puts the
    # line outside DB_RE, so this is exe-only. Offset verified against the exe on
    # 2026-10-27: file 0x0E8F is `20 49 53 20 44 45 41 44 21` followed by `8d 00`.
    # Length 9 stops before the 8d because the engine emits the newline itself.
    ("U2_S_IS_DEAD",           "0C8C_character_dead_msg.asm", ("run", 0x0E8F, 9, " IS DEAD!")),
    # CP5 W6 — the creature special's own words. Every one of these is exe-only for
    # the same reason as U2_S_IS_DEAD: the db line carries a trailing glyph byte
    # (0x0d or 0x8d, both of which char_print masks to CR) between the text and the
    # terminator, which puts it outside DB_RE. Offsets and lengths verified against
    # the exe on 2026-10-27; each is unique in the file, so no locator ambiguity.
    ("U2_S_LEGS_PARALYZED",    "0E70_combat_paralyzed_legs.asm", ("run", 0x1073, 15, "LEGS PARALIZED!")),
    ("U2_S_SAVED_BY_BOOTS",    "0E70_combat_paralyzed_legs.asm", ("run", 0x109E, 23, "SAVED BY MAGICAL BOOTS!")),
    ("U2_S_ARMS_PARALYZED",    "0EC2_combat_paralyzed_arms.asm", ("run", 0x10C5, 15, "ARMS PARALIZED!")),
    ("U2_S_SAVED_BY_CLOAK",    "0EC2_combat_paralyzed_arms.asm", ("run", 0x10F0, 22, "SAVED BY MAGICAL CLOAK")),
    ("U2_S_MAGIC_MISSILE",     "0F12_combat_magic_missile.asm",  ("run", 0x1115, 14, "MAGIC MISSILE!")),
    ("U2_S_SLEEP_SPELL",       "0F48_combat_sleep_spell.asm",    ("run", 0x114B, 12, "SLEEP SPELL!")),
    ("U2_S_SAVED_BY_IDOL",     "0F48_combat_sleep_spell.asm",    ("run", 0x1173, 14, "SAVED BY IDOL!")),
    ("U2_S_THIEF_STOLE",       "0FCD_combat_thief_steal.asm",    ("run", 0x11F8, 24, "A THIEF STOLE SOMETHING!")),
    # Site transitions (docs/sector-rulesets.md § 6). cmd_E's " WHAT?" is the
    # second of eleven copies of that literal in the file, so every one of these is
    # addressed by offset rather than by index; the offsets were read off the asm
    # fragments and then confirmed against the exe on 2026-10-27.
    ("U2_S_ENTER",             "3389_cmd_E.asm",          ("run", 0x358C, 5, "ENTER")),
    ("U2_S_ENTER_WHAT",        "3399_sub_3399.asm",       ("run", 0x359C, 6, " WHAT?")),
    ("U2_S_ONLY_ON_FOOT",      "33AE_move_only_on_foot.asm", ("run", 0x35B1, 14, "-ONLY ON FOOT!")),
    ("U2_S_DESCEND",           "334D_cmd_D.asm",          ("run", 0x3550, 7, "DESCEND")),
    ("U2_S_DESCEND_WHAT",      "334D_cmd_D.asm",          ("run", 0x3566, 6, "-WHAT?")),
    ("U2_S_SITE_TOWN",         "343F_sub_343f.asm",       ("run", 0x364A, 5, "-TOWN")),
    ("U2_S_SITE_TOWER",        "343F_sub_343f.asm",       ("run", 0x367F, 6, "-TOWER")),
    ("U2_S_SITE_CASTLE",       "34B5_sub_34b5.asm",       ("run", 0x36B8, 7, "-CASTLE")),
    ("U2_S_SITE_DUNGEON",      "34E4_sub_34e4.asm",       ("run", 0x36EF, 8, "-DUNGEON")),
    # The UNLOCK command (asm/42F1 cmd_U and its two refusals). The prompt's db line
    # terminates with `,0` so the db-index locator finds it; both refusals carry a
    # leading 0x8d line-marker byte, which puts them outside DB_RE on purpose (see the
    # DB_RE note), so they are addressed by offset. Offsets read off the exe 2026-10-28
    # while closing G30 -- each literal is unique in the file.
    ("U2_S_UNLOCK_DIRECTION",  "42F1_cmd_U.asm",          0),
    ("U2_S_NO_DOOR_THERE",     "4310_open_no_door.asm",   ("run", 0x4514, 14, "NO DOOR THERE!")),
    ("U2_S_NO_KEYS_FIT",       "4345_open_no_key_fit.asm", ("run", 0x4549, 17, "NO KEYS THAT FIT!")),
]

# The terminator is matched as `0x00` OR `0` because the asm tree is not uniform:
# asm/2B8F_cmd_A writes `db "ATTACK--",0` while the bulk wave writes `,0x00`.
# Narrowing this to one form silently drops a string from the fallback path, which
# is worse than a build error because the engine then prints an empty word.
# A leading `0xNN,` glyph byte (asm/2E3D's `db 0x8d,"KILLED--GOLD+"`) is NOT
# matched on purpose: accepting it would renumber the string indices of every file
# that has one, silently pointing existing manifest entries at the wrong string.
# That string is addressed by offset instead.
DB_RE = re.compile(r'^\s*db "((?:[^"\\]|\\.)*)",(?:0x00|0)\s*#\s*string')
FUNC_RE = re.compile(r'^#\s*func\s+([0-9A-Fa-f]{4})\.\.([0-9A-Fa-f]{4})')


def decode_gas_string(s):
    """Decode a gas db payload (the asm tree writes plain ASCII plus \\xNN)."""
    out = bytearray()
    i = 0
    while i < len(s):
        c = s[i]
        if c == "\\":
            nxt = s[i + 1] if i + 1 < len(s) else ""
            if nxt in ("x", "X"):
                out.append(int(s[i + 2:i + 4], 16))
                i += 4
                continue
            out.extend(bytes(s[i:i + 2], "latin-1").decode("unicode_escape").encode("latin-1"))
            i += 2
            continue
        out.append(ord(c))
        i += 1
    return bytes(out)


def parse_asm(path):
    """Return (func_lo, func_hi, [string bytes in file order]) for one asm file."""
    lo = hi = None
    strings = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            m = FUNC_RE.match(line.rstrip("\n"))
            if m:
                lo = int(m.group(1), 16) + FILE_BIAS
                hi = int(m.group(2), 16) + FILE_BIAS
            m = DB_RE.match(line)
            if m:
                strings.append(decode_gas_string(m.group(1)))
    if lo is None:
        raise ValueError(f"{path}: no '# func' range line")
    return lo, hi, strings


def locate(exe, lo, hi, strings):
    """Find each string inside the function's range in the exe.

    Returns [(file_offset, bytes)] or None if any string is missing. Searching
    forward from the previous hit keeps repeated short strings unambiguous.
    """
    window_end = min(len(exe), hi + 0x100)
    pos = lo
    out = []
    for want in strings:
        idx = exe.find(want, pos, window_end)
        if idx < 0:
            return None
        end = exe.find(b"\x00", idx)
        out.append((idx, exe[idx:end]))
        pos = idx + len(want)
    return out


def collect(source, exe, exe_path, warn):
    cache = {}
    rows = []
    for sym, fname, loc in MANIFEST:
        path = os.path.join(REPO, "asm", fname)
        if not os.path.exists(path):
            sys.exit(f"extractor: missing {path}")
        if fname not in cache:
            lo, hi, strings = parse_asm(path)
            found = None
            if source in ("auto", "exe") and exe is not None:
                found = locate(exe, lo, hi, strings)
                if found is None and source == "exe":
                    sys.exit(f"extractor: strings for {fname} not found in {exe_path}")
                if found is None:
                    warn(f"extractor: {fname} not located in the exe; using the asm fallback")
            cache[fname] = (strings, found)
        strings, found = cache[fname]

        if isinstance(loc, tuple) and loc[0] == "exe_only":
            # Some labels exist only as bytes the bulk wave could not turn back into text —
            # "SPELL-" sits in asm/464E as `.byte 0x8f,0x09,0x53,0x50` and friends, because
            # the disassembler read the string as instructions. There is no honest asm
            # fallback for those, and inventing one by widening DB_RE is the hazard that
            # comment documents. So: real value when the user's copy is present, omitted
            # with a warning when it is not, and anything that prints it guards on the
            # define existing. CI loses that one label and still proves the field's
            # position and value; the dev box checks the text.
            off = loc[1]
            if exe is not None:
                rows.append((sym, exe[off:off + loc[2]], f"exe@0x{off:04X}"))
            else:
                warn(f"extractor: {sym} is exe-only (asm/ has it as bytes, not text); "
                     f"omitting — callers must #ifdef it")
            continue

        if isinstance(loc, tuple) and loc[0] == "run":
            off = loc[1]
            if exe is not None:
                # A 3-tuple gives an explicit byte length: some strings are not
                # NUL-terminated (the '(INSERT A BLANK PLAYER DISK)' prompt) and
                # reading to the next NUL would swallow following code bytes.
                # A 2-tuple keeps the original semantics — read up to but not
                # including the terminator — because the emitted C literal is
                # terminated anyway and changing this silently altered the
                # CP1 title strings.
                if len(loc) >= 3:
                    val = exe[off:off + loc[2]]
                else:
                    val = exe[off:exe.index(b"\x00", off)]
                rows.append((sym, val, f"exe@0x{off:04X}"))
            elif len(loc) >= 4:
                # The fourth element is the same string as it appears in the asm
                # tree, so the fallback can find it by content. Without it a `run`
                # locator has nothing to resolve against when the exe is absent and
                # the emitted literal was silently empty — which CI could not see
                # until a test started asserting on the text.
                #
                # This deliberately searches the file's raw text and NOT the parsed
                # db-string list: those lines carry a trailing glyph byte
                # (`db " IS DEAD!",0x8d,0x00`) and widening DB_RE to match them
                # would renumber the string indices of every file that has one,
                # which is the exact hazard the DB_RE comment above documents.
                want = loc[3].encode("latin-1")
                if ('"%s"' % loc[3]) not in open(path, encoding="utf-8").read():
                    sys.exit(f"extractor: {sym}: asm fallback cannot find "
                             f"{loc[3]!r} as a quoted literal in {fname}")
                rows.append((sym, want, f"asm:{fname}"))
            else:
                rows.append((sym, b"", "unavailable without the user's copy"))
            continue

        idx = loc
        if idx >= len(strings):
            sys.exit(f"extractor: {fname} has {len(strings)} strings, manifest wants index {idx}")
        if found:
            off, val = found[idx]
            rows.append((sym, val, f"exe@0x{off:04X}"))
            if val != strings[idx]:
                warn(f"extractor: note {sym}: exe bytes differ from the asm reconstruction")
        else:
            rows.append((sym, strings[idx], f"asm:{fname}"))
    return rows


# ---------------------------------------------------------------------------
# The indexed name pool
#
# One contiguous run of NUL-separated entries in the data segment. asm/508C takes the
# entry index in AL, and the Z-screen print sites add a constant to reach each group,
# read off asm/45D2 (weapons, +0x13), asm/4618 (armour, +0x1d), file 0x4A1D (spells,
# +0x24), file 0x4A75 (items, +0x2e), the six stat literals 0x3E..0x43, asm/45A3
# (races, +0x44) and asm/45B1 (classes, +0x48).
#
# The base is anchored on HANDS at index 19, which is what the +0x13 sites require:
# readied_weapon 9 must print QUICK SWORD, and the WEAPONS: list starts its loop at
# index 1 and prints DAGGER first. Entry 0 is not a display string — it is the tail of
# a compressed picture that happens to be NUL-terminated before the pool begins — and
# it is counted because the code counts it. POOL_ANCHOR makes that explicit instead of
# leaving it to a lucky split.
POOL_FILE = "4C50_plane_landing_site.asm"
POOL_ANCHOR_STRING = "IN THE WATER."   # pool index 1
POOL_ANCHOR_INDEX = 1
# The pool sits on ONE db line with every entry quoted and separated by ,0x00,, which
# DB_RE deliberately does not match (it wants a single string per line). This reads the
# whole operand instead, so a build with no exe still gets the same table the exe does.
POOL_DB_RE = re.compile(r'^\s*db\s+(.*?)\s*#\s*string\s*$')
POOL_ITEM_RE = re.compile(r'"((?:[^"\\]|\\.)*)"')


def parse_asm_db_items(path):
    """Every quoted string on every `db ... # string` line of one asm file.

    parse_asm's DB_RE deliberately wants a single string per line, which is right for
    code and wrong for the data blobs — the bulk wave wrote the Z screen's separators as
    `db "S",0x00,"-",0x00` on one line and DB_RE sees none of it. This reads the whole
    operand. Returns [] when the file does not exist, so a caller can fall back.
    """
    items = []
    if not os.path.exists(path):
        return items
    with open(path, encoding="utf-8") as f:
        for line in f:
            m = POOL_DB_RE.match(line.rstrip("\n"))
            if m:
                items += [decode_gas_string(q) for q in POOL_ITEM_RE.findall(m.group(1))]
    return items
NAME_TABLES = [
    ("U2_T_WEAPONS", 0x13, 10),
    ("U2_T_ARMOUR",  0x1d, 8),
    ("U2_T_SPELLS",  0x24, 10),
    ("U2_T_ITEMS",   0x2e, 16),
    ("U2_T_STATS",   0x3e, 6),
    ("U2_T_RACES",   0x44, 4),
    ("U2_T_CLASSES", 0x48, 4),
]


def pool_from_exe(exe):
    """Split the pool region and return entries indexed the way the code indexes them.

    The split starts at the first display string, "IN THE WATER.", and one placeholder
    is prepended: the byte before it in the image is a second NUL, so the code's index
    base counts one entry that carries no text at all. That is what makes HANDS index 19,
    and pool_anchor_check asserts it rather than trusting the split.
    """
    first = exe.index(POOL_ANCHOR_STRING.encode("latin-1") + b"\0")
    ents = [b""] * POOL_ANCHOR_INDEX
    i = first
    while i < len(exe) and len(ents) < 96:
        if exe[i] == 0:
            i += 1
            continue
        j = exe.index(b"\0", i)
        ents.append(exe[i:j])
        i = j + 1
    return ents

def pool_from_asm(asm_dir):
    """The same pool from the db line of asm/POOL_FILE, for a build with no exe.

    The db list begins at pool index 1, so index 0 is filled with a placeholder: it is
    never displayed, and pool_anchor_check is what stops a drift here from becoming a
    wrong name on screen.
    """
    items = []
    with open(os.path.join(asm_dir, POOL_FILE), encoding="utf-8") as f:
        for line in f:
            m = POOL_DB_RE.match(line.rstrip("\n"))
            if not m:
                continue
            items = [decode_gas_string(q) for q in POOL_ITEM_RE.findall(m.group(1))]
            break
    anchor = POOL_ANCHOR_STRING.encode("latin-1")
    try:
        k = items.index(anchor)
    except ValueError:
        raise SystemExit(f"extractor: {POOL_FILE} has no {POOL_ANCHOR_STRING!r} db entry")
    return [b""] * POOL_ANCHOR_INDEX + items[k:]


def pool_anchor_check(ents, source):
    """Fail loudly rather than emit a table that puts PHASER where QUICK SWORD belongs."""
    if len(ents) <= 75 or ents[19] != b"HANDS" or ents[28] != b"QUICK SWORD":
        raise SystemExit(f"extractor: name pool anchor broken from {source} "
                         f"— HANDS is not index 19")


def emit_tables(ents):
    """C declarations for the seven groups, or [] when the pool is unavailable."""
    out = []
    for sym, base, count in NAME_TABLES:
        items = ents[base:base + count]
        if len(items) != count:
            raise SystemExit(f"extractor: pool too short for {sym}")
        out.append(f"#define {sym}_N {count}")
        out.append(f"static const char *const {sym}[{sym}_N] = {{")
        out.append("    " + ", ".join(c_escape(v) for v in items))
        out.append("};")
    return out


def c_escape(data):
    out = []
    for b in data:
        if b in (0x22, 0x5C):
            out.append("\\%c" % b)
        elif 0x20 <= b < 0x7F:
            out.append(chr(b))
        else:
            out.append("\\x%02x" % b)
    return '"' + "".join(out) + '"'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--exe", default=os.path.join(REPO, "original", "ultimaii.exe"))
    ap.add_argument("--source", choices=["auto", "exe", "asm"], default="auto")
    ap.add_argument("-o", "--out", default=os.path.join(ENGINE, "build", "gen_content.h"))
    ap.add_argument("--emit", choices=["header", "text"], default="header")
    ap.add_argument("--check", action="store_true",
                    help="fail if the existing output differs from what would be written")
    args = ap.parse_args()

    def warn(msg):
        print(msg, file=sys.stderr)

    exe = None
    note = "asm fallback (no exe supplied)"
    if args.source in ("auto", "exe") and os.path.exists(args.exe):
        exe = open(args.exe, "rb").read()
        md5 = hashlib.md5(exe).hexdigest()
        note = f"exe:{os.path.relpath(args.exe, REPO)} md5={md5}"
        if md5 != EXPECTED_MD5:
            warn(f"extractor: warning: {args.exe} md5 {md5} != {EXPECTED_MD5}")
    elif args.source == "exe":
        sys.exit(f"extractor: --exe {args.exe} not found")

    rows = collect("exe" if exe is not None else "asm", exe, args.exe, warn)

    asm_dir = os.path.join(REPO, "asm")
    try:
        pool = pool_from_exe(exe) if exe is not None else pool_from_asm(asm_dir)
        pool_anchor_check(pool, "exe" if exe is not None else POOL_FILE)
        tables = emit_tables(pool)
    except (SystemExit, FileNotFoundError, ValueError) as e:
        # The single-string table is what the engine has always built against, so a pool
        # that cannot be reconstructed must not take it down: warn loudly, emit no
        # tables, and let whatever needs them fail at its own gate. docs/status-screen-z.md
        # § 7 records why the asm fallback cannot supply the pool today.
        warn(f"extractor: name pool unavailable ({e}); emitting no tables")
        tables = []

    if args.emit == "text":
        for sym, val, _ in rows:
            print(f"{sym}\t{val.decode('latin-1')}")
        return 0

    body = [
        "/* GENERATED by engine/tools/extract/extractor.py — do not edit, do not commit.",
        " *",
        " * Game content extracted at build time from the user's own copy.",
        f" * Source: {note}",
        " * These strings belong to the copyright holder of Ultima II; the engine",
        " * reads them from a file it does not ship. See engine/README.md.",
        " */",
        "#ifndef U2_GEN_CONTENT_H",
        "#define U2_GEN_CONTENT_H",
        "",
        f'#define U2_CONTENT_SOURCE "{note}"',
        "",
    ]
    for sym, val, origin in rows:
        body.append(f"/* {origin} */")
        body.append(f"#define {sym} {c_escape(val)}")
    if tables:
        body += ["", "/* Indexed name pool, file 0x4F53.. — see the extractor's NAME_TABLES "
                 "comment for\n * how the Z screen's group offsets pin each base. */"]
        body += tables
    body += ["", "#endif /* U2_GEN_CONTENT_H */", ""]
    text = "\n".join(body)

    if args.check:
        cur = ""
        if os.path.exists(args.out):
            cur = open(args.out, encoding="utf-8").read()
        if cur != text:
            warn(f"extractor: {args.out} is stale or missing")
            return 1
        return 0

    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as f:
        f.write(text)
    print(f"extractor: wrote {os.path.relpath(args.out, REPO)} "
          f"({len(rows)} strings, {note})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
