# Assets

Approved Wallforge project assets live here (see [`design.md`](../design.md) §30).

Suggested layout:

```text
assets/
├── images/
├── icons/
├── audio/
└── fonts/
```

## Rules

- Prefer vector assets where they provide a clear benefit.
- Avoid unnecessarily large raster images.
- Do **not** depend on the rejected Google Stitch export folder.

No assets are added in Phase 0. Empty subfolders are intentionally not created,
because Flutter requires registered asset paths in `pubspec.yaml` and adds no
value when empty.

## Licences

- `fonts/InterVariable.ttf` — Inter, SIL Open Font License 1.1
  (the licence text ships beside it as `fonts/OFL.txt`).
- `audio/` (Phase 12) — every file (`button.wav`, `move.wav`,
  `wall.wav`, `invalid.wav`, `turn.wav`, `victory.wav`, `music.mp3`)
  was synthesized for this project by `tool/audio/generate_audio.py`;
  no third-party audio is included. Released under CC0 1.0 Universal —
  the licence text ships beside the files as `audio/LICENCE.txt`.
  Total size 152 KB.
