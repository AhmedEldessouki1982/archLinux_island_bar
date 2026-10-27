# AGENTS.md — working on Island

Notes for anyone (human or agent) changing this repo. Read this before touching
QML; the rules below are what the code is actually held to.

## What this is

A single Quickshell/QML status bar for Hyprland: one morphing pill at the top of
the screen plus a floating health panel. Everything is drawn from flat fills and
Canvas glyphs — no images, no shader effects, no icon theme dependence.

```
island/
├── shell.qml              entry point: PanelWindow + pill + panel + popup layers
├── config/
│   ├── Theme.qml          design tokens: palette, type scale, 36px grid, motion
│   ├── Config.qml         personal settings: diskMounts, preferredScreens
│   ├── Format.qml         number/unit formatting
│   └── qmldir             singleton registration for the three files above
├── components/            reusable items (WorkspaceItem, PillTray, Txt, graphs…)
├── services/              one file per data source; all event- or open-gated
└── modules/               the pill, the health panel, notifications, popups
```

## Run and reload

```bash
quickshell -c island                     # normal launch
quickshell -p "$PWD/island/shell.qml"    # explicit path — must be absolute
scripts/check.sh                         # offline gate, run before every commit
```

`quickshell -p island/shell.qml` (relative) exits silently. Always pass the
absolute path.

## Non-negotiable rules

1. **Idle CPU ≤ 0.3% with the panel closed.** No `Animation.Infinite`, no
   always-running `Timer` or `Process`. Polling and animation may only run while
   the pill is expanded or the panel is open. `Animation.Infinite` and effect
   APIs are rejected by `scripts/check.sh`.
2. **Design tokens only.** Colours, sizes, radii, spacing and durations come
   from `config/Theme.qml`. A hex literal or a numeric `pixelSize` anywhere else
   fails the gate.
3. **Text goes through `components/Txt.qml`**, and only in four variants:
   `caption` 10, `body` 12, `value` 15, `hero` 24. A raw `Text {}` outside
   `Txt.qml` fails the gate.
4. **Flat fills only.** No `DropShadow`, `BoxShadow`, `FastBlur`, `MultiEffect`,
   `ShaderEffect` or `layer.effect`.
5. **No fake data.** A value that cannot be read renders as a dimmed `--`, never
   as `0`. If the tool or device behind a card is missing, the card is hidden
   (see the ASUS cards and the charge-limit row).
6. **Keep the panel grid.** Three columns of 36px units with 8px gutters; the
   columns must end on the same baseline. Changing a card's height means
   changing its neighbours or the layout's compensating rule.
7. **Personal settings are not design tokens.** Mounts, outputs, host
   preferences belong in `config/Config.qml`, not `Theme.qml`.

## Services: how data is allowed to arrive

- Prefer event-driven Quickshell natives (`UPower`, `Pipewire`, `SystemClock`).
- CLI reads are `Process` one-shots fired by the panel opening, a service
  signal, or an explicit user action. Nothing polls on a timer while the UI is
  closed.
- CPython-free: shell out to the same tools a user would run (`wpctl`,
  `brightnessctl`, `asusctl`, `df`, `hyprctl`), and parse defensively — a
  missing binary or an empty line must degrade to "unknown", not crash.
- `HealthPanel.qml` must not contain a `Timer`; its clock is `SystemClock`
  (minutes) and its graphs advance from service change signals.

## Verification before a commit

```bash
scripts/check.sh                 # must print "all checks passed"
quickshell -p "$PWD/island/shell.qml"
```

Then check the shell log for warnings — Quickshell writes to
`/run/user/1000/quickshell/by-id/<id>/log.qslog`; the file uses `\r` as its line
separator, so convert before grepping:

```bash
tr '\r' '\n' < <newest-log> | grep -aiE 'warning|error'
```

The count must be zero. `scripts/check.sh` runs `qmllint` too: it picks Qt6's
binary explicitly, because `/usr/bin/qmllint` on Arch is the Qt5 one and cannot
parse this code.

## Environment traps

- Hyprland 0.56+: `hyprctl dispatch movecursor X Y` is a Lua syntax error.
  Use `hyprctl eval 'hl.dispatch(hl.dsp.cursor.move({x=X,y=Y}))'`.
- The health panel auto-closes 15 s after the last pointer motion inside it.
  Any measurement that keeps it open must keep the pointer inside.
- UPower reports `PendingCharge` on some laptops, so "charging" can be false
  while on AC. That is the daemon, not the UI.
- `amdgpu`'s `gpu_busy_percent` flickers between 0 and 100 between reads; the
  GPU figure is noisy at the source.
- `/home` is not a separate mount on every machine. `StorageService` drops any
  mount that `df` does not report, so the storage card adapts instead of
  printing 0%.

## Commits

One logical change per commit, imperative subject in the form
`Stop repainting the idle pill: gate EQ animation` — say what changed and why
the change matters. Never commit `.pi/`, `.agents/`, `.codex/`, `*.bak`,
`*.qmlc` or `.qmlls.ini` (see `.gitignore`).
