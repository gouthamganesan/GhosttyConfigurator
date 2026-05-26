# Branding assets

## `logo-source.png`

Master logo for **Ghostty Configurator**. 1254×1254 PNG, RGB (no alpha), black background.

Design: a terminal window with the standard three traffic-light dots in cyan and a shell prompt (`> _`) in cyan, with a ghost mascot in front holding a `{=}` config-block glyph in its mouth. White outlines, cyan accents (`#~00E5FF`), on pure black.

Use this single file as the source for **every** rendering:

| Use | Conversion |
|---|---|
| macOS app icon (`Assets.xcassets/AppIcon.appiconset/`) | Downscale to 1024×1024, then let Xcode 14+ "Single Size" app icon generate all 10 required sizes. Alternatively, generate manually with `sips` — see `scripts/generate-app-icon.sh` (to be authored in Phase 0). |
| About pane hero icon (in-app) | Use the source PNG via an asset catalog `Logo.imageset` with 1x / 2x / 3x variants (e.g. 64pt → 64/128/192px). Renders on top of the grouped section's background; the black square reads as a deliberate tile. |
| DMG window icon | macOS Finder uses the `.app`'s embedded icon automatically — no extra work. |
| Sidebar tile in System Settings sidebar | **Not used.** Sidebar tiles use SF Symbols per section per [02-information-architecture.md](../../docs/02-information-architecture.md). The logo is the *app's* identity, not a section identity. |
| GitHub repo social preview / README banner | Use source PNG directly. |
| Landing page favicon | Convert via `sips -z 64 64 logo-source.png --out favicon.png` or use a favicon generator. |

## Conversion notes

- **No transparent-background variant yet.** The black square is deliberate; works on both light and dark Finder backgrounds because the macOS app-icon mask is a rounded squircle that clips evenly.
- **If a transparent variant is ever needed** (e.g. for a watermark over a screenshot), crop to just the terminal + ghost; preserve aspect of the asymmetric composition.
- **Color accent (`#00E5FF` approximate)** — sample exactly with Digital Color Meter before introducing a Swift `Color` constant; use it in `Tokens.swift` as `Color.brandAccent` if it differs from `Color.cyan`.
