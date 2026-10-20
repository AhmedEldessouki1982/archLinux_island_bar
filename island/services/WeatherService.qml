import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  visible: false

  property string city: ""
  property real tempC: 0
  property int weatherCode: -1
  property string _pendingCity: ""

  function refresh() {
    if (!geoProc.running) geoProc.running = true
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
          weatherProc.command = ["curl", "-sS", "--max-time", "8",
            "https://api.open-meteo.com/v1/forecast?latitude=" + lat
            + "&longitude=" + lon + "&current=temperature_2m,weather_code"]
          if (!weatherProc.running) weatherProc.running = true
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
          var w = Number(cur.weather_code)
          if (!isFinite(t) || !isFinite(w)) return
          root.city = root._pendingCity
          root.tempC = t
          root.weatherCode = w
        } catch (e) {}
      }
    }
  }

  Timer {
    id: weatherTimer
    interval: 1800000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Component.onCompleted: root.refresh()
}
