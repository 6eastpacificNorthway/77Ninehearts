# PS2 Horror Aesthetic — GMod Addon

A Garry's Mod addon that replicates the look of early-2000s PS2 survival horror games (specifically *Haunting Ground* — cyan-shifted shadows, warm crushed highlights, 8×8 Bayer dithering, chromatic aberration, subtle scanlines).

Two render paths:
1. **Native** — custom HLSL pixel shader via Source's `screenspace_general`. Authentic, cheap, correct dithering.
2. **Lua fallback** — automatic when native shaders aren't installed. Uses `DrawColorModify` + a baked LUT + a Bayer texture overlay. Good enough, not identical.

The addon auto-detects which path to use per client.

## Quickstart — for server admins

1. Clone this repo.
2. Push to your own GitHub. First push triggers GitHub Actions to compile the shaders on a Windows runner; the workflow commits the resulting `.vcs` files back to the repo with `[skip ci]`.
3. Wait for the CI to finish (~2 minutes). Check the latest commit for a `shaders/fxc/*.vcs` file and a `shaders/_manifest.json` showing what was compiled.
4. Upload the repo contents as a Workshop addon using GMad. Include the `shaders/` folder.
5. Subscribe the server to the Workshop addon, or mount it in your collection.
6. Optional: add `resource.AddWorkshop("YOUR_WORKSHOP_ID")` to `lua/autorun/server/sv_ps2_horror.lua` so clients auto-download.

That's it. Clients join, shaders load on startup, everyone sees the same aesthetic.

## Quickstart — for solo/singleplayer use

1. Clone this repo and wait for CI to compile shaders (or compile locally — see "Manual compilation" below).
2. Drop the contents into `garrysmod/addons/ps2_horror/` (create the folder).
3. Launch GMod. Console: `ps2_horror_status` to verify native mode.

## Runtime controls

| Command / convar | Effect |
|---|---|
| `ps2_horror_menu` | Open the tuning UI with live sliders |
| `ps2_horror_enabled 0/1` | Master toggle |
| `ps2_horror_effect_strength 0..1` | Overall blend (1 = full, 0 = off) |
| `ps2_horror_force_lua 1` | Force Lua fallback even if shaders are installed (debug) |
| `ps2_horror_force_lowgfx 1` | Aggressively disable specular / phong / HDR for that crunchy look |
| `ps2_horror_flatten_materials 1` | Strip bumpmaps from world materials on join |
| `ps2_horror_status` | Print current mode, DX level, shader detection results |

Server-admin commands (must be superadmin):

| Command | Effect |
|---|---|
| `ps2_horror_preset haunting_ground` | Apply the HG preset to all clients |
| `ps2_horror_preset silent_hill_2` | SH2 preset — darker, more contrast |
| `ps2_horror_preset re_outbreak` | RE Outbreak preset — warmer, lighter |
| `ps2_horror_preset fatal_frame` | Fatal Frame preset — very crushed, heavy vignette |
| `ps2_horror_set <key> <value>` | Override any setting server-wide |
| `ps2_horror_enable` / `ps2_horror_disable` | Toggle server-wide |

Server settings are re-pushed to clients every 30 seconds to defeat local overrides.

## Repository layout

```
.
├── .github/workflows/          CI: compiles shaders on Windows runners
│   ├── build-shaders.yml       Main workflow (on push)
│   └── package-release.yml     Builds a Workshop-ready zip on git tag
├── addon.json                  Workshop metadata + ignore list
├── shadersrc/                  HLSL source (not shipped to Workshop)
│   ├── ps2_master_ps2x.hlsl    Combined effects (main pipeline)
│   ├── ps2_dither_ps2x.hlsl    Grading + dither + vignette only
│   ├── ps2_chroma_ps2x.hlsl    Chromatic aberration only
│   ├── ps2_affine_ps2x.hlsl    Screen-space warp (experimental)
│   └── ps2_crt_ps2x.hlsl       CRT/composite video simulation
├── shaders/                    Compiled .vcs files (produced by CI)
│   └── fxc/                    Where GMod looks for compiled pixel shaders
├── materials/
│   ├── effects/shaders/        One VMT per shader variant
│   ├── correction/             Baked LUT for Lua fallback
│   └── ps2_horror/             Bayer pattern VTF for Lua fallback overlay
├── lua/autorun/
│   ├── client/                 Shader detection, render hooks, tuning UI
│   └── server/                 Settings push, admin commands
├── generate_lut.py             Rebuild the color correction LUT
├── generate_bayer.py           Rebuild the Bayer pattern PNG
├── generate_vtf.py             Convert bayer8x8.png → bayer8x8.vtf
└── compile_wine.sh             Local shader compile via Wine (advanced)
```

## How the visual pipeline works

Per-pixel, in the master shader:

1. **Sample with chromatic aberration** — R/G/B sampled at different horizontal offsets, falloff quadratic with distance from screen center
2. **Desaturate** toward luminance (keep ~45% of chroma)
3. **Contrast** boost around mid-gray (×1.18)
4. **Brightness** multiplier (×0.95)
5. **Shadow/highlight tint split** — cyan push on dark pixels, warm push on bright pixels (computed *after* contrast so dark pixels aren't crushed before tinting)
6. **Quantize with Bayer dither** — 6 levels per channel with ordered 8×8 Bayer pattern providing stipple at band transitions
7. **Scanlines** — sinusoidal darkening, 24 bands per screen height (~45 px on 1080p)
8. **Vignette** — quadratic falloff, ~25% corner darkening
9. **Master blend** — lerp with original for smooth on/off

The Lua fallback does steps 2-4 via `DrawColorModify`, step 5 via the pre-baked LUT (so tints are static at server-set defaults, not tunable at runtime), step 6 via a Bayer texture overlay, and steps 7-9 via `surface.DrawRect` layers.

## Manual shader compilation

The CI workflow handles this automatically. If you want to compile locally:

### Windows
```
powershell -File tools/compile_shaders.ps1
```
Requires [SCell555's ShaderCompile](https://github.com/SCell555/ShaderCompile) in `tools/`.

### Linux / macOS (via Wine)
```
./compile_wine.sh
```
Requires Wine ≥ 6.0. This is slower than CI and the resulting `.vcs` files should not be committed — let CI regenerate them.

## Known limitations

- **Lua mode can't do runtime tint adjustment** — the LUT is baked offline at whatever cyan/warm settings `generate_lut.py` has when you run it. Regenerate and re-upload to change baked tints.
- **Lua mode has no real chromatic aberration** — Source's screenspace effects can't shift individual channels. Lua clients just miss this effect.
- **No true vertex snap / affine mapping** — real PS2 affine was a vertex-space effect. Faking it screen-space looks like shimmer, not PS2. The `ps2_affine` shader is a subtle ripple, not authentic affine.
- **Dither pattern density is resolution-dependent** — the shader uses a fixed 1920×1080 reference. On other resolutions the pattern scales proportionally (which is arguably authentic since PS2 native res was 480p).
- **Scanlines are an addition, not authentic** — HG itself didn't draw scanlines. CRTs produced them naturally. Our scanlines are for retro flavor; set `ps2_horror_scanlines 0` to remove.
- **`ps2_horror_force_lowgfx`** is aggressive: strips specular, phong, HDR, flashlight shadows. It will affect gameplay visibility. Off by default; opt in via convar.

## Troubleshooting

**Native mode never activates:**
- Run `ps2_horror_status` and check what the shader detection found.
- If `shader file: nil`, the `.vcs` didn't ship — check CI status and the `_manifest.json` in the repo.
- If `DX level < 90`, the client has DX8 set; there's nothing we can do.
- Try unsubscribing/resubscribing the Workshop addon to force a redownload.

**Shaders load but look wrong:**
- Check the VMT's `$pixshader` string matches the actual compiled filename (check `_manifest.json`).
- Try `ps2_horror_preset haunting_ground` to reset to known-good defaults.
- If things look *too* subtle, check `ps2_horror_effect_strength` isn't below 1.

**Performance drop:**
- Lua mode costs ~0.3ms extra per frame. Native shader is essentially free.
- If on native and seeing drops, check `ps2_horror_force_lowgfx 0` (should be off) and gamemode-level rendering.

## License

MIT. Do what you want.
