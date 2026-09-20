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
