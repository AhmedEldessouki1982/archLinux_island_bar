# Island — macOS Dynamic Island-style Status Bar for Hyprland

A sleek, interactive pill-shaped status bar for **Hyprland** (Wayland) built with **Quickshell/QML**. Inspired by the iPhone 14 Pro's Dynamic Island and macOS menu bar.

![Dracula Theme](https://img.shields.io/badge/theme-Dracula-ff79c6)

---

## Features

### Idle Mode (narrow pill)
- **EQ Bars** — animated audio visualizer (appears when audio plays)
- **Workspace** — current Hyprland workspace number
- **Window title** — focused toplevel title
- **Clock** — current time (HH:mm, updates every second)
- **Date** — day, month, year
- **System Tray** — StatusNotifierItem icons

### Expanded Mode (hover to reveal)
Smoothly animates to a wider pill showing:
- **Network** — IP address with WiFi/Ethernet/disconnected indicator
- **Volume** — meter bar, percentage, scroll-to-adjust, click-to-mute
- **Brightness** — sun icon, slotted bar, scroll-to-adjust, click-to-toggle (20%–80%)
- **Workspace Dots** — clickable workspace switcher
- **Health toggle** — pulsing heart icon to open the monitoring panel
- **Battery** — animated icon with percentage (green when charging, red ≤ 20%)

### Floating Health Panel
A popup overlay with real-time system monitoring:
- **CPU** — load + temperature (color-coded thresholds)
- **GPU** — load, temperature, mode, power (via `nvidia-smi` / `supergfxctl`)
- **RAM** — used / total with percentage
- **FAN** — CPU + GPU fan speeds (RPM)
- **BAT** — power draw (W) when charging, capacity (%) when discharging
- **PWR** — power profile (via `asusctl`)
- **NET** — download / upload rates
- **Kernel + user info** in footer

Auto-closes after 10s of inactivity; polls every 2s.

---

## Requirements

| Dependency | Purpose |
|---|---|
| [Quickshell](https://github.com/Quickshell/Quickshell) | QML shell runtime for Wayland |
| Qt 6 (Quick, Wayland, QML) | UI framework |
| Hyprland | Wayland compositor |
| PipeWire + wireplumber | Audio (`wpctl`) |
| `brightnessctl` | Backlight control |
| `nvidia-smi` | GPU monitoring (optional) |
| `supergfxctl` | ASUS GPU mode switching (optional) |
| `asusctl` | ASUS power profiles (optional) |

---

## Installation

```bash
# Clone into Quickshell config directory
git clone https://github.com/yourusername/quickshell ~/.config/quickshell

# Or symlink your config
ln -sf /path/to/quickshell ~/.config/quickshell
```

---

## Usage

```bash
quickshell ~/.config/quickshell/island/shell.qml
```

If Quickshell is configured to autoload `~/.config/quickshell/`, it will pick up `island/shell.qml` automatically.

---

## Project Structure

```
island/
├── shell.qml              # Entry point — PanelWindow + FloatingHealth + IslandPill
├── config/
│   ├── qmldir             # QML module definition (Theme singleton)
│   └── Theme.qml          # Dracula color palette
├── components/
│   ├── EQBars.qml         # Animated equalizer bars
│   ├── BatteryIcon.qml    # Canvas-drawn battery
│   ├── BrightnessIcon.qml # Sun icon with bar
│   ├── HealthIcon.qml     # Pulsing heart icon
│   ├── NetworkIcon.qml    # WiFi/Ethernet/disconnected icon
│   ├── VolumeIcon.qml     # Speaker/headphone icon
│   └── WorkspaceDot.qml   # Workspace indicator dot
├── services/
│   ├── AudioService.qml   # PipeWire audio control
│   ├── BatteryService.qml # Battery readout via sysfs
│   ├── BrightnessService.qml # Backlight control
│   └── NetworkService.qml # Network detection via ip
└── modules/
    ├── IslandPill.qml     # Main pill bar (idle + expanded)
    ├── FloatingHealth.qml # Health panel popup window
    └── HealthPanel.qml    # CPU/GPU/RAM/FAN/BAT/PWR/NET monitor
```

---

## Configuration

Colors are defined in `island/config/Theme.qml` (Dracula palette). Modify them to customize the look.

---

## ASUS ROG Laptop Support

Island detects ASUS hardware and reads:
- GPU mode via `supergfxctl`
- Power profile via `asusctl`
- Fan speeds from hwmon sysfs

---

## License

MIT
