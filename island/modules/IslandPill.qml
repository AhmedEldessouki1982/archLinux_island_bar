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
  property int pillHeight: 35
  readonly property int pillEarRadius: Theme.pillEarRadius
  property alias inputRegionItem: pill

  // --- drop-shape geometry -------------------------------------------------
  // Horizontal padding inside the body, on top of the ear radius which is
  // part of the silhouette. Content therefore starts at ear + pillPad from
  // the shape's outer edge and is identical on both sides.
  readonly property int pillPad: 12
  readonly property real _pillContentWidth: _psm.meterMode !== ""
    ? _psm.meterPillWidth
    : _psm.isExpanded ? expandedLayout.implicitWidth
    : idleLayout.implicitWidth

  // Body width (excluding the two ears). Rounded to an even number so the
  // total shape width is even and centring lands on a whole pixel.
  property real pillBodyWidth: {
    var w = Math.round(_pillContentWidth) + 2 * pillPad
    return w - (w % 2)
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
  property var notificationLayer: null
  property var notificationCenter: null

  width: parent.width
  height: root.pillHeight

  function friendlyAppName(toplevel) {
    if (!toplevel)
      return "DESKTOP"
    var ipc = toplevel.lastIpcObject || ({})
    var raw = String(ipc["class"] || ipc.initialClass || "").trim()
    if (!raw)
      return "APP"
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
    if (/^python(?:[0-9]+(?:\.[0-9]+)?)?$/.test(key))
      return key.replace(/\.\d+$/, "")
    return raw.length > 0 ? raw.charAt(0).toUpperCase() + raw.slice(1) : "APP"
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
    y: 0
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
      fillColor: Theme.background
      borderColor: Theme.shapeBorder
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

    RowLayout {
      id: idleLayout
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: parent.left
      anchors.leftMargin: Theme.pillEarRadius + root.pillPad
      anchors.right: parent.right
      anchors.rightMargin: Theme.pillEarRadius + root.pillPad
      spacing: Theme.pillGap
      opacity: _psm.isExpanded || _psm.meterMode !== "" ? 0 : 1
      clip: true

      Behavior on opacity {
        NumberAnimation { duration: Theme.animDurationFast; easing: Easing.OutQuad }
      }

      EQBars {
        active: _audioService.active
        animate: _psm.isExpanded || (root.healthWindow && root.healthWindow.visible)
        Layout.alignment: Qt.AlignVCenter
      }

      Txt {
        Layout.maximumWidth: Theme.pillWorkspaceWidth
        text: Hyprland.focusedWorkspace?.id ?? ""
        color: Theme.accent
        variant: "body"
        Layout.alignment: Qt.AlignVCenter
        elide: Text.ElideNone
      }

      Txt {
        id: timeText
        Layout.maximumWidth: Theme.pillTimeWidth
        text: Qt.formatDateTime(root.currentDateTime, "HH:mm")
        color: Theme.accent
        variant: "value"
        Layout.alignment: Qt.AlignVCenter
        elide: Text.ElideNone

        Timer {
          interval: 30000
          running: true
          repeat: true
          onTriggered: root.currentDateTime = new Date()
        }
      }

      Txt {
        Layout.maximumWidth: Theme.pillDateWidth
        text: Qt.formatDateTime(root.currentDateTime, "dd MMM yyyy")
        color: Theme.foreground
        variant: "body"
        Layout.alignment: Qt.AlignVCenter
        elide: Text.ElideNone
      }

      RegWarningIcon {
        Layout.alignment: Qt.AlignVCenter
      }

      Txt {
        Layout.maximumWidth: Theme.fontSizeBody
        text: "|"
        color: Theme.selection
        variant: "body"
        Layout.alignment: Qt.AlignVCenter
        visible: SystemTray.items.length > 0
        elide: Text.ElideNone
      }

      Repeater {
        model: SystemTray.items

        Item {
          id: trayItem
          width: Theme.trayIconSize
          height: Theme.trayIconSize
          Layout.alignment: Qt.AlignVCenter

          required property var modelData

          QsMenuAnchor {
            id: trayMenu
            anchor.item: trayItem
            menu: trayItem.modelData.menu
          }

          Image {
            anchors.centerIn: parent
            source: modelData.icon
            width: Theme.trayIconSize
            height: Theme.trayIconSize
            fillMode: Image.PreserveAspectFit
            sourceSize.width: Theme.trayIconSize
            sourceSize.height: Theme.trayIconSize
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function(mouse) {
              if (mouse.button === Qt.RightButton) {
                if (modelData.hasMenu)
                  trayMenu.open()
              } else {
                modelData.activate()
              }
            }
          }
        }
      }

      VDiv {}

      Txt {
        Layout.maximumWidth: Theme.pillBatteryWidth
        text: Math.round(_batteryService.capacity) + "%"
        color: !_psm.readyForDisplay ? Theme.foreground
          : Theme.batteryColor(_batteryService.capacity, _batteryService.charging)
        variant: "body"
        Layout.alignment: Qt.AlignVCenter
        elide: Text.ElideNone
      }
    }

    RowLayout {
      id: expandedLayout
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: parent.left
      anchors.leftMargin: Theme.pillEarRadius + root.pillPad
      anchors.right: parent.right
      anchors.rightMargin: Theme.pillEarRadius + root.pillPad
      spacing: Theme.pillGap
      opacity: _psm.isExpanded ? 1 : 0
      clip: true

      Behavior on opacity {
        NumberAnimation { duration: Theme.animDurationNormal; easing: Easing.OutQuad }
      }

      NetworkIcon {
        width: Theme.iconSize
        height: Theme.iconSize
        color: Theme.accent
        connected: networkService.connected
        type: networkService.type
        Layout.alignment: Qt.AlignVCenter
      }

      Txt {
        Layout.maximumWidth: Theme.pillIpMaxWidth
        text: networkService.ipAddress
        color: Theme.accent
        variant: "body"
        Layout.minimumWidth: 60
        Layout.alignment: Qt.AlignVCenter
        elide: Text.ElideNone
        clip: true
      }

      Item {
        id: workspaceArea
        Layout.preferredWidth: workspaceRow.implicitWidth
        Layout.preferredHeight: 20
        Layout.alignment: Qt.AlignVCenter

        MouseArea {
          id: workspaceHover
          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.NoButton
        }

        RowLayout {
          id: workspaceRow
          anchors.centerIn: parent
          spacing: 2

          Repeater {
            model: Hyprland.workspaces

            Item {
              id: workspaceItem
              required property var modelData
              readonly property bool occupied: modelData && modelData.toplevels
                ? modelData.toplevels.values.length > 0 : false

              visible: true
              opacity: workspaceHover.containsMouse || occupied
                || (modelData ? modelData.active || modelData.focused : false) ? 1 : 0
              Layout.preferredWidth: txt.implicitWidth + 6
              Layout.preferredHeight: 20
              Layout.alignment: Qt.AlignVCenter

              Txt {
                id: txt
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                text: workspaceItem.modelData?.id ?? ""
                color: workspaceItem.modelData?.focused ? Theme.accent : Theme.comment
                opacity: workspaceItem.occupied || workspaceItem.modelData?.active ? 1 : 0.6
                variant: "body"
                elide: Text.ElideNone
              }

              MouseArea {
                anchors.fill: parent
                enabled: workspaceItem.opacity > 0
                hoverEnabled: false
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (workspaceItem.modelData)
                    workspaceItem.modelData.activate()
                }
              }
            }
          }
        }
      }

      Txt {
        text: root.friendlyAppName(Hyprland.activeToplevel)
        color: Theme.foreground
        variant: "body"
        elide: Text.ElideNone
        clip: true
        maximumLineCount: 1
        Layout.maximumWidth: 140
        Layout.alignment: Qt.AlignVCenter
      }

      // --- actions zone: health + notifications ---
      Item {
        Layout.alignment: Qt.AlignVCenter
        height: 26
        width: actionsRow.implicitWidth

        RowLayout {
          id: actionsRow
          anchors.centerIn: parent
          spacing: Theme.gapSmall

          RegWarningIcon {
            width: Theme.trayIconSize
            height: Theme.trayIconSize
            Layout.alignment: Qt.AlignVCenter
          }

          HealthIcon {
            id: healthIcon
            width: Theme.trayIconSize
            height: Theme.trayIconSize
            iconColor: Theme.foreground
            Layout.alignment: Qt.AlignVCenter

            MouseArea {
              anchors.fill: parent
              onClicked: _psm.toggleHealthPanel()
            }
          }

          Item {
            width: Theme.trayIconSize
            height: Theme.trayIconSize
            Layout.alignment: Qt.AlignVCenter

            Txt {
              anchors.centerIn: parent
              width: parent.width
              height: parent.height
              text: root.notificationLayer && root.notificationLayer.dnd ? "\uF1F7" : "\uF0F3"
              color: root.notificationLayer && root.notificationLayer.dnd ? Theme.comment : Theme.foreground
              variant: "body"
              elide: Text.ElideNone
            }

            Rectangle {
              anchors.right: parent.right
              anchors.top: parent.top
              width: 13
              height: 13
              radius: 6.5
              color: Theme.red
              border.width: 1
              border.color: Theme.background
              visible: root.notificationLayer && !root.notificationLayer.dnd && root.notificationLayer.notificationCount > 0

              Txt {
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                text: root.notificationLayer ? Math.min(root.notificationLayer.notificationCount, 9) : ""
                color: Theme.foreground
                variant: "body"
                elide: Text.ElideNone
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: _psm.toggleNotificationCenter()
            }
          }

          KbLayoutIcon {
            width: Theme.trayIconSize
            height: Theme.trayIconSize
          }
        }
      }

      MouseArea {
        Layout.alignment: Qt.AlignVCenter
        width: 56
        height: Theme.iconSize
        cursorShape: Qt.PointingHandCursor

        BatteryIcon {
          anchors.fill: parent
          percent: _batteryService.capacity
          charging: _batteryService.charging
        }

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
      anchors.leftMargin: Theme.pillEarRadius + root.pillPad
      anchors.right: parent.right
      anchors.rightMargin: Theme.pillEarRadius + root.pillPad
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

  component VDiv: Rectangle {
    width: 1
    height: 16
    color: Theme.comment
    opacity: 0.4
    Layout.alignment: Qt.AlignVCenter
  }

component RegWarningIcon: Txt {
    id: regWarn
    width: Theme.iconSize
    height: Theme.iconSize
    text: "󰀦"
    color: Theme.yellow
    variant: "body"
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    Layout.alignment: Qt.AlignVCenter
    visible: root.notificationLayer ? root.notificationLayer.registrationFailed : false
    elide: Text.ElideNone
  }

  property date currentDateTime: new Date()

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
}

