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

  property bool isExpanded: false
  property bool isHealthPanelOpen: false
  property int pillHeight: 35
  property var healthWindow: null

  onHealthWindowChanged: {
    if (root.healthWindow)
      root.healthWindow.closed.connect(() => root.isHealthPanelOpen = false)
  }
  property string meterMode: ""
  property int meterPillWidth: 240
  property bool meterReady: false
  property var notificationLayer: null
  property var notificationCenter: null

  width: parent.width
  height: root.pillHeight

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
        duration: 300
        easing: Easing.OutCubic
      }
    }

    Behavior on radius {
      NumberAnimation {
        duration: 300
        easing: Easing.OutCubic
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
        NumberAnimation { duration: 150; easing: Easing.OutQuad }
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
        font.pixelSize: 11
        font.bold: true
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
        NumberAnimation { duration: 200; easing: Easing.OutQuad }
      }

      NetworkIcon {
        width: 16
        height: 16
        color: Theme.cyan
        connected: networkService.connected
        type: networkService.type
        Layout.alignment: Qt.AlignVCenter
        Connections {
          target: networkService
          function onTypeChanged() { parent.requestPaint() }
        }
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
          width: txt.implicitWidth + (modelData?.focused ? 14 : 6)
          height: 20

          required property var modelData

          Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Theme.accent
            visible: modelData?.focused ?? false
          }

          Text {
            id: txt
            anchors.centerIn: parent
            text: modelData?.id ?? ""
            color: modelData?.focused ? Theme.background : Theme.comment
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

      BatteryIcon {
        percent: batteryService.capacity
        charging: batteryService.charging
        Layout.alignment: Qt.AlignVCenter
      }
    }

    Item {
      id: meterLayout
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: parent.left
      anchors.leftMargin: 12
      anchors.right: parent.right
      anchors.rightMargin: 12
      opacity: root.meterMode !== "" ? 1 : 0
      visible: root.meterMode !== ""
      clip: false

      Behavior on opacity {
        NumberAnimation { duration: 200; easing: Easing.OutQuad }
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

        Canvas {
          id: meterIcon
          width: 22
          height: 22
          Layout.alignment: Qt.AlignVCenter

          onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.lineCap = "round"
            ctx.lineJoin = "round"
            ctx.globalAlpha = 1

            var cx = 11, cy = 11
            if (root.meterMode === "volume") {
              var muted = audioService.muted
              var vol = audioService.volume
              ctx.strokeStyle = muted ? Theme.red : Theme.accent
              ctx.fillStyle = ctx.strokeStyle
              ctx.lineWidth = 2

              ctx.beginPath()
              ctx.rect(cx - 4, cy - 4, 3, 8)
              ctx.fill()
              ctx.beginPath()
              ctx.moveTo(cx - 1, cy - 5)
              ctx.lineTo(cx + 3, cy - 8)
              ctx.lineTo(cx + 3, cy + 8)
              ctx.lineTo(cx - 1, cy + 5)
              ctx.closePath()
              ctx.fill()

              if (!muted && vol > 0) {
                var wx = cx + 4
                ctx.beginPath()
                ctx.arc(wx, cy, 3, 5.8, 6.6, false)
                ctx.stroke()
                if (vol > 0.33) {
                  ctx.beginPath()
                  ctx.arc(wx, cy, 5, 5.8, 6.6, false)
                  ctx.stroke()
                }
                if (vol > 0.66) {
                  ctx.beginPath()
                  ctx.arc(wx, cy, 7, 5.8, 6.6, false)
                  ctx.stroke()
                }
              }
            } else if (root.meterMode === "caps" || root.meterMode === "num") {
              var lit = root.meterMode === "caps" ? lockService.capsOn : lockService.numOn
              ctx.strokeStyle = lit ? Theme.green : Theme.foreground
              ctx.fillStyle = ctx.strokeStyle
              ctx.lineWidth = 2

              ctx.beginPath()
              ctx.rect(cx - 6, cy - 6, 12, 12)
              ctx.stroke()

              ctx.font = "bold 9px 'JetBrainsMono Nerd Font'"
              ctx.textAlign = "center"
              ctx.textBaseline = "middle"
              ctx.fillText(root.meterMode === "caps" ? "A" : "1", cx, cy + 0.5)

              if (lit) {
                ctx.fillStyle = Theme.green
                ctx.beginPath()
                ctx.arc(cx + 5, cy - 5, 1.5, 0, Math.PI * 2)
                ctx.fill()
              }
            } else {
              var bp = brightnessService.percent
              var ratio = Math.max(0, Math.min(1, bp / 100))
              ctx.strokeStyle = Theme.yellow
              ctx.fillStyle = Theme.yellow
              ctx.globalAlpha = 0.35 + 0.65 * ratio

              var coreR = 3 + 2 * ratio
              ctx.lineWidth = 2
              ctx.beginPath()
              ctx.arc(cx, cy, coreR, 0, Math.PI * 2)
              ctx.stroke()

              var rayCount = ratio > 0.6 ? 8 : (ratio > 0.15 ? 4 : 0)
              var rayLen = 2.5 + 2 * ratio
              var inner = coreR + 1
              for (var i = 0; i < rayCount; i++) {
                var a = i * Math.PI * 2 / rayCount - Math.PI / 2
                ctx.lineWidth = 1.8
                ctx.beginPath()
                ctx.moveTo(cx + Math.cos(a) * inner, cy + Math.sin(a) * inner)
                ctx.lineTo(cx + Math.cos(a) * (inner + rayLen), cy + Math.sin(a) * (inner + rayLen))
                ctx.stroke()
              }
              ctx.globalAlpha = 1
            }
          }

          Connections {
            target: root
            function onMeterModeChanged() { meterIcon.requestPaint() }
          }

          Connections {
            target: audioService
            function onVolumeChanged() { if (root.meterMode === "volume") meterIcon.requestPaint() }
            function onMutedChanged() { if (root.meterMode === "volume") meterIcon.requestPaint() }
          }

          Connections {
            target: brightnessService
            function onPercentChanged() { if (root.meterMode === "brightness") meterIcon.requestPaint() }
          }

          Connections {
            target: lockService
            function onCapsChanged() { if (root.meterMode === "caps") meterIcon.requestPaint() }
            function onNumChanged() { if (root.meterMode === "num") meterIcon.requestPaint() }
          }
        }

        Rectangle {
          id: meterBarBg
          Layout.alignment: Qt.AlignVCenter
          Layout.fillWidth: true
          Layout.minimumWidth: 120
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
              var maxW = meterBarBg.width - 3
              var pct = root.meterMode === "volume"
                ? (audioService.muted ? 0 : audioService.volume)
                : root.meterMode === "caps"
                  ? (lockService.capsOn ? 1 : 0)
                  : root.meterMode === "num"
                    ? (lockService.numOn ? 1 : 0)
                    : (brightnessService.percent / 100)
              return Math.max(0, Math.min(maxW, maxW * pct))
            }
            color: {
              if (root.meterMode === "volume")
                return audioService.muted ? Theme.red : Theme.accent
              if (root.meterMode === "caps" || root.meterMode === "num") {
                var lit = root.meterMode === "caps" ? lockService.capsOn : lockService.numOn
                return lit ? Theme.green : Theme.red
              }
              return brightnessService.percent > 20 ? Theme.yellow : Theme.red
            }

            Behavior on width {
              NumberAnimation { duration: 100; easing: Easing.OutQuad }
            }
          }
        }

        Text {
          text: {
            if (root.meterMode === "volume")
              return Math.round(audioService.volume * 100) + "%"
            if (root.meterMode === "caps") return "CAPS"
            if (root.meterMode === "num") return "NUM"
            return Math.round(brightnessService.percent) + "%"
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

  }

  component VDiv: Rectangle {
    width: 1
    height: 16
    color: Theme.comment
    opacity: 0.4
    Layout.alignment: Qt.AlignVCenter
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
  BatteryService { id: batteryService }
  BrightnessService { id: brightnessService }
  LockService { id: lockService }

  IpcHandler {
    target: "island"
    function triggerMeter(mode: string): void {
      root.onMeterActivity(mode)
    }
    function toggleHealth(): void {
      root.toggleHealthPanel()
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