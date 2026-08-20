import QtQuick
import QtQuick.Layouts
import "../config"

Item {
  id: root
  width: 56
  height: Theme.iconSize

  property int percent: 100
  property bool charging: false

  RowLayout {
    anchors.fill: parent
    spacing: 4

    // Battery Canvas - draws the battery shape
    Canvas {
      id: batteryCanvas
      anchors.fill: parent
      onPaint: drawBattery
    }

    // Percentage text on the right side
    Text {
      Layout.right: root.right
      Layout.rightMargin: 4
      Layout.verticalCenter: root.verticalCenter
      text: Math.round(root.percent) + "%"
      color: root.charging ? Theme.green : root.batteryColor()
      font.family: Theme.fontFamily
      font.pixelSize: 15
      font.bold: true
      Layout.horizontalAlignment: Text.AlignHCenter
      Layout.verticalAlignment: Text.AlignVCenter
    }
  }

  function batteryColor() {
    var pct = root.percent
    if (root.charging) return Theme.green
    if (pct <= 10) return Theme.red
    if (pct <= 20) return Theme.orange
    return Theme.foreground
  }

  function drawBattery(ctx) {
    var w = root.width
    var h = root.height
    var pct = root.percent

    ctx.clearRect(0, 0, w, h)

    ctx.save()

    // Draw battery body background
    ctx.fillStyle = Theme.background
    ctx.fillRect(0, 0, w, h)

    // Draw battery outline
    ctx.strokeStyle = Theme.foreground
    ctx.lineWidth = 1
    ctx.strokeRect(1, 1, root.width - 2, root.height - 2)

    // Draw terminal on right
    ctx.fillStyle = Theme.foreground
    ctx.fillRect(
      root.width - 8,
      4,
      4,
      root.height - 8
    )

    // Draw battery fill based on percentage
    var fillWidth = Math.max(1, Math.floor((root.width - 8) * root.percent / 100))
    ctx.fillStyle = root.charging ? Theme.green : root.batteryColor()

    if (root.percent >= 100) {
      ctx.fillRect(2, 2, root.width - 6, root.height - 4)
    } else if (root.percent > 0) {
      ctx.fillRect(2, 2, Math.max(1, fillWidth), root.height - 4)
    }

    ctx.restore()
  }