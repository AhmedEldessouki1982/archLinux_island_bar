import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  visible: false

  property string city: ""
  property real tempC: 0
  property int weatherCode: 0

  function refresh() {
    geoProc.running = true
  }

  Process {
    id: geoProc
    command: ["sh", "-c", "echo \"$(curl -s --max-time 8 https://ipwho.is/ | tr -d '\\n')\""]
    running: false
    stdout: SplitParser {
      onRead: data => {
        var body = String(data).trim()
        if (body.length === 0 || body.indexOf("{") !== 0) return
        try {
          var obj = JSON.parse(body)
          if (obj && (obj.error || obj.success === false)) return
          var lat = Number(obj.latitude)
          var lon = Number(obj.longitude)
          if (!isFinite(lat) || !isFinite(lon)) return
          root.city = String(obj.city || "")
          weatherProc.command = ["sh", "-c",
            "echo \"$(curl -s --max-time 8 'https://api.open-meteo.com/v1/forecast?latitude="
            + lat + "&longitude=" + lon + "&current=temperature_2m,weather_code' | tr -d '\\n')\""]
          weatherProc.running = true
        } catch (e) {}
      }
    }
  }

  Process {
    id: weatherProc
    command: ["sh", "-c", ""]
    running: false
    stdout: SplitParser {
      onRead: data => {
        var body = String(data).trim()
        if (body.length === 0 || body.indexOf("{") !== 0) return
        try {
          var obj = JSON.parse(body)
          var cur = obj && obj.current
          if (!cur) return
          var t = Number(cur.temperature_2m)
          var w = Number(cur.weather_code)
          if (isFinite(t)) root.tempC = t
          if (isFinite(w)) root.weatherCode = w
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
