import QtQuick
import QtQuick.Layouts
import Quickshell
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

  ListModel {
    id: historyModel

    function add(n) {
      historyModel.insert(0, {
        appName: n.appName || "",
        appIcon: n.appIcon || "",
        summary: n.summary || "",
        body: n.body || "",
        urgency: n.urgency,
        persistent: n.expireTimeout <= 0,
        deadline: n.expireTimeout > 0 ? Date.now() + n.expireTimeout : 0
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
      var now = Date.now()
      for (var i = historyModel.count - 1; i >= 0; i--) {
        var item = historyModel.get(i)
        if (item.persistent) continue
        if (now >= item.deadline) historyModel.remove(i, 1)
      }
      root.notificationCount = historyModel.count
      if (historyModel.count === 0) root.showBanners = false
    }
  }

  NotificationServer {
    id: server
  }

  Connections {
    target: server
    function onNotification(n) { root.historyModel.add(n) }
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
              text: "🔔"
              color: Theme.foreground
              visible: model.appIcon === ""
              font.family: Theme.fontFamily
              font.pixelSize: 14
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
