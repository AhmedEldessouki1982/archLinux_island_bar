import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  visible: false

  property bool active: false
  property int count: -1
  property double lastRefreshMs: 0
  readonly property string cachePath: Quickshell.statePath("island-updates.cache")
  readonly property double refreshIntervalMs: 3600000

  function start() {
    root.active = true
    if (root.count < 0 || Date.now() - root.lastRefreshMs >= root.refreshIntervalMs)
      root.refresh()
  }

  function stop() {
    root.active = false
    if (updateProc.running) updateProc.running = false
  }

  function refresh() {
    if (!updateProc.running) updateProc.running = true
  }

  Process {
    id: updateProc
    command: ["sh", "-c",
      "cache=$1; now=$(date +%s); if [ -r \"$cache\" ]; then read ts count < \"$cache\"; if [ -n \"$ts\" ] && [ $((now-ts)) -lt 3600 ]; then printf '%s|%s\\n' \"$count\" \"$ts\"; exit 0; fi; fi; updates=$(checkupdates 2>/dev/null); rc=$?; if [ $rc -eq 0 ] || [ $rc -eq 2 ]; then if [ -n \"$updates\" ]; then count=$(printf '%s\\n' \"$updates\" | wc -l); else count=0; fi; printf '%s %s\\n' \"$now\" \"$count\" > \"$cache\"; printf '%s|%s\\n' \"$count\" \"$now\"; elif [ -r \"$cache\" ]; then read ts count < \"$cache\"; printf '%s|%s\\n' \"$count\" \"$ts\"; else printf '%s\\n' '-1|0'; fi",
      "island-updates", root.cachePath]
    running: false
    stdout: SplitParser {
      onRead: data => {
        var fields = String(data).trim().split("|")
        if (fields.length !== 2) return
        var value = Number(fields[0])
        var timestamp = Number(fields[1])
        root.count = isFinite(value) ? value : -1
        root.lastRefreshMs = isFinite(timestamp) ? timestamp * 1000 : 0
      }
    }
  }

  Timer {
    interval: root.refreshIntervalMs
    running: root.active
    repeat: true
    onTriggered: root.refresh()
  }
}
