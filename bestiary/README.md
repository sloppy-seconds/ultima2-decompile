# bestiary/

Community creature data for Ultima II, joined to our own tile table by bitmap
identity. **Read `docs/bestiary.md` for the method, the evidence grades and the
conflicts.** This file is only the operating instructions.

## Layout

| path | what | git |
| --- | --- | --- |
| `bestiary.tsv` | the join: art index, name, source, variant, verdict, stats, image hash | committed — our own derived facts |
| `matches.md` | the same, rendered as a table for reading | committed |
| `README.md` | this file | committed |
| `cache/` | raw HTML, parsed JSON, and **copyrighted art rips in 7 platform variants** plus FM Towns frame strips | **gitignored — never commit** |
| `view.html` | the viewer, with every image embedded as a data URI | **gitignored — never commit** |

## Run it

```sh
python3 tools/bestiary_fetch.py          # network: two pages + their images
python3 tools/bestiary_fetch.py --offline # re-parse what is already cached
python3 tools/bestiary_match.py --self-test   # 6 controls; must pass
python3 tools/bestiary_match.py --md          # regenerate bestiary.tsv + matches.md
python3 tools/bestiary_view.py                # regenerate view.html
```

Open `bestiary/view.html` in a browser. It makes no network requests. Pick a
platform to compare our tile against that variant's art; FM Towns cards also show
the extracted animation frame strip. Filter by name; cards with no matched tile are
dimmed.

## Two rules about this directory

1. **Nothing under `cache/` or `view.html` goes in git.** They are copyrighted game
   art. Only the derived table and the prose are ours to commit.
2. **This directory is forbidden to anyone drawing substitute tile art.** It holds
   the originals in more variants than `original/` does. It is listed in the
   forbidden table of `docs/tile-art-spec.md` § 2 and `docs/cleanroom-procedure.md`.
   If you are doing a redraw, close this folder.

## Regenerating from scratch

`cache/` is disposable. Delete it and rerun `bestiary_fetch.py` to rebuild; the
manifest records a sha256 and fetch timestamp per file, so a re-run is also how you
notice the upstream pages changed.
