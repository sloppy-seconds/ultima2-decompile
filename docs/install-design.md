# Installer design — building a game directory out of a pile of media

Status: **design only, nothing implemented.** This document takes over as the entry
point for everything about *assembling* a playable tree, and it inherits the parts
of `docs/handoff-themes-builder.md` that were never built. That handover is now
**locked off** — its slice C list is folded into § 10 below rather than left in a
handover, because handovers are entry points and this is the one.

Prerequisite reading: `AGENTS.md`, then `docs/theme-format.md` (the contract for
what a themes directory holds), then `docs/planet-maps-galaxy-patch.md` (why the
outer planets need a fan patch at all).

Grades per `AGENTS.md` § 5. Claims marked *measured* were checked against the tree
on 2026-11-04; claims marked *proposal* are decisions being asked for, not facts.

---

## 0. The problem, stated honestly

Today the shipped artifact is a single binary that you drop next to the game files
and hope. `--data-dir` and `--save-dir` point at things, and if the player's
directory is missing a file the engine reports what it could not find — which is
good behaviour for an engine and a poor story for a person who has downloaded a
1982 game in three zips from two different projects.

Two facts make this worse than a copy operation:

* The game's content is **layered**. `original/` is the DOS release; `updated/` is
  the fan Galaxy patch carrying `MAPG*`/`MONG*`/`TLKG*`, which are the outer
  planets the floppy release lost to an MS-DOS filename collision
  (`MAPG10` vs `mapx10`). A tree with only the first layer is a game with one
  planet, and it runs perfectly happily, so the player cannot tell.
* The shipped binary currently **knows where a developer's checkout lives**:
  `references/u2upgrade` is a fallback candidate in both the theme and picture
  resolution orders. That is a dev convenience baked into a player artifact, and an
  installer that writes an explicit config is the honest place to delete it.

**Both modes must keep working.** "Drop the binary in the Internet Archive copy and
run it" is true today and stays true; the installer is additive, not a
prerequisite. If that drifts into requiring the installer, the artifact has become
worse than the thing it replaces.

## 1. Why the installer lives in the binary

*measured* — `engine/src/core/world.c` already resolves content with a
patched-first candidate list: `updated/MAPG` → `updated/mapg` → `MAPG` → `mapx`,
and the same shape for `MONG` and `TLKG`, recording the bare prefix on write-back
so a map read from `updated/` still stores under a legal root name.

That ordering is the whole Galaxy-patch mechanism, and it is the reason the
installer should not be a separate script: a second implementation of "which file
wins" in another language is free to drift from the one the engine actually uses,
and the failure is silent — "I copied everything and the planets still do not
work". Same argument for themes: `docs/theme-format.md` is a contract between the
builder and `tiles_ega.c`, and every bug in this thread so far came from the two
sides of that contract disagreeing.

Secondary reasons, in order of weight:

* No interpreter on the target. A player artifact should not require Python.
* The installer becomes testable by the same CP harness as the engine, which is the
  only kind of test this project trusts.
* *measured* — the binary already has a tool family that prints and exits ahead of
  the game: `--version`, `--licenses`, `--video-drivers`. `--install` is not a new
  kind of thing, it is the fourth member.
* It gives a future self-update a place to live (§ 9).

## 2. Modes

| mode | what it does | writes |
| --- | --- | --- |
| `--install` | build a game tree from the supplied sources | yes |
| `--install --check` | inventory an existing tree and report what is missing, stale or unexpected | nothing |
| `--install --from DIR` | the original DOS release (an unzipped IA copy, a CD rip, anything) | — |
| `--install --upgrade DIR` | the Galaxy patch directory (`updated/`, or a tree where the patch already ran) | — |
| `--install --themes DIR` | the fan art package (a `U2Upgrade` directory or the patcher archive) | — |
| `--install --media DIR` | optional extras, e.g. the FM Towns disc, for derived themes | — |

Three rules about the shape:

1. **Declarative first, prompts second.** Every input has a flag. Interactive
   prompting is only the fallback when a required input is missing, and it is the
   last thing written, because a prompt loop cannot be gated.
2. **It runs before video init**, like the other tool modes. An installer that
   needs a display is useless on a headless box, and headless is where it gets
   tested.
3. **Re-running is normal and must be safe.** The realistic sequence is install the
   original, play for a week, discover the upgrade pack, re-run. So `--install` is
   `--check` plus a write, not a separate code path.

## 3. Target layout — the open decision

*proposal, needs a ruling.* The engine's resolution order today expects the patch
in a subdirectory literally named `updated/` (or the patched files at the root).
The layout floated in discussion was `data/original` + `data/updated`, which is
clearer to a human and matches nothing the engine currently looks for.

| option | shape | cost |
| --- | --- | --- |
| **A. engine-native** | `data/` holds the release files, `data/updated/` holds the patch files, verbatim | zero engine change; the directory name is a magic string the installer must keep in step with `world.c` |
| **B. explicit layers** | `data/original/`, `data/updated/`, and `world.c` learns both names | one engine change now, and the layout says what it means instead of encoding it in a name |

Recommendation: **A for the first version**, because it copies verbatim and lets the
existing resolution order do the work, and because a rename is a transformation the
installer then has to defend. Note the trap A avoids: the fan patch's own
`RENGAL.BAT` *renames* `mapx` to `mapg` in place. An installer that runs that rename
mutates the content; one that copies verbatim leaves the engine's precedence to
choose. Take the second.

Whatever the layout, three parts are fixed:

* `data/` — the game content, treated as read-only after install.
* `saves/` — the live `player` file and any sector files. This matters beyond
  tidiness: the original rewrites `player` in place, which is why `AGENTS.md` says
  never run the game in place. If `data/` keeps a pristine copy and `saves/` holds
  the live one, a DOS run and an engine run stop fighting over the same file.
* `themes/` — built by the same code as `tools/build_themes.py`, shared rather than
  reimplemented (§ 10).

And `ultima2.ini` in the game directory, naming the three.

## 4. Config file and precedence

*proposal.* `ultima2.ini` is a small `key = value` file — the same grammar
`THEME.INI` already uses, so there is one parser and one set of refusals, not two.

Precedence, and this is the part that must be explicit or the feature rots:

```
command line  >  ultima2.ini  >  nothing
```

* An explicit path from either source is **authoritative with no fall-through**.
  That is the `[LOCKED]` rule from `docs/ega-graphics-plan.md` § 2 for
  `--ega-theme-dir`, and a config file is a second place a path can come from, so
  it inherits the rule: a typo in the ini is reported, never papered over by
  finding the theme somewhere else.
* **The shipped artifact stops carrying dev fallbacks.** `references/u2upgrade`
  stays a candidate for a developer checkout (driven by the ini or the flags) and
  disappears from the release build, which is what `U2_ARTIFACT=release` is for.
* An ini naming a directory that does not exist is an error at startup, not a
  silent default.

## 5. Inputs it must recognise

Discovery is **by content, never by name** — the lesson from the theme builder,
where keying on `EGATHEME.*` produced a tree with no themes in it.

| input | how it is recognised | note |
| --- | --- | --- |
| original DOS release | presence of `ultimaii.exe` plus `mapx*`/`monx*`/`tlkx*` | an IA zip, a CD rip, or a directory someone has already unpacked |
| Galaxy patch | a directory holding `MAPG*`/`MONG*`/`TLKG*` | often named `updated/`, but the name is not the evidence |
| **a tree where the patch already ran** | `mapg*` sitting beside `monx*` at the root | this is an *input*, not a mess to clean up — see § 8 |
| fan art package | a directory containing a tile atlas, at any name or depth | *measured* — `references/up/Files/U2Upgrade` and `references/u2upgrade` differ in exactly three files (`U2.CFG`, `u2up.exe`, `u2upw.exe`); all art is byte-identical, so either is a valid source and the version drift is in the patcher's own binaries |
| FM Towns disc | the `.img` with `GRAPH/*.TIF` inside | optional; produces a derived v2 theme, and needs the crosswalk, so it is a developer-box feature before it is a player feature |
| themes | reshaped into the layout `docs/theme-format.md` specifies | the vendor's directory names and depth are not our layout |

The patcher is **linked, never bundled**:
`https://github.com/Fenyx4/UltimaPatcher/releases/download/1.70/UltimaPatcher.zip`.
That is also the only posture compatible with `AGENTS.md` — the art is Origin's and
the patcher is a third party's, so the installer asks the player to supply both and
writes only into the player's own directory.

## 6. Invariants

These are the rules that make the difference between a tool that feels solid and
one that feels magical, and every one of them is here because of something that
went wrong in this project.

1. **Never write into a source.** Hash the source tree before and after, and prove
   it is untouched. `tools/build_themes.py` already refuses to write into
   `original/` or `references/`; the installer inherits that rule and the proof.
2. **Byte-identical copies, no transforms.** No renames, no case-fixing, no
   `RENGAL.BAT`. A transformation is a claim, and claims need evidence.
3. **Idempotent.** A second run changes nothing and says so.
4. **Location-independent.** Everything resolves from argv and the ini, never from
   where the binary sits. *measured* — deriving paths from the script's own
   location is exactly what emitted `themes/ultima2/EGATHEME.C64/` when the theme
   builder was run beside the game on another machine, and the engine then refused
   every theme by name while the builder reported success.
5. **Verify by re-derivation, not by "the copy returned 0".** Build, then
   re-derive what the tree should contain and diff it. A gate that cannot go red in
   the place it enforces is worse than no gate.
6. **Every state change is reported.** The owner's rule for the game applies to the
   tool: no silent mutation.

## 7. The gate

Greenfield is easy to test, and a tmp-dir run is only a gate if it asserts the
**result** rather than the run. The fixture sources already exist on a dev box:
`references/ultima2/` (pristine release), `references/up/Files/U2Upgrade` (the
patcher's own tree), `references/fmtowns/` (the disc).

Six assertions, each written red-first per `AGENTS.md` § 3:

1. the installed tree is **exactly** the expected file set — no strays, nothing
   missing
2. every copied file is byte-identical to its source
3. the engine, pointed at the installed tree with **no other flags**, loads Earth
   *and* at least one outer planet — this is the assertion that proves the patch
   layer did something, and the only one that catches "copied the files, planets
   still missing"
4. re-running the install is a no-op
5. `--install --check` goes red on a deliberately broken tree (a missing `TLKG81`,
   a truncated `EGATILES`, a stale theme)
6. the source directory is byte-for-byte untouched

Plus one structural rule about how it is run: **the binary is invoked from a third
directory** — neither the install target nor a source — so any cwd or self-path
assumption fails loudly instead of working by accident on the developer's machine.

## 8. Stretch goal: cleaning up an existing install

A player who has been running the game under DOSBox or a similar emulator may
already have a directory holding some or all of this content. The instinct to tidy
it is right and the risk is out of proportion to the reward, so:

* **v1 is read-only.** `--install --check` reports "you appear to already have a
  working install at X, and here is what differs from what an install would
  produce". No deletion, no moving, no "recommended cleanup".
* **Detection and cleanup are the same code path**, and the interesting case proves
  it: a directory where `RENGAL.BAT` already ran has `mapg` where the release had
  `mapx`. That is the Galaxy patch already applied — an **input** to recognise, not
  junk to remove. A tool that classifies by expected-name-then-delete gets this
  exactly backwards.
* Such a directory may also hold the player's own saves and their emulator config,
  which are the only files in the whole arrangement that cannot be re-downloaded.
  `AGENTS.md` has a standing incident about an agent deleting irreplaceable files it
  was confident about; a cleanup mode is that failure mode with a friendlier face.
* If deletion ever ships, it is per-item, explicit, confirmed, and it copies
  anything irreplaceable somewhere safe and says where first.

## 9. Self-update: split it in two

*measured* — the pieces already exist. The binary stamps `U2_VERSION`,
`U2_BUILD_TARGET`, `U2_SDL_IMPL`, `U2_SDL_LINKAGE` and `U2_ARTIFACT`, prints them
under `--version`, and `release-builds.yml` publishes assets plus a
`SHA256SUMS.txt` on a `v*` tag, and refuses to ship a dev-shaped build.

Splitting it matters because the two halves have completely different costs:

* **`--check-update` (cheap, no new trust).** Compare the stamped version against a
  published list over HTTPS, print "a newer release exists at URL", download
  nothing. This builds the channel plumbing and the version comparison under test
  with none of the risk.
* **Self-replacement (expensive, and not now).** Three reasons, in order:
  1. A checksum fetched from the same origin as the binary proves nothing. If the
     channel is compromised the sums are too. The releases are **not signed
     today**, so the first requirement is signing them, not writing the downloader.
  2. It undermines a guarantee the release workflow deliberately enforces: the
     binary identifies itself as the release build precisely so that "v0.0.7 does
     not work" is answerable. A self-mutating binary breaks that unless it records
     what it updated from and to and keeps the previous binary rather than
     overwriting it.
  3. Windows cannot overwrite a running executable — rename-then-replace — and the
     release workflow deliberately never executes the Windows binary, so that path
     would ship untested.

## 10. What the theme work leaves behind

**Done and gated** (see `docs/theme-format.md` for the contract): the v1 and v2
loaders, content-based theme discovery, the reshaped `default/` theme, the FM Towns
v2 derivation, `--ega` compositing at 640×400 with the doubled-dump ruling, the
theme palette driving both the renderer and the text ink, `tools/build_themes.py`
with 19 controls, and `engine/tests/theme_v2_check.c` with 39 checks including six
refusals.

**Inherited by the installer** — these were theme-handover items and they are now
this document's problem:

| item | where it lands |
| --- | --- |
| asking the player for the art package | § 5, `--themes` |
| the FM Towns disc as an optional source | § 5, `--media` |
| `themes/` being built rather than hand-copied | § 3, shared code with `build_themes.py` |
| the dev-checkout fallbacks going away in a release build | § 4 |

**Still engine work, not installer work** — unchanged from the handover's slice C,
and still held:

* animation (frame lists are already carried in `MAP.TSV`; needs a tick source and
  a game-tick-vs-wall-clock decision)
* the `PLAYER` bank, which needs a second mapping key, not more rows
* dungeon and tower art, and whether dungeon appearance comes from the map byte at
  all
* horse and boat directional variants; per-planet terrain beyond tile 17
* per-theme pictures — `EGATHEME.10` and `EGATHEME.C64` ship their own `PICDNG` and
  `PICSPA` and they genuinely differ, but `pic_ega.c` resolves pictures at the
  themes-dir top level only
* the `EGACOLOR` remap, decoded and understood, wired to nothing
* per-screen FM Towns palettes, unproven

## 11. Decisions needed before any of this is built

1. **Layout**: option A (engine-native, verbatim) or option B (explicit layers plus
   a `world.c` change). § 3 recommends A.
2. **The ini**: name, and whether it reuses the `THEME.INI` grammar or grows a
   shared config parser.
3. **Which binaries ship `--install`**: the static SDL artifact only, or the
   terminal build too (the terminal build is what CI can actually execute).
4. **Is the FM Towns disc in scope for v1**, given the derivation needs the
   crosswalk and the disc, neither of which ships?
5. **Self-update**: confirm it is out, and whether signing releases is worth doing
   now on its own merits.
