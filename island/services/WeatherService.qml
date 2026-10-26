import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

Item {
  id: root
  visible: false

  // Where the coordinates come from.
  //
  //   Config.weatherCity === ""  -> ipwho.is, re-resolved every geoMaxAgeMs.
  //                                 The ISP decides the city, and it can decide
  //                                 differently tomorrow, so the coordinates are
  //                                 a cache with an expiry rather than a fact.
  //   Config.weatherCity !== ""  -> that city, geocoded once via open-meteo.
  //                                 The IP lookup is never made.
  //
  // `geoKey` is what the current coordinates were resolved from ("" for IP,
  // the city string otherwise). Comparing it with `wantedKey` is what notices a
  // changed setting, including a restart that reloaded the cache.
  //
  // Two consumers share this location: the weather card, and the prayer alarms
  // (PrayerService reads latitude/longitude/city). The alarms have to work with
  // the panel never opened, so the coordinates are resolved on cache load even
  // while inactive - one request per boot when the cache has expired, none when
  // it has not. The forecast itself stays panel-gated: `pendingForecast` records
  // that the coordinates moved without a forecast for them, so the next open
  // fetches instead of showing the old city's temperature.
  readonly property string wantedKey: Config.weatherCity.trim()
  readonly property double geoMaxAgeMs: 6 * 3600000
  readonly property double cacheMaxAgeMs: 1800000

  property string city: ""
  property real tempC: 0
  property real feelsLikeC: 0
  property real highC: 0
  property real lowC: 0
  property int weatherCode: -1
  property string _pendingCity: ""
  property bool active: false
  property real latitude: NaN
  property real longitude: NaN
  property double lastFetchMs: 0
  property double geolocatedMs: 0
  property string geoKey: ""
  // Coordinates resolved while the panel was closed, so no forecast exists for
  // them yet. Cleared by the forecast that answers them.
  property bool pendingForecast: false

  // Daylight. Both values come out of the same forecast request, so no extra
  // network call is made: is_day is part of `current`, sunrise and sunset are
  // part of `daily`.
  property bool isDay: true
  property string sunriseIso: ""
  property string sunsetIso: ""

  readonly property string sunriseText: formatClock(root.sunriseIso)
  readonly property string sunsetText: formatClock(root.sunsetIso)

  function formatClock(iso) {
    if (!iso || iso.length < 16) return ""
    var d = new Date(iso)
    if (isNaN(d.getTime())) return ""
    return Qt.formatTime(d, "HH:mm")
  }

  // Day/night from the local sunrise and sunset; the clock window 06:00-18:00
  // is the fallback when the forecast has no daylight data.
  function updateDaylight() {
    var now = new Date()
    var rise = root.sunriseIso.length > 0 ? new Date(root.sunriseIso) : null
    var set = root.sunsetIso.length > 0 ? new Date(root.sunsetIso) : null
    if (rise && set && !isNaN(rise.getTime()) && !isNaN(set.getTime())) {
      root.isDay = now >= rise && now < set
      return
    }
    var hour = now.getHours()
    root.isDay = hour >= 6 && hour < 18
  }

  function needsGeolocation() {
    if (root.geoKey !== root.wantedKey) return true
    if (!isFinite(root.latitude) || !isFinite(root.longitude)) return true
    return Date.now() - root.geolocatedMs >= root.geoMaxAgeMs
  }

  // Coordinates just moved to a new place, so any forecast on screen describes
  // the old one. Ask for a new forecast only when the card is actually open;
  // otherwise leave a note for the next open.
  function afterGeolocation() {
    if (root.active) root.fetchWeather()
    else root.pendingForecast = true
  }

  function refresh() {
    if (geoProc.running || geocodeProc.running || weatherProc.running) return
    if (root.needsGeolocation()) root.startGeolocation()
    else root.fetchWeather()
  }

  function startGeolocation() {
    if (root.wantedKey.length > 0) {
      geocodeProc.command = ["curl", "-sS", "--max-time", "8",
        "https://geocoding-api.open-meteo.com/v1/search?name="
        + encodeURIComponent(root.wantedKey)
        + "&count=1&language=en&format=json"]
      if (!geocodeProc.running) geocodeProc.running = true
    } else if (!geoProc.running) {
      geoProc.running = true
    }
  }

  function fetchWeather() {
    weatherProc.command = ["curl", "-sS", "--max-time", "8",
      "https://api.open-meteo.com/v1/forecast?latitude=" + root.latitude
      + "&longitude=" + root.longitude
      + "&current=temperature_2m,apparent_temperature,weather_code,is_day"
      + "&daily=temperature_2m_max,temperature_2m_min,sunrise,sunset&forecast_days=1&timezone=auto"]
    if (!weatherProc.running) weatherProc.running = true
  }

  function applyData(data) {
    root.city = String(data.city || "")
    root._pendingCity = root.city
    root.latitude = Number(data.latitude)
    root.longitude = Number(data.longitude)
    root.tempC = Number(data.tempC) || 0
    root.feelsLikeC = Number(data.feelsLikeC) || 0
    root.highC = Number(data.highC) || 0
    root.lowC = Number(data.lowC) || 0
    root.weatherCode = Number(data.weatherCode)
    root.lastFetchMs = Number(data.lastFetchMs) || 0
    root.geolocatedMs = Number(data.geolocatedMs) || 0
    root.geoKey = String(data.geoKey || "")
    root.sunriseIso = String(data.sunriseIso || "")
    root.sunsetIso = String(data.sunsetIso || "")
    if (data.isDay !== undefined) root.isDay = !!data.isDay
    if (data.pendingForecast !== undefined) root.pendingForecast = !!data.pendingForecast
    root.updateDaylight()
  }

  function saveCache() {
    cache.setText(JSON.stringify({
      city: root.city,
      latitude: root.latitude,
      longitude: root.longitude,
      tempC: root.tempC,
      feelsLikeC: root.feelsLikeC,
      highC: root.highC,
      lowC: root.lowC,
      weatherCode: root.weatherCode,
      isDay: root.isDay,
      sunriseIso: root.sunriseIso,
      sunsetIso: root.sunsetIso,
      lastFetchMs: root.lastFetchMs,
      geolocatedMs: root.geolocatedMs,
      geoKey: root.geoKey,
      pendingForecast: root.pendingForecast
    }))
  }

  Process {
    id: geoProc
    command: ["curl", "-sS", "--max-time", "8", "https://ipwho.is/"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        var body = this.text.trim()
        if (body.length === 0 || body.indexOf("{") !== 0) return
        try {
          var obj = JSON.parse(body)
          if (obj && (obj.error || obj.success === false)) return
          var lat = Number(obj.latitude)
          var lon = Number(obj.longitude)
          if (!isFinite(lat) || !isFinite(lon)) return
          root._pendingCity = String(obj.city || "")
          root.city = root._pendingCity
          root.latitude = lat
          root.longitude = lon
          root.geolocatedMs = Date.now()
          root.geoKey = ""
          root.afterGeolocation()
          root.saveCache()
        } catch (e) {}
      }
    }
  }

  Process {
    id: geocodeProc
    command: ["true"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        var body = this.text.trim()
        if (body.length === 0 || body.indexOf("{") !== 0) return
        try {
          var obj = JSON.parse(body)
          var hit = obj && obj.results && obj.results.length ? obj.results[0] : null
          if (!hit) return
          var lat = Number(hit.latitude)
          var lon = Number(hit.longitude)
          if (!isFinite(lat) || !isFinite(lon)) return
          root._pendingCity = String(hit.name || root.wantedKey)
          root.city = root._pendingCity
          root.latitude = lat
          root.longitude = lon
          root.geolocatedMs = Date.now()
          root.geoKey = root.wantedKey
          root.afterGeolocation()
          root.saveCache()
        } catch (e) {}
      }
    }
  }

  Process {
    id: weatherProc
    command: ["true"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        var body = this.text.trim()
        if (body.length === 0 || body.indexOf("{") !== 0) return
        try {
          var obj = JSON.parse(body)
          var cur = obj && obj.current
          if (!cur) return
          var t = Number(cur.temperature_2m)
          var feels = Number(cur.apparent_temperature)
          var w = Number(cur.weather_code)
          if (!isFinite(t) || !isFinite(w)) return
          root.city = root._pendingCity
          root.tempC = t
          root.feelsLikeC = isFinite(feels) ? feels : t
          var daily = obj.daily || ({})
          root.highC = daily.temperature_2m_max && daily.temperature_2m_max.length ? Number(daily.temperature_2m_max[0]) : t
          root.lowC = daily.temperature_2m_min && daily.temperature_2m_min.length ? Number(daily.temperature_2m_min[0]) : t
          root.weatherCode = w
          root.lastFetchMs = Date.now()
          root.sunriseIso = daily.sunrise && daily.sunrise.length ? String(daily.sunrise[0]) : ""
          root.sunsetIso = daily.sunset && daily.sunset.length ? String(daily.sunset[0]) : ""
          root.isDay = cur.is_day !== undefined ? Number(cur.is_day) === 1 : root.isDay
          root.updateDaylight()
          root.pendingForecast = false
          root.saveCache()
        } catch (e) {}
      }
    }
  }

  Timer {
    id: weatherTimer
    interval: 1800000
    running: root.active
    repeat: true
    onTriggered: root.refresh()
  }

  // Daylight drifts with the clock, so it is re-checked every few minutes
  // while the panel is open. Nothing runs while it is closed.
  Timer {
    id: daylightTimer
    interval: 300000
    running: root.active
    repeat: true
    onTriggered: root.updateDaylight()
  }

  // A changed city applies on the spot; with the panel closed only the
  // coordinates are re-resolved, because the prayer alarms follow this location
  // too and must not keep a city the user has just replaced.
  Connections {
    target: Config
    function onWeatherCityChanged() {
      if (root.active) root.refresh()
      else if (root.needsGeolocation()) root.startGeolocation()
    }
  }

  FileView {
    id: cache
    path: Quickshell.statePath("island-weather.json")
    watchChanges: false
    onLoaded: {
      try { root.applyData(JSON.parse(text())) } catch (e) {}
      // Location first, panel or not: see the note at `wantedKey`.
      if (root.needsGeolocation()) root.startGeolocation()
      else if (root.active && Date.now() - root.lastFetchMs >= root.cacheMaxAgeMs)
        root.refresh()
    }
    onLoadFailed: error => {
      if (error === FileViewError.FileNotFound) {
        cache.setText("{}")
        root.startGeolocation()
      }
    }
  }

  onActiveChanged: {
    if (!root.active) return
    if (root.weatherCode < 0 || Date.now() - root.lastFetchMs >= root.cacheMaxAgeMs
      || root.needsGeolocation() || root.pendingForecast)
      root.refresh()
  }
}
