# Island — a macOS Dynamic Island-style status bar for Hyprland

A single morphing pill that expands on hover into a full status cluster, built with Quickshell/QML and running on Wayland under Hyprland.

---

## Features

- **Morphing pill** — three states in one bar: a narrow idle pill, a hover-expanded layout, and a compact centered meter for transient feedback (volume / brightness / keyboard-lock OSD).
- **Volume + brightness control** — scroll to adjust, click to mute / toggle; each shows a compact centered meter that pops up on bind, triggered over Hyprland IPC from your hardware keys.
- **Brightness remap & cap** — the on-screen `1–100%` scale is remapped onto the real backlight range, which is capped at **95%** (`realMaxPercent`) to protect the panel; the hardware keys route through this capped IPC so they can never blow past the limit.
- **Battery charge-limit popup** — click the battery icon for **60%**, **80%**, or **100%** presets via `asusctl battery limit`; the active preset is read back from the system and marked red.
- **Caps / Num lock OSD** — a short-lived, centered popup that appears when either lock key changes.
- **Headphone jack detection** — the volume icon reflects the active `wpctl` sink port.
- **EQ visualizer** — hand-drawn animated bars that appear while audio plays.
- **iwd network identity** — the health panel shows the connected SSID with latency and transfer rates, while the expanded pill keeps its compact IP address readout.
- **Notifications** — banner + center, with deadline-based expiry for transient notifications and true pinning for persistent ones.
- **Calendar** — independent month navigation and a six-week grid keep the current-day marker accurate without snapping the view back.
- **Full system health panel** — a floating overlay showing CPU load + temp, GPU load/temp/mode/power, RAM, CPU + GPU fan speeds, network transfer rate, battery charge + draw, power profile, and kernel/user info. Auto-dismisses after 15 s idle and resets its timer while you interact with it.
- **Bento health panel** — fixed 196 / 232 / 196px columns on a 36px unit grid with 8px gutters. Each column is exactly ten units tall, so all three end on the same baseline without stretched cards. The left column carries the clock/calendar and top processes; the middle carries quick toggles, audio/brightness, smooth CPU/GPU load graphs, RAM/fan, network and weather; the right carries identity, battery power, profile/GPU mode, two storage rings and updates/uptime.
- **Quick-toggle status** — the Bluetooth chip shows the number of connected devices; empty workspace slots fade in without changing the pill's size.
- **Shared panel typography and toggle glyphs** — four monospace sizes and one high-contrast lavender label color are shared across cards; the DND, keep-awake and Bluetooth chips use stateful Canvas glyphs and full-name tooltips.
- **Storage card** — two fixed 64px ring gauges for `/` and `/home`, with a mount label and consistent `used / total` units.
- **Live weather card** — the health panel shows current location (geo via `ipwho.is`) and temperature + conditions (via `open-meteo`), refreshed every 30 min; if the network or geo lookup fails it silently keeps the last-known-good reading. The card also shows the day/night state and the sunrise / sunset times.
- **Native Quickshell integration** — battery/charging read straight from the built-in **UPower** service (event-driven, zero polling); active-audio detection scrapes the built-in **Pipewire** node tree for stream sinks.
- **Dracula throughout** — one singleton theme, a single palette, no hard-coded colors.
- **Custom icons** — battery, network, weather, meter bars and the health heart are drawn directly on Qt `Canvas` items, with a small icon-font set for standard controls.

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
| `iwd` (`iwctl`) | Connected WiFi SSID readout |
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

### Autostart

Add this to your `hyprland.conf` so Island launches automatically on login:

```bash
exec-once = quickshell -c island
```

### Hardware-key IPC

Bind your volume/brightness keys to the island IPC:

```bash
quickshell -c island ipc call island triggerMeter volume     # pop the volume OSD
quickshell -c island ipc call island triggerMeter brightness # pop the brightness OSD
quickshell -c island ipc call island toggleHealth            # toggle the health panel
quickshell -c island ipc call island adjustBrightness 5      # +5% on the capped scale
quickshell -c island ipc call island adjustBrightness -5     # -5% on the capped scale
```

`adjustBrightness` clamps at 1% and the 95% real-backlight cap, so the hardware keys can never push the panel past its limit.

---

## Project structure

```
island/
├── shell.qml              # Entry — PanelWindow + every floating layer + pill
├── config/
│   ├── qmldir             # QML module definition (Theme singleton)
│   └── Theme.qml          # Dracula palette + font/type scale, single source of truth
├── components/
│   ├── AudioDeviceMenu.qml # Output / input device picker for the controls card
│   ├── BatteryIcon.qml    # Canvas-drawn battery
│   ├── DropShape.qml      # Shared flat silhouette (pill + health panel)
│   ├── EQBars.qml         # Animated equalizer bars
│   ├── HealthIcon.qml     # Health panel toggle icon
│   ├── KbLayoutIcon.qml   # Keyboard layout glyph
│   ├── NetworkIcon.qml    # WiFi / ethernet / disconnected
│   ├── NotificationCard.qml # Notification banner content
│   ├── PillStateMachine.qml # Idle / hover / meter state machine
│   ├── RingGauge.qml      # Flat ring gauge (storage disks, power)
│   └── WeatherGlyph.qml   # Canvas-drawn WMO weather-condition icon
├── services/
│   ├── AudioService.qml   # Pipewire stream detect; volume/mute via wpctl
│   ├── BatteryService.qml # Native UPower + asusctl charge-limit read/set
│   ├── BrightnessService.qml # Backlight via brightnessctl, 0–95% remap
│   ├── GpuModeService.qml # Hybrid / integrated GPU mode switch
│   ├── LockService.qml    # Caps/Num-OSD (LED sysfs)
│   ├── NetworkService.qml # Network readout
│   ├── ProcessStatsService.qml # Top CPU / RAM processes
│   ├── StorageService.qml # Per-mount usage (df), sampled while open
│   ├── SystemStatsService.qml # CPU / RAM / uptime / load averages
│   ├── ThermalService.qml # CPU + GPU temperatures, fan speeds
│   ├── UpdateService.qml  # Pending package updates
│   └── WeatherService.qml # ipwho.is geolocation + open-meteo forecast
└── modules/
    ├── IslandPill.qml     # The pill — idle / hover / meter states + IPC
    ├── BatteryLimitPopup.qml # Charge-threshold radio presets (58/79/100%)
    ├── FloatingHealth.qml # Overlay window hosting the consolidated panel
    ├── HealthPanel.qml    # Bento panel: clock+procs / controls+weather / power+storage
    ├── NotificationLayer.qml # Banner stack w/ expiry
    └── NotificationCenter.qml # Full notification history
```

---

## Known limitations & tested-on

- **ASUS**-only extras (`asusctl`, `supergfxctl`, and the fan readback) are gated: without that hardware they simply stay empty — nothing breaks.
- **Weather** needs network access; `ipwho.is` and `open-meteo.com` are called at 30-min intervals. On failure the last-known-good reading is kept, and a failed geo lookup short-circuits so the card doesn't spin on stale coordinates.
- **WiFi identity** is read from the active iwd station with `iwctl`; Island never starts, enables, or reconfigures a network controller.
- **Quickshell 0.3.x quirks** are worked around, not hidden:
  - Pipewire audio read/write is bypassed via `wpctl` (see the opening comment in `BatteryService`/`AudioService`);
  - standard action glyphs use the configured icon font alongside the custom canvas icons;
  - the volume/brightness meter temporarily blooms the poll rate (150 ms) only while its OSD is on screen, then returns to the normal slow poll;
- **Tested on**: Hyprland 0.56, Quickshell 0.3.1 (Qt6), Arch `extra`; screen selector defaults to `eDP-1` then `eDP-2`, then the first output.

## License

MIT
