pragma Singleton
import QtQuick

// Personal settings — the things that belong to *this* machine rather than to
// the design. Theme.qml holds the design tokens (palette, type scale, grid);
// this file holds the answers that change from one install to the next, so a
// fork can be made one's own without touching the design system.
QtObject {
  id: root

  // Filesystems drawn as ring gauges in the health panel, in display order.
  // A mount that is not a real, readable filesystem is dropped by
  // StorageService — a missing mount is never drawn as 0%.
  property var diskMounts: [
    { "mount": "/", "label": "ROOT" },
    { "mount": "/home", "label": "HOME" },
    { "mount": "/mnt/data", "label": "DATA" }
  ]

  // Output the bar is placed on, in preference order. The first name that
  // exists wins; if none do, the first available output is used, so a machine
  // with different output names still gets a working bar.
  property var preferredScreens: ["eDP-1", "eDP-2"]

  // Derive the drop's corner radii from Hyprland's `decoration:rounding`, so
  // the island keeps its silhouette but sits in sympathy with the windows on
  // the same screen. The bridge is a floor, not a copy: square windows (the
  // default here) leave the shape exactly as Theme.qml designs it, and only a
  // rounder compositor pulls it outwards. Set false to pin the tokens.
  property bool followHyprlandRounding: true

  // Battery charge-limit presets, in display order. `pct` is the value written
  // to `asusctl battery limit` (20-100); `detail` is the line printed beside it
  // in the popup. The chips stay clickable when the EC reports a limit outside
  // this list (a machine left on 60%, say): none is marked selected, so the UI
  // never claims a preset that is not actually set.
  property var chargeLimitPresets: [
    { "pct": 58, "detail": "Longest battery life" },
    { "pct": 78, "detail": "Balanced" },
    { "pct": 100, "detail": "Full capacity" }
  ]
}
