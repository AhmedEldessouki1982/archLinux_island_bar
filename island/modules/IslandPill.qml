import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray
import "../components"
import "../services"
import "../config"

Item {
  id: root

  // --- state delegated to PillStateMachine ---
  property int pillHeight: Theme.pillHeight
  readonly property int pillEarRadius: Theme.pillEarRadius

  // Pixels reserved for a display cutout on this output (0 on a normal panel).
  // The bar window's height and exclusive zone follow the same number, so the
  // pill sits below the camera housing instead of under it - and its ears flip
  // from concave to convex because it is no longer hanging off the screen edge.
  property int topInset: 0
  property alias inputRegionItem: pill

  // --- drop-shape geometry -------------------------------------------------
  // Horizontal padding inside the body, on top of the ear radius which is
  // part of the silhouette. Content therefore starts at ear + padding from
  // the shape's outer edge and is identical on both sides.
  readonly property real _pillContentWidth: _psm.meterMode !== ""
    ? _psm.meterPillWidth
    : _psm.isExpanded ? expandedLayout.implicitWidth
    : idleLayout.contentWidth

  // Body width (excluding the two ears). The pill is content-driven between a
  // floor and a ceiling; at the ceiling the title elides instead of pushing
  // the pill wider. The result is rounded UP to an even number: rounding down
  // would shave up to 2px off the last slot and clip its text.
  property real pillBodyWidth: {
    var w = Math.ceil(_pillContentWidth + Theme.pillPaddingLeft + Theme.pillPaddingRight)
    w = Math.max(Theme.pillMinWidth, Math.min(Theme.pillMaxWidth, w))
    return w + (w % 2)
  }

  // A resize only animates while it is happening (one-shot, 180 ms); at rest
  // no animation object is running.
  Behavior on pillBodyWidth {
    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
  }
  property alias audioService: _audioService
  property alias batteryService: _batteryService
  property alias networkService: _networkService
  property var sharedBrightnessService: null
  property var healthWindow: null
  property var batteryLimitWindow: null
  property var prayerWindow: null
  property var notificationLayer: null
  property var notificationCenter: null

  // The window whose title the pill shows. `focusedToplevel` is the live
  // Hyprland handle (kept current by focus events); `seededWindow` is the raw
  // `hyprctl -j activewindow` object captured once at startup, used only
  // until the first focus event arrives. It is stored raw instead of being
  // matched against Hyprland.toplevels because that list may still be empty
  // when the query returns.
  property var focusedToplevel: Hyprland.activeToplevel
  property var seededWindow: null
  readonly property var titleWindow: root.focusedToplevel || root.seededWindow

  width: parent.width
  height: root.pillHeight

  function friendlyAppName(win) {
    if (!win) return ""
    // Accepts either a Hyprland toplevel (lastIpcObject) or a raw hyprctl
    // client object with class/title at the top level.
    var ipc = win.lastIpcObject || win
    var raw = String(ipc["class"] || ipc.initialClass || "").trim()
    var title = String(ipc.title || win.title || "").trim()
    if (raw.toLowerCase() === "app") raw = ""
    if (!raw) return title && title.toUpperCase() !== "APP" ? title : ""
    raw = raw.replace(/\\/g, "/")
    if (raw.indexOf("/") >= 0)
      raw = raw.substring(raw.lastIndexOf("/") + 1)
    raw = raw.replace(/\.desktop$/i, "")
    var key = raw.toLowerCase()
    var names = {
      "google-chrome": "Chrome",
      "google-chrome-stable": "Chrome",
      "chromium": "Chromium",
      "firefox": "Firefox",
      "code": "VS Code",
      "code-oss": "Code OSS",
      "kitty": "Kitty",
      "alacritty": "Alacritty",
      "org.wezfurlong.wezterm": "WezTerm",
      "org.gnome.nautilus": "Files",
      "thunar": "Thunar",
      "steam": "Steam",
      "discord": "Discord"
    }
    if (names[key])
      return names[key]
    // X11/Wayland app identifiers often retain the reverse-domain id.
    raw = raw.replace(/^(?:org|com|net|io|dev|app)\.[^.]+\./i, "")
    raw = raw.replace(/[-_]+/g, " ").trim()
    if (/^python(?:[0-9]+(?:\.[0-9]+)?)?$/.test(key))
      return key.replace(/\.\d+$/, "")
    if (raw.length > 0) return raw.charAt(0).toUpperCase() + raw.slice(1)
    return title && title.toUpperCase() !== "APP" ? title : ""
  }

  PillStateMachine {
    id: _psm
    healthWindow: root.healthWindow
    batteryLimitWindow: root.batteryLimitWindow
    notificationLayer: root.notificationLayer
    notificationCenter: root.notificationCenter
    audioService: _audioService
    brightnessService: brightnessService
    lockService: lockService
  }

  // Flat style: no drop shadow, no accent halo behind the pill.
  // Depth comes from fill shades only (pill fill + 1px border).

  Item {
    id: pill
    y: root.topInset
    width: pillShape.width
    height: root.pillHeight
    // Integer x keeps both edges on whole pixels; pillBodyWidth is forced
    // even so the shape lands exactly on the window centre.
    x: Math.round((root.width - width) / 2)

    // The same DropShape the health panel uses, with the small radii, hung
    // directly off the top screen edge: y = 0, no gap and no seam.
    DropShape {
      id: pillShape
      bodyWidth: root.pillBodyWidth
      bodyHeight: root.pillHeight
      earRadius: Theme.pillEarRadius
      bottomRadius: Theme.pillBottomRadius
      concaveTop: root.topInset === 0
      fillColor: Config.pillSurface === "clear" ? "transparent" : Theme.background
      borderColor: Config.pillSurface === "clear" ? Theme.shapeBorderClear : Theme.shapeBorder
      borderWidth: 1
    }

    MouseArea {
      id: mouseArea
      anchors.fill: parent
      hoverEnabled: false
      onWheel: (event) => {
        var dir = event.angleDelta.y > 0 ? 1 : -1
        _psm.onWheel(dir)
        event.accepted = true
      }
    }

    HoverHandler {
      target: pill
      onHoveredChanged: _psm.setPointerInside(hovered)
    }

    // The idle pill is three zones, not one row. The clock group is pinned to
    // the body's centre and the two clusters hug the inner edges, so the clock
    // cannot be pushed off centre by a tray icon appearing or by the EQ bars
    // starting. A single content-sized row put it at (left - right) / 2 from
    // the centre: about 25px with an idle tray, up to ~75px with three icons.
    Item {
      id: idleLayout
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: parent.left
      anchors.leftMargin: Theme.pillEarRadius + Theme.pillPaddingLeft
      anchors.right: parent.right
      anchors.rightMargin: Theme.pillEarRadius + Theme.pillPaddingRight
      height: Theme.pillSlot
      opacity: _psm.isExpanded || _psm.meterMode !== "" ? 0 : 1
      clip: true

      // Each side must hold its own cluster *plus* half of the clock, so the
      // body is sized by the wider cluster rather than by their sum. The
      // narrower side simply gets the difference as air, which is what keeps
      // the clock on the centre line.
      readonly property real contentWidth: Math.max(idleLeft.implicitWidth,
        idleRight.implicitWidth) * 2 + idleClock.implicitWidth
        + Theme.pillGroupGap * 2

      Behavior on opacity {
        NumberAnimation { duration: Theme.animDurationFast; easing: Easing.OutQuad }
      }

      RowLayout {
        id: idleLeft
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.pillGroupGap

        EQBars {
          // Visible whenever audio is playing, but never animated at rest: the
          // bars only live in the collapsed pill, and the collapsed pill is
          // the idle state. `animated` can only become true while the pill is
          // open, where these bars are not drawn, so the 160 ms timer never
          // runs.
          active: _audioService.active
          animated: _audioService.active && _psm.isExpanded
          Layout.alignment: Qt.AlignVCenter
        }

        WorkspaceItem {
          workspaceId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0
          visible: workspaceId > 0
          Layout.alignment: Qt.AlignVCenter
        }
      }

      RowLayout {
        id: idleClock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.pillGroupGap

        Txt {
          id: timeText
          Layout.maximumWidth: Theme.pillTimeWidth
          text: Qt.formatDateTime(clock.date, "HH:mm")
          color: Theme.accent
          variant: "body"
          font.weight: Theme.fontWeightClock
          Layout.alignment: Qt.AlignVCenter
          elide: Text.ElideNone
        }

        Txt {
          Layout.maximumWidth: Theme.pillDateWidth
          text: Qt.formatDateTime(clock.date, "dd MMM yyyy")
          color: Theme.foreground
          variant: "body"
          Layout.alignment: Qt.AlignVCenter
          elide: Text.ElideNone
        }
      }

      RowLayout {
        id: idleRight
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.pillGroupGap

        RegWarningIcon {
          Layout.alignment: Qt.AlignVCenter
        }

        PillDivider {
          visible: idleTray.visible
        }

        PillTray {
          id: idleTray
        }

        PillDivider {
          visible: idleTray.visible && idleBattery.visible
        }

        PillBattery {
          id: idleBattery
          service: root.batteryService
          // Number, no glyph, while collapsed: the glyph makes the right arm
          // ~31px wider than the 22px workspace chip, and the centred clock
          // turns that difference into air between the chip and the time. The
          // percentage is the same width as the chip, so nothing is left over,
          // and its colour still reports the level.
          showGlyph: false
          onClicked: {
            if (root.batteryLimitWindow) root.batteryLimitWindow.open()
          }
        }
      }
    }

    RowLayout {
      id: expandedLayout
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: parent.left
      anchors.leftMargin: Theme.pillEarRadius + Theme.pillPaddingLeft
      anchors.right: parent.right
      anchors.rightMargin: Theme.pillEarRadius + Theme.pillPaddingRight
      spacing: Theme.pillGroupGap
      opacity: _psm.isExpanded ? 1 : 0
      clip: true

      Behavior on opacity {
        NumberAnimation { duration: Theme.animDurationNormal; easing: Easing.OutQuad }
      }

      RowLayout {
        spacing: Theme.pillSlotGap
        Layout.alignment: Qt.AlignVCenter
        NetworkIcon {
          width: Theme.pillGlyph
          height: Theme.pillGlyph
          color: Theme.accent
          connected: networkService.connected
          type: networkService.type
        }
        Txt {
          Layout.maximumWidth: Theme.pillIpMaxWidth
          text: networkService.ipAddress
          color: Theme.accent
          variant: "body"
          Layout.minimumWidth: 60
          elide: Text.ElideRight
          clip: true
        }
      }

      PillDivider {}

      Item {
        id: workspaceArea
        readonly property int pitch: Theme.wsSlot + Theme.wsGap
        // Slot index (0..9) of the focused workspace, or -1 when focus is on a
        // workspace outside 1..10. The shared highlight only exists for 1..10.
        readonly property int activeIndex: {
          var id = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0
          return id >= 1 && id <= 10 ? id - 1 : -1
        }
        Layout.preferredWidth: workspaceRow.implicitWidth
        Layout.preferredHeight: Theme.wsSlot
        Layout.alignment: Qt.AlignVCenter

        // One accent pill for the whole strip instead of one per slot: this is
        // the only way the highlight can slide between slots. 150 ms, one
        // shot — nothing is running while the workspace stays put.
        Rectangle {
          width: Theme.wsSlot
          height: Theme.wsSlot
          radius: Theme.wsRadius
          color: Theme.accent
          visible: workspaceArea.activeIndex >= 0
          x: Math.max(0, workspaceArea.activeIndex) * workspaceArea.pitch

          Behavior on x {
            NumberAnimation { duration: Theme.animDurationFast; easing.type: Easing.OutCubic }
          }
        }

        Row {
          id: workspaceRow
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: Theme.wsGap

          Repeater {
            model: 10

            WorkspaceItem {
              required property int index
              workspaceId: index + 1
              activeFill: false
            }
          }
        }
      }

      PillDivider {}

      Txt {
        id: appTitle
        text: root.friendlyAppName(root.titleWindow)
        color: Theme.foreground
        variant: "body"
        elide: Text.ElideRight
        clip: true
        maximumLineCount: 1
        Layout.fillWidth: true
        Layout.maximumWidth: Theme.pillTitleMaxWidth
        Layout.minimumWidth: 0
        Layout.alignment: Qt.AlignVCenter
      }

      PillDivider {}

      // --- actions zone: health + notifications ---
      Item {
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: actionsRow.implicitWidth
        implicitHeight: Theme.pillSlot
        Layout.preferredWidth: actionsRow.implicitWidth
        Layout.preferredHeight: Theme.pillSlot

        RowLayout {
          id: actionsRow
          anchors.centerIn: parent
          spacing: Theme.pillSlotGap

          RegWarningIcon {
            width: Theme.pillSlot
            height: Theme.pillSlot
            Layout.alignment: Qt.AlignVCenter
          }

          HealthIcon {
            id: healthIcon
            width: Theme.pillSlot
            height: Theme.pillSlot
            iconColor: Theme.foreground
            Layout.alignment: Qt.AlignVCenter

            MouseArea {
              anchors.fill: parent
              onClicked: _psm.toggleHealthPanel()
            }
          }

          Item {
            implicitWidth: Theme.pillSlot
            implicitHeight: Theme.pillSlot
            Layout.preferredWidth: Theme.pillSlot
            Layout.preferredHeight: Theme.pillSlot
            Layout.alignment: Qt.AlignVCenter

            Txt {
              anchors.fill: parent
              text: root.notificationLayer && root.notificationLayer.dnd ? "\uF1F7" : "\uF0F3"
              color: root.notificationLayer && root.notificationLayer.dnd ? Theme.comment : Theme.foreground
              variant: "value"
              font.pixelSize: Theme.pillGlyph
              // A Text is top-aligned by default; the slot it fills is taller
              // than the glyph, so centre it or the icon sits high in the row.
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              elide: Text.ElideNone
            }

            Rectangle {
              anchors.right: parent.right
              anchors.top: parent.top
              width: Theme.toggleBadgeSize
              height: Theme.toggleBadgeSize
              radius: Theme.toggleBadgeSize / 2
              color: Theme.red
              border.width: 1
              border.color: Theme.background
              visible: root.notificationLayer && !root.notificationLayer.dnd && root.notificationLayer.notificationCount > 0

              Txt {
                anchors.fill: parent
                text: root.notificationLayer ? Math.min(root.notificationLayer.notificationCount, 9) : ""
                color: Theme.foreground
                variant: "caption"
                font.letterSpacing: 0
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideNone
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: _psm.toggleNotificationCenter()
            }
          }

          Item {
            // Hidden with the feature: no alarms configured means no timetable
            // to show either. The times themselves may still be in flight, and
            // the popup says so rather than inventing them.
            visible: Config.prayerAlarms
            implicitWidth: Theme.pillSlot
            implicitHeight: Theme.pillSlot
            Layout.preferredWidth: Theme.pillSlot
            Layout.preferredHeight: Theme.pillSlot
            Layout.alignment: Qt.AlignVCenter

            PrayerIcon {
              anchors.centerIn: parent
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: if (root.prayerWindow) root.prayerWindow.open()
            }
          }

          KbLayoutIcon {
            width: Theme.pillSlot
            height: Theme.pillSlot
          }
        }
      }

      PillDivider {
        visible: expandedTray.visible
      }

      PillTray {
        id: expandedTray
      }

      PillDivider {
        visible: expandedTray.visible && expandedBattery.visible
      }

      PillBattery {
        id: expandedBattery
        service: root.batteryService
        onClicked: {
          if (root.batteryLimitWindow) root.batteryLimitWindow.open()
        }
      }
    }

    Item {
      id: meterLayout
      height: parent.height
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: parent.left
      anchors.leftMargin: Theme.pillEarRadius + Theme.pillPaddingLeft
      anchors.right: parent.right
      anchors.rightMargin: Theme.pillEarRadius + Theme.pillPaddingRight
      opacity: _psm.meterMode !== "" ? 1 : 0
      visible: _psm.meterMode !== ""
      clip: true

      Behavior on opacity {
        NumberAnimation { duration: Theme.animDurationNormal; easing: Easing.OutQuad }
      }

      RowLayout {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 10

        Txt {
          id: meterIcon
          width: 22
          height: 22
          elide: Text.ElideNone
          Layout.alignment: Qt.AlignVCenter
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter

          text: {
            if (_psm.meterMode === "volume") {
              if (_audioService.headphoneConnected && _audioService.micConnected) return "󰋎"
              if (_audioService.headphoneConnected) return "󰋋"
              if (_audioService.micConnected) return "󰍬"
              if (_audioService.muted) return "\uF026"
              var v = _audioService.volume
              if (v >= 0.67) return "\uF028"
              if (v >= 0.34) return "\uF027"
              if (v > 0) return "\uF026"
              return "\uF026"
            } else if (_psm.meterMode === "caps" || _psm.meterMode === "num") {
              return _psm.meterMode === "caps" ? "A" : "1"
            } else {
              return "󰖨"
            }
          }

          color: {
            if (_psm.meterMode === "volume") {
              return _audioService.muted ? Theme.red : Theme.accent
            } else if (_psm.meterMode === "caps" || _psm.meterMode === "num") {
              return (_psm.meterMode === "caps" ? lockService.capsOn : lockService.numOn) ? Theme.green : Theme.foreground
            } else {
              return Theme.accent
            }
          }

          opacity: {
            if (_psm.meterMode === "brightness") {
              var ratio = Math.max(0, Math.min(1, brightnessService.displayPercent / 100))
              return 0.35 + 0.65 * ratio
            }
            return 1
          }

          variant: "body"
        }

        Rectangle {
          id: meterBarBg
          Layout.alignment: Qt.AlignVCenter
          Layout.preferredWidth: _psm.meterMaxBarWidth
          Layout.minimumWidth: _psm.meterMaxBarWidth
          height: 14
          radius: 7
          color: Theme.selection

          Rectangle {
            id: meterBarFill
            height: parent.height - 3
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 1.5
            radius: parent.radius - 1.5
            width: {
              var maxW = _psm.meterMaxBarWidth - 3
              var pct = _psm.meterMode === "volume"
                ? (_audioService.muted ? 0 : _audioService.volume)
                : _psm.meterMode === "caps"
                  ? (lockService.capsOn ? 1 : 0)
                  : _psm.meterMode === "num"
                    ? (lockService.numOn ? 1 : 0)
                    : (brightnessService.displayPercent / 100)
              return Math.max(0, Math.min(maxW, maxW * pct))
            }
            color: {
              if (_psm.meterMode === "volume")
                return _audioService.muted ? Theme.red : Theme.accent
              if (_psm.meterMode === "caps" || _psm.meterMode === "num") {
                var lit = _psm.meterMode === "caps" ? lockService.capsOn : lockService.numOn
                return lit ? Theme.green : Theme.red
              }
              return brightnessService.displayPercent > 20 ? Theme.accent : Theme.red
            }

            Behavior on width {
              NumberAnimation { duration: Theme.animDurationFast; easing: Easing.OutQuad }
            }
          }
        }

        Txt {
          Layout.maximumWidth: Theme.pillMeterMaxWidth
          text: {
            if (_psm.meterMode === "volume")
              return Math.round(_audioService.volume * 100) + "%"
            if (_psm.meterMode === "caps") return "CAPS"
            if (_psm.meterMode === "num") return "NUM"
            return Math.round(brightnessService.displayPercent) + "%"
          }
          color: {
            if (_psm.meterMode === "volume") return Theme.accent
            if (_psm.meterMode === "caps" || _psm.meterMode === "num") {
              var lit = _psm.meterMode === "caps" ? lockService.capsOn : lockService.numOn
              return lit ? Theme.green : Theme.red
            }
            return Theme.accent
          }
          variant: "body"
          Layout.alignment: Qt.AlignVCenter
          Layout.minimumWidth: 38
          elide: Text.ElideNone
        }
      }
    }

  }

  component RegWarningIcon: Txt {
    id: regWarn
    width: Theme.pillSlot
    height: Theme.pillSlot
    Layout.preferredWidth: Theme.pillSlot
    Layout.preferredHeight: Theme.pillSlot
    text: "󰀦"
    color: Theme.yellow
    variant: "value"
    font.pixelSize: Theme.pillGlyph
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    Layout.alignment: Qt.AlignVCenter
    visible: root.notificationLayer ? root.notificationLayer.registrationFailed : false
    elide: Text.ElideNone
  }

  // Minute-precision clock. The pill only ever shows "HH:mm", so a per-second
  // or 30-second polling timer was pure idle cost: SystemClock wakes exactly
  // once per minute and updates `date` itself.
  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  AudioService {
    id: _audioService
    monitoring: _psm.isExpanded || _psm.meterMode === "volume"
      || (root.healthWindow && root.healthWindow.visible)
  }
  NetworkService {
    id: _networkService
    monitoring: _psm.isExpanded || (root.healthWindow && root.healthWindow.visible)
  }
  BatteryService {
    id: _batteryService
    chargeLimitMonitoring: (root.batteryLimitWindow && root.batteryLimitWindow.visible)
      || (root.healthWindow && root.healthWindow.visible)
  }
  BrightnessService {
    id: brightnessService
    monitoring: _psm.isExpanded || _psm.meterMode === "brightness"
      || (root.healthWindow && root.healthWindow.visible)
  }
  LockService {
    id: lockService
    monitoring: _psm.isExpanded || _psm.meterMode === "caps" || _psm.meterMode === "num"
  }

  Component.onCompleted: {
    root.sharedBrightnessService = brightnessService
  }

  // Hyprland.activeToplevel is populated by a focus *event*, so after the shell
  // restarts with a window already focused it stays null and the title is blank
  // until the next window switch. Seed it once from the compositor, then let
  // the event keep it current; there is no polling.
  Connections {
    target: Hyprland
    function onActiveToplevelChanged() {
      // The event is authoritative: drop the startup seed even when nothing
      // is focused, otherwise a closed window's title would stick.
      root.seededWindow = null
      root.focusedToplevel = Hyprland.activeToplevel
    }
  }

  Process {
    id: seedActiveToplevel
    command: ["hyprctl", "-j", "activewindow"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        if (root.focusedToplevel) return
        try {
          var win = JSON.parse(this.text)
          if (win && win.address) root.seededWindow = win
        } catch (e) {}
      }
    }
  }
}

