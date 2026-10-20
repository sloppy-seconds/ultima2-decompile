# Phase 3.5 — Naming Pass (log)

Goal (owner-approved post-CP6): rename `sub_*` functions where evidence is
provable — honest naming only, `check_func.py` green throughout. Better names
in later passes was the CP3 directive; this is pass 1.

## Method

Evidence table built from the cleaned tree (`/var/tmp/naming-evidence.json`):
per-function strings, call/jump targets, fan-in (references from other
functions), INT/port seams. Renames applied only where the evidence is direct:
* **system wrappers** — recognizable INT/port shapes (`key_poll` = int16 ah=1,
  `char_out` = int10 ah=1, `speaker_freq` = PIT port 0x42 latches),
* **string evidence** — the function's own inline messages (`tavern_menu`,
  `combat_minax_attack`, `status_torches`, `show_hitpoints`, …),
* **structural anchors** — Phase 2 facts (`cmd_dispatch` = the cs:0x730 jump
  table; `cmd_done` = the 59-site handler return that prints CR).

Every renamed file carries a `# name-evidence:` header line. Renames touch
only the file name + header + entry label; cross-function references are
address labels (`L_<file-offset>`), so nothing else moves. Each rename
re-verified with `check_func.py`; full sweeps green after every batch:
`check_func` 1299/1299, `assemble_clean.sh` byte-identical.

## Batches

| Batch | Commit | Count | Content |
| --- | --- | --- | --- |
| 1 | naming batch 1 | 11 | core I/O + system wrappers: `char_out`, `char_print(_wrap)`, `str_out_at`, `str_out_core`, `key_poll`, `rand_byte`, `cmd_done`, `timed_wait`, `map_tile_ptr`, `speaker_freq` |
| 2 | naming batch 2 | 71 | string-evidence names: combat events, shops/taverns/shrines, street NPCs, status lines, shop headers, dungeon/space events, `cast_spell_flow`, `illegal_command_msg`, `msg_wrong_disk` |
| 3 | naming corrections | +1 / −1 | added `cmd_dispatch` (0A1F); **reverted** `cmd_prompt_loop` (277B is a mis-decode region — evidence did not support the claim); softened `show_year_1990/2112` and `plane_landing_site` to display-only claims |

## Result

* **109 meaningfully named** functions (26 `cmd_*` + `str_out` from the pilot,
  82 from this pass), each with `name-evidence`.
* **1187 remain `sub_*`** — honest: they need behavioral tracing (data-flow,
  selfmod interactions, overlay structure), not string/fan-in heuristics.
  That is pass-2 / Phase 4 territory.
* Invariants: `check_func` 1299/1299, `assemble_all` and `assemble_clean`
  byte-identical.

## Explicitly rejected (kept `sub_*`)

`508C` (7-byte fragment, no ret — falls into next map fragment),
`53B5`/`0711`/`1040` (plausible but unproven roles), `2290` (writes into the
selfmod area — semantics runtime-dependent), `67B3`/`0DC4`/`0C62` (need full
body reads). Guessing names here would violate the CP3 honesty directive.
