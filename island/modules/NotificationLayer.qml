import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "../components"
import "../config"

PanelWindow {
  id: root

  visible: root.bannerNotifs.length > 0
  implicitWidth: 380
  implicitHeight: bannerList.y + bannerList.height + (moreChip.visible ? moreChip.height + 8 : 0) + 12
  color: "transparent"
  exclusionMode: ExclusionMode.Normal
  aboveWindows: true

  WlrLayershell.layer: WlrLayer.Overlay
  anchors.top: true
  margins.top: 46

  property bool dnd: false
  property int maxVisibleBanners: 3
  property int normalTimeoutMs: 6000
  property int lowTimeoutMs: 4000

  readonly property var bannerNotifs: root.notifs.filter(n => n.showBanner)
  readonly property int hiddenBannerCount: Math.max(0, root.bannerNotifs.length - root.maxVisibleBanners)
  property int notificationCount: root.notifs.length
  property bool registrationFailed: false
  property bool debug: false
  property var server: null
  property var notifs: []
  property var liveNotifs: ({})
  property int historySerial: 0
  property bool tearingDown: false
  property bool storeReady: false

  signal moreClicked()

  Component.onDestruction: root.tearingDown = true

  function shouldShowBanner(urgency) {
    return !root.dnd || urgency >= 2
  }

  function newHistoryKey() {
    root.historySerial += 1
    return "notification-" + Date.now() + "-" + root.historySerial
  }

  function findEntryIndex(historyKey) {
    for (var i = 0; i < root.notifs.length; i++)
      if (root.notifs[i].historyKey === historyKey)
        return i
    return -1
  }

  function removeEntry(historyKey) {
    if (root.tearingDown)
      return
    var idx = root.findEntryIndex(historyKey)
    if (idx < 0)
      return
    var copy = root.notifs.slice()
    copy.splice(idx, 1)
    root.notifs = copy
    saveTimer.restart()
  }

  function liveRecord(entry) {
    if (!entry || typeof entry.liveId !== "number")
      return null
    var record = root.liveNotifs[entry.liveId]
    return record && record.historyKey === entry.historyKey ? record : null
  }

  function detachLive(record, operation) {
    if (!record)
      return
    if (root.liveNotifs[record.liveId] === record)
      delete root.liveNotifs[record.liveId]
    if (record.connection) {
      record.connection.enabled = false
      record.connection.destroy()
    }
    if (operation === "dismiss") record.notification.dismiss()
    else if (operation === "expire") record.notification.expire()
  }

  function dismissEntry(entry) {
    var record = root.liveRecord(entry)
    root.removeEntry(entry.historyKey)
    root.detachLive(record, "dismiss")
  }

  function invokeAction(entry, identifier) {
    var record = root.liveRecord(entry)
    if (!record)
      return
    var live = record.notification
    for (var i = 0; i < live.actions.length; i++) {
      if (live.actions[i].identifier === identifier) {
        live.actions[i].invoke()
        return
      }
    }
  }

  function invokeDefaultAction(entry) {
    root.invokeAction(entry, "default")
  }

  function sendReply(entry, text) {
    var record = root.liveRecord(entry)
    var live = record ? record.notification : null
    if (live && live.hasInlineReply)
      live.sendInlineReply(text)
  }

  function clearAll() {
    root.notifs = []
    var records = []
    for (var id in root.liveNotifs) records.push(root.liveNotifs[id])
    for (var i = 0; i < records.length; i++) root.detachLive(records[i], "dismiss")
    saveTimer.restart()
  }

  function toggleDnd() {
    root.dnd = !root.dnd
  }

  function handleNotification(n) {
    n.tracked = true

    var actions = []
    for (var i = 0; i < n.actions.length; i++) {
      var a = n.actions[i]
      if (a.identifier !== "default" && a.identifier !== "inline-reply")
        actions.push({
          identifier: a.identifier,
          text: a.text || ""
        })
    }

    var previousRecord = root.liveNotifs[n.id]
    var existingIdx = previousRecord ? root.findEntryIndex(previousRecord.historyKey) : -1
    var historyKey = existingIdx >= 0 ? root.notifs[existingIdx].historyKey : root.newHistoryKey()
    var requestedTimeout = typeof n.expireTimeout === "number" ? n.expireTimeout : -1
    var deadline = 0
    if (requestedTimeout > 0)
      deadline = Date.now() + requestedTimeout
    else if (requestedTimeout < 0 && n.urgency < 2)
      deadline = Date.now() + (n.urgency <= 0 ? root.lowTimeoutMs : root.normalTimeoutMs)
    var entry = {
      historyKey: historyKey,
      liveId: n.id,
      appName: n.appName || "",
      appIcon: n.appIcon || "",
      image: n.image || "",
      summary: n.summary || "",
      body: n.body || "",
      urgency: n.urgency,
      timestamp: existingIdx >= 0 ? root.notifs[existingIdx].timestamp : Date.now(),
      actions: actions,
      hasInlineReply: n.hasInlineReply,
      replyPlaceholder: n.inlineReplyPlaceholder || "",
      resident: n.resident,
      transient: n.transient,
      showBanner: root.shouldShowBanner(n.urgency),
      deadline: deadline,
      _expiring: false
    }

    if (previousRecord) root.detachLive(previousRecord, "")
    var connection = closedConn.createObject(root, {
      notif: n,
      liveId: n.id,
      historyKey: historyKey
    })
    root.liveNotifs[n.id] = {
      liveId: n.id,
      historyKey: historyKey,
      notification: n,
      connection: connection
    }

    var copy = root.notifs.slice()
    if (existingIdx >= 0)
      copy[existingIdx] = entry
    else
      copy.unshift(entry)
    var evicted = copy.slice(50)
    root.notifs = copy.slice(0, 50)
    for (var j = 0; j < evicted.length; j++)
      root.detachLive(root.liveRecord(evicted[j]), "expire")
    saveTimer.restart()
  }

  function handleClosed(liveId, historyKey, notification) {
    if (root.tearingDown)
      return
    var record = root.liveNotifs[liveId]
    if (!record || record.historyKey !== historyKey || record.notification !== notification)
      return
    var entryIdx = root.findEntryIndex(historyKey)
    root.detachLive(record, "")
    if (entryIdx >= 0 && !root.notifs[entryIdx]._expiring)
      root.removeEntry(historyKey)
    else
      saveTimer.restart()
  }

  function persistNotifs() {
    if (root.tearingDown || !root.storeReady)
      return
    var out = root.notifs.filter(e => !e.transient).map(e => ({
      historyKey: e.historyKey,
      appName: e.appName,
      appIcon: e.appIcon,
      summary: e.summary,
      body: e.body,
      urgency: e.urgency,
      timestamp: e.timestamp
    }))
    store.setText(JSON.stringify(out))
  }

  function loadHistory(text) {
    try {
      var data = JSON.parse(text)
      if (!Array.isArray(data))
        return
      var restored = data.slice(0, 50).map((e, index) => ({
        historyKey: e.historyKey || ("legacy-" + (e.timestamp || 0) + "-" + index + "-" + (e.id || 0)),
        appName: e.appName || "",
        appIcon: e.appIcon || "",
        image: "",
        summary: e.summary || "",
        body: e.body || "",
        urgency: typeof e.urgency === "number" ? e.urgency : 1,
        timestamp: e.timestamp || 0,
        actions: [],
        hasInlineReply: false,
        replyPlaceholder: "",
        resident: false,
        transient: false,
        showBanner: false,
        deadline: 0,
        _expiring: false
      }))
      restored.sort((a, b) => b.timestamp - a.timestamp)
      root.notifs = restored
    } catch (err) {
      if (root.debug) console.log("[notif] history restore failed:", err)
    }
  }

  Behavior on implicitHeight {
    NumberAnimation {
      duration: Theme.animDurationFast
      easing.type: Easing.OutQuad
    }
  }

  Timer {
    id: saveTimer
    interval: 1000
    onTriggered: root.persistNotifs()
  }

  Timer {
    id: expireTick
    interval: 1000
    running: root.bannerNotifs.length > 0
    repeat: true
    onTriggered: {
      var now = Date.now()
      var changed = false
      var copy = root.notifs.slice()
      for (var i = 0; i < copy.length; i++) {
        var e = copy[i]
        if (e.showBanner && e.deadline > 0 && now >= e.deadline) {
          e.showBanner = false
          changed = true
          var record = root.liveRecord(e)
          if (record) {
            e._expiring = true
            root.detachLive(record, "expire")
          }
        }
      }
      if (changed)
        root.notifs = copy
    }
  }

  Component {
    id: closedConn

    Connections {
      required property var notif
      required property int liveId
      required property string historyKey

      target: notif

      function onClosed(reason) {
        root.handleClosed(liveId, historyKey, notif)
      }
    }
  }

  Component {
    id: serverComponent

    NotificationServer {
      keepOnReload: false
      bodySupported: true
      bodyMarkupSupported: true
      bodyHyperlinksSupported: true
      bodyImagesSupported: true
      imageSupported: true
      actionsSupported: true
      actionIconsSupported: true
      inlineReplySupported: true
      persistenceSupported: true

      onNotification: n => root.handleNotification(n)
    }
  }

  function spawnServer() {
    if (root.server)
      root.server.destroy()
    root.server = serverComponent.createObject(root)
  }

  FileView {
    id: store
    path: Quickshell.statePath("island-notifications.json")
    watchChanges: false
    onLoaded: {
      root.loadHistory(text())
      root.storeReady = true
    }
    onLoadFailed: err => {
      if (err === FileViewError.FileNotFound) {
        root.storeReady = true
        Qt.callLater(root.persistNotifs)
      }
    }
  }

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
        if (root.debug) console.log("[notif] org.freedesktop.Notifications owner pid=" + v + " self=" + Quickshell.processId + " => " + (ok ? "REGISTERED OK" : "NOT REGISTERED (conflict or absent)"))
        if (!ok && isNaN(owner))
          respawnCooldown.restart()
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

  ListView {
    id: bannerList

    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: 12
    height: Math.min(contentHeight, 700)
    clip: true
    spacing: 8
    interactive: false

    model: ScriptModel {
      values: root.bannerNotifs.slice(0, root.maxVisibleBanners)
    }

    delegate: NotificationCard {
      id: bannerCard
      required property var modelData

      width: bannerList.width
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

      onBackgroundClicked: root.invokeDefaultAction(bannerCard.modelData)
      onDismissRequested: root.dismissEntry(bannerCard.modelData)
      onActionTriggered: identifier => root.invokeAction(bannerCard.modelData, identifier)
      onReplySent: text => root.sendReply(bannerCard.modelData, text)
    }

    add: Transition {
      ParallelAnimation {
        NumberAnimation {
          property: "opacity"
          from: 0
          to: 1
          duration: 200
        }
        NumberAnimation {
          property: "y"
          from: -24
          duration: 200
          easing.type: Easing.OutCubic
        }
      }
    }

    addDisplaced: Transition {
      NumberAnimation {
        property: "y"
        duration: 200
        easing.type: Easing.OutQuad
      }
    }

    remove: Transition {
      ParallelAnimation {
        NumberAnimation {
          property: "opacity"
          to: 0
          duration: 200
        }
        NumberAnimation {
          property: "height"
          to: 0
          duration: 200
          easing.type: Easing.InQuad
        }
      }
    }

    removeDisplaced: Transition {
      NumberAnimation {
        property: "y"
        duration: 200
        easing.type: Easing.OutQuad
      }
    }
  }

  Rectangle {
    id: moreChip

    readonly property bool hovered: moreMa.containsMouse

    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: bannerList.bottom
    anchors.topMargin: 8
    anchors.leftMargin: 60
    anchors.rightMargin: 60
    height: 26
    radius: 13
    visible: root.hiddenBannerCount > 0
    color: hovered ? Theme.accent : Theme.selection

    Text {
      anchors.centerIn: parent
      text: "+" + root.hiddenBannerCount + " more · open center"
      color: moreChip.hovered ? Theme.background : Theme.comment
      font.family: Theme.fontFamily
      font.pixelSize: 10
      font.bold: true
      font.letterSpacing: 0.5
    }

    MouseArea {
      id: moreMa
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.moreClicked()
    }
  }

  Component.onCompleted: {
    root.spawnServer()
    regCheckProc.running = true
  }
}

