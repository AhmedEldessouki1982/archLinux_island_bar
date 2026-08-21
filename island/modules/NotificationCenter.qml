import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../components"
import "../config"

PanelWindow {
  id: root

  visible: false
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  aboveWindows: true

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
  anchors.top: true
  anchors.left: true
  anchors.right: true
  anchors.bottom: true

  property var layer: null
  property real nowEpoch: Date.now()

  function toggle() {
    root.visible = !root.visible
    if (root.visible) {
      root.nowEpoch = Date.now()
      idleTimer.restart()
    }
  }

  function open() {
    if (!root.visible)
      root.toggle()
  }

  function close() {
    root.visible = false
  }

  Shortcut {
    sequence: "Esc"
    enabled: root.visible
    onActivated: root.close()
  }

  Timer {
    id: idleTimer
    interval: 15000
    running: root.visible
    onTriggered: root.close()
  }

  Timer {
    interval: 30000
    running: root.visible
    repeat: true
    onTriggered: root.nowEpoch = Date.now()
  }

  MouseArea {
    anchors.fill: parent
    onClicked: root.close()
  }

  Rectangle {
    id: panel

    width: 380
    height: 320
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.rightMargin: 8
    anchors.topMargin: 44
    radius: 12
    color: Theme.background
    border.width: 1
    border.color: Theme.selection
    clip: true

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onPositionChanged: idleTimer.restart()
      onClicked: idleTimer.restart()
    }

    ColumnLayout {
      anchors.fill: parent
      spacing: 0

      RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 34
        Layout.leftMargin: 12
        Layout.rightMargin: 8
        spacing: 10

        Text {
          text: "Notifications"
          color: Theme.foreground
          font.family: Theme.fontFamily
          font.pixelSize: 12
          font.bold: true
          font.letterSpacing: 0.5
        }

        Rectangle {
          visible: root.layer ? root.layer.notificationCount > 0 : false
          Layout.preferredWidth: countLabel.implicitWidth + 12
          Layout.preferredHeight: 16
          radius: 8
          color: Theme.selection

          Text {
            id: countLabel
            anchors.centerIn: parent
            text: root.layer ? root.layer.notificationCount : 0
            color: Theme.comment
            font.family: Theme.fontFamily
            font.pixelSize: 9
            font.bold: true
          }
        }

        Item {
          Layout.fillWidth: true
        }

        Rectangle {
          id: dndBtn

          readonly property bool active: root.layer ? root.layer.dnd : false
          readonly property bool hovered: dndMa.containsMouse

          Layout.preferredWidth: dndRow.implicitWidth + 16
          Layout.preferredHeight: 22
          radius: 11
          color: active ? Theme.accent : hovered ? Theme.selection : "transparent"
          border.width: 1
          border.color: active ? Theme.accent : Theme.selection

          RowLayout {
            id: dndRow
            anchors.centerIn: parent
            spacing: 5

            Text {
              text: "\uF186"
              color: dndBtn.active ? Theme.background : dndBtn.hovered ? Theme.foreground : Theme.comment
              font.family: Theme.fontFamily
              font.pixelSize: 11
            }

            Text {
              text: "DND"
              color: dndBtn.active ? Theme.background : dndBtn.hovered ? Theme.foreground : Theme.comment
              font.family: Theme.fontFamily
              font.pixelSize: 9
              font.bold: true
              font.letterSpacing: 0.5
            }
          }

          MouseArea {
            id: dndMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (root.layer)
                root.layer.toggleDnd()
            }
          }
        }

        Text {
          text: "Clear all"
          color: clearMa.containsMouse ? Theme.red : Theme.comment
          font.family: Theme.fontFamily
          font.pixelSize: 10
          font.bold: true

          MouseArea {
            id: clearMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (root.layer)
                root.layer.clearAll()
            }
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Theme.selection
      }

      ListView {
        id: historyList

        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 6
        model: root.layer ? root.layer.notifs : []

        delegate: NotificationCard {
          id: centerCard
          required property var modelData

          width: historyList.width - 12
          x: 6
          showTimestamp: true
          clock: root.nowEpoch
          appName: modelData.appName
          appIcon: modelData.appIcon
          image: modelData.image
          summary: modelData.summary
          body: modelData.body
          urgency: modelData.urgency
          timestamp: modelData.timestamp
          actions: modelData.actions
          hasInlineReply: modelData.hasInlineReply
          replyPlaceholder: modelData.replyPlaceholder

          onBackgroundClicked: root.layer ? root.layer.dismissEntry(centerCard.modelData) : {}
          onDismissRequested: root.layer ? root.layer.dismissEntry(centerCard.modelData) : {}
          onActionTriggered: identifier => {
            if (root.layer)
              root.layer.invokeAction(centerCard.modelData, identifier)
          }
          onReplySent: text => {
            if (root.layer)
              root.layer.sendReply(centerCard.modelData, text)
          }
        }

      }
    }

    Rectangle {
      id: scrollbarTrack

      readonly property double ratio: historyList.visibleArea.heightRatio > 0 ? historyList.visibleArea.heightRatio : 1
      readonly property double trackHeight: height - 8

      anchors.right: parent.right
      anchors.rightMargin: 3
      anchors.top: parent.top
      anchors.topMargin: 40
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 6
      width: 3
      radius: 1.5
      color: Theme.selection
      visible: historyList.contentHeight > historyList.height + 1

      Rectangle {
        width: parent.width
        height: Math.max(30, parent.trackHeight * parent.ratio)
        y: 4 + parent.trackHeight * historyList.visibleArea.yPosition
        radius: parent.radius
        color: Theme.foreground
        opacity: historyList.moving ? 0.7 : 0.35
      }
    }

    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.topMargin: 35
      color: Theme.background
      visible: root.layer ? root.layer.notificationCount === 0 : true

      Text {
        anchors.centerIn: parent
        text: "No notifications"
        color: Theme.comment
        font.family: Theme.fontFamily
        font.pixelSize: 11
      }

      MouseArea {
        anchors.fill: parent
        onClicked: idleTimer.restart()
      }
    }
  }
}
