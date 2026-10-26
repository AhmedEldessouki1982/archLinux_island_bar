import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

// Prayer alarms: each of the five obligatory prayers is announced by name at
// the minute it falls due, for the location the weather card already uses.
//
// Times come from AlAdhan, once per day, and are cached with the day, the place
// and the calculation they were fetched for. A shell started at noon reuses that
// cache and makes no request at all; a shell started before Fajr makes exactly
// one. This is the only thing in Island that talks to the network with the UI
// closed, and an alarm cannot work any other way.
//
// Scheduling is a single one-shot Timer armed for the next event - the next
// prayer, or midnight when the day's list is spent - and it sleeps the rest of
// the time. A per-minute clock check would be a permanent poll *and* up to 59 s
// late; a prayer at 05:37 should ring at 05:37.
//
// `iso8601=true` makes every timing an absolute instant carrying the location's
// own offset ("2026-10-26T05:37:00+03:00"). The alarm therefore fires at the
// right moment whatever timezone the machine is in, and no timezone comparison
// between this machine and the location is needed.
Item {
  id: root
  visible: false

  // The five prayers, in the order they occur. Sunrise is deliberately absent:
  // it is a time, not a prayer.
  readonly property var prayerNames: ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
  readonly property string cachePath: Quickshell.statePath("island-prayers.json")

  // A prayer that has just passed is still announced inside this window - the
  // resume-from-suspend case - and dropped (recorded as missed) after it.
  readonly property int graceMs: 120000
  // A failed fetch is retried a few times, then left for the next day: a
  // permanent retry loop with the UI closed would be a poll.
  readonly property int retryMs: 900000
  readonly property int maxRetries: 4
  // A prayer that falls due while the shell is still starting is delivered a
  // moment later, once the notification server has claimed its bus name.
  readonly property int startDelayMs: 1500

  property bool enabled: Config.prayerAlarms
  property int method: Config.prayerMethod
  property int school: Config.prayerSchool
  property var wantedPrayers: Config.prayerNames
  // WeatherService: the coordinates and the city name to print on the banner.
  property var location: null

  readonly property real latitude: root.location ? Number(root.location.latitude) : NaN
  readonly property real longitude: root.location ? Number(root.location.longitude) : NaN
  readonly property string city: root.location ? String(root.location.city || "") : ""

  // Coordinates are the location's identity: a pinned city that moves, or an
  // ISP that changes its mind, moves these and invalidates the cached times.
  readonly property string locationKey: isFinite(root.latitude) && isFinite(root.longitude)
    ? root.latitude.toFixed(2) + "," + root.longitude.toFixed(2) : ""

  property var times: ({})
  property string loadedDay: ""
  property string loadedKey: ""
  property int loadedMethod: -1
  property int loadedSchool: -1
  property var fired: ({})
  property var missed: []
  property int retries: 0
  property string lastAlarm: ""

  function todayKey() {
    return Qt.formatDate(new Date(), "dd-MM-yyyy")
  }

  // One definition of "the cached times are usable": the day, the place and the
  // calculation all have to be the ones being asked for now.
  function haveTimes() {
    return root.locationKey.length > 0
      && root.loadedDay === root.todayKey()
      && root.loadedKey === root.locationKey
      && root.loadedMethod === root.method
      && root.loadedSchool === root.school
      && Object.keys(root.times).length > 0
  }

  function wantsPrayer(name) {
    var list = root.wantedPrayers || []
    for (var i = 0; i < list.length; i++)
      if (list[i] === name) return true
    return false
  }

  function sync() {
    if (!root.enabled || root.locationKey.length === 0) {
      armTimer.stop()
      return
    }
    root.armNext()
  }

  function setTimer(target, delay) {
    armTimer.target = target
    armTimer.interval = Math.max(1000, Math.round(delay))
    armTimer.start()
  }

  // The whole schedule, recomputed from scratch: cheapest correct way to handle
  // a changed location, a changed method, a fired prayer and a clock that moved.
  function armNext() {
    armTimer.stop()
    if (!root.enabled) return
    if (!root.haveTimes()) {
      root.fetchTimes()
      return
    }
    var now = Date.now()
    var target = ""
    var at = 0
    for (var i = 0; i < root.prayerNames.length; i++) {
      var name = root.prayerNames[i]
      if (!root.wantsPrayer(name) || root.fired[name]) continue
      var t = Number(root.times[name])
      if (!isFinite(t)) continue
      if (now - t > root.graceMs) { root.markMissed(name); continue }
      if (at === 0 || t < at) { at = t; target = name }
    }
    if (target === "") {
      // Nothing left today: wake just past midnight and ask for the new day.
      var midnight = new Date()
      midnight.setHours(24, 0, 15, 0)
      root.setTimer("", midnight.getTime() - now)
      return
    }
    // `at` in the past means the moment slipped by while the machine slept; the
    // grace window above is what makes that a late alarm rather than a missed
    // one. The floor keeps the notification server ahead of us at startup.
    root.setTimer(target, Math.max(root.startDelayMs, at - now))
  }

  function markMissed(name) {
    var copy = root.missed.slice()
    if (copy.indexOf(name) < 0) copy.push(name)
    root.missed = copy
    console.log("prayer: " + name + " passed unannounced on " + root.loadedDay)
  }

  function announce(name, at) {
    var when = Qt.formatTime(new Date(at), "HH:mm")
    var body = root.city.length > 0 ? when + " \u00b7 " + root.city : when
    root.lastAlarm = name + " " + body
    console.log("prayer alarm: " + name + " \u00b7 " + when + " (" + root.city + ")")
    // Urgency critical: NotificationLayer gives it no deadline, so the banner
    // waits for a dismissal instead of expiring in six seconds.
    notifyProc.command = ["notify-send", "-a", "Island", "-u", "critical",
      "-t", "0", name, body]
    if (!notifyProc.running) notifyProc.running = true
  }

  function fire(target) {
    if (target === "retry") { root.fetchTimes(); return }
    if (target === "") {
      // Woke early (a clock nudge): try again in a moment instead of skipping
      // the day, which is what re-arming for the *next* midnight would do.
      if (root.haveTimes()) { root.setTimer("", 5000); return }
      root.retries = 0
      root.fired = ({})
      root.fetchTimes()
      return
    }
    var at = Number(root.times[target])
    var now = Date.now()
    if (!isFinite(at) || now - at > root.graceMs) {
      root.markMissed(target)
      root.armNext()
      return
    }
    var marked = Object.assign({}, root.fired)
    marked[target] = true
    root.fired = marked
    root.announce(target, at)
    root.saveCache()
    root.armNext()
  }

  function fetchTimes() {
    if (!root.enabled || fetchProc.running) return
    if (!isFinite(root.latitude) || !isFinite(root.longitude)) return
    fetchProc.command = ["curl", "-sS", "--max-time", "10",
      "https://api.aladhan.com/v1/timings/" + root.todayKey()
      + "?latitude=" + root.latitude + "&longitude=" + root.longitude
      + "&method=" + root.method + "&school=" + root.school + "&iso8601=true"]
    fetchProc.running = true
  }

  function retry() {
    if (root.retries >= root.maxRetries) {
      console.log("prayer: no times for " + root.todayKey() + " after "
        + root.retries + " attempts")
      return
    }
    root.retries += 1
    root.setTimer("retry", root.retryMs)
  }

  function applyResponse(body) {
    var text = String(body).trim()
    if (text.length === 0 || text.indexOf("{") !== 0) { root.retry(); return }
    var payload = null
    try { payload = JSON.parse(text) } catch (e) { payload = null }
    var data = payload && payload.data ? payload.data : null
    if (!data || !data.timings) { root.retry(); return }
    var out = ({})
    for (var i = 0; i < root.prayerNames.length; i++) {
      var name = root.prayerNames[i]
      // iso8601 gives "2026-10-26T05:37:00+03:00"; the split also survives a
      // plain "05:37 (EEST)" if the flag is ever ignored.
      var iso = String(data.timings[name] || "").split(" ")[0]
      var ms = new Date(iso).getTime()
      if (isFinite(ms)) out[name] = ms
    }
    if (Object.keys(out).length !== root.prayerNames.length) { root.retry(); return }
    root.times = out
    root.loadedDay = root.todayKey()
    root.loadedKey = root.locationKey
    root.loadedMethod = root.method
    root.loadedSchool = root.school
    root.retries = 0
    root.saveCache()
    root.armNext()
  }

  function applyCache(data) {
    root.loadedDay = String(data.day || "")
    root.loadedKey = String(data.key || "")
    root.loadedMethod = data.method === undefined ? -1 : Number(data.method)
    root.loadedSchool = data.school === undefined ? -1 : Number(data.school)
    root.times = data.times && typeof data.times === "object" ? data.times : ({})
    root.fired = data.fired && typeof data.fired === "object" ? data.fired : ({})
    root.lastAlarm = String(data.lastAlarm || "")
  }

  function saveCache() {
    cache.setText(JSON.stringify({
      day: root.loadedDay,
      key: root.loadedKey,
      method: root.loadedMethod,
      school: root.loadedSchool,
      times: root.times,
      fired: root.fired,
      lastAlarm: root.lastAlarm
    }))
  }

  Process {
    id: fetchProc
    command: ["true"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: root.applyResponse(this.text)
    }
  }

  Process {
    id: notifyProc
    command: ["true"]
    running: false
  }

  Timer {
    id: armTimer
    repeat: false
    running: false
    property string target: ""
    onTriggered: root.fire(armTimer.target)
  }

  FileView {
    id: cache
    path: root.cachePath
    watchChanges: false
    onLoaded: {
      try { root.applyCache(JSON.parse(text())) } catch (e) {}
      root.sync()
    }
    onLoadFailed: error => {
      if (error === FileViewError.FileNotFound) cache.setText("{}")
      root.sync()
    }
  }

  // Every input that changes the schedule re-derives it; nothing polls.
  onEnabledChanged: root.sync()
  onMethodChanged: root.sync()
  onSchoolChanged: root.sync()
  onWantedPrayersChanged: root.sync()
  onLocationKeyChanged: root.sync()
}
