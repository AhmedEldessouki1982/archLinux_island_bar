import QtQuick
import Quickshell
import Quickshell.Services.UPower

// UPower verification on Quickshell 0.3.0 (unlike Quickshell.Services.Pipewire,
// where PwNodeAudio.volume/.muted read 0 and PwLink.state is stuck):
//   - UPowerDevice.percentage -> 0..1 fraction (NOT 0..100), live
//   - UPowerDevice.state      -> raw UPowerDeviceState (Charging=1,
//     Discharging=2, FullyCharged=4, PendingCharge=5); stateChanged fires on
//     AC plug/unplug
//   - UPowerDevice.changeRate -> real watts, changeRateChanged fires
// All three verified against sysfs /sys/class/power_supply/BAT0 through a live
// AC plug/unplug cycle. No polling fallback needed.

Item {
  id: root
  visible: false

  property var battery: null
  property int capacity: root.battery ? Math.round(root.battery.percentage * 100) : 0
  property bool charging: !UPower.onBattery
  property real power: root.battery ? root.battery.changeRate : 0

  function pickBattery() {
    var vals = UPower.devices.values
    for (var i = 0; i < vals.length; i++) {
      var d = vals[i]
      if (d.isLaptopBattery) {
        root.battery = d
        return
      }
    }
  }

  Connections {
    target: UPower.devices
    function onValuesChanged() { root.pickBattery() }
  }

  Component.onCompleted: root.pickBattery()

  Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: {
      if (!root.battery) root.pickBattery()
    }
  }
}
