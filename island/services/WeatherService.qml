import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  visible: false

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
  readonly property double cacheMaxAgeMs: 1800000

  function refresh() {
    if (geoProc.running || weatherProc.running) return
    if (isFinite(root.latitude) && isFinite(root.longitude)) root.fetchWeather()
    else geoProc.running = true
  }

  function fetchWeather() {
    weatherProc.command = ["curl", "-sS", "--max-time", "8",
      "https://api.open-meteo.com/v1/forecast?latitude=" + root.latitude
      + "&longitude=" + root.longitude
      + "&current=temperature_2m,apparent_temperature,weather_code"
      + "&daily=temperature_2m_max,temperature_2m_min&forecast_days=1&timezone=auto"]
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
          root.latitude = lat
          root.longitude = lon
          root.fetchWeather()
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
          cache.setText(JSON.stringify({
            city: root.city,
            latitude: root.latitude,
            longitude: root.longitude,
            tempC: root.tempC,
            feelsLikeC: root.feelsLikeC,
            highC: root.highC,
            lowC: root.lowC,
            weatherCode: root.weatherCode,
            lastFetchMs: root.lastFetchMs
          }))
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

  FileView {
    id: cache
    path: Quickshell.statePath("island-weather.json")
    watchChanges: false
    onLoaded: {
      try { root.applyData(JSON.parse(text())) } catch (e) {}
      if (root.active && Date.now() - root.lastFetchMs >= root.cacheMaxAgeMs)
        root.refresh()
    }
    onLoadFailed: error => {
      if (error === FileViewError.FileNotFound) {
        cache.setText("{}")
        if (root.active) root.refresh()
      }
    }
  }

  onActiveChanged: {
    if (root.active && (root.weatherCode < 0 || Date.now() - root.lastFetchMs >= root.cacheMaxAgeMs))
      root.refresh()
  }
}
