import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray
import "../components"
import "../services"
import "../config"

Item {
  id: root

  property bool isExpanded: false
  property bool isHealthPanelOpen: false
  property int pillHeight: 35
  property var healthWindow: null
  property var batteryLimitWindow: null
  property alias batteryService: _batteryService
  property var sharedBrightnessService: null

  onHealthWindowChanged: {
    if (root.healthWindow)
      root.healthWindow.closed.connect(() => root.isHealthPanelOpen = false)
  }
  property string meterMode: ""
  property int meterPillWidth: 240
  property int meterMaxBarWidth: root.meterPillWidth - 104
  property bool meterReady: false
  property var notificationLayer: null
  property var notificationCenter: null

  width: parent.width
  height: root.pillHeight

  DropShadow {
    id: pillShadow
    anchors.fill: pill
    source: pill
    radius: 16
    samples: 24
    horizontalOffset: 0
    verticalOffset: 4
    color: Qt.rgba(0, 0, 0, 0.4)
    transparentBorder: true
  }

  Rectangle {
    id: pill
    anchors.horizontalCenter: parent.horizontalCenter
    y: 0
    width: root.meterMode !== "" ? root.meterPillWidth
      : root.isExpanded ? expandedLayout.implicitWidth + 24
      : idleLayout.implicitWidth + 24
    height: parent.height
    radius: root.pillHeight / 2
    color: Theme.background
    clip: false

    Behavior on width {
      NumberAnimation {
        duration: Theme.animDurationSlow
        easing.type: Easing.OutBack
        easing.overshoot: 1.3
      }
    }

    Behavior on radius {
      NumberAnimation {
        duration: Theme.animDurationSlow
        easing.type: Easing.OutBack
        easing.overshoot: 1.3
      }
    }

    MouseArea {
      id: mouseArea
      anchors.fill: parent
      hoverEnabled: true
      onEntered: {
        if (root.meterMode === "") root.isExpanded = true
        if (root.isHealthPanelOpen) root.resetAutoClose()
      }
      onExited: {
        if (!root.isHealthPanelOpen) root.isExpanded = false
        if (root.isHealthPanelOpen) root.resetAutoClose()
      }
      onWheel: (event) => {
        var dir = event.angleDelta.y > 0 ? 1 : -1
        if (root.meterMode === "brightness") {
          root.onMeterActivity("brightness")
          brightnessService.stepPercent(dir * 5)
        } else {
          root.onMeterActivity("volume")
          audioService.stepVolume(dir * 0.05)
        }
        event.accepted = true
      }
    }

    RowLayout {
      id: idleLayout
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: parent.left
      anchors.leftMargin: 12
      anchors.right: parent.right
      anchors.rightMargin: 12
      spacing: 10
      opacity: root.isExpanded || root.meterMode !== "" ? 0 : 1
      clip: true

      Behavior on opacity {
        NumberAnimation { duration: Theme.animDurationFast; easing: Easing.OutQuad }
      }

      EQBars {
        active: audioService.active
        Layout.alignment: Qt.AlignVCenter
      }

      Text {
        text: Hyprland.focusedWorkspace?.id ?? ""
        color: Theme.pink
        font.family: Theme.fontFamily
        font.pixelSize: 12
        font.bold: true
        font.letterSpacing: 0.5
      }

      Text {
        text: Hyprland.activeToplevel?.title ?? ""
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: 12
        font.letterSpacing: 0.3
        elide: Text.ElideRight
        maximumLineCount: 1
        Layout.maximumWidth: 140
      }

      Text {
        id: timeText
        text: Qt.formatDateTime(new Date(), "HH:mm")
        color: Theme.accent
        font.family: Theme.fontFamily
        font.pixelSize: 12
        font.letterSpacing: 0.5
        font.bold: true

        Timer {
          interval: 1000
          running: true
          repeat: true
          onTriggered: parent.text = Qt.formatDateTime(new Date(), "HH:mm")
        }
      }

      Text {
        text: Qt.formatDateTime(new Date(), "dd MMM yyyy")
        color: Theme.yellow
        font.family: Theme.fontFamily
        font.pixelSize: 13
        font.bold: true
      }

      RegWarningIcon {
        Layout.alignment: Qt.AlignVCenter
      }

      Text {
        text: "|"
        color: Theme.selection
        font.family: Theme.fontFamily
        font.pixelSize: 14
        font.bold: true
        Layout.alignment: Qt.AlignVCenter
        visible: SystemTray.items.length > 0
      }

      Repeater {
        model: SystemTray.items

        Item {
          width: 22
          height: 22
          Layout.alignment: Qt.AlignVCenter

          required property var modelData

          Image {
            anchors.centerIn: parent
            source: modelData.icon
            width: 18
            height: 18
            fillMode: Image.PreserveAspectFit
            sourceSize.width: 18
            sourceSize.height: 18
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function(mouse) {
              if (mouse.button === Qt.RightButton) {
                if (modelData.hasMenu)
                  modelData.display(root.Window, mouse.x, mouse.y)
              } else {
                modelData.activate()
              }
            }
          }
        }
      }
    }

    RowLayout {
      id: expandedLayout
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: parent.left
      anchors.leftMargin: 12
      anchors.right: parent.right
      anchors.rightMargin: 12
      spacing: 10
      opacity: root.isExpanded ? 1 : 0
      clip: true

      Behavior on opacity {
        NumberAnimation { duration: Theme.animDurationNormal; easing: Easing.OutQuad }
      }

      NetworkIcon {
        width: 16
        height: 16
        color: Theme.cyan
        connected: networkService.connected
        type: networkService.type
        Layout.alignment: Qt.AlignVCenter
      }

      Text {
        text: networkService.ipAddress
        color: Theme.cyan
        font.family: Theme.fontFamily
        font.pixelSize: 11
        font.letterSpacing: 0.3
        Layout.minimumWidth: 60
      }

      VDiv {}

      Repeater {
        model: Hyprland.workspaces

        Item {
          width: txt.implicitWidth + 6
          height: 20

          required property var modelData

          Text {
            id: txt
            anchors.centerIn: parent
            text: modelData?.id ?? ""
            color: modelData?.focused ? Theme.yellow : Theme.comment
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.bold: modelData?.focused ?? false
            font.letterSpacing: 0.5
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (modelData)
                modelData.activate()
            }
          }
        }
      }

      VDiv {}

      Text {
        text: Hyprland.activeToplevel?.title ?? ""
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: 11
        elide: Text.ElideRight
        maximumLineCount: 1
        Layout.maximumWidth: 140
      }

      VDiv {}

      // --- actions zone: health + notifications ---
      Rectangle {
        Layout.alignment: Qt.AlignVCenter
        height: 26
        radius: 13
        width: actionsRow.implicitWidth + 16
        color: Qt.rgba(Theme.selection.r, Theme.selection.g, Theme.selection.b, 0.75)

        RowLayout {
          id: actionsRow
          anchors.centerIn: parent
          spacing: 6

          RegWarningIcon {
            Layout.alignment: Qt.AlignVCenter
          }

          HealthIcon {
            id: healthIcon
            iconColor: Theme.foreground
            Layout.alignment: Qt.AlignVCenter

            MouseArea {
              anchors.fill: parent
              onClicked: root.toggleHealthPanel()
            }
          }

          Item {
            width: 22
            height: 22
            Layout.alignment: Qt.AlignVCenter

            Text {
              anchors.centerIn: parent
              text: "🔔"
              font.family: Theme.fontFamily
              font.pixelSize: 11
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
              visible: root.notificationLayer && root.notificationLayer.notificationCount > 0

              Text {
                anchors.centerIn: parent
                text: root.notificationLayer ? Math.min(root.notificationLayer.notificationCount, 9) : ""
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 8
                font.bold: true
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.toggleNotificationCenter()
            }
          }
        }
      }

      VDiv {}

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
      anchors.leftMargin: 12
      anchors.right: parent.right
      anchors.rightMargin: 12
      opacity: root.meterMode !== "" ? 1 : 0
      visible: root.meterMode !== ""
      clip: true

      Behavior on opacity {
        NumberAnimation { duration: Theme.animDurationNormal; easing: Easing.OutQuad }
      }

      Rectangle {
        anchors.fill: parent
        color: Theme.background
        radius: root.pillHeight / 2
      }

      RowLayout {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 10

        Text {
          id: meterIcon
          width: 22
          height: 22
          Layout.alignment: Qt.AlignVCenter

          font.family: Theme.fontFamily
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter

          text: {
            if (root.meterMode === "volume") {
              if (audioService.headphoneConnected && audioService.micConnected) return "\uF02D6"
              if (audioService.headphoneConnected) return "\uF02CB"
              if (audioService.micConnected) return "\uF036C"
              if (audioService.muted) return "\uF026"
              var v = audioService.volume
              if (v >= 0.67) return "\uF028"
              if (v >= 0.34) return "\uF027"
              if (v > 0) return "\uF026"
              return "\uF026"
            } else if (root.meterMode === "caps" || root.meterMode === "num") {
              return root.meterMode === "caps" ? "A" : "1"
            } else {
              return "\uF006D"
            }
          }

          color: {
            if (root.meterMode === "volume") {
              return audioService.muted ? Theme.red : Theme.accent
            } else if (root.meterMode === "caps" || root.meterMode === "num") {
              return (root.meterMode === "caps" ? lockService.capsOn : lockService.numOn) ? Theme.green : Theme.foreground
            } else {
              return Theme.yellow
            }
          }

          opacity: {
            if (root.meterMode === "brightness") {
              var ratio = Math.max(0, Math.min(1, brightnessService.displayPercent / 100))
              return 0.35 + 0.65 * ratio
            }
            return 1
          }

          font.bold: root.meterMode === "caps" || root.meterMode === "num"
          font.pixelSize: root.meterMode === "caps" || root.meterMode === "num" ? 20 : 24
        }

        Rectangle {
          id: meterBarBg
          Layout.alignment: Qt.AlignVCenter
          Layout.preferredWidth: root.meterMaxBarWidth
          Layout.minimumWidth: root.meterMaxBarWidth
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
              var maxW = root.meterMaxBarWidth - 3
              var pct = root.meterMode === "volume"
                ? (audioService.muted ? 0 : audioService.volume)
                : root.meterMode === "caps"
                  ? (lockService.capsOn ? 1 : 0)
                  : root.meterMode === "num"
                    ? (lockService.numOn ? 1 : 0)
                    : (brightnessService.displayPercent / 100)
              return Math.max(0, Math.min(maxW, maxW * pct))
            }
            color: {
              if (root.meterMode === "volume")
                return audioService.muted ? Theme.red : Theme.accent
              if (root.meterMode === "caps" || root.meterMode === "num") {
                var lit = root.meterMode === "caps" ? lockService.capsOn : lockService.numOn
                return lit ? Theme.green : Theme.red
              }
              return brightnessService.displayPercent > 20 ? Theme.yellow : Theme.red
            }

            Behavior on width {
              NumberAnimation { duration: Theme.animDurationFast; easing: Easing.OutQuad }
            }
          }
        }

        Text {
          text: {
            if (root.meterMode === "volume")
              return Math.round(audioService.volume * 100) + "%"
            if (root.meterMode === "caps") return "CAPS"
            if (root.meterMode === "num") return "NUM"
            return Math.round(brightnessService.displayPercent) + "%"
          }
          color: {
            if (root.meterMode === "volume") return Theme.accent
            if (root.meterMode === "caps" || root.meterMode === "num") {
              var lit = root.meterMode === "caps" ? lockService.capsOn : lockService.numOn
              return lit ? Theme.green : Theme.red
            }
            return Theme.yellow
          }
          font.family: Theme.fontFamily
          font.pixelSize: 13
          font.bold: true
          font.letterSpacing: 0.5
          Layout.alignment: Qt.AlignVCenter
          Layout.minimumWidth: 38
        }
      }
    }

    Canvas {
      id: pillBorder
      anchors.fill: parent
      antialiasing: true
      property real boundRadius: parent.radius
      onBoundRadiusChanged: requestPaint()
      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()
      onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        var g = ctx.createLinearGradient(0, 0, width, height)
        g.addColorStop(0, Theme.borderA)
        g.addColorStop(1, Theme.borderB)
        ctx.strokeStyle = g
        ctx.lineWidth = 1.5
        ctx.lineCap = "round"
        var x = 0.75, y = 0.75
        var w = width - 1.5, h = height - 1.5
        var r = Math.min(parent.radius, w / 2, h / 2)
        ctx.beginPath()
        ctx.moveTo(x + r, y)
        ctx.lineTo(x + w - r, y)
        ctx.arcTo(x + w, y, x + w, y + r, r)
        ctx.lineTo(x + w, y + h - r)
        ctx.arcTo(x + w, y + h, x + w - r, y + h, r)
        ctx.lineTo(x + r, y + h)
        ctx.arcTo(x, y + h, x, y + h - r, r)
        ctx.lineTo(x, y + r)
        ctx.arcTo(x, y, x + r, y, r)
        ctx.closePath()
        ctx.stroke()
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

component RegWarningIcon: Text {
    id: regWarn
    text: "\uF0026"
    color: Theme.yellow
    font.family: Theme.fontFamily
    font.pixelSize: 17
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    Layout.alignment: Qt.AlignVCenter
    visible: root.notificationLayer ? root.notificationLayer.registrationFailed : false
  }

  Timer {
    id: autoCloseTimer
    interval: 10000
    running: root.isHealthPanelOpen
    onTriggered: root.closeHealthPanel()
  }

  Timer {
    id: meterTimer
    interval: 1500
    onTriggered: root.dismissMeter()
  }

  Timer {
    id: hoverRecheckTimer
    interval: 300
    onTriggered: {
      if (root.meterMode === "" && mouseArea.containsMouse)
        root.isExpanded = true
    }
  }

  Timer {
    interval: 500
    running: true
    onTriggered: root.meterReady = true
  }

  function toggleHealthPanel() {
    if (root.isHealthPanelOpen) {
      root.healthWindow.close()
      root.isHealthPanelOpen = false
    } else {
      if (root.notificationCenter) root.notificationCenter.close()
      root.healthWindow.open()
      root.isHealthPanelOpen = true
      resetAutoClose()
    }
  }

  function toggleNotificationCenter() {
    if (root.notificationCenter && root.notificationCenter.visible) {
      root.notificationCenter.close()
    } else {
      if (root.healthWindow && root.isHealthPanelOpen) root.closeHealthPanel()
      if (root.notificationCenter) root.notificationCenter.toggle()
    }
  }

  function closeHealthPanel() {
    root.healthWindow.close()
    root.isHealthPanelOpen = false
  }

  function resetAutoClose() {
    autoCloseTimer.stop()
    autoCloseTimer.start()
  }

  function showMeter(mode) {
    root.meterMode = mode
    meterTimer.restart()
  }

  function onMeterActivity(mode) {
    if (!root.meterReady) return
    if (mode === "volume") audioService.requestFastPoll()
    else if (mode === "brightness") brightnessService.requestFastPoll()
    root.showMeter(mode)
  }

  function dismissMeter() {
    root.meterMode = ""
    root.isExpanded = false
    hoverRecheckTimer.start()
  }

  AudioService { id: audioService }
  NetworkService { id: networkService }
  BatteryService { id: _batteryService }
  BrightnessService { id: brightnessService }
  LockService { id: lockService }

  Component.onCompleted: root.sharedBrightnessService = brightnessService

  IpcHandler {
    target: "island"
    function triggerMeter(mode: string): void {
      root.onMeterActivity(mode)
    }
    function toggleHealth(): void {
      root.toggleHealthPanel()
    }
    function adjustBrightness(delta: int): void {
      root.onMeterActivity("brightness")
      brightnessService.stepPercent(delta)
    }
  }

  Connections {
    target: audioService
    function onExternalChangeDetected() { if (!root.isHealthPanelOpen) root.onMeterActivity("volume") }
  }

  Connections {
    target: brightnessService
    function onExternalChangeDetected() { if (!root.isHealthPanelOpen) root.onMeterActivity("brightness") }
  }

  Connections {
    target: lockService
    function onCapsChanged() { root.onMeterActivity("caps") }
    function onNumChanged() { root.onMeterActivity("num") }
  }
}