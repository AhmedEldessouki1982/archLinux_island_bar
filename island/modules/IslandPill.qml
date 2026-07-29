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

  width: parent.width
  height: root.pillHeight

  Rectangle {
    id: pill
    anchors.horizontalCenter: parent.horizontalCenter
    y: 0
    width: root.isExpanded ? expandedLayout.implicitWidth + 24 : idleLayout.implicitWidth + 24
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
      opacity: root.isExpanded ? 0 : 1
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

  }

  Timer {
    id: autoCloseTimer
    interval: 10000
    running: root.isHealthPanelOpen
    onTriggered: root.closeHealthPanel()
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

  AudioService { id: audioService }
  NetworkService { id: networkService }
  BatteryService { id: batteryService }
  BrightnessService { id: brightnessService }

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