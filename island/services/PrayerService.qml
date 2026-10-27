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
// between this machine and the location is needed. That offset is kept, so the
// day keys are the location's too: a pinned city abroad rolls over at its own
// midnight rather than at this machine's.
//
// What is cached is only trusted for the day, the place and the calculation it
// was fetched for. The set of prayers already announced is dropped with them -
// carrying it forward silently swallowed the next day's alarms.
Item {
  id: root
  visible: false

  // The five prayers, in the order they occur. Sunrise is deliberately absent:
  // it is a time, not a prayer.
  readonly property var prayerNames: ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
  readonly property string cachePath: Quickshell.statePath("island-prayers.json")

  // A prayer that has just passed is still announced inside this window - the
  // resume-from-suspend case - and dropped silently after it.
  readonly property int graceMs: 120000
  // A failed fetch is retried a few times, then the scheduler sleeps until the
  // next midnight and asks again: a permanent retry loop with the UI closed
  // would be a poll. What it must never do is go quiet for the rest of the
  // session, which is how a boot with no network lost every alarm that day.
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
  // The request those times answer. Stamped from what was asked for, never from
  // what is current: `haveTimes()` then tells the truth when the city moved
  // while the request was in flight, and the next reply is asked for again.
  property string fetchDay: ""
  property string fetchKey: ""
  property int fetchMethod: -1
  property int fetchSchool: -1
  property var fired: ({})
  property int retries: 0
  // The location's offset from UTC in ms, as carried by the last reply. It is
  // what makes the day keys - and so the midnight rollover - the location's.
  // Until one arrives, this machine's offset is the best guess there is.
  property real zoneOffsetMs: -60000 * new Date().getTimezoneOffset()

  // This machine's UTC offset in ms, east of Greenwich.
  function machineOffsetMs() {
    return -60000 * new Date().getTimezoneOffset()
  }

  // The location's wall clock as a naive timestamp: read as UTC, it spells the
  // time on the location's own clocks.
  function wallClockMs() {
    return Date.now() + root.zoneOffsetMs
  }

  // The location's calendar day. Formatting reads a Date in this machine's zone,
  // so the machine's own offset is taken back out first.
  function todayKey() {
    return Qt.formatDate(new Date(root.wallClockMs() - root.machineOffsetMs()), "dd-MM-yyyy")
  }

  // Milliseconds from now to 00:00:15 at the location - the first moment it is
  // worth asking for the new day. Always inside (0, 24 h].
  function nextDayDelay() {
    var wall = root.wallClockMs()
    var target = Math.floor(wall / 86400000) * 86400000 + 15000
    if (target <= wall) target += 86400000
    return target - wall
  }

  // One definition of "the times in hand describe exactly what is asked for".
  function sameIdentity() {
    return root.loadedDay === root.todayKey()
      && root.loadedKey === root.locationKey
      && root.loadedMethod === root.method
      && root.loadedSchool === root.school
  }

  // One definition of "the cached times are usable": the day, the place and the
  // calculation all have to be the ones being asked for now.
  function haveTimes() {
    return root.locationKey.length > 0 && root.sameIdentity()
      && Object.keys(root.times).length > 0
  }

  // The announced set belongs to the list it was recorded against. Carrying it
  // into a new day - or a new city - is what silently swallowed that day's
  // alarms, so it goes with the identity. Nothing is dropped while the
  // coordinates are still unknown: a restart at noon would otherwise announce
  // prayers that had already fired.
  function forgetStaleAlarms() {
    if (root.locationKey.length === 0 || root.sameIdentity()) return
    if (Object.keys(root.fired).length > 0) root.fired = ({})
  }

  // A prayer cannot have been announced before it fell due. A flag that says it
  // was was written against an older list, and honouring it would mute the alarm
  // for good, so it is dropped. This also heals caches written before the set
  // was identity-scoped, without waiting for the day to change.
  function forgetImpossibleAlarms() {
    var now = Date.now()
    var kept = ({})
    var dropped = false
    for (var i = 0; i < root.prayerNames.length; i++) {
      var name = root.prayerNames[i]
      if (!root.fired[name]) continue
      var t = Number(root.times[name])
      if (isFinite(t) && t - now > root.graceMs) { dropped = true; continue }
      kept[name] = true
    }
    if (!dropped) return
    root.fired = kept
    root.saveCache()
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
      root.forgetStaleAlarms()
      // One hop rather than a direct call: this is also the path a reply takes
      // when it answered a request that is no longer current, and the process
      // that delivered it may not have cleared `running` yet.
      root.setTimer("retry", 1000)
      return
    }
    root.forgetImpossibleAlarms()
    var now = Date.now()
    var target = ""
    var at = 0
    for (var i = 0; i < root.prayerNames.length; i++) {
      var name = root.prayerNames[i]
      if (!root.wantsPrayer(name) || root.fired[name]) continue
      var t = Number(root.times[name])
      if (!isFinite(t)) continue
      // Past the grace window the moment was missed and there is nothing left to
      // do about it today; a resume from suspend inside the window still rings.
      if (now - t > root.graceMs) continue
      if (at === 0 || t < at) { at = t; target = name }
    }
    if (target === "") {
      // Nothing left today: wake just past midnight and ask for the new day.
      root.setTimer("", root.nextDayDelay())
      return
    }
    // `at` in the past means the moment slipped by while the machine slept; the
    // grace window above is what makes that a late alarm rather than a missed
    // one. The floor keeps the notification server ahead of us at startup.
    root.setTimer(target, Math.max(root.startDelayMs, at - now))
  }

  function announce(name, at) {
    var when = Qt.formatTime(new Date(at), "HH:mm")
    var body = root.city.length > 0 ? when + " \u00b7 " + root.city : when
    console.log("prayer alarm: " + name + " \u00b7 " + when + " (" + root.city + ")")
    // Urgency critical: NotificationLayer gives it no deadline, so the banner
    // waits for a dismissal instead of expiring in six seconds.
    notifyProc.command = ["notify-send", "-a", "Island", "-u", "critical",
      "-t", "0", name, body]
    if (!notifyProc.running) notifyProc.running = true
  }

  function fire(target) {
    if (target === "retry") {
      // Nothing to ask for if the schedule was switched off, the coordinates are
      // still unknown (the location signal re-derives it), or the times arrived
      // while this timer was pending.
      if (!root.enabled || root.locationKey.length === 0 || root.haveTimes()) return
      // A silent no-op here used to leave the scheduler with nothing pending, so
      // a failed start never recovered: keep a timer either way.
      if (!root.fetchTimes()) root.setTimer("retry", root.retryMs)
      return
    }
    if (target === "") {
      // The day's list is spent, or a timer woke early after a clock jump.
      // Starting over covers both: `armNext` asks for new times only when
      // today's are not in hand, so a nudge with valid times just re-derives.
      root.retries = 0
      root.forgetStaleAlarms()
      root.armNext()
      return
    }
    var at = Number(root.times[target])
    var now = Date.now()
    // Past the grace window the moment was missed. More than `startDelayMs` in
    // the future means the schedule moved under the timer - a clock correction,
    // or new times - and announcing now would be ahead of the minute it names.
    if (!isFinite(at) || now - at > root.graceMs || at - now > root.startDelayMs) {
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

  // Returns whether a request was actually started, so the caller can re-arm
  // instead of assuming one is on the wire.
  function fetchTimes() {
    if (!root.enabled || fetchProc.running) return false
    if (!isFinite(root.latitude) || !isFinite(root.longitude)) return false
    root.fetchDay = root.todayKey()
    root.fetchKey = root.locationKey
    root.fetchMethod = root.method
    root.fetchSchool = root.school
    fetchProc.command = ["curl", "-sS", "--max-time", "10",
      "https://api.aladhan.com/v1/timings/" + root.fetchDay
      + "?latitude=" + root.latitude + "&longitude=" + root.longitude
      + "&method=" + root.method + "&school=" + root.school + "&iso8601=true"]
    fetchProc.running = true
    return true
  }

  function retry() {
    if (root.retries >= root.maxRetries) {
      // Out of attempts for today: sleep to just past midnight and ask again, so
      // the scheduler always owns a timer. The cost is that a machine that comes
      // back online later the same day waits for the rollover.
      console.log("prayer: no times for " + root.todayKey() + " after "
        + root.retries + " attempts; next try after midnight")
      root.setTimer("", root.nextDayDelay())
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
    // The reply has to be for the day on the wire, not for the day being asked
    // for now: a proxy or a retry can hand back an older one. Only a reply that
    // positively names another day in the expected shape is rejected; anything
    // unparsable is left alone, so a change of formatting cannot go silent.
    var answered = data.date && data.date.gregorian
      ? String(data.date.gregorian.date || "") : ""
    if (/^\d{2}-\d{2}-\d{4}$/.test(answered) && answered !== root.fetchDay) {
      root.retry()
      return
    }
    var out = ({})
    for (var i = 0; i < root.prayerNames.length; i++) {
      var name = root.prayerNames[i]
      // iso8601 gives "2026-10-26T05:37:00+03:00".
      var iso = String(data.timings[name] || "").split(" ")[0]
      var ms = new Date(iso).getTime()
      if (isFinite(ms)) out[name] = ms
    }
    if (Object.keys(out).length !== root.prayerNames.length) { root.retry(); return }
    root.keepOffset(String(data.timings.Fajr || ""))
    // Stamped with the request, not with what is current. If the city moved
    // while curl was running, `haveTimes()` now says "not for this place" and
    // the schedule asks again instead of another city's times passing as this
    // one's for the rest of the day.
    root.times = out
    root.loadedDay = root.fetchDay
    root.loadedKey = root.fetchKey
    root.loadedMethod = root.fetchMethod
    root.loadedSchool = root.fetchSchool
    root.retries = 0
    root.saveCache()
    root.armNext()
  }

  // Keep the location's UTC offset carried by its own timestamps. A new offset
  // that moves the date leaves `haveTimes()` false, so `armNext` asks for the
  // location's real day before anything is scheduled.
  function keepOffset(iso) {
    var m = String(iso).match(/([+-])(\d{2}):(\d{2})$/)
    if (!m) return
    var sign = m[1] === "-" ? -1 : 1
    root.zoneOffsetMs = sign * (Number(m[2]) * 60 + Number(m[3])) * 60000
  }

  function applyCache(data) {
    root.loadedDay = String(data.day || "")
    root.loadedKey = String(data.key || "")
    root.loadedMethod = data.method === undefined ? -1 : Number(data.method)
    root.loadedSchool = data.school === undefined ? -1 : Number(data.school)
    root.times = data.times && typeof data.times === "object" ? data.times : ({})
    root.fired = data.fired && typeof data.fired === "object" ? data.fired : ({})
    var zone = Number(data.zoneOffsetMs)
    if (data.zoneOffsetMs !== undefined && data.zoneOffsetMs !== null && isFinite(zone))
      root.zoneOffsetMs = zone
  }

  function saveCache() {
    cache.setText(JSON.stringify({
      day: root.loadedDay,
      key: root.loadedKey,
      method: root.loadedMethod,
      school: root.loadedSchool,
      zoneOffsetMs: root.zoneOffsetMs,
      times: root.times,
      fired: root.fired
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
    // The alarm is marked fired whether or not the banner appeared, so a failure
    // here would otherwise leave no trace at all.
    onExited: (exitCode, exitStatus) => {
      if (exitCode !== 0) console.log("prayer: notify-send exited " + exitCode)
    }
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
