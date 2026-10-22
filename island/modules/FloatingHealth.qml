import Quickshell
import Quickshell.Wayland
import QtQuick
import "../config"
import "../services"

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
    interval: 15000
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

    // --- flat background: one static path, painted only on size change ---
    //
    // Body spans x = ear .. width-ear. Top corners are inverted (concave)
    // radii biting out of the corner, bottom corners are normal convex radii.
    // The whole silhouette is a single filled path, so the ears can never show
    // a seam, and it carries the same colour as the island pill so the panel
    // reads as growing out of it.

    Canvas {
      id: panelShape
      anchors.fill: parent
      antialiasing: true
      renderTarget: Canvas.Image

      property color fillColor: Theme.background
      property color edgeColorA: Theme.panelBorderA
      property color edgeColorB: Theme.panelBorderB
      property real earRadius: Theme.panelEarRadius
      property real bottomRadius: Theme.panelBottomRadius

      onFillColorChanged: requestPaint()
      onEdgeColorAChanged: requestPaint()
      onEdgeColorBChanged: requestPaint()
      onEarRadiusChanged: requestPaint()
      onBottomRadiusChanged: requestPaint()
      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()

      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.clearRect(0, 0, width, height)

        var E = Math.min(earRadius, width / 2, height)
        var B = Math.min(bottomRadius, width / 2, height)
        var W = width
        var H = height

        ctx.beginPath()
        // top-left concave ear: centre (0, E), from (0,0) to (E,E)
        ctx.arc(0, E, E, -Math.PI / 2, 0, false)
        ctx.lineTo(E, H - B)
        // bottom-left convex corner
        ctx.arc(E + B, H - B, B, Math.PI, Math.PI / 2, true)
        ctx.lineTo(W - B, H)
        // bottom-right convex corner
        ctx.arc(W - B, H - B, B, Math.PI / 2, 0, true)
        ctx.lineTo(W - E, E)
        // top-right concave ear: centre (W, E), from (W-E,E) to (W,0)
        ctx.arc(W, E, E, Math.PI, Math.PI * 1.5, false)
        ctx.closePath()

        ctx.fillStyle = fillColor
        ctx.fill()

        var g = ctx.createLinearGradient(0, 0, W, H)
        g.addColorStop(0, edgeColorA)
        g.addColorStop(1, edgeColorB)
        ctx.strokeStyle = g
        ctx.lineWidth = 1
        ctx.stroke()
      }
    }

    HealthPanel {
      id: healthPanel
      x: root.ear
      y: 0
      width: container.width - root.ear * 2
      height: container.height
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
        root.hpW = Qt.binding(() => healthPanel.contentWidth + root.ear * 2)
        root.hpH = Qt.binding(() => healthPanel.contentHeight)
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
