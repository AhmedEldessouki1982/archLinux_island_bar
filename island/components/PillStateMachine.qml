import QtQuick
import Quickshell
import Quickshell.Io
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
  property bool pointerInside: false

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
      root.healthWindow.panelClosed.connect(() => {
        root.isHealthPanelOpen = false
        // Nothing that widened the pill may outlive the panel, and the OSD must
        // not spring back the moment the card leaves.
        root.clearMeter()
        root.isExpanded = false
        // The pointer did not move, so no hover event is coming to bring the
        // pill back: reclaim it here rather than leaving it collapsed under a
        // cursor that is still on it. Moving off and back works either way.
        if (root.pointerInside) hoverRecheckTimer.restart()
      })
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
    id: meterTimer
    interval: 1500
    onTriggered: root.dismissMeter()
  }

  Timer {
    id: hoverRecheckTimer
    interval: Theme.hoverCollapseDelay
    onTriggered: {
      if (root.meterMode === "" && root.pointerInside && !root.isHealthPanelOpen)
        root.isExpanded = true
      else if (!root.isHealthPanelOpen) root.isExpanded = false
    }
  }

  Timer {
    interval: 500
    running: true
    onTriggered: root.meterReady = true
  }

  // --- hover bridge (set by the pill's single HoverHandler) ---
  function setPointerInside(inside) {
    root.pointerInside = inside
    if (inside) {
      hoverRecheckTimer.stop()
      // The panel owns the screen while it is open: hovering the pill must not
      // stretch it back out from behind the card.
      if (root.meterMode === "" && !root.isHealthPanelOpen) root.isExpanded = true
    } else if (!root.isHealthPanelOpen) {
      hoverRecheckTimer.restart()
    }
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
      root.clearMeter()
    } else {
      if (root.notificationCenter) root.notificationCenter.close()
      if (root.healthWindow) root.healthWindow.open()
      root.isHealthPanelOpen = true
      // The panel replaces the pill: collapse it so it is not left stretched
      // behind the card, drop any OSD that would hold it at meter width, and
      // stop the hover timer that would re-expand it.
      root.clearMeter()
      hoverRecheckTimer.stop()
      root.isExpanded = false
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
    root.clearMeter()
    hoverRecheckTimer.stop()
    root.isExpanded = false
  }

  // --- meter overlay ---

  // The pill's OSD is the only thing that widens it while it is collapsed, so
  // the state - including its timer - goes whenever the panel takes the screen
  // and again when it gives it back. A leftover `meterMode` would leave the
  // pill stretched at meter width with nothing drawn in it.
  function clearMeter() {
    meterTimer.stop()
    if (root.meterMode !== "") root.meterMode = ""
  }

  function showMeter(mode) {
    if (root.isHealthPanelOpen) {
      root.clearMeter()
      return
    }
    root.meterMode = mode
    meterTimer.restart()
  }

  function onMeterActivity(mode) {
    // The panel has its own sliders, and an OSD here would push the collapsed
    // pill out from under the card. Suppress it at the single entry point - the
    // wheel, the keybind IPC and the caps/num listeners all come through here -
    // so no fast poll is asked for either.
    if (root.isHealthPanelOpen) return
    if (!root.meterReady) return
    if (mode === "volume" && root.audioService) root.audioService.requestFastPoll()
    else if (mode === "brightness" && root.brightnessService) root.brightnessService.requestFastPoll()
    root.showMeter(mode)
  }

  function dismissMeter() {
    root.meterMode = ""
    if (root.pointerInside && !root.isHealthPanelOpen) root.isExpanded = true
    else if (!root.isHealthPanelOpen) {
      root.isExpanded = false
      hoverRecheckTimer.restart()
    }
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
