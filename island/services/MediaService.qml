import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Item {
  id: root
  visible: false

  readonly property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null

  readonly property bool hasPlayer: root.player != null
  readonly property string title: root.hasPlayer ? (root.player.trackTitle || "") : ""
  readonly property string artist: root.hasPlayer ? (root.player.trackArtist || "") : ""
  readonly property string album: root.hasPlayer ? (root.player.trackAlbum || "") : ""
  readonly property string artUrl: root.hasPlayer ? (root.player.trackArtUrl || "") : ""
  readonly property bool isPlaying: root.hasPlayer && root.player.isPlaying
  readonly property real position: root.hasPlayer ? (root.player.position || 0) : 0
  readonly property real length: root.hasPlayer ? (root.player.length || 0) : 0

  readonly property bool canPrevious: root.hasPlayer && root.player.canGoPrevious
  readonly property bool canNext: root.hasPlayer && root.player.canGoNext
  readonly property bool canToggle: root.hasPlayer && root.player.canTogglePlaying

  function togglePlay() {
    if (!root.canToggle) return
    if (root.player.togglePlaying) root.player.togglePlaying()
    else root.player.isPlaying = !root.player.isPlaying
  }

  function nextTrack() {
    if (root.canNext) root.player.next()
  }

  function prevTrack() {
    if (root.canPrevious) root.player.previous()
  }

  function formatTime(seconds) {
    if (!seconds || seconds <= 0 || !isFinite(seconds)) return "0:00"
    var total = Math.floor(seconds)
    var mins = Math.floor(total / 60)
    var secs = total % 60
    return mins + ":" + (secs < 10 ? "0" : "") + secs
  }
}
