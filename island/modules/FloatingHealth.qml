import Quickshell
import Quickshell.Wayland
import QtQuick
import "../config"
import "../components"
import "../services"

// Flat floating container for the health panel. The window is sized to the
// panel body plus one ear radius on each side and padded by Theme.panelPadding.
// The DropShape is shared with the island pill so the silhouette is identical.
PanelWindow {
  id: root
  visible: false
  color: "transparent"

  // Never reserve screen space: the panel floats over whatever is below it.
  exclusionMode: ExclusionMode.Ignore
  exclusiveZone: 0
  aboveWindows: true

  // Window size = visible card + one ear radius on each side.
  property int hpW: 0
  property int hpH: 0
  readonly property int ear: Theme.panelEarRadius
  // Inset of the card body from the window edge (matches Theme.panelPadding).
  readonly property int pad: Theme.panelPadding

  property bool panelActive: false

  signal panelClosed()

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "island-health"

  anchors.top: true
  anchors.left: true
  anchors.right: true
  anchors.bottom: true

  Timer {
    id: autoCloseTimer
    interval: Theme.healthPanelAutoCloseMs
    onTriggered: root.close()
  }

  WeatherService {
    id: _weatherService
    active: root.panelActive
  }
  SystemStatsService { id: _systemStatsService }
  ThermalService { id: _thermalService }
  GpuModeService { id: _gpuModeService }
  ProcessStatsService { id: _processStatsService }
  UpdateService { id: _updateService }
  StorageService { id: _storageService }

  property var audioService: null
  property var brightnessService: null
  property var networkService: null
  property var batteryService: null
  property var weatherService: _weatherService
  property var systemStatsService: _systemStatsService
  property var thermalService: _thermalService
  property var gpuModeService: _gpuModeService
  property var processStatsService: _processStatsService
  property var updateService: _updateService
  property var storageService: _storageService
  property var notificationLayer: null
  property var idleInhibitController: null

  onVisibleChanged: {
    if (root.visible) autoCloseTimer.restart()
    else autoCloseTimer.stop()
  }

  function resetIdleTimer() {
    if (root.visible) autoCloseTimer.restart()
  }

  // Click anywhere outside the panel to dismiss it.
  MouseArea {
    anchors.fill: parent
    onClicked: root.close()
  }

  // ---------------------------------------------------------------------------
  // Panel container. `y` is driven imperatively (never bound) so the drop
  // animation can own it; it is parked at -height whenever the panel is hidden.
  // ---------------------------------------------------------------------------

  Item {
    id: container
    width: root.hpW
    height: root.hpH
    anchors.horizontalCenter: parent.horizontalCenter
    // Parked above the screen edge whenever the panel is hidden.
    y: -Math.max(1, height)

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

    // --- flat drop shape: one shared silhouette, one fill, one border ------
    //
    // Same DropShape component as the island pill, with the large radii. The
    // top edge sits exactly on y = 0 of the screen, and the border path is
    // open along the top so no line is drawn where the panel meets the edge.

    DropShape {
      id: panelShape
      bodyWidth: container.width - root.ear * 2
      bodyHeight: container.height
      earRadius: Theme.panelEarRadius
      bottomRadius: Theme.panelBottomRadius
      fillColor: Theme.background
      borderColor: Theme.shapeBorder
      borderWidth: Theme.cardBorderWidth
    }

    HealthPanel {
      id: healthPanel
      x: root.ear + root.pad
      y: root.pad
      width: Theme.bodyWidth
      height: Theme.columnHeight
      active: root.panelActive
      audioService: root.audioService
      brightnessService: root.brightnessService
      batteryService: root.batteryService
      weatherService: root.weatherService
      networkService: root.networkService
      systemStatsService: root.systemStatsService
      thermalService: root.thermalService
      gpuModeService: root.gpuModeService
      processStatsService: root.processStatsService
      updateService: root.updateService
      storageService: root.storageService
      notificationLayer: root.notificationLayer
      idleInhibitController: root.idleInhibitController
      onUserActivity: root.resetIdleTimer()

      Component.onCompleted: {
        root.hpW = Theme.panelWidth
        root.hpH = Theme.panelHeight
      }
    }
  }

  // --- drop in / drop out ----------------------------------------------------

  NumberAnimation {
    id: dropIn
    target: container
    properties: "y"
    to: 0
    duration: Theme.panelDropInDuration
    easing.type: Easing.OutCubic
  }

  NumberAnimation {
    id: dropOut
    target: container
    properties: "y"
    duration: Theme.panelDropOutDuration
    easing.type: Easing.InCubic
    onFinished: root.finishClose()
  }

  function open() {
    // Re-opening while the close animation is still running simply reverses it.
    var reopening = dropOut.running
    if (root.visible && root.panelActive && !reopening) return

    var wasHidden = !root.visible || !root.panelActive
    root.panelActive = true
    root.visible = true

    if (wasHidden) {
      healthPanel.start()
      healthPanel.playEntrance()
      container.y = -Math.max(1, container.height)
    }

    dropOut.stop()
    dropIn.from = container.y
    dropIn.start()
    autoCloseTimer.restart()
  }

  // Reverses the drop; services and timers are only torn down once the panel
  // has actually left the screen.
  function close() {
    autoCloseTimer.stop()
    if (!root.visible) return
    if (dropOut.running) return
    dropIn.stop()
    dropOut.from = container.y
    dropOut.to = -Math.max(1, container.height)
    dropOut.start()
  }

  function finishClose() {
    if (!root.panelActive) return
    healthPanel.stop()
    root.panelActive = false
    root.visible = false
    container.y = -Math.max(1, container.height)
    root.panelClosed()
  }
}
