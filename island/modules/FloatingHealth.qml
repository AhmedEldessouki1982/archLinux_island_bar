import Quickshell
import Quickshell.Wayland
import QtQuick
import "../config"
import "../services"

PanelWindow {
  id: root
  visible: false
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  aboveWindows: true

  property int hpW: 0
  property int hpH: 0

  signal panelClosed()

  WlrLayershell.layer: WlrLayer.Overlay

  anchors.top: true
  anchors.left: true
  anchors.right: true
  anchors.bottom: true

  Timer {
    id: autoCloseTimer
    interval: 15000
    onTriggered: root.close()
  }

  property bool panelActive: false

  WeatherService { id: _weatherService }
  SystemStatsService { id: _systemStatsService }
  ThermalService { id: _thermalService }
  GpuModeService { id: _gpuModeService }

  property var audioService: null
  property var brightnessService: null
  property var networkService: null
  property var batteryService: null
  property var weatherService: _weatherService
  property var systemStatsService: _systemStatsService
  property var thermalService: _thermalService
  property var gpuModeService: _gpuModeService

  onVisibleChanged: {
    if (root.visible) autoCloseTimer.restart()
    else autoCloseTimer.stop()
  }

  function resetIdleTimer() {
    if (root.visible) autoCloseTimer.restart()
  }

  MouseArea {
    anchors.fill: parent
    onClicked: root.close()
  }

  Item {
    id: container
    width: root.hpW
    height: root.hpH
    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.topMargin: 44
    opacity: 0

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onEntered: root.resetIdleTimer()
      onPositionChanged: root.resetIdleTimer()
      onPressed: mouse => {
        root.resetIdleTimer()
      }
    }

    HoverHandler {
      target: container
      blocking: false
      onHoveredChanged: {
        if (hovered) root.resetIdleTimer()
      }
      onPointChanged: {
        if (hovered) root.resetIdleTimer()
      }
    }

    Behavior on opacity {
      NumberAnimation { duration: Theme.animDurationNormal; easing: Easing.OutQuad }
    }

    Rectangle {
      anchors.fill: parent
      radius: 12
      color: Theme.background
      clip: true
      border.width: 1
      border.color: Theme.selection

      HealthPanel {
        id: healthPanel
        anchors.fill: parent
        active: root.panelActive
        audioService: root.audioService
        brightnessService: root.brightnessService
        batteryService: root.batteryService
        weatherService: root.weatherService
        networkService: root.networkService
        systemStatsService: root.systemStatsService
        thermalService: root.thermalService
        gpuModeService: root.gpuModeService
        onUserActivity: root.resetIdleTimer()

        Component.onCompleted: {
          root.hpW = Qt.binding(() => healthPanel.contentWidth + 24)
          root.hpH = Qt.binding(() => healthPanel.contentHeight)
        }
      }
    }

    // --- corner dots (cosmetic "hardware panel" accent) ---

    Rectangle {
      width: 5
      height: 5
      radius: 2.5
      color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.topMargin: 7
      anchors.leftMargin: 9
    }

    Rectangle {
      width: 5
      height: 5
      radius: 2.5
      color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.topMargin: 7
      anchors.rightMargin: 9
    }

    Rectangle {
      width: 5
      height: 5
      radius: 2.5
      color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      anchors.bottomMargin: 7
      anchors.leftMargin: 9
    }

    Rectangle {
      width: 5
      height: 5
      radius: 2.5
      color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
      anchors.bottom: parent.bottom
      anchors.right: parent.right
      anchors.bottomMargin: 7
      anchors.rightMargin: 9
    }
  }

  function open() {
    root.panelActive = true
    root.visible = true
    container.opacity = 0
    container.opacity = 1
    healthPanel.start()
  }

  function close() {
    autoCloseTimer.stop()
    container.opacity = 0
    healthPanel.stop()
    root.panelActive = false
    root.visible = false
    root.panelClosed()
  }
}
