# Island — a macOS Dynamic Island-style status bar for Hyprland

A single morphing pill that expands on hover into a full status cluster, built with Quickshell/QML and running on Wayland under Hyprland.

---

## Features

- **Morphing pill** — three states in one bar: a narrow idle pill, a hover-expanded layout, and a compact centered meter for transient feedback (volume / brightness / keyboard-lock OSD).
- **Volume + brightness control** — scroll to adjust, click to mute / toggle; each shows a compact centered meter that pops up on bind, triggered over Hyprland IPC from your hardware keys.
- **Brightness remap & cap** — the on-screen `0–100%` scale is remapped onto the real backlight range, which is capped at **95%** (`realMaxPercent`) to protect the panel; the hardware keys route through this capped IPC so they can never blow past the limit.
- **Battery charge-limit popup** — click the battery icon for radio presets (**Max Protection 58%**, **Balanced 79%**, **Fully Charged 100%**) that set the ASUS charge threshold live via `asusctl battery limit`; the active preset is highlighted in yellow and stays in sync with `rog-control-center`.
- **Caps / Num lock OSD** — a short-lived, centered popup that appears when either lock key changes.
- **Headphone jack detection** — the volume icon reflects the active `wpctl` sink port.
- **EQ visualizer** — hand-drawn animated bars that appear while audio plays.
- **Notifications** — banner + center, with deadline-based expiry for transient notifications and true pinning for persistent ones.
- **Calendar popup** — click a date to open it.
- **Full system health panel** — a floating overlay showing CPU load + temp, GPU load/temp/mode/power, RAM, CPU + GPU fan speeds, network transfer rate, battery charge + draw, power profile, and kernel/user info. Auto-dismisses after 8 s idle.
- **Live weather card** — the health panel shows current location (geo via `ipwho.is`) and temperature + conditions (via `open-meteo`), refreshed every 30 min; if the network or geo lookup fails it silently keeps the last-known-good reading.
- **Native Quickshell integration** — battery/charging read straight from the built-in **UPower** service (event-driven, zero polling); active-audio detection scrapes the built-in **Pipewire** node tree for stream sinks.
- **Dracula throughout** — one singleton theme, a single palette, no hard-coded colors.
- **Hand-drawn icons** — battery, network, weather, meter bars and the health heart are drawn directly on Qt `Canvas` items; no icon-font glyph set.

---

## Why this isn't just another rice

Quickshell ships native services (UPower, and a hostile Pipewire module), but Quickshell **0.3.0**'s Pipewire audio/volume read-back is broken — `PwNodeAudio.volume`/`mute` read 0 and `PwLink.state` is stuck. So the services here are event-driven where the native module is reliable, and fall back to a polled CLI (`wpctl`, `brightnessctl`, `asusctl`) where it isn't, with temporary speed-ups only while an OSD is on screen.

The payoff is **idle CPU around 0.1%** instead of the slow battery drain from an infinite `SequentialAnimation` repaint loop or an aggressive polling loop. The OSD meter layers also react instantly because they're a low-cost repaint triggered over IPC, not a 2-second poll. The charge-limit poll (10 s) and weather refresh (30 min) are deliberately slow to keep the idle cost near zero.

None of that is a substitute for benchmarking on your own hardware — it's simply what the implementation was tuned for, and the reasoning is written into the service sources.

---

## Requirements

| Dependency | Purpose |
|---|---|
| [Quickshell](https://github.com/Quickshell/Quickshell) ≥ 0.3.0 | QML shell runtime for Wayland |
| Qt 6 (Quick, Wayland, QML) | UI framework |
| [Hyprland](https://github.com/hyprwm/Hyprland) | Wayland compositor |
| PipeWire + wireplumber | Audio (the `wpctl` control) |
| `brightnessctl` | Backlight control |
| `upower` | Battery/charging events (for the native UPower service) |
| `curl` | Weather geolocation + forecast fetches |
| _optional_ `asusctl` | Battery charge-limit popup (`asusd` daemon) + power-profile readout |
| _optional_ `supergfxctl` | ASUS GPU mode/status readout |
| _optional_ `nvidia-utils` | GPU load/temp via `nvidia-smi` |
| _optional_ `lm_sensors` | CPU/GPU temperature fallback |

> The battery charge-limit popup needs the `asusd` system daemon running (it owns the write path, so `asusctl battery limit` works without sudo). Without ASUS hardware, the popup's rows simply never match a limit and everything else stays functional.

### 0. Install Quickshell

Arch (and most rolling distros) ship it:

```bash
# Arch / package manager that has it in the repos
sudo pacman -S quickshell
```

Otherwise build from source ([upstream README](https://github.com/Quickshell/Quickshell)):

```bash
git clone https://github.com/Quickshell/Quickshell.git
cd Quickshell
cmake -B build -G Ninja
cmake --build build
sudo cmake --install build
# verify
quickshell --version
```

### 1. Install Island

```bash
# Clone into Quickshell's config directory
git clone git@github.com:AhmedEldessouki1982/archLinux_island_bar.git ~/.config/quickshell

# …or clone elsewhere and symlink
ln -sf ~/projects/quickshell ~/.config/quickshell
```

### 2. Optional hardware extras

| Package | Used for |
|---|---|
| `asusctl` | ASUS power profile + battery charge-limit popup |
| `supergfxctl` | ASUS GPU mode switching |
| `lm_sensors` / `nvidia-utils` | temperature / NVIDIA GPU stats |

---

## Usage

```bash
quickshell -c island
```

If Quickshell is set to autoload a config layout, place or symlink it so it stays under `~/.config/quickshell`.

### Hardware-key IPC

Bind your volume/brightness keys to the island IPC:

```bash
quickshell -c island ipc call island triggerMeter volume     # pop the volume OSD
quickshell -c island ipc call island triggerMeter brightness # pop the brightness OSD
quickshell -c island ipc call island toggleHealth            # toggle the health panel
quickshell -c island ipc call island adjustBrightness 5      # +5% on the capped scale
quickshell -c island ipc call island adjustBrightness -5     # -5% on the capped scale
```

`adjustBrightness` clamps at 0% and the 95% real-backlight cap, so the hardware keys can never push the panel past its limit.

---

## Project structure

```
island/
├── shell.qml              # Entry — PanelWindow + every floating layer + pill
├── config/
│   ├── qmldir             # QML module definition (Theme singleton)
│   └── Theme.qml          # Dracula palette + font/type scale, single source of truth
├── components/
│   ├── BatteryIcon.qml    # Canvas-drawn battery
│   ├── EQBars.qml         # Animated equalizer bars
│   ├── HealthIcon.qml     # Health panel toggle icon
│   ├── NetworkIcon.qml    # WiFi / ethernet / disconnected
│   └── WeatherIcon.qml    # Canvas-drawn WMO weather-condition icon
├── services/
│   ├── AudioService.qml   # Pipewire stream detect; volume/mute via wpctl
│   ├── BatteryService.qml # Native UPower + asusctl charge-limit read/set
│   ├── BrightnessService.qml # Backlight via brightnessctl, 0–95% remap
│   ├── LockService.qml    # Caps/Num-OSD (LED sysfs)
│   ├── NetworkService.qml # Network readout
│   └── WeatherService.qml # ipwho.is geolocation + open-meteo forecast
└── modules/
    ├── IslandPill.qml     # The pill — idle / hover / meter states + IPC
    ├── BatteryLimitPopup.qml # Charge-threshold radio presets (58/79/100%)
    ├── FloatingHealth.qml # Overlay window hosting the consolidated panel
    ├── HealthPanel.qml    # 3-column panel: rings+calendar / sliders+tiles / battery+weather
    ├── NotificationLayer.qml # Banner stack w/ expiry
    └── NotificationCenter.qml # Full notification history
```

---

## Known limitations & tested-on

- **ASUS**-only extras (`asusctl`, `supergfxctl`, and the fan readback) are gated: without that hardware they simply stay empty — nothing breaks.
- **Weather** needs network access; `ipwho.is` and `open-meteo.com` are called at 30-min intervals. On failure the last-known-good reading is kept, and a failed geo lookup short-circuits so the card doesn't spin on stale coordinates.
- **Quickshell 0.3.0 quirks** are worked around, not hidden:
  - Pipewire audio read/write is bypassed via `wpctl` (see the opening comment in `BatteryService`/`AudioService`);
  - the "bell"/"calendar" glyphs are rendered with the system emoji font, not the hand-drawn canvas set;
  - the volume/brightness meter temporarily blooms the poll rate (150 ms) only while its OSD is on screen, then returns to the normal slow poll;
  - redeclaring `closed()` on the floating layers shadows the base `Window` signal — functional, but logs an `invalidOverride` warning.
- **Tested on**: Hyprland 0.56, Quickshell 0.3.0 (Qt6), Arch `extra`; screen selector defaults to `eDP-1` then `eDP-2`, then the first output.

## License

MIT
