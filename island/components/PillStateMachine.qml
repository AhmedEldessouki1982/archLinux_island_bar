import QtQuick
import Quickshell
import "../config"

Item {
  id: root
  visible: false

  // --- public state ---
  property bool isExpanded: false
  property bool isHealthPanelOpen: false
  property string meterMode: ""
  property bool meterReady: false
  property bool readyForDisplay: false

  // --- external references ---
  property var healthWindow: null
  property var batteryLimitWindow: null
  property var notificationLayer: null
  property var notificationCenter: null

  // --- services (set by IslandPill) ---
  property var audioService: null
  property var brightnessService: null
  property var lockService: null

  // --- meter geometry ---
  property int meterPillWidth: 240
  property int meterMaxBarWidth: root.meterPillWidth - 104

  onHealthWindowChanged: {
    if (root.healthWindow)
      root.healthWindow.closed.connect(() => root.isHealthPanelOpen = false)
  }

  // --- timers ---

  Timer {
    id: bootDelayTimer
    interval: 5000
    running: true
    repeat: false
    onTriggered: root.readyForDisplay = true
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
      if (root.meterMode === "" && mouseArea && mouseArea.containsMouse)
        root.isExpanded = true
    }
  }

  Timer {
    interval: 500
    running: true
    onTriggered: root.meterReady = true
  }

  // --- hover bridge (set by IslandPill's MouseArea) ---
  property QtObject mouseArea: null

  function onHoverEntered() {
    if (root.meterMode === "") root.isExpanded = true
    if (root.isHealthPanelOpen) root.resetAutoClose()
  }

  function onHoverExited() {
    if (!root.isHealthPanelOpen) root.isExpanded = false
    if (root.isHealthPanelOpen) root.resetAutoClose()
  }

  function onWheel(dir) {
    if (root.meterMode === "brightness") {
      root.onMeterActivity("brightness")
      if (root.brightnessService) root.brightnessService.stepPercent(dir * 5)
    } else {
      root.onMeterActivity("volume")
      if (root.audioService) root.audioService.stepVolume(dir * 0.05)
    }
  }

  // --- health panel orchestration ---

  function toggleHealthPanel() {
    if (root.isHealthPanelOpen) {
      if (root.healthWindow) root.healthWindow.close()
      root.isHealthPanelOpen = false
    } else {
      if (root.notificationCenter) root.notificationCenter.close()
      if (root.healthWindow) root.healthWindow.open()
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
    if (root.healthWindow) root.healthWindow.close()
    root.isHealthPanelOpen = false
  }

  function resetAutoClose() {
    autoCloseTimer.stop()
    autoCloseTimer.start()
  }

  // --- meter overlay ---

  function showMeter(mode) {
    root.meterMode = mode
    meterTimer.restart()
  }

  function onMeterActivity(mode) {
    if (!root.meterReady) return
    if (mode === "volume" && root.audioService) root.audioService.requestFastPoll()
    else if (mode === "brightness" && root.brightnessService) root.brightnessService.requestFastPoll()
    root.showMeter(mode)
  }

  function dismissMeter() {
    root.meterMode = ""
    root.isExpanded = false
    hoverRecheckTimer.start()
  }

  // --- IPC ---

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
      if (root.brightnessService) root.brightnessService.stepPercent(delta)
    }
  }

  // --- service event listeners ---

  Connections {
    target: root.audioService
    function onExternalChangeDetected() { if (!root.isHealthPanelOpen) root.onMeterActivity("volume") }
  }

  Connections {
    target: root.brightnessService
    function onExternalChangeDetected() { if (!root.isHealthPanelOpen) root.onMeterActivity("brightness") }
  }

  Connections {
    target: root.lockService
    function onCapsChanged() { root.onMeterActivity("caps") }
    function onNumChanged() { root.onMeterActivity("num") }
  }
}