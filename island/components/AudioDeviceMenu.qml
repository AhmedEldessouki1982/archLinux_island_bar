import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../config"

Popup {
  id: root

  property var audioService: null

  width: 280
  padding: 10
  closePolicy: Popup.CloseOnPressOutside

  background: Rectangle {
    radius: 10
    color: Theme.background
    border.width: 1
    border.color: Theme.selection
  }

  component DeviceRow: Item {
    id: row
    property string deviceName: ""
    property string label: ""
    property bool activeDevice: false

    signal picked(string name)

    width: parent ? parent.width : 0
    height: 26

    RowLayout {
      anchors.fill: parent
      spacing: 8

      Rectangle {
        width: 12
        height: 12
        radius: 6
        color: row.activeDevice ? Theme.accent : "transparent"
        border.width: 1
        border.color: row.activeDevice ? Theme.accent : Theme.selection
        Layout.alignment: Qt.AlignVCenter
      }

      Text {
        text: row.label
        color: row.activeDevice ? Theme.foreground : Theme.comment
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeLabel
        elide: Text.ElideRight
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
      }
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: row.picked(row.deviceName)
    }
  }

  contentItem: ColumnLayout {
    spacing: 4

    Text {
      text: "OUTPUT"
      color: Theme.comment
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSizeTitle
      font.bold: true
      font.letterSpacing: 1.6
    }

    Repeater {
      model: root.audioService ? root.audioService.sinks : []

      DeviceRow {
        deviceName: modelData.name
        label: modelData.desc
        activeDevice: root.audioService ? root.audioService.defaultSink === modelData.name : false
        onPicked: name => {
          if (root.audioService)
            root.audioService.setDefaultSink(name)
          root.close()
        }
      }
    }

    Rectangle {
      Layout.fillWidth: true
      height: 1
      color: Theme.selection
    }

    Text {
      text: "INPUT"
      color: Theme.comment
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSizeTitle
      font.bold: true
      font.letterSpacing: 1.6
    }

    Repeater {
      model: root.audioService ? root.audioService.sources : []

      DeviceRow {
        deviceName: modelData.name
        label: modelData.desc
        activeDevice: root.audioService ? root.audioService.defaultSource === modelData.name : false
        onPicked: name => {
          if (root.audioService)
            root.audioService.setDefaultSource(name)
          root.close()
        }
      }
    }

    Text {
      visible: root.audioService && root.audioService.sinks.length === 0 && root.audioService.sources.length === 0
      text: "no audio devices found"
      color: Theme.comment
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSizeLabel
    }
  }
}
