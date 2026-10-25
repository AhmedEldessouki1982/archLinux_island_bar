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
}
