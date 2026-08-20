pragma Singleton
import QtQuick

QtObject {
  property color background: "#282a36"
  property color foreground: "#f8f8f2"
  property color accent: "#bd93f9"
  property color selection: "#44475a"
  property color comment: "#6272a4"
  property color cyan: "#8be9fd"
  property color green: "#50fa7b"
  property color orange: "#ffb86c"
  property color pink: "#ff79c6"
  property color red: "#ff5555"
  property color yellow: "#f1fa8c"

  property string fontFamily: "JetBrainsMono Nerd Font"
  property int fontSizeLabel: 12
  property int fontSizeTitle: 15
  property int fontSizeValue: 14
  property int fontSizeHero: 20

  property real iconLineWidth: 1.5
  property int iconSize: 16
  property int iconFontSize: 17

  property int animDurationFast: 150
  property int animDurationNormal: 250
  property int animDurationSlow: 350

  property color borderA: Qt.rgba(0.2, 0.8, 1.0, 0.35)
  property color borderB: Qt.rgba(0, 1.0, 0.6, 0.35)
}
