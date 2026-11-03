import QtQuick
import Quickshell.Io

// OpenCode Go limit windows (rolling 5h, weekly, monthly), read the way the
// Omarchy OpenCode Go plugin does it: the `opencode-go` API key from auth.json
// is sent as a bearer token to GET /zen/go/v1/usage.
//
// The endpoint is undocumented (it is used by the Omarchy OpenCode Go plugin,
// github.com/ardfard/omarchy-opencode-usage).
//
// Nothing polls. refresh() runs once when the usage card opens. A missing key,
// a rejected key or an unreachable server leaves every value as "--" - never a
// fake 0%. If jq or curl is missing the card shows a hint instead.
Item {
  id: root
  visible: false

  readonly property var windowNames: ["rolling", "weekly", "monthly"]

  property bool ready: false
  // { rolling: { percent, resetsAtMs }, weekly: {...}, monthly: {...} }
  property var windows: ({})
  property string missingTool: ""

  function refresh() {
    root.missingTool = ""
    if (!depsProc.running) depsProc.running = true
  }

  function parse(text) {
    var out = {}
    var usage = null
    try {
      usage = JSON.parse(String(text)).usage
    } catch (e) {
      return out
    }
    if (!usage) return out
    for (var i = 0; i < root.windowNames.length; i++) {
      var name = root.windowNames[i]
      var w = usage[name]
      if (!w || typeof w.percent !== "number") continue
      out[name] = {
        percent: w.percent,
        resetsAtMs: Date.parse(w.resetsAt)
      }
    }
    return out
  }

  Process {
    id: depsProc
    command: ["sh", "-c", "command -v jq >/dev/null 2>&1 || exit 10; command -v curl >/dev/null 2>&1 || exit 11"]
    running: false
    onExited: code => {
      if (code === 10) {
        root.missingTool = "jq"
        root.ready = false
        root.windows = ({})
        return
      }
      if (code === 11) {
        root.missingTool = "curl"
        root.ready = false
        root.windows = ({})
        return
      }
      if (!usageProc.running) usageProc.running = true
    }
  }

  Process {
    id: usageProc
    command: ["sh", "-c",
      "key=$(jq -r '.\"opencode-go\".key // empty' \"$HOME/.local/share/opencode/auth.json\" 2>/dev/null) || exit 2; "
      + "[ -n \"$key\" ] || exit 2; "
      + "printf 'Authorization: Bearer %s\\n' \"$key\" | curl -sf -m 10 -H @- https://opencode.ai/zen/go/v1/usage"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        var parsed = root.parse(this.text)
        root.windows = parsed
        root.ready = Object.keys(parsed).length > 0
      }
    }
    onExited: code => {
      if (code !== 0) {
        root.ready = false
        root.windows = ({})
      }
    }
  }
}
