import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Networking
import "../components"
import "../services"
import "../config"

Item {
  id: root

  property bool isExpanded: false
  property bool isHealthPanelOpen: false
  property int pillHeight: 35
  property var healthWindow: null
  property string meterMode: ""
  property int meterPillWidth: 240
  property bool meterReady: false

  width: parent.width
  height: root.pillHeight

  Rectangle {
    id: pill
    anchors.horizontalCenter: parent.horizontalCenter
    y: 0
    width: root.meterMode !== "" ? root.meterPillWidth : (root.isExpanded ? expandedLayout.implicitWidth + 24 : idleLayout.implicitWidth + 24)
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
        root.isExpanded = true
        if (root.isHealthPanelOpen) root.resetAutoClose()
      }
      onExited: {
        if (!root.isHealthPanelOpen) root.isExpanded = false
        if (root.isHealthPanelOpen) root.resetAutoClose()
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
        font.pixelSize: 12
        font.bold: true
        font.letterSpacing: 0.5
      }

      Text {
        text: Hyprland.activeToplevel?.title ?? ""
        color: Theme.foreground
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
        font.pixelSize: 11
        font.bold: true
      }

      Text {
        text: "|"
        color: Theme.selection
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
        font.pixelSize: 11
        font.letterSpacing: 0.3
        Layout.minimumWidth: 60
      }

      Rectangle {
        width: 1
        height: 14
        color: Theme.selection
        Layout.alignment: Qt.AlignVCenter
      }

      VolumeIcon {
        id: volumeIcon
        color: audioService.muted ? Theme.red : Theme.foreground
        volume: audioService.volume
        muted: audioService.muted
        headphoneConnected: audioService.headphoneConnected
        Layout.alignment: Qt.AlignVCenter
        onScrollRequested: delta => audioService.stepVolume(delta)
        onToggleMuteRequested: audioService.toggleMute()
      }

      BrightnessIcon {
        percent: brightnessService.percent
        Layout.alignment: Qt.AlignVCenter
        color: Theme.foreground

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onWheel: event => {
            var delta = event.angleDelta.y > 0 ? 5 : -5
            brightnessService.stepPercent(delta)
          }
          onClicked: brightnessService.setPercent(brightnessService.percent > 50 ? 20 : 80)
        }
      }

      Rectangle {
        width: 1
        height: 14
        color: Theme.selection
        Layout.alignment: Qt.AlignVCenter
      }

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
            color: modelData?.focused ? Theme.accent : Theme.selection
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

      Rectangle {
        width: 1
        height: 14
        color: Theme.selection
        Layout.alignment: Qt.AlignVCenter
      }

      Text {
        text: Hyprland.activeToplevel?.title ?? ""
        color: Theme.foreground
        font.pixelSize: 11
        elide: Text.ElideRight
        maximumLineCount: 1
        Layout.maximumWidth: 140
      }

      Rectangle {
        width: 1
        height: 14
        color: Theme.selection
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

      Rectangle {
        width: 1
        height: 14
        color: Theme.selection
        Layout.alignment: Qt.AlignVCenter
      }

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
            ctx.strokeStyle = root.meterMode === "volume" ? Theme.accent : Theme.yellow
            ctx.fillStyle = ctx.strokeStyle
            ctx.lineWidth = 2
            ctx.lineCap = "round"
            ctx.lineJoin = "round"

            var cx = 11, cy = 11
            if (root.meterMode === "volume") {
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
            } else {
              ctx.beginPath()
              ctx.arc(cx, cy, 4, 0, Math.PI * 2)
              ctx.stroke()
              ctx.lineWidth = 2.5
              for (var i = 0; i < 4; i++) {
                var a = i * Math.PI / 2
                ctx.beginPath()
                ctx.moveTo(cx + Math.cos(a) * 5.5, cy + Math.sin(a) * 5.5)
                ctx.lineTo(cx + Math.cos(a) * 8, cy + Math.sin(a) * 8)
                ctx.stroke()
              }
            }
          }

          Connections {
            target: root
            function onMeterModeChanged() { meterIcon.requestPaint() }
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
                : (brightnessService.percent / 100)
              return Math.max(0, Math.min(maxW, maxW * pct))
            }
            color: {
              if (root.meterMode === "volume")
                return audioService.muted ? Theme.red : Theme.accent
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
            return Math.round(brightnessService.percent) + "%"
          }
          color: root.meterMode === "volume" ? Theme.accent : Theme.yellow
          font.pixelSize: 13
          font.bold: true
          font.letterSpacing: 0.5
          Layout.alignment: Qt.AlignVCenter
          Layout.minimumWidth: 38
        }
      }
    }

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
    interval: 500
    running: true
    onTriggered: root.meterReady = true
  }

  function toggleHealthPanel() {
    if (root.isHealthPanelOpen) {
      root.healthWindow.close()
      root.isHealthPanelOpen = false
    } else {
      root.healthWindow.open()
      root.isHealthPanelOpen = true
      resetAutoClose()
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
    root.showMeter(mode)
  }

  function dismissMeter() {
    root.meterMode = ""
  }

  AudioService { id: audioService }
  NetworkService { id: networkService }
  BatteryService { id: batteryService }
  BrightnessService { id: brightnessService }

  Connections {
    target: audioService
    function onExternalChangeDetected() { root.onMeterActivity("volume") }
  }

  Connections {
    target: brightnessService
    function onExternalChangeDetected() { root.onMeterActivity("brightness") }
  }

  function setupHealthBindings() {
    if (root.healthWindow) {
      root.healthWindow.batteryPower = Qt.binding(() => batteryService.power)
      root.healthWindow.batteryCharging = Qt.binding(() => batteryService.charging)
      root.healthWindow.batteryCapacity = Qt.binding(() => batteryService.capacity)
    }
  }

  onHealthWindowChanged: root.setupHealthBindings()
  Component.onCompleted: root.setupHealthBindings()
}