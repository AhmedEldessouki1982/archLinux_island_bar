# Island — a macOS Dynamic Island-style status bar for Hyprland

A single morphing pill that expands on hover into a full status cluster, built with Quickshell/QML and running on Wayland under Hyprland.

![demo](./docs/demo.gif)

---

## Features

- **Morphing pill** — three states in one bar: a narrow idle pill, a hover-expanded layout, and a compact centered meter for transient feedback (volume / brightness / keyboard-lock OSD).
- **Volume + brightness control** — scroll to adjust, click to mute / toggle; each shows a compact centered meter that pops up on bind, triggered over Hyprland IPC from your hardware keys.
- **Caps / Num lock OSD** — a short-lived, centered popup that appears when either lock key changes.
- **Headphone jack detection** — the volume icon reflects the active `wpctl` sink port.
- **EQ visualizer** — hand-drawn animated bars that appear while audio plays.
- **Notifications** — banner + center, with deadline-based expiry for transient notifications and true pinning for persistent ones.
- **Calendar popup** — click a date to open it.
- **Full system health panel** — a floating overlay showing CPU load + temp, GPU load/temp/mode/power, RAM, CPU + GPU fan speeds, network transfer rate, battery charge + draw, power profile, and kernel/user info. Auto-dismisses after 10 s idle.
- **Native Quickshell integration** — battery/charging read straight from the built-in **UPower** service (event-driven, zero polling); active-audio detection scrapes the built-in **Pipewire** node tree for stream sinks.
- **Dracula throughout** — one singleton theme, a single palette, no hard-coded colors.
- **Hand-drawn icons** — battery, network, meter bars and the health heart are drawn directly on Qt `Canvas` items; no icon-font glyph set.

---

## Why this isn't just another rice

Quickshell ships native services (UPower, and a hostile Pipewire module), but Quickshell **0.3.0**'s Pipewire audio/volume read-back is broken — `PwNodeAudio.volume`/`mute` read 0 and `PwLink.state` is stuck. So the services here are event-driven where the native module is reliable, and fall back to a polled CLI (`wpctl`, `brightnessctl`) where it isn't, with temporary speed-ups only while an OSD is on screen.

The payoff is **idle CPU around 0.1%** instead of the slow battery drain from an infinite `SequentialAnimation` repaint loop or an aggressive polling loop. The OSD meter layers also react instantly because they're a low-cost repaint triggered over IPC, not a 2-second poll.

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
| _optional_ `asusctl` | ASUS power-profile readout in the health panel |
| _optional_ `supergfxctl` | ASUS GPU mode/status readout |
| _optional_ `nvidia-utils` | GPU load/temp via `nvidia-smi` |
| _optional_ `lm_sensors` | CPU/GPU temperature fallback |

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
| `asusctl` | ASUS power profile |
| `supergfxctl` | ASUS GPU mode switching |
| `lm_sensors` / `nvidia-utils` | temperature / NVIDIA GPU stats |

---

## Usage

```bash
quickshell -c island
```

If Quickshell is set to autoload a config layout, place or symlink it so it stays under `~/.config/quickshell`.

To bind the volume/brightness hardware keys, call the trigger IPC from your keybind: `quickshell -c island ipc call island triggerMeter <mode>`, e.g. `triggerMeter volume`.

---

## Project structure

```
island/
├── shell.qml              # Entry — PanelWindow + every floating layer + pill
├── config/
│   ├── qmldir             # QML module definition (Theme singleton)
│   └── Theme.qml          # Dracula palette + font/type scale, single source of truth
├── components/
│   ├── EQBars.qml         # Animated equalizer bars
│   ├── BatteryIcon.qml    # Canvas-drawn battery
│   ├── HealthIcon.qml     # Health panel toggle icon
│   └── NetworkIcon.qml    # WiFi / ethernet / disconnected
├── services/
│   ├── AudioService.qml   # Pipewire stream detect; volume/mute via wpctl
│   ├── BatteryService.qml # Native UPower (no polling)
│   ├── BrightnessService.qml # Backlight via brightnessctl
│   ├── LockService.qml    # Caps/Num-OSD (LED sysfs) 
│   └── NetworkService.qml # Network readout
└── modules/
    ├── IslandPill.qml     # The pill — idle / hover / meter states
    ├── FloatingHealth.qml # Overlay window hosting the consolidated panel
    ├── HealthPanel.qml    # 3-column panel: rings+calendar / sliders+tiles / battery+identity
    ├── NotificationLayer.qml # Banner stack w/ expiry
    └── NotificationCenter.qml # Full notification history
```

---

## Known limitations & tested-on

- **ASUS**-only extras (`asusctl`, `supergfxctl`, and the fan readback) are gated: without that hardware they simply stay empty — nothing breaks.
- **Quickshell 0.3.0 quirks** are worked around, not hidden:
  - Pipewire audio read/write is bypassed via `wpctl` (see the opening comment in `BatteryService`/`AudioService`);
  - the "bell"/"calendar" glyphs are rendered with the system emoji font, not the hand-drawn canvas set;
  - the volume/brightness meter temporarily blooms the poll rate (150 ms) only while its OSD is on screen, then returns to the normal slow poll;
- **Tested on**: Hyprland 0.56, Quickshell 0.3.0 (Qt6), Arch `extra`; screen selector defaults to `eDP-1` then `eDP-2`, then the first output.

## License

MIT