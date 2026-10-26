# Island — a macOS Dynamic Island-style status bar for Hyprland

A single morphing pill that expands on hover into a full status cluster, built with Quickshell/QML and running on Wayland under Hyprland.

---

## Features

- **Morphing pill** — three states in one bar: a narrow idle pill, a hover-expanded layout, and a compact centered meter for transient feedback (volume / brightness / keyboard-lock OSD).
- **Volume + brightness control** — scroll to adjust, click to mute / toggle; each shows a compact centered meter that pops up on bind, triggered over Hyprland IPC from your hardware keys.
- **Honest brightness scale** — the percentage on screen is exactly what `brightnessctl` reports, from 1% to 100%. There is no hidden remap: a backlight at 100% of its range reads 100%.
- **Battery charge-limit popup** — click the battery icon for **58%**, **78%**, or **100%** presets via `asusctl battery limit`; the selected preset is read back from the system and marked in Dracula yellow. Without `asusd` the row is not drawn at all.
- **Workspaces** — one `WorkspaceItem` component drives both states: the idle pill shows only the active workspace, the expanded pill shows **1–10** in fixed 22px slots with a single accent pill that **slides** between them (150 ms). Occupied slots carry a dot, empty slots stay dim, hover lightens the fill, and clicking an empty slot focuses it.
- **Caps / Num lock OSD** — a short-lived, centered popup that appears when either lock key changes.
- **Headphone jack detection** — the volume icon reflects the active `wpctl` sink port.
- **EQ visualizer** — hand-drawn bars that animate **only while audio is actually playing and the pill is expanded**; collapsed, they hold still so the idle bar can reach 0% CPU.
- **Network identity** — the health panel shows the connected SSID with latency and transfer rates, while the expanded pill keeps its compact IP address readout.
- **Notifications** — banner + center, with deadline-based expiry for transient notifications and true pinning for persistent ones.
- **Calendar** — independent month navigation and a six-week grid (adjacent-month days dimmed) keep the current-day marker accurate without snapping the view back.
- **Full system health panel** — a floating overlay showing CPU load + temp, GPU load/temp/mode/power, RAM, CPU + GPU fan speeds, network transfer rate, battery charge + draw, power profile, and kernel/user info. Auto-dismisses after 15 s idle and resets its timer while you interact with it.
- **Bento health panel** — fixed 196 / 232 / 196px columns on a 36px unit grid with 8px gutters. Each column is exactly **11 units** (476px) tall, so all three end on the same baseline without stretched cards; the whole body is **640×476** inside a **716×500** window. The left column carries the clock/calendar and top processes; the middle carries quick toggles, audio/brightness, smooth CPU/GPU load graphs, RAM/fan, network and weather; the right carries identity, battery power, profile/GPU mode, two storage rings and updates/uptime.
- **Quick-toggle status** — the Bluetooth chip shows the number of connected devices; the tray is one 24px slot grid in both pill states.
- **Shared panel typography and toggle glyphs** — four monospace sizes (10 / 12 / 15 / 24) and one high-contrast lavender label colour are shared across cards; the DND, keep-awake and Bluetooth chips use stateful Canvas glyphs and full-name tooltips.
- **Storage card** — two 64px ring gauges for the mounts listed in `config/Config.qml` (ROOT and DATA by default). A mount the system does not actually report is dropped, never drawn as 0%.
- **Live weather card** — current location (geo via `ipwho.is`) and temperature + conditions (via `open-meteo`), refreshed every 30 min; if the network or geo lookup fails it silently keeps the last-known-good reading. The card also shows the day/night state and the sunrise / sunset times.
- **Native Quickshell integration** — battery/charging straight from the built-in **UPower** service (event-driven, zero polling) and the clock from **SystemClock**; active-audio detection scrapes the built-in **Pipewire** node tree for stream sinks.
- **Dracula throughout** — one singleton theme, a single palette, no hard-coded colours and no literal font sizes outside it.
- **Custom icons** — battery, network, weather, meter bars and the health heart are drawn directly on Qt `Canvas` items, with a small icon-font set for standard controls.

---

## Why this isn't just another rice

Quickshell ships native services (UPower, and a hostile Pipewire module), but Quickshell **0.3.x**'s Pipewire audio/volume read-back is broken — `PwNodeAudio.volume`/`mute` read 0 and `PwLink.state` is stuck. So the services here are event-driven where the native module is reliable, and fall back to a polled CLI (`wpctl`, `brightnessctl`, `asusctl`, `df`, `hyprctl`) where it isn't — and only while the panel or an OSD is actually on screen.

The payoff is a bar that genuinely sleeps. Measured on the development machine (Ryzen 9 5900HS, 1920×1080 @ 120Hz, Hyprland 0.56, Quickshell 0.3.2):

| State | Before the idle pass | Now |
|---|---|---|
| Idle, panel closed | 7.7% CPU, ~0.5 child spawns/s | **≈0.02% CPU, 0 spawns/s** |
| Health panel open | 20.5% CPU | **≈1.8% CPU** |

The idle number came from two things: an equalizer repainting 160 ms forever because a sink node existed, and a 30 s clock `Timer` that kept the shell awake. Both are gone — the EQ bars are gated on real playback *and* expansion, and the clock is a `SystemClock` on the minute. The health panel itself contains **zero** `Timer`s: its graphs advance when a service publishes a new sample, and its clock ticks from the same signal every other card uses.

None of that is a substitute for benchmarking on your own hardware — it's simply what the implementation was tuned for, and the reasoning is written into the service sources.

---

## Shape

The bar is one top-edge drop, not a strip. `components/DropShape.qml` draws the
whole silhouette as a single closed path: the two top corners are **concave**
(inverted) radii so the surface reads as hanging from the screen edge, the
bottom corners are ordinary convex radii, and the border is a second open path
that runs left → bottom → right and deliberately stops before the top edge. The
pill and the health panel use the same component, so their geometry cannot
drift apart; only the radii differ (14px on the 32px pill, 26px on the panel).

Three rules keep it honest:

- **The clock is centred by construction.** The idle pill is three zones, not
  one row: `left cluster | clock | right cluster`, with the clock anchored to
  the body's centre and the body sized `2 × max(left, right) + clock + gaps`.
  A percent, a tray icon or the EQ bars can no longer push the clock off the
  centre line — measured at 959.75px against a 960px screen centre.
- **The radii follow the compositor, as a floor.** `services/HyprStyleService.qml`
  reads `decoration:rounding` once at startup and exits;
  `Config.followHyprlandRounding` maps it to `max(14, min(pillHeight/2,
  rounding + 4))` for the pill and `max(26, min(44, 2 × rounding + 6))` for the
  panel. Square windows (rounding 0) leave the shape exactly as designed;
  rounding 16 gives 16px pill ears (the drop component caps an ear at half the
  body height) and 38px panel ears. No `hyprctl`, no change.
- **The surface is a choice, not a blur.** `Config.pillSurface` is `"opaque"`
  (fill + hairline outline) or `"clear"` (no fill, a stronger outline). Clear is
  for dark wallpapers only: on the development wallpaper the measured contrast
  between the text and the backdrop through a clear pill is **1.95:1 median**
  (5th–95th percentile 1.19–3.25:1), well under the 4.5:1 needed for body text.
  That is the wallpaper's fault, not the border's, and it is why opaque is the
  default. No glass/blur mode exists: it would need a blur effect, which this
  repo bans.
- **The reserved strip grows with the housing, never shrinks.**
  `Config.displayCutouts` maps an output name to a hardware cutout height. The
  bar reserves `36 + cutout` - its own strip, pushed down by the housing;
  reserving only the cutout would let the pill cover the first tiled window -
  and moves the pill down by the cutout itself. That 36 is the 32px pill plus
  4px of clearance, so a tiled window sits almost as close below the pill as
  `general:gaps_out` sets it from the side walls; the window's own `border_size`
  is the rest of the visible gap. The drop's ears then flip from concave to
  convex (`DropShape.concaveTop`), because a surface that no longer hangs off
  the screen edge needs a top border too. Banners sit 8px under the strip and
  follow it for free: on Hyprland a top-anchored layer surface is positioned
  *below* the reserved area, which is why the old 46px margin actually placed
  banners at y=84 rather than y=46. An empty map, the default, changes nothing:
  36px strip, pill at y=0, first window frame at y=39 and its content at y=41
  (`gaps_out 3`, `border_size 2`). Verified with a synthetic 44px cutout: strip
  80px, bar window 104px, first window at y=85, pill filling rows 45-74, convex
  corners, banner at y=88.

---

## Warning levels

One ramp, defined once in `island/config/Theme.qml`. Every card, glyph and ring
reads it, so a value cannot be one colour in the pill and another in the panel.
Bands are inclusive at the lower edge: 75% load is already orange, not still
yellow.

| Metric | Yellow | Orange | Red | Healthy |
|---|---|---|---|---|
| CPU / GPU load | ≥ 40% | ≥ 75% | ≥ 90% | foreground |
| CPU / GPU temp | ≥ 60 °C | ≥ 75 °C | ≥ 88 °C | foreground |
| Memory | ≥ 60% | ≥ 78% | ≥ 90% | foreground |
| Latency (`ping 8.8.8.8`) | ≥ 30 ms | ≥ 80 ms | ≥ 150 ms | foreground |
| Disk use (ring) | ≥ 70% | ≥ 85% | ≥ 93% | green |
| Battery | ≤ 35% | ≤ 20% | ≤ 10% | green while charging, else foreground |

Battery is the one metric that reads downward, and being plugged in does not
mask a low level: 8% is red whether or not a charger is attached — charging
only turns the *healthy* bands green. Text values stay in the foreground colour
until they leave the healthy band; disk rings read green when healthy, because
a ring is a status instrument rather than a number. Unreadable values render as
a dimmed `--`, never as 0, and the card that needs the missing tool is not drawn
at all.

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
| `iproute2`, `procps-ng`, `coreutils` | Address, `top`, `df`/`ping` readouts |
| `pacman-contrib` (`checkupdates`) | Pending-update count (cached 5 min; a `pacman.log` append invalidates it) |
| _optional_ `asusctl` | Battery charge-limit popup (`asusd` daemon) + power-profile readout |
| _optional_ `supergfxctl` | ASUS GPU mode/status readout |
| _optional_ `nvidia-utils` | GPU load/temp via `nvidia-smi` |
| _optional_ `lm_sensors` | CPU/GPU temperature fallback |

> The battery charge-limit popup needs the `asusd` system daemon running (it owns the write path, so `asusctl battery limit` works without sudo). Without ASUS hardware the PROFILE / GPU MODE cards and the charge-limit row are **hidden**, and the storage card grows to keep the right column ending on the same baseline.

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

### 3. Personal settings

`island/config/Config.qml` is yours to edit; nothing there is design:

```qml
property var diskMounts: [                 // ring gauges, in display order
  { "mount": "/", "label": "ROOT" },
  { "mount": "/mnt/data", "label": "DATA" }
]
property var preferredScreens: ["eDP-1"]   // first name that exists wins
property bool followHyprlandRounding: true // drop radii follow decoration:rounding
property string pillSurface: "opaque"      // or "clear" - dark wallpapers only
property var displayCutouts: ({})          // output name -> cutout px, e.g. { "eDP-1": 44 }

property var chargeLimitPresets: [         // battery popup + panel chips
  { "pct": 58, "detail": "Longest battery life" },
  { "pct": 78, "detail": "Balanced" },
  { "pct": 100, "detail": "Full capacity" }
]
```

Unknown mounts are dropped, and an unknown output name falls through to the first screen the compositor reports.

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
quickshell -c island ipc call island adjustBrightness 5      # +5%
quickshell -c island ipc call island adjustBrightness -5     # -5%
```

`adjustBrightness` clamps at 1% and 100%, matching the real backlight range.

---

## Project structure

```
scripts/check.sh           # offline gate: qmllint + design-rule greps
AGENTS.md                  # rules and environment traps for contributors
island/
├── shell.qml              # Entry — PanelWindow + every floating layer + pill
├── config/
│   ├── qmldir             # QML module definition (three singletons)
│   ├── Theme.qml          # Dracula palette + type scale + 36px grid, single source of truth
│   ├── Config.qml         # Personal settings: mounts, output, surface, rounding, charge presets
│   └── Format.qml         # Number / unit formatting
├── components/
│   ├── AudioDeviceMenu.qml # Output / input device picker for the controls card
│   ├── BatteryIcon.qml    # Canvas-drawn battery
│   ├── DropShape.qml      # Shared flat silhouette (pill + health panel)
│   ├── EQBars.qml         # Equalizer bars, gated on playback + expansion
│   ├── GlyphIcon.qml      # Icon-font glyph wrapper
│   ├── HealthIcon.qml     # Health panel toggle icon
│   ├── KbLayoutIcon.qml   # Keyboard layout glyph
│   ├── LineGraph.qml      # Dense CPU/GPU history inset
│   ├── NetworkIcon.qml    # WiFi / ethernet / disconnected
│   ├── NotificationCard.qml # Notification banner content
│   ├── PillBattery.qml    # Battery slot (glyph + percentage)
│   ├── PillDivider.qml    # 1px group divider inside the pill
│   ├── PillStateMachine.qml # Idle / hover / meter state machine
│   ├── PillTray.qml       # StatusNotifier slot row
│   ├── RingGauge.qml      # Flat ring gauge (storage disks, power)
│   ├── ToggleChip.qml     # DND / keep-awake / Bluetooth chip
│   ├── Txt.qml            # The only text item: caption / body / value / hero
│   ├── WeatherGlyph.qml   # Canvas-drawn WMO weather-condition icon
│   └── WorkspaceItem.qml  # One workspace slot, identical in both pill states
├── services/
│   ├── AudioService.qml   # Pipewire stream detect; volume/mute via wpctl
│   ├── BatteryService.qml # Native UPower + asusctl charge-limit read/set
│   ├── BrightnessService.qml # Backlight via brightnessctl, true 1–100%
│   ├── GpuModeService.qml # Hybrid / integrated GPU mode switch + tool detection
│   ├── HyprStyleService.qml # One-shot read of decoration:rounding for the drop
│   ├── LockService.qml    # Caps/Num-OSD (LED sysfs)
│   ├── NetworkService.qml # Address, SSID, latency, transfer rates
│   ├── ProcessStatsService.qml # Top CPU / RAM processes
│   ├── StorageService.qml # Per-mount usage (df), sampled while open
│   ├── SystemStatsService.qml # CPU / RAM / uptime / load averages
│   ├── ThermalService.qml # CPU + GPU temperatures, fan speeds
│   ├── UpdateService.qml  # Pending package updates
│   └── WeatherService.qml # ipwho.is geolocation + open-meteo forecast
└── modules/
    ├── IslandPill.qml     # The pill — idle / hover / meter states + IPC
    ├── BatteryLimitPopup.qml # Charge-threshold radio presets (from Config: 58/78/100%)
    ├── FloatingHealth.qml # Overlay window hosting the consolidated panel
    ├── HealthPanel.qml    # Bento panel: clock+procs / controls+weather / power+storage
    ├── NotificationLayer.qml # Banner stack w/ expiry
    └── NotificationCenter.qml # Full notification history
```

---

## Checks

`scripts/check.sh` runs without a compositor and is the gate before any commit:

```bash
scripts/check.sh
```

It fails on QML errors, on a hex colour or numeric `pixelSize` outside `config/Theme.qml`, on a raw `Text {}` outside `components/Txt.qml`, on `Animation.Infinite` or any shadow/effect API, on a `Timer` inside the health panel, and on personal settings leaking back into `Theme.qml`.

Then reload the shell and confirm the log is clean — Quickshell separates log records with `\r`, so convert it first:

```bash
tr '\r' '\n' < /run/user/1000/quickshell/by-id/*/log.qslog | grep -aiE 'warning|error'
```

Screenshots taken at each step of the idle / workspace / tray / panel pass — before and after, with the measured geometry they were checked against — are in [`docs/screenshots/`](docs/screenshots/).

---

## Known limitations & tested-on

- **ASUS**-only extras are gated on the binaries, not on hope: `asusctl` and `supergfxctl` are probed once at startup, and the PROFILE / GPU MODE cards plus the charge-limit row are hidden when the matching tool is absent. A single surviving card takes the full column width.
- **Weather** needs network access; `ipwho.is` and `open-meteo.com` are called at 30-min intervals. On failure the last-known-good reading is kept, and a failed geo lookup short-circuits so the card doesn't spin on stale coordinates.
- **WiFi identity** is read from the active iwd station with `iwctl`; Island never starts, enables, or reconfigures a network controller.
- **GPU load** comes from amdgpu's `gpu_busy_percent`, which on some APUs flickers between 0 and 100 between reads. The card shows what the kernel reports; it does not smooth the source away.
- **Quickshell 0.3.x quirks** are worked around, not hidden:
  - Pipewire audio read/write is bypassed via `wpctl` (see the opening comment in `BatteryService`/`AudioService`);
  - standard action glyphs use the configured icon font alongside the custom canvas icons;
  - the volume/brightness meter temporarily blooms the poll rate (150 ms) only while its OSD is on screen, then returns to the normal slow poll;
- **Tested on**: Hyprland 0.56.2, Quickshell 0.3.2 (Qt6), Arch `extra`; the output is chosen from `Config.preferredScreens`, then the first output.

## License

MIT — see [LICENSE](LICENSE). © Ahmed Eldessouki.
