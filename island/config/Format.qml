pragma Singleton
import QtQuick

// Shared number formatting for the health panel.
//
// Every figure the panel prints goes through this singleton, so the same
// quantity is written the same way everywhere: bytes as "158G" / "1.8T",
// rates as "3.2K/s", temperatures as "53°", uptime as "0h 25m".
//
// Formatting rules:
//   * sizes keep one decimal below 10 units and none above ("2.7G", "158G")
//   * a value is never padded with a trailing ".0"
//   * unknown values print as "--" instead of "0"
QtObject {
  id: root

  // "158G", "467G", "1.8T", "2.7G"
  function size(bytes) {
    var b = Number(bytes)
    if (!isFinite(b) || b < 0) return "--"
    if (b === 0) return "0G"
    var gb = b / 1073741824
    if (gb < 1000) {
      if (gb >= 100) return Math.round(gb) + "G"
      if (gb >= 10) return Math.round(gb) + "G"
      return root.stripZero(gb.toFixed(1)) + "G"
    }
    var tb = gb / 1024
    if (tb >= 10) return Math.round(tb) + "T"
    return root.stripZero(tb.toFixed(1)) + "T"
  }

  // "2.7G / 31G"
  function usedTotal(used, total) {
    if (!(Number(total) > 0)) return "--"
    return root.size(used) + " / " + root.size(total)
  }

  // "577B/s", "3.2K/s", "1.4M/s"
  function rate(bytesPerSecond) {
    var v = Number(bytesPerSecond)
    if (!isFinite(v) || v < 0) return "0B/s"
    if (v < 1000) return Math.round(v) + "B/s"
    if (v < 1000000) return root.stripZero((v / 1000).toFixed(1)) + "K/s"
    if (v < 1000000000) return root.stripZero((v / 1000000).toFixed(1)) + "M/s"
    return root.stripZero((v / 1000000000).toFixed(1)) + "G/s"
  }

  // "53°"
  function temp(celsius) {
    var v = Number(celsius)
    if (!isFinite(v)) return "--"
    return Math.round(v) + "\u00b0"
  }

  // "11%"
  function percent(value) {
    var v = Number(value)
    if (!isFinite(v)) return "--"
    return Math.round(v) + "%"
  }

  function percent1(value) {
    var v = Number(value)
    if (!isFinite(v)) return "--"
    return root.stripZero(v.toFixed(1)) + "%"
  }

  // "135ms"
  function latency(milliseconds) {
    var v = Number(milliseconds)
    if (!isFinite(v) || v < 0) return "--"
    return Math.round(v) + "ms"
  }

  // "0h 25m" (and "2d 3h" once the machine has been up for more than a day)
  function uptime(seconds) {
    var total = Math.floor((Number(seconds) || 0) / 60)
    var days = Math.floor(total / 1440)
    var hours = Math.floor((total % 1440) / 60)
    var minutes = total % 60
    if (days > 0) return days + "d " + hours + "h"
    return hours + "h " + minutes + "m"
  }

  // "28.1 W"
  function watts(value) {
    var v = Number(value)
    if (!isFinite(v)) return "--"
    return v.toFixed(1) + " W"
  }

  function stripZero(text) {
    return text.indexOf(".0") === text.length - 2 ? text.slice(0, text.length - 2) : text
  }
}
