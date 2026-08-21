import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "../config"

PanelWindow {
  id: root
  visible: showBanners
  implicitWidth: 380
  color: "transparent"
  exclusionMode: ExclusionMode.Normal
  aboveWindows: true

  WlrLayershell.layer: WlrLayer.Overlay
  anchors.top: true
  margins.top: 46

  property bool showBanners: false
  property int notificationCount: 0
  property alias historyModel: historyModel
  property bool registrationFailed: false
  property var server: null

  ListModel {
    id: historyModel

    function add(n) {
      historyModel.insert(0, {
        appName: n.appName || "",
        appIcon: n.appIcon || "",
        summary: n.summary || "",
        body: n.body || "",
        urgency: n.urgency,
        persistent: true,
        deadline: 0
      })
      root.notificationCount = historyModel.count
      root.showBanners = true
    }
  }

  function clearHistory() {
    historyModel.clear()
    root.notificationCount = 0
    root.showBanners = false
  }

  Timer {
    id: expireTimer
    interval: 1000
    running: root.showBanners
    repeat: true
    onTriggered: {
      // All notifications are persistent by default; they are only removed via
      // the manual "✕" click or the clear-all action. Nothing auto-expires.
      root.notificationCount = historyModel.count
      if (historyModel.count === 0) root.showBanners = false
    }
  }

  Component {
    id: serverComponent
    NotificationServer {}
  }

  function spawnServer() {
    if (root.server) root.server.destroy()
    root.server = serverComponent.createObject(root)
  }

  Connections {
    target: root.server
    function onNotification(n) { root.historyModel.add(n) }
  }

  // --- registration diagnostics: verify we own org.freedesktop.Notifications ---
  Process {
    id: regCheckProc
    command: ["sh", "-c", "out=$(dbus-send --session --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.GetConnectionUnixProcessID string:org.freedesktop.Notifications 2>/dev/null | grep -o '[0-9]*' | tail -1); [ -n \"$out\" ] && echo \"$out\" || echo \"NO-OWNER\""]
    running: false
    stdout: SplitParser {
      onRead: data => {
        var v = String(data).trim()
        var owner = parseInt(v, 10)
        var ok = !isNaN(owner) && owner === Quickshell.processId
        root.registrationFailed = !ok
        console.log("[notif] org.freedesktop.Notifications owner pid=" + v + " self=" + Quickshell.processId + " => " + (ok ? "REGISTERED OK" : "NOT REGISTERED (conflict or absent)"))
        if (!ok && isNaN(owner)) {
          // The name is free but we don't hold it (we were never registered or
          // the claim was lost). Respawn the server to re-attempt registration.
          // This is a best-effort recovery — Quickshell 0.3.0's NotificationServer
          // exposes no public retry/re-claim API, so recreation is the only option.
          respawnCooldown.restart()
        }
      }
    }
  }

  Timer {
    id: respawnCooldown
    interval: 5000
    onTriggered: root.spawnServer()
  }

  Timer {
    id: regRecheckTimer
    interval: 30000
    running: true
    repeat: true
    onTriggered: regCheckProc.running = true
  }

  Component.onCompleted: {
    root.spawnServer()
    regCheckProc.running = true
  }

  ColumnLayout {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    width: parent.width
    spacing: 8

    Repeater {
      model: root.showBanners ? historyModel : null

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 58
        radius: 10
        color: Theme.background
        border.width: 1
        border.color: model.urgency >= 2 ? Theme.red : (model.urgency === 1 ? Theme.accent : Theme.selection)

        RowLayout {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: 10
          anchors.rightMargin: 6
          spacing: 10

          Rectangle {
            id: iconBox
            width: 32
            height: 32
            radius: 8
            color: Theme.selection
            Layout.alignment: Qt.AlignVCenter

            Image {
              anchors.fill: parent
              anchors.margins: 4
              source: model.appIcon !== "" ? "image://icon/" + model.appIcon : ""
              fillMode: Image.PreserveAspectFit
              visible: model.appIcon !== ""
            }
            Text {
              anchors.centerIn: parent
              text: "\uF0F3"
              color: Theme.foreground
              visible: model.appIcon === ""
              font.family: Theme.fontFamily
              font.pixelSize: 18
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Text {
              text: model.appName !== "" ? model.appName : "Notification"
              color: Theme.comment
              font.family: Theme.fontFamily
              font.pixelSize: 9
              font.bold: true
              font.letterSpacing: 0.5
            }
            Text {
              text: model.summary
              color: Theme.foreground
              font.family: Theme.fontFamily
              font.pixelSize: 12
              font.bold: true
              elide: Text.ElideRight
              Layout.fillWidth: true
            }
            Text {
              text: model.body
              color: Theme.comment
              font.family: Theme.fontFamily
              font.pixelSize: 11
              wrapMode: Text.WordWrap
              elide: Text.ElideRight
              maximumLineCount: 1
              visible: model.body !== ""
              Layout.fillWidth: true
            }
          }

          Rectangle {
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            radius: 10
            color: "transparent"
            Layout.alignment: Qt.AlignTop

            Text {
              anchors.centerIn: parent
              text: "✕"
              color: Theme.comment
              font.family: Theme.fontFamily
              font.pixelSize: 10
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                historyModel.remove(index, 1)
                root.notificationCount = historyModel.count
                if (historyModel.count === 0) root.showBanners = false
              }
            }
          }
        }
      }
    }
  }
}
