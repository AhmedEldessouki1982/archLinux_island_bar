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

  // Two clock-scales, deliberately different:
  //   - the cache lives for 5 minutes, only so opening and closing the panel a
  //     few times does not re-run `checkupdates` (a network read) each time;
  //   - a pacman transaction invalidates it immediately, whatever its age,
  //     because a count of pending updates that survives the update it
  //     describes is worse than no number at all.
  //
  // `/var/log/pacman.log` is the signal: world-readable, and ALPM appends to it
  // at every transaction, so its mtime is later than the cache as soon as an
  // update has landed. No root, no pacman hook, no polling.
  readonly property string probe: "cache=$1; now=$(date +%s);"
    + " log=$(stat -c %Y /var/log/pacman.log 2>/dev/null || echo 0);"
    + " if [ -r \"$cache\" ]; then"
    + " read ts count < \"$cache\";"
    + " if [ -n \"$ts\" ] && [ $((now-ts)) -lt 300 ] && [ \"$log\" -le \"$ts\" ]; then"
    + " printf '%s|%s\\n' \"$count\" \"$ts\"; exit 0; fi; fi;"
    + " updates=$(checkupdates 2>/dev/null); rc=$?;"
    + " if [ $rc -eq 0 ] || [ $rc -eq 2 ]; then"
    + " if [ -n \"$updates\" ]; then count=$(printf '%s\\n' \"$updates\" | wc -l); else count=0; fi;"
    + " printf '%s %s\\n' \"$now\" \"$count\" > \"$cache\";"
    + " printf '%s|%s\\n' \"$count\" \"$now\";"
    + " elif [ -r \"$cache\" ]; then read ts count < \"$cache\";"
    + " printf '%s|%s\\n' \"$count\" \"$ts\";"
    + " else printf '%s\\n' '-1|0'; fi"

  // Opening the panel always asks. The cache above decides whether that costs a
  // `checkupdates` run, so the "still fresh" branch lives in one place instead
  // of being duplicated in QML as a one-hour gate that hid every update made in
  // the last hour.
  function start() {
    root.active = true
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
    command: ["sh", "-c", root.probe, "island-updates", root.cachePath]
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

  // While the panel stays open for a long session, re-ask hourly. The cache
  // still absorbs it unless the five minutes have passed.
  Timer {
    interval: root.refreshIntervalMs
    running: root.active
    repeat: true
    onTriggered: root.refresh()
  }
}
