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

### 1. Install Quickshell

Quickshell is not in most distro repos — you need to build it from source.

#### Prerequisites

Install Qt6 and build dependencies:

<details>
<summary><b>Arch Linux</b></summary>

```bash
sudo pacman -S --needed git cmake ninja qt6-base qt6-declarative qt6-wayland \
  wayland-protocols pipewire wireplumber brightnessctl
```
</details>

<details>
<summary><b>Ubuntu / Debian</b></summary>

```bash
sudo apt install git cmake ninja-build qt6-base-dev qt6-declarative-dev \
  qt6-wayland libwayland-dev libpipewire-0.3-dev libpulse-dev \
  brightnessctl pipewire pipewire-pulse wireplumber
```
</details>

<details>
<summary><b>Fedora</b></summary>

```bash
sudo dnf install git cmake ninja-build qt6-qtbase-devel qt6-qtdeclarative-devel \
  qt6-qtwayland-devel wayland-devel pipewire-devel pulseaudio-libs-devel \
  brightnessctl pipewire wireplumber
```
</details>

#### Build Quickshell from source

```bash
git clone https://github.com/Quickshell/Quickshell.git
cd Quickshell
cmake -B build -G Ninja
cmake --build build
sudo cmake --install build
```

Verify it installed:

```bash
quickshell --version
```

### 2. Install Island

```bash
# Clone directly into Quickshell's config directory
git clone https://github.com/yourusername/quickshell ~/.config/quickshell

# Or clone elsewhere and symlink
git clone https://github.com/yourusername/quickshell ~/projects/quickshell
ln -sf ~/projects/quickshell ~/.config/quickshell
```

### 3. Optional Dependencies

These enable extra hardware monitoring features:

| Package | Purpose | Install |
|---|---|---|
| `nvidia-smi` | NVIDIA GPU stats | `pacman -S nvidia-utils` / `apt install nvidia-utils` |
| `supergfxctl` | ASUS GPU mode switching | AUR / [GitHub](https://github.com/asus-linux/supergfxctl) |
| `asusctl` | ASUS power profiles | AUR / [GitHub](https://github.com/asus-linux/asusctl) |
| `lm_sensors` | CPU/GPU temperature | `pacman -S lm_sensors` / `apt install lm-sensors` |

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
