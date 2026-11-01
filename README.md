# TemariLantern
Branch of Magic Lantern that puts a temari plush on every screen. There is no utility to this. She will be in the way.

`plush` is a [Magic Lantern](https://github.com/reticulatedpines/magiclantern_simplified)
module. Every time the screen changes (LiveView, playback, Canon menus, the ML menu,
each DISP/INFO press), she pops up somewhere random, between 0.3" and 1" tall.
Canon keeps redrawing its screens, so the module keeps redrawing her on top.

![preview](images/plush.webp)

## Cameras

The module draws on the 8-bit overlay that DIGIC 4 and 5 cameras use:

| Works | Camera folder names |
|---|---|
| Tested | `550D.109` (Kiss X4 / Rebel T2i) |
| Should work (untested) | `100D.101` `1100D.105` `1300D.110` `500D.111` `50D.109` `5D2.212` `5D3.113` `5D3.123` `600D.102` `60D.111` `650D.104` `6D.116` `700D.115` `70D.112` `EOSM.202` |
| Won't work | DIGIC 6 and newer (`200D`, `5D4`, `6D2`, `750D`, `77D`, `7D2`, `80D`, `850D`, `M50`, `M6II`, R bodies, ...) |

The folder name is the camera plus the Canon firmware ML needs: `600D.102` means a
600D on firmware 1.0.2. Check yours in Canon's menu → wrench tab → *Firmware Ver.*

## Install

You need Magic Lantern on the card, built from a recent
[magiclantern_simplified](https://github.com/reticulatedpines/magiclantern_simplified)
(`plush.mo` has to match the ML build it runs on). Either:

- **Card already has a recent ML:** build just the module (`./build.sh ML_DIR`) and
  copy `out/addon/ML/` onto the card, merging with the `ML` folder there.
- **Starting fresh:** build ML and the module together (`./build.sh ML_DIR CAMERA`),
  format the card in the camera, and copy everything in `out/card-CAMERA/` onto it.
  Then, in Canon's menu, run *Firmware Ver. → update* with the mode dial on M. That
  starts ML's installer (it doesn't change Canon's firmware); follow its prompts and
  restart the camera.

Then turn her on:

1. Press **Trash** to open ML's menu.
2. **Modules** tab → **plush** → SET, then restart the camera. (Modules only load
   after a restart.)
3. **Overlay** tab → **Plush** is on by default. *Shuffle now* moves her right away.

To remove ML, run the firmware update from the ML card again and remove the boot
flag, or just use a card without ML.

## Build

### What you need

- An ARM cross-compiler **with its C library headers**:
  - macOS: ARM's official toolchain. Homebrew's `arm-none-eabi-gcc` lacks the headers,
    and the `gcc-arm-embedded` cask needs an admin password, so the tarball is easiest:
    ```bash
    mkdir -p ~/opt && cd ~/opt
    curl -fLO "https://gitlab.arm.com/api/v4/projects/tooling%2Fgnu-toolchains-for-arm/packages/generic/gnu-toolchain/15.3.rel2/arm-gnu-toolchain-15.3.rel2-darwin-arm64-arm-none-eabi.tar.xz"
    tar xJf arm-gnu-toolchain-15.3.rel2-darwin-arm64-arm-none-eabi.tar.xz
    ```
    (Intel Macs: use the `darwin-x86_64` file from
    [ARM's downloads page](https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads).)
  - Linux (Debian/Ubuntu): `sudo apt install gcc-arm-none-eabi libnewlib-arm-none-eabi`
- Python 3 with `docutils` and `pillow`:
  ```bash
  python3 -m venv ~/opt/ml-venv && ~/opt/ml-venv/bin/pip install docutils pillow
  ```
  (`build.sh` uses `~/opt/ml-venv` if it exists; set `ML_VENV` to use another.)

`build.sh` finds the compiler on your `PATH`, then in `~/opt/arm-gnu-toolchain-*`.
Set `ARM_TC` to point it somewhere else.

### Steps

```bash
git clone https://github.com/reticulatedpines/magiclantern_simplified.git
git clone https://github.com/ericz0u/TemariLantern.git
cd TemariLantern
```

Just the module:

```bash
./build.sh ../magiclantern_simplified
```

Module plus Magic Lantern for your camera (use the folder name from the table):

```bash
./build.sh ../magiclantern_simplified 550D.109
```

What ends up in `out/`:

| Path | What it is |
|---|---|
| `addon/ML/modules/plush.mo` | the module |
| `addon/ML/data/PLUSH.BMP` | the plush the module draws |
| `addon/ML/cropmks/PLUSH.BMP` | a fixed, centered plush for ML's *Crop marks* (LiveView only, no module needed) |
| `card-CAMERA/` | the whole card: Magic Lantern plus everything above |
| `preview.png` | roughly how the crop mark looks on the camera |
| `build-*.log` | build output |

`build.sh` copies `plush/` into `ML_DIR/modules/plush/`. For a camera build it also
swaps `lua` for `plush` in `ML_DIR/platform/CAMERA/modules.included` while it runs
(and puts it back after), because Lua doesn't compile with newer ARM toolchains. So
that build has no Lua scripting.

## Use your own image

Replace `images/plush.webp` with any image (a transparent background works best) and
run `build.sh` again, or convert it by hand:

```bash
python3 tools/make_cropmark.py me.png STICKER.BMP --sticker --height 288   # for the module
python3 tools/make_cropmark.py me.png PLUSH.BMP --preview preview.png      # crop mark
```

Put the sticker on the card as `ML/data/PLUSH.BMP`. `--no-dither` gives flat colors
instead of dithering.

## How it works, and quirks

- **Colors.** The overlay has 256 palette colors, and Canon swaps some of them
  between screens (on the 550D, skin tones turn blue in LiveView). The converter
  only uses colors that stay put, plus 12 picked from the image, which it stores in
  palette slots `0x1A`–`0x25`. Neither Canon nor ML uses those slots, and the module
  re-applies its colors every 100 ms. The crop mark can't set colors, so it looks
  grayer.
- **Size.** The 0.3"–1" range assumes a 3" 3:2 screen (`PX_PER_INCH` in
  `plush/plush.c`). On 4:3 screens (500D, 50D, 5D2, 1100D, 1300D) ML's 720×480
  overlay is squeezed, so she looks a little narrow.
- **Flicker.** Canon redraws its own screens whenever it likes, so she may vanish
  for a moment before the module repaints her.
- **Screen changes** are detected from Canon's current dialog, GUI mode, LiveView
  state, zoom, the ML menu and the display power, plus every DISP/INFO press.
  Switching tabs inside ML's menu doesn't count.

## License

GPL v2, like Magic Lantern; see [LICENSE](LICENSE).
