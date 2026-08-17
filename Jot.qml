import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui
import "InboxModel.js" as InboxModel

Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string pluginId: manifest?.id || "lun.jot"
  readonly property string pluginDir: manifest?.__sourceDir
    || (Quickshell.env("HOME") + "/.config/omarchy/plugins/lun.jot")

  property bool opened: false
  property string mode: "inbox" // "capture" or "inbox"
  property string text: ""
  property var inboxItems: []

  property string fontFamily: Style.font.menuFamily
  property string monoFamily: Style.font.monoFamily || "monospace"
  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color borderColor: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", borderColor, Math.max(1, Style.space(1)))
  property color scrim: Color.menu.scrim
  readonly property int cornerRadius: 6
  property int contentMargin: 12

  readonly property string inboxPath: Quickshell.env("HOME") + "/notes/inbox.md"

  // Dynamic dimensions based on content and mode
  readonly property int captureCardWidth: Math.min(480, panel.width - Style.gapsOut * 2)
  readonly property int captureCardHeight: Math.min(
    contentMargin * 2 + Math.max(34, contentText.contentHeight + 10),
    panel.height - Style.gapsOut * 2)

  readonly property int inboxCardWidth: Math.min(560, panel.width - Style.gapsOut * 2)
  readonly property int inboxCardHeight: Math.min(
    Math.max(180, inboxView.preferredHeight + contentMargin * 2),
    Math.min(480, panel.height - Style.gapsOut * 2)
  )

  property int currentCardWidth: mode === "inbox" ? inboxCardWidth : captureCardWidth
  property int currentCardHeight: mode === "inbox" ? inboxCardHeight : captureCardHeight

  function loadInbox(raw) {
    root.inboxItems = InboxModel.parseInbox(raw)
  }

  function saveInbox() {
    var serialized = InboxModel.serializeInbox(root.inboxItems)
    inboxFile.setText(serialized)
  }

  function open(payloadJson) {
    var payload = ({})
    try {
      if (payloadJson && typeof payloadJson === "string") {
        payload = JSON.parse(payloadJson)
      } else if (payloadJson && typeof payloadJson === "object") {
        payload = payloadJson
      }
    } catch (e) {
      payload = ({})
    }

    if (payload.mode === "inbox" || payload.mode === "capture") {
      root.mode = payload.mode
    }

    root.opened = true
    root.text = ""

    if (root.mode === "inbox") {
      inboxFile.reload()
      inboxView.resetState()
    } else {
      Qt.callLater(function() { captureKeyCatcher.forceActiveFocus() })
    }
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function") {
      root.shell.hide(root.pluginId)
    }
  }

  function toggle(payloadJson) {
    var payload = ({})
    try {
      if (payloadJson && typeof payloadJson === "string") payload = JSON.parse(payloadJson)
      else if (payloadJson && typeof payloadJson === "object") payload = payloadJson
    } catch (e) {
      payload = ({})
    }

    var targetMode = payload.mode || "inbox"

    if (root.opened) {
      if (root.mode === targetMode) {
        root.dismiss()
      } else {
        root.mode = targetMode
        root.open(payloadJson)
      }
    } else {
      root.open(payloadJson)
    }
  }

  function submitCapture() {
    var captured = root.text
    if (!captured.trim()) {
      root.dismiss()
      return
    }

    Quickshell.execDetached([root.pluginDir + "/bin/jot-append", captured])
    root.dismiss()
  }

  FileView {
    id: inboxFile
    path: root.inboxPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadInbox(text())
    onLoadFailed: root.loadInbox("")
    onFileChanged: reload()
  }

  Process {
    id: setupProcess
    command: [root.pluginDir + "/bin/jot-setup"]
  }
  Component.onCompleted: setupProcess.running = true

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "lun-jot"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: root.currentCardWidth
      height: root.currentCardHeight
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      Behavior on width {
        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
      }
      Behavior on height {
        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
      }

      MouseArea { anchors.fill: parent; onClicked: {} }

      // --- INBOX VIEW (mode === "inbox") ---
      InboxView {
        id: inboxView
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        visible: root.mode === "inbox"

        items: root.inboxItems
        foreground: root.foreground
        background: root.background
        fontFamily: root.fontFamily
        monoFamily: root.monoFamily

        onRequestSave: root.saveInbox()
        onRequestCapture: {
          root.mode = "capture"
          root.text = ""
          Qt.callLater(function() { captureKeyCatcher.forceActiveFocus() })
        }
        onRequestDismiss: root.dismiss()
      }

      // --- CAPTURE VIEW (mode === "capture") ---
      Item {
        id: captureContainer
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        visible: root.mode === "capture"

        Item {
          id: captureKeyCatcher
          anchors.fill: parent
          focus: root.mode === "capture"

          Keys.priority: Keys.BeforeItem
          Keys.onPressed: function(event) {
            if (root.mode !== "capture") return

            var isEnter = event.key === Qt.Key_Return || event.key === Qt.Key_Enter
            if (event.key === Qt.Key_Escape) {
              root.dismiss()
              event.accepted = true
            } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Down) {
              root.mode = "inbox"
              inboxFile.reload()
              inboxView.resetState()
              event.accepted = true
            } else if (isEnter && (event.modifiers & Qt.ShiftModifier)) {
              root.text = root.text + "\n"
              event.accepted = true
            } else if (isEnter) {
              root.submitCapture()
              event.accepted = true
            } else if (Util.editsFilter(event, root.text)) {
              root.text = Util.editedFilter(event, root.text)
              event.accepted = true
            } else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127) {
              root.text = root.text + event.text
              event.accepted = true
            }
          }
        }

        Item {
          anchors.fill: parent

          Text {
            id: contentText
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.text || "Jot something down (Tab for Inbox)..."
            textFormat: Text.PlainText
            color: root.foreground
            opacity: root.text ? 1 : 0.58
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            wrapMode: Text.Wrap
          }
        }
      }
    }
  }
}
