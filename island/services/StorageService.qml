import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

// Disk usage for the mount points whitelisted in Theme.diskMounts.
//
// One `df` per sample, and sampling only happens while the panel is open: once
// on start, then every 30s. Overlapping runs are impossible because a sample is
// dropped while a previous df is still in flight.
Item {
  id: root
  visible: false

  property bool active: false
  property double uptimeSeconds: 0

  // [{ mount, label, size, used, percent }] in whitelist order.
  // Mounts that resolve to a filesystem already listed (for example /home on a
  // single-root-disk install) are dropped instead of being shown twice.
  property var volumes: []

  function start() {
    root.active = true
    root.sample()
  }

  function stop() {
    root.active = false
    if (diskProc.running) diskProc.running = false
  }

  function sample() {
    if (!root.active) return
    if (uptimeView.path !== "") uptimeView.reload()
    if (diskProc.running) return
    diskProc.running = true
  }

  function mountArguments() {
    var out = []
    var mounts = Theme.diskMounts || []
    for (var i = 0; i < mounts.length; i++) out.push(mounts[i].mount)
    return out
  }

  function labelFor(mount) {
    var mounts = Theme.diskMounts || []
    for (var i = 0; i < mounts.length; i++) {
      if (mounts[i].mount === mount) return mounts[i].label
    }
    return mount
  }

  function parse(text) {
    var lines = String(text).trim().split("\n")
    var result = []
    var seen = {}
    for (var i = 1; i < lines.length; i++) {
      // target, then three numeric columns; target first so paths with spaces
      // still parse from the right
      var m = lines[i].match(/^(.*?)\s+(\d+)\s+(\d+)\s+(\d+)%$/)
      if (!m) continue
      var mount = m[1]
      if (seen[mount]) {
        // same filesystem reached through another whitelisted path: keep the
        // first (highest priority) label, ignore the duplicate row
        continue
      }
      seen[mount] = true
      result.push({
        "mount": mount,
        "label": root.labelFor(mount),
        "size": Number(m[2]),
        "used": Number(m[3]),
        "percent": Number(m[4])
      })
    }
    root.volumes = result
  }

  FileView {
    id: uptimeView
    path: "/proc/uptime"
    watchChanges: false
    onLoaded: {
      var value = Number(text().trim().split(/\s+/)[0])
      if (isFinite(value)) root.uptimeSeconds = value
    }
  }

  Process {
    id: diskProc
    command: ["env", "LC_ALL=C", "df", "-B1", "--output=target,size,used,pcent"]
      .concat(root.mountArguments())
    running: false
    stdout: StdioCollector {
      onStreamFinished: root.parse(this.text)
    }
  }

  Timer {
    interval: 30000
    running: root.active
    repeat: true
    onTriggered: root.sample()
  }
}
