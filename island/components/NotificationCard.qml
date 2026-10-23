import QtQuick
import QtQuick.Layouts
import "."
import "../config"

Rectangle {
  id: card

  property string appName: ""
  property string appIcon: ""
  property string image: ""
  property string summary: ""
  property string body: ""
  property int urgency: 1
  property real timestamp: 0
  property var actions: []
  property bool hasInlineReply: false
  property string replyPlaceholder: "Reply…"
  property bool showTimestamp: false
  property real clock: Date.now()

  signal backgroundClicked()
  signal dismissRequested()
  signal actionTriggered(string identifier)
  signal replySent(string text)

  readonly property color accentColor: urgency >= 2 ? Theme.red : urgency === 1 ? Theme.accent : Theme.comment

  function relativeTime(ms) {
    var d = Math.max(0, clock - ms)
    if (d < 60000) return "now"
    if (d < 3600000) return Math.floor(d / 60000) + "m"
    if (d < 86400000) return Math.floor(d / 3600000) + "h"
    return Math.floor(d / 86400000) + "d"
  }

  radius: 10
  color: Theme.background
  border.width: 1
  border.color: urgency >= 2 ? Theme.red : urgency === 1 ? Theme.accent : Theme.selection
  implicitHeight: contentCol.implicitHeight + 20
  opacity: urgency === 0 ? 0.8 : 1

  MouseArea {
    anchors.fill: parent
    onClicked: card.backgroundClicked()
  }

  Rectangle {
    width: 3
    radius: 1.5
    color: card.accentColor
    anchors.left: parent.left
    anchors.leftMargin: 5
    anchors.top: parent.top
    anchors.topMargin: 12
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 12
  }

  ColumnLayout {
    id: contentCol

    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.leftMargin: 14
    anchors.rightMargin: 10
    anchors.topMargin: 10
    spacing: 6

    RowLayout {
      Layout.fillWidth: true
      spacing: 10

      Rectangle {
        id: iconBox
        width: 36
        height: 36
        radius: 8
        color: Theme.selection
        Layout.alignment: Qt.AlignVCenter

        property bool imageFailed: false
        Connections {
          target: card
          function onImageChanged() { iconBox.imageFailed = false }
        }
        readonly property bool hasImage: card.image !== "" && !imageFailed
        readonly property bool hasIcon: !hasImage && card.appIcon !== ""

        Image {
          anchors.fill: parent
          anchors.margins: 4
          source: iconBox.hasImage ? card.image : iconBox.hasIcon ? "image://icon/" + card.appIcon : ""
          fillMode: Image.PreserveAspectFit
          visible: iconBox.hasImage || iconBox.hasIcon
          onStatusChanged: {
            if (status === Image.Error && iconBox.hasImage)
              iconBox.imageFailed = true
          }
        }

        Txt {
          anchors.centerIn: parent
          width: parent.width
          height: parent.height
          text: "\uF0F3"
          color: card.accentColor
          visible: !iconBox.hasImage && !iconBox.hasIcon
          variant: "value"
          elide: Text.ElideNone
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: 2

        RowLayout {
          Layout.fillWidth: true
          spacing: 6

          Txt {
            text: card.appName !== "" ? card.appName : "Notification"
            color: Theme.comment
            variant: "caption"
            elide: Text.ElideNone
            clip: true
            Layout.maximumWidth: 180
          }

          Txt {
            text: card.showTimestamp ? card.relativeTime(card.timestamp) : ""
            visible: card.showTimestamp
            color: Theme.comment
            variant: "caption"
            Layout.maximumWidth: parent.width
            elide: Text.ElideNone
          }
        }

        Txt {
          text: card.summary
          color: Theme.foreground
          variant: "body"
          elide: Text.ElideNone
          clip: true
          textFormat: Text.PlainText
          Layout.fillWidth: true
          Layout.maximumWidth: parent.width
        }

        Txt {
          text: card.body
          color: Theme.comment
          variant: "caption"
          wrapMode: Text.WordWrap
          elide: Text.ElideNone
          clip: true
          maximumLineCount: 2
          textFormat: Text.PlainText
          visible: card.body !== ""
          Layout.fillWidth: true
          Layout.maximumWidth: parent.width
        }
      }

      Rectangle {
        Layout.preferredWidth: 20
        Layout.preferredHeight: 20
        radius: 10
        color: closeMa.containsMouse ? Theme.selection : "transparent"
        Layout.alignment: Qt.AlignTop

        Txt {
          anchors.centerIn: parent
          width: parent.width
          height: parent.height
          text: "✕"
          color: closeMa.containsMouse ? Theme.foreground : Theme.comment
          variant: "caption"
          elide: Text.ElideNone
        }

        MouseArea {
          id: closeMa
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: card.dismissRequested()
        }
      }
    }

    RowLayout {
      visible: card.actions.length > 0
      spacing: 6
      Layout.fillWidth: true

      Repeater {
        model: card.actions

        Rectangle {
          id: actionBtn
          required property var modelData

          readonly property bool hovered: actionMa.containsMouse

          Layout.preferredHeight: 24
          Layout.preferredWidth: actionLabel.implicitWidth + 20
          radius: 6
          color: hovered ? Theme.cardHoverFill : Theme.selection

          Txt {
            id: actionLabel
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            text: actionBtn.modelData.text !== "" ? actionBtn.modelData.text : "Action"
            color: actionBtn.hovered ? Theme.foreground : Theme.comment
            variant: "caption"
            elide: Text.ElideNone
          }

          MouseArea {
            id: actionMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: card.actionTriggered(actionBtn.modelData.identifier)
          }
        }
      }
    }

    RowLayout {
      visible: card.hasInlineReply
      spacing: 6
      Layout.fillWidth: true

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 26
        radius: 6
        color: Theme.selection
        border.width: 1
        border.color: replyInput.activeFocus ? Theme.accent : "transparent"

        TextInput {
          id: replyInput
          anchors.fill: parent
          anchors.leftMargin: 8
          anchors.rightMargin: 8
          anchors.topMargin: 6
          anchors.bottomMargin: 6
          verticalAlignment: TextInput.AlignVCenter
          clip: true
          color: Theme.foreground
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSizeCaption
          font.weight: Theme.fontWeightCaption
          font.letterSpacing: Theme.letterSpacingCaption
          font.capitalization: Font.AllUppercase
          echoMode: TextInput.Normal
          Txt {
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            visible: replyInput.text === "" && !replyInput.activeFocus
            text: card.replyPlaceholder !== "" ? card.replyPlaceholder : "Reply…"
            color: Theme.comment
            variant: "caption"
            elide: Text.ElideNone
          }
          Keys.onReturnPressed: card.sendReply()
          Keys.onEnterPressed: card.sendReply()
        }

        MouseArea {
          anchors.fill: parent
          onClicked: replyInput.forceActiveFocus()
        }
      }

      Rectangle {
        readonly property bool hovered: sendMa.containsMouse

        Layout.preferredWidth: 30
        Layout.preferredHeight: 26
        radius: 6
        color: hovered ? Theme.accent : Theme.selection

        Txt {
          anchors.centerIn: parent
          width: parent.width
          height: parent.height
          text: "\uF061"
          color: parent.hovered ? Theme.background : Theme.comment
          variant: "body"
          elide: Text.ElideNone
        }

        MouseArea {
          id: sendMa
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: card.sendReply()
        }
      }
    }
  }

  function sendReply() {
    if (replyInput.text.trim() === "")
      return
    card.replySent(replyInput.text)
    replyInput.text = ""
  }
}
