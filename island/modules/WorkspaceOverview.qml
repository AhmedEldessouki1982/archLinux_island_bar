import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "../config"

PanelWindow {
  id: root
  visible: false
  color: "transparent"
  exclusionMode: ExclusionMode.Normal
  aboveWindows: true

  WlrLayershell.layer: WlrLayer.Overlay
  anchors.top: true
  anchors.bottom: true
  anchors.left: true
  anchors.right: true
  margins.top: 2
  margins.bottom: 2
  margins.left: 2
  margins.right: 2

  property string bgSource: ""
  property int cardCount: 3

  ListModel {
    id: wsModel

    function refresh() {
      wsModel.clear()
      var arr = []
      var values = Hyprland.workspaces.values
      for (var i = 0; i < values.length; i++) {
        if (values[i] && values[i].id !== undefined && values[i].id >= 0)
          arr.push(values[i])
      }
      arr.sort(function(a, b) { return a.id - b.id })
      for (var j = 0; j < arr.length; j++)
        wsModel.append({ ws: arr[j] })
    }
  }

  Connections {
    target: Hyprland.workspaces
    function onValuesChanged() {
      if (root.visible) wsModel.refresh()
    }
  }

  Image {
    anchors.fill: parent
    source: root.bgSource
    fillMode: Image.Stretch
    opacity: 0.35
    smooth: true
  }

  Rectangle {
    anchors.fill: parent
    color: "#11121a"
    opacity: 0.75
  }

  MouseArea {
    anchors.fill: parent
    onClicked: root.close()
  }

  Rectangle {
    id: content
    width: 820
    height: 470
    anchors.centerIn: parent
    radius: 14
    color: Theme.background
    border.width: 1
    border.color: Theme.selection

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 18
      spacing: 14

      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
          text: "Workspaces"
          color: Theme.foreground
          font.pixelSize: 15
          font.bold: true
          font.letterSpacing: 0.5
        }

        Item { Layout.fillWidth: true }

        Text {
          text: "✕"
          color: Theme.comment
          font.pixelSize: 13
          font.bold: true

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.close()
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Theme.selection
      }

      Flow {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 12

        Repeater {
          model: wsModel

          Rectangle {
            id: card
            required property var ws
            width: (content.width - 36 - 12 * (root.cardCount - 1)) / root.cardCount
            height: 180
            radius: 10
            color: ws.focused ? "#3b3f55" : Theme.selection
            border.width: ws.focused ? 2 : 1
            border.color: ws.focused ? Theme.accent : Theme.comment

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                ws.activate()
                root.close()
              }
            }

            ColumnLayout {
              anchors.fill: parent
              anchors.margins: 10
              spacing: 4

              RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                  text: ws.id
                  color: ws.focused ? Theme.accent : Theme.foreground
                  font.pixelSize: 14
                  font.bold: true
                }

                Text {
                  text: ws.name !== "" ? ws.name : ("Workspace " + ws.id)
                  color: Theme.comment
                  font.pixelSize: 10
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }

                Text {
                  text: ws.monitor ? ws.monitor.name : ""
                  color: Theme.cyan
                  font.pixelSize: 9
                  visible: ws.monitor !== null
                }
              }

              Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.comment
                opacity: 0.5
              }

              Repeater {
                model: ws.toplevels ? ws.toplevels.values : []

                RowLayout {
                  required property var modelData
                  Layout.fillWidth: true
                  spacing: 6

                  Rectangle {
                    width: 6
                    height: 6
                    radius: 3
                    color: modelData.activated ? Theme.green : Theme.comment
                    Layout.alignment: Qt.AlignVCenter
                  }

                  Text {
                    text: {
                      var c = ""
                      if (modelData.lastIpcObject)
                        c = modelData.lastIpcObject["class"] || ""
                      if (c === "") c = "?"
                      return c
                    }
                    color: Theme.pink
                    font.pixelSize: 9
                    font.bold: true
                    Layout.alignment: Qt.AlignVCenter
                  }

                  Text {
                    text: modelData.title || ""
                    color: Theme.foreground
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  Process {
    id: shotProc
    running: false
    command: ["true"]
    stdout: SplitParser {}
  }

  Connections {
    target: shotProc
    function onRunningChanged() {
      if (!shotProc.running) {
        root.bgSource = "file:///tmp/quickshell-overview.png"
        root.visible = true
      }
    }
  }

  function open() {
    wsModel.refresh()
    var mon = Hyprland.focusedMonitor
    var monName = mon && mon.name ? mon.name : ""
    if (monName !== "") {
      shotProc.command = ["sh", "-c", "grim -o \"" + monName + "\" -t png /tmp/quickshell-overview.png 2>/dev/null"]
      shotProc.running = true
    } else {
      root.bgSource = ""
      root.visible = true
    }
  }

  function close() {
    root.visible = false
  }

  function toggle() {
    if (root.visible) root.close()
    else root.open()
  }
}
