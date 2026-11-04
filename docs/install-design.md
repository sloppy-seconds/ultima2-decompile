# Installer design — building a game directory out of a pile of media

Status: **design only, nothing implemented.** This document takes over as the entry
point for everything about *assembling* a playable tree, and it inherits the parts
of `docs/handoff-themes-builder.md` that were never built. That handover is now
**locked off** — its slice C list is folded into § 10 below rather than left in a
handover, because handovers are entry points and this is the one.

**The five open decisions were ruled on 2026-11-04** and the rulings are recorded in
§ 11, along with two that came out of them (D6, D7). One point is still open and it
needs an answer before any code: D7 and the re-run rule contradict each other as
written, and § 11 proposes the resolution rather than choosing silently.

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
| `--install --to DIR` | build a game tree at DIR from the supplied sources | DIR |
| `--install --check` | inventory a tree and report what is missing, stale or unexpected | nothing |
| `--original-dir DIR` | the original DOS release: an unzipped IA copy, a CD rip, or an existing emulator directory | — |
| `--updated-dir DIR` | the Galaxy patch layer (`updated/`, or a tree where the patch already ran) | — |
| `--themes-dir DIR` | the fan art package (a `U2Upgrade` directory or the patcher archive) | — |
| `--media-dir DIR` | reserved for optional extras, e.g. the FM Towns disc (§ 5) | — |

Every question the installer can ask has a flag, so nothing about its behaviour
requires a keyboard. `--to` is the target and is required; the source flags are what
a prompt would otherwise ask for, and a prompt is only ever the fallback (§ 8).

Three rules about the shape:

1. **Declarative first, prompts second.** Every input has a flag. Interactive
   prompting is only the fallback when a required input is missing, and it is the
   last thing written, because a prompt loop cannot be gated.
2. **It runs before video init**, like the other tool modes. An installer that
   needs a display is useless on a headless box, and headless is where it gets
   tested.
3. **Re-running is normal and must be safe.** The realistic sequence is install the
   original, play for a week, discover the upgrade pack, re-run. So `--install` is
   `--check` plus a write, not a separate code path. What exactly "re-running" means
   against a target that already exists is the open point in § 11.

## 3. Target layout — ruled: option B, explicit layers

*Ruled 2026-11-04: B.* The installed tree is `data/original/` + `data/updated/`,
and `world.c` learns both names. The owner's reasoning: explicit layers are easier
to keep idempotent, easier to extend with a further layer later, and obviously
organised to a human who opens the directory.

The formulation that stops this becoming two layouts: the content root becomes an
**ordered list of roots**, not a single path.

```
data/updated/     <- patch layer, wins
data/original/    <- release layer
```

and for the drop-in case, which stays required:

```
./updated/        <- patch layer, wins
./                <- release layer
```

Layer order is fixed (patch over release) and within one root the existing
`MAPG` / `mapg` / `mapx` try-order is untouched. Drop-in is then the degenerate case
of the same mechanism rather than a special path, which is what makes "both work" a
claim the gate can test instead of a hope. Note the trap to avoid: the fan patch's
own `RENGAL.BAT` *renames* `mapx` to `mapg` in place. The installer copies verbatim
and lets precedence choose; it never runs that rename.

What was on the table, kept as the record of why B and not A:

| option | shape | cost |
| --- | --- | --- |
| A. engine-native | `data/` holds the release files, `data/updated/` holds the patch files, verbatim | zero engine change, but the directory name is a magic string the installer must keep in step with `world.c`, and it says nothing to a human opening the folder |
| **B. explicit layers** *(chosen)* | `data/original/`, `data/updated/`, and `world.c` learns both names | one engine change now, and the layout states what it means instead of encoding it in a name |

A was the smaller change and B was rejected only on the strength of the reasoning in
the first paragraph: A's zero-cost claim is real for the first version and false for
every version after it, because every later layer has to be squeezed into a naming
convention rather than added to a list.

Three parts, plus the config file:

* `data/` — the game content. **Not immutable**: D6 below keeps sector write-back
  here, so an installed tree is expected to drift under play.
* `saves/` — the live `player` file. This matters beyond tidiness: the original
  rewrites `player` in place, which is why `AGENTS.md` says never run the game in
  place. If `data/` keeps the installed copy and `saves/` holds the live one, a DOS
  run and an engine run stop fighting over the same file.
* `themes/` — built by the same code as `tools/build_themes.py`, shared rather than
  reimplemented (§ 10).
* `config.ini` in the game directory, naming the three.

**D6 — sector write-back stays where it is, for now.** *measured* —
`u2_world_store` writes changed sectors into the content directory it read from,
using the bare prefix recorded at load, and checks writability at store time
precisely so a read-only content dir is tolerated rather than fatal. The owner ruled
that this stays as it is and is re-addressed when the save-game mechanisms are
updated. The consequence is not cosmetic, and it is recorded here so the gate does
not contradict it: **an installed tree is allowed to differ from what the installer
wrote**, so `--install --check` must separate "these sector files have been played
in" (expected, report as a note) from "this file is missing or a stray appeared"
(red). A check that goes red the first time someone plays is a check that will be
ignored.

## 4. Config file and precedence — ruled: `config.ini`, global

*Ruled 2026-11-04.* The global file is `config.ini`, and it keeps the `key = value`
grammar `THEME.INI` already uses, so there is one parser and one set of refusals
rather than two.

**`THEME.INI` stays per-theme and is not folded in.** The two files have different
subjects, different writers and different lifetimes:

| file | subject | written by | read when |
| --- | --- | --- | --- |
| `config.ini` | where things are, what the user prefers | the installer, and the user | every startup |
| `<theme>/THEME.INI` | what the art in *that directory* is: tile size, bpp, bank layout, palette, scope, `MAP.TSV` | `tools/build_themes.py` | when that theme is selected |

Three reasons the per-theme file cannot move into a global one:

* the engine resolves a theme by name from the themes directory and must be able to
  do it with no global file present at all
* the metadata travels with the art — copy a theme directory in and it works,
  whereas a global config would need an edit per theme
* the builder emits it as part of emitting a theme and `--verify` re-derives it to
  catch drift. If installing a theme mutated one shared file, then installing two
  themes is two writes to the same file, and the idempotence story gets worse
  rather than better

What does go in `config.ini` is a `[themes]` section for the settings side: the
themes directory, the selected theme, and anything else that is a preference rather
than a fact about the art.

Precedence, and this is the part that must be explicit or the feature rots:

```
command line  >  config.ini  >  nothing
```

* An explicit path from either source is **authoritative with no fall-through**.
  That is the `[LOCKED]` rule from `docs/ega-graphics-plan.md` § 2 for
  `--ega-theme-dir`, and a config file is a second place a path can come from, so
  it inherits the rule: a typo in the ini is reported, never papered over by
  finding the theme somewhere else.
* **The shipped artifact stops carrying dev fallbacks.** `references/u2upgrade`
  stays a candidate for a developer checkout (driven by the ini or the flags) and
  disappears from the release build, which is what `U2_ARTIFACT=release` is for.
* A `config.ini` naming a directory that does not exist is an error at startup, not
  a silent default.

**Where the code lives.** *ruled* — `--install` ships in both builds and is purely
text/terminal, needing no SDL, which is what makes it testable headless and in CI.
The consequence is structural: the installer goes in `engine/src/core/`, not
`platform/`, and must not reach for a renderer at all.

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
3. **Idempotent.** A second run changes nothing and says so — which needs the § 11
   open point settled, because "a second run" and "the target must be empty" do not
   yet agree. Note also that idempotence is about the installer's output, not about
   the tree being frozen: D6 lets play itself change sector files.
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
   missing. File set and sizes, with the D6 carve-out: content drift in the
   writable sector files is expected once someone plays
2. every copied file is byte-identical to its source
3. the engine, pointed at the installed tree with **no other flags**, loads Earth
   *and* at least one outer planet — this is the assertion that proves the patch
   layer did something, and the only one that catches "copied the files, planets
   still missing"
4. re-running the install is a no-op, once § 11 settles what re-running into a tree
   we already built means
5. `--install --check` goes red on a deliberately broken tree (a missing `TLKG81`,
   a truncated `EGATILES`, a stale theme)
6. the source directory is byte-for-byte untouched

Plus one structural rule about how it is run: **the binary is invoked from a third
directory** — neither the install target nor a source — so any cwd or self-path
assumption fails loudly instead of working by accident on the developer's machine.

## 8. Cleanup: reorganise into a new directory, never touch the old one

*Ruled 2026-11-04, and it is a better answer than the one this section started
with.* A player who has been running the game under DOSBox or a similar emulator may
already have a directory holding some or all of this content. The first draft
treated "clean up an existing install" as a destructive mode with a confirmation
flow. The ruling removes the category: **the installer does not clean anything up,
it builds a new tree somewhere else.**

* `--to DIR` accepts an **empty directory, or one that does not exist and is
  created**. Anything else is refused. There is no merge, no overwrite and no
  deletion, so the mode has no destructive path to get wrong.
* The existing emulator directory is then just another **source** — § 5 recognises a
  tree where the patch already ran, which is the common case in the wild — and the
  old install keeps working under DOSBox until the player decides otherwise.
  Deleting it is their call, made later, with a file manager and a backup.
* This is why detection and cleanup were the same code path in the first draft. A
  directory where `RENGAL.BAT` already ran has `mapg` where the release had `mapx`,
  and a tool that classifies by expected-name-then-delete reads that as junk when it
  is the Galaxy patch already applied. Under this ruling the misclassification is no
  longer dangerous, which is the argument for it.
* `AGENTS.md` has a standing incident about an agent deleting irreplaceable files it
  was confident about. A mode whose worst failure is "refused: directory not empty"
  is the shape this project should prefer on principle.

One case survives the ruling and needs an explicit answer: if the source directory
holds the player's own `player` save, adopting it is a **migration**, not a cleanup.
The installer should ask, and must never silently overwrite the `player` file it
just installed into `saves/`.

## 9. Self-update: ruled out

*Ruled 2026-11-04: out.* The reasoning stays below, because it is the record of why,
and because the cheap half is still a reasonable thing to want someday.

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
| asking the player for the art package | § 5, `--themes-dir` |
| the FM Towns disc as an optional source | § 5, `--media-dir` (deferred, § 11) |
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

## 11. Decisions

Ruled 2026-11-04, in the order they were asked:

| # | decision | ruling |
| --- | --- | --- |
| 1 | Layout | **B** — `data/original/` + `data/updated/`, with `./` + `./updated/` still working for the drop-in case (§ 3) |
| 2 | Config file | **`config.ini`**, global, same grammar as `THEME.INI`; `THEME.INI` stays per-theme; a `[themes]` section carries the settings (§ 4) |
| 3 | Which builds | **both**, and `--install` is purely terminal with no SDL, so it runs headless and in CI; the code lives in `engine/src/core/` (§ 4) |
| 4 | FM Towns disc | **follow up later** — not in the first version, though § 5 still recognises it as a source |
| 5 | Self-update | **out** (§ 9) |
| D6 | Sector write-back | **stays in the content dir for now**, re-addressed with the save-game mechanisms; the gate must tolerate play drift (§ 3) |
| D7 | `--to` target | **empty or nonexistent only** (§ 8) |

**One open point, created by D7.** D7 says the target must be empty. § 2 rule 3 says
re-running is normal and must be safe — install the release, play for a week,
discover the upgrade pack, add it. Those two cannot both hold as written, and the
resolution needs a ruling rather than a silent choice:

* **Proposal: recognise our own tree.** The installer writes a manifest of what it
  emitted, exactly as `themes/_BUILD.tsv` already does for the theme builder. An
  empty target is installable; a target carrying a valid manifest is *completable*
  — `--check` says which layers it has and which are missing, and `--install` adds
  the missing ones and re-verifies. A target that is non-empty with no manifest is
  refused, which is the case D7 was protecting. This keeps the re-run story, keeps
  idempotence provable, and still never touches a directory the installer did not
  build.
* The alternative is that adding a layer means a fresh `--to` and a discarded tree.
  Simpler, but it throws away the saves unless they live outside the game directory,
  and it makes "re-running is a no-op" untestable.

Recommend the first. It is also the pattern the theme builder already proved, which
is worth something: emit, record what was emitted, re-derive and diff.
