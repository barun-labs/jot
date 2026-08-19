import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "InboxModel.js" as InboxModel

Item {
  id: root

  property var items: []
  property int selectedIndex: 0
  property bool isEditing: false
  property string filterQuery: ""
  property bool newestFirst: true

  property color foreground: Color.menu.text
  property color background: Color.menu.background
  property color selectedBg: Color.menu.selectedBackground
  property color mutedText: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.6)
  property color dividerColor: Util.alpha(root.foreground, 0.1)
  property color accentColor: Color.accent
  property string fontFamily: Style.font.menuFamily
  property string monoFamily: Style.font.monoFamily || "monospace"

  readonly property int headerHeight: 40
  readonly property int filterHeight: 36
  readonly property int footerHeight: 32
  readonly property int baseRowHeight: 40
  readonly property int maxListHeight: 320

  readonly property int calculatedListHeight: {
    if (visibleIndices.length === 0) return 80
    var h = 0
    for (var i = 0; i < visibleIndices.length; i++) {
      var item = items[visibleIndices[i]]
      if (item && item.extra) h += 54
      else h += baseRowHeight
      if (h >= maxListHeight) return maxListHeight
    }
    return Math.max(baseRowHeight, h)
  }

  readonly property int preferredHeight: headerHeight + filterHeight + calculatedListHeight + footerHeight

  // Carries the mutated list up: assigning root.items here would break the
  // `items: root.inboxItems` binding and the change would never reach the file.
  signal requestSave(var newItems)
  signal requestCapture()
  signal requestDismiss()

  function resetState() {
    isEditing = false
    filterQuery = ""
    if (searchInput) searchInput.text = ""
    selectedIndex = Math.min(selectedIndex, Math.max(0, visibleIndices.length - 1))
    Qt.callLater(function() { listKeyCatcher.forceActiveFocus() })
  }

  function toggleDone(index) {
    if (index < 0 || index >= items.length) return
    root.requestSave(InboxModel.toggleItemAt(root.items, index))
  }

  function deleteItem(index) {
    if (index < 0 || index >= items.length) return
    root.requestSave(InboxModel.deleteItemAt(root.items, index))
    if (root.selectedIndex >= root.visibleIndices.length) {
      root.selectedIndex = Math.max(0, root.visibleIndices.length - 1)
    }
  }

  function commitEdit(index, newText) {
    if (index >= 0 && index < root.items.length) {
      root.requestSave(InboxModel.updateItemTextAt(root.items, index, newText))
    }
    root.isEditing = false
    Qt.callLater(function() { listKeyCatcher.forceActiveFocus() })
  }

  function cancelEdit() {
    root.isEditing = false
    Qt.callLater(function() { listKeyCatcher.forceActiveFocus() })
  }

  readonly property var visibleIndices: {
    var list = []
    var query = root.filterQuery.toLowerCase().trim()
    for (var i = 0; i < root.items.length; i++) {
      if (!query) {
        list.push(i)
      } else {
        var text = (root.items[i].text + " " + root.items[i].timestamp + " " + (root.items[i].extra || "")).toLowerCase()
        if (text.indexOf(query) !== -1) list.push(i)
      }
    }
    // Newest entries live at the bottom of inbox.md; reverse so they list first.
    if (root.newestFirst) list.reverse()
    return list
  }

  readonly property int pendingCount: InboxModel.countPending(root.items)
  readonly property int completedCount: InboxModel.countCompleted(root.items)

  Column {
    anchors.fill: parent
    spacing: 0

    // --- HEADER ---
    Item {
      width: parent.width
      height: root.headerHeight

      Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        Text {
          text: "INBOX"
          font.family: root.fontFamily
          font.pixelSize: 13
          font.weight: Font.DemiBold
          font.letterSpacing: 1.0
          color: root.foreground
          anchors.verticalCenter: parent.verticalCenter
        }

        // Pending count chip
        Rectangle {
          radius: 4
          color: root.pendingCount > 0 ? Util.alpha(root.accentColor, 0.15) : Util.alpha(root.foreground, 0.08)
          border.width: 1
          border.color: root.pendingCount > 0 ? Util.alpha(root.accentColor, 0.3) : "transparent"
          height: 20
          width: pendingText.implicitWidth + 12
          anchors.verticalCenter: parent.verticalCenter

          Text {
            id: pendingText
            anchors.centerIn: parent
            text: root.pendingCount + " PENDING"
            font.family: root.monoFamily
            font.pixelSize: 10
            font.weight: Font.Medium
            color: root.pendingCount > 0 ? root.accentColor : root.mutedText
          }
        }
      }

      // Mode switch tab hint
      Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 22
        radius: 4
        color: tabHover.hovered ? Util.alpha(root.foreground, 0.1) : "transparent"
        border.width: 1
        border.color: tabHover.hovered ? root.dividerColor : "transparent"
        width: tabHintText.implicitWidth + 12

        Text {
          id: tabHintText
          anchors.centerIn: parent
          text: "[TAB] CAPTURE"
          font.family: root.monoFamily
          font.pixelSize: 10
          font.weight: Font.Medium
          color: tabHover.hovered ? root.foreground : root.mutedText
        }

        MouseArea {
          id: tabHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.requestCapture()
        }
      }

      Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: root.dividerColor
      }
    }

    // --- SEARCH / FILTER BAR ---
    Item {
      width: parent.width
      height: root.filterHeight

      Row {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        spacing: 10

        Text {
          text: "/"
          font.family: root.monoFamily
          font.pixelSize: 12
          font.weight: Font.Bold
          color: root.filterQuery ? root.accentColor : root.mutedText
          anchors.verticalCenter: parent.verticalCenter
        }

        TextInput {
          id: searchInput
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - 24
          font.family: root.fontFamily
          font.pixelSize: 13
          color: root.foreground
          clip: true
          text: root.filterQuery
          onTextChanged: {
            root.filterQuery = text
            if (root.visibleIndices.length > 0) {
              root.selectedIndex = 0
            }
          }

          Text {
            anchors.fill: parent
            text: "Filter notes..."
            font.family: root.fontFamily
            font.pixelSize: 13
            color: root.mutedText
            opacity: 0.6
            visible: !searchInput.text && !searchInput.activeFocus
          }

          Keys.onEscapePressed: {
            if (searchInput.text) {
              searchInput.text = ""
              root.filterQuery = ""
            }
            listKeyCatcher.forceActiveFocus()
          }
          Keys.onDownPressed: listKeyCatcher.forceActiveFocus()
          Keys.onReturnPressed: listKeyCatcher.forceActiveFocus()
        }
      }

      Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: root.dividerColor
      }
    }

    // --- LIST VIEW CONTAINER ---
    Item {
      width: parent.width
      height: root.calculatedListHeight
      clip: true

      Item {
        id: listKeyCatcher
        anchors.fill: parent
        focus: true

        Keys.onPressed: function(event) {
          if (root.isEditing) return

          var key = event.key
          var isDown = (key === Qt.Key_J || key === Qt.Key_Down)
          var isUp = (key === Qt.Key_K || key === Qt.Key_Up)
          var isToggle = (key === Qt.Key_Space || key === Qt.Key_X)
          var isEdit = (key === Qt.Key_E || key === Qt.Key_Return || key === Qt.Key_Enter)
          var isDelete = (key === Qt.Key_D || key === Qt.Key_Delete || key === Qt.Key_Backspace)
          var isNew = (key === Qt.Key_A || key === Qt.Key_Tab)
          var isSearch = (key === Qt.Key_Slash)
          var isSort = (key === Qt.Key_S)
          var isCopy = (key === Qt.Key_C)

          if (isDown) {
            if (root.visibleIndices.length > 0) {
              root.selectedIndex = Math.min(root.visibleIndices.length - 1, root.selectedIndex + 1)
              listView.positionViewAtIndex(root.selectedIndex, ListView.Contain)
            }
            event.accepted = true
          } else if (isUp) {
            if (root.visibleIndices.length > 0) {
              root.selectedIndex = Math.max(0, root.selectedIndex - 1)
              listView.positionViewAtIndex(root.selectedIndex, ListView.Contain)
            }
            event.accepted = true
          } else if (isToggle) {
            if (root.visibleIndices.length > 0) {
              var realIdx = root.visibleIndices[root.selectedIndex]
              root.toggleDone(realIdx)
            }
            event.accepted = true
          } else if (isEdit) {
            if (root.visibleIndices.length > 0) {
              root.isEditing = true
            }
            event.accepted = true
          } else if (isDelete) {
            if (root.visibleIndices.length > 0) {
              var delIdx = root.visibleIndices[root.selectedIndex]
              root.deleteItem(delIdx)
            }
            event.accepted = true
          } else if (isNew) {
            root.requestCapture()
            event.accepted = true
          } else if (isSearch) {
            searchInput.forceActiveFocus()
            event.accepted = true
          } else if (isCopy) {
            if (root.visibleIndices.length > 0) {
              var copyItem = root.items[root.visibleIndices[root.selectedIndex]]
              var copyText = copyItem.text + (copyItem.extra ? "\n" + copyItem.extra : "")
              Quickshell.execDetached(["wl-copy", copyText])
            }
            event.accepted = true
          } else if (isSort) {
            root.newestFirst = !root.newestFirst
            root.selectedIndex = Math.max(0, root.visibleIndices.length - 1 - root.selectedIndex)
            listView.positionViewAtIndex(root.selectedIndex, ListView.Contain)
            event.accepted = true
          } else if (key === Qt.Key_Escape) {
            if (root.filterQuery) {
              root.filterQuery = ""
              searchInput.text = ""
            } else {
              root.requestDismiss()
            }
            event.accepted = true
          }
        }
      }

      // Empty State
      Item {
        anchors.fill: parent
        visible: root.visibleIndices.length === 0

        Column {
          anchors.centerIn: parent
          spacing: 6

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.items.length === 0 ? "Inbox zero." : "No matching notes."
            font.family: root.fontFamily
            font.pixelSize: 14
            color: root.mutedText
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Press [Tab] to capture."
            font.family: root.monoFamily
            font.pixelSize: 11
            color: root.mutedText
            opacity: 0.6
          }
        }
      }

      // ListView
      ListView {
        id: listView
        anchors.fill: parent
        anchors.topMargin: 4
        anchors.bottomMargin: 4
        spacing: 2
        model: root.visibleIndices
        currentIndex: root.selectedIndex

        delegate: Item {
          id: rowItem
          width: listView.width
          readonly property int realIndex: modelData
          readonly property var noteItem: root.items[realIndex] || ({})
          readonly property bool isSelected: index === root.selectedIndex
          readonly property bool isRowEditing: root.isEditing && isSelected

          height: isRowEditing ? 40 : (noteItem.extra ? 54 : root.baseRowHeight)

          Rectangle {
            anchors.fill: parent
            radius: 6
            color: isSelected ? root.selectedBg : (rowHover.hovered ? Util.alpha(root.foreground, 0.04) : "transparent")
          }

          MouseArea {
            id: rowHover
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
              root.selectedIndex = index
              listKeyCatcher.forceActiveFocus()
            }
            onDoubleClicked: {
              root.selectedIndex = index
              root.isEditing = true
            }
          }

          Item {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            visible: !isRowEditing

            // Checkbox
            Rectangle {
              id: checkbox
              width: 16
              height: 16
              radius: 4
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              color: noteItem.checked ? Util.alpha(root.accentColor, 0.2) : "transparent"
              border.width: 1
              border.color: noteItem.checked ? root.accentColor : root.mutedText

              Text {
                anchors.centerIn: parent
                text: "✓"
                font.pixelSize: 10
                font.weight: Font.Bold
                color: root.accentColor
                visible: noteItem.checked
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleDone(realIndex)
              }
            }

            // Right Meta
            Row {
              id: rightMeta
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: 10

              Text {
                text: noteItem.displayTime || noteItem.timestamp || ""
                font.family: root.monoFamily
                font.pixelSize: 11
                color: root.mutedText
                visible: Boolean(noteItem.timestamp)
                anchors.verticalCenter: parent.verticalCenter
              }

              Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                visible: isSelected

                Rectangle {
                  height: 20
                  radius: 4
                  color: Util.alpha(root.foreground, 0.1)
                  width: editHint.implicitWidth + 12
                  Text {
                    id: editHint
                    anchors.centerIn: parent
                    text: "[e] edit"
                    font.family: root.monoFamily
                    font.pixelSize: 10
                    color: root.mutedText
                  }
                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { root.selectedIndex = index; root.isEditing = true; }
                  }
                }

                Rectangle {
                  height: 20
                  radius: 4
                  color: Util.alpha(Color.urgent, 0.15)
                  width: delHint.implicitWidth + 12
                  Text {
                    id: delHint
                    anchors.centerIn: parent
                    text: "[d] del"
                    font.family: root.monoFamily
                    font.pixelSize: 10
                    color: Color.urgent
                  }
                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.deleteItem(realIndex)
                  }
                }
              }
            }

            // Note Text
            Column {
              anchors.left: checkbox.right
              anchors.leftMargin: 12
              anchors.right: rightMeta.left
              anchors.rightMargin: 12
              anchors.verticalCenter: parent.verticalCenter
              spacing: 2

              Text {
                width: parent.width
                text: noteItem.text || ""
                font.family: root.fontFamily
                font.pixelSize: 14
                font.strikeout: Boolean(noteItem.checked)
                color: noteItem.checked ? root.mutedText : root.foreground
                opacity: noteItem.checked ? 0.5 : 1.0
                elide: Text.ElideRight
                textFormat: Text.PlainText
              }

              Text {
                width: parent.width
                text: noteItem.extra || ""
                font.family: root.fontFamily
                font.pixelSize: 12
                font.strikeout: Boolean(noteItem.checked)
                color: root.mutedText
                opacity: noteItem.checked ? 0.4 : 0.8
                elide: Text.ElideRight
                visible: Boolean(noteItem.extra)
                textFormat: Text.PlainText
              }
            }
          }

          // Inline Edit Mode
          Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: 4
            color: Util.alpha(root.foreground, 0.1)
            border.width: 1
            border.color: root.accentColor
            visible: isRowEditing

            TextInput {
              id: editField
              anchors.fill: parent
              anchors.leftMargin: 10
              anchors.rightMargin: 10
              verticalAlignment: TextInput.AlignVCenter
              font.family: root.fontFamily
              font.pixelSize: 14
              color: root.foreground
              clip: true
              text: noteItem.text || ""
              visible: isRowEditing

              Component.onCompleted: {
                if (isRowEditing) {
                  editField.forceActiveFocus()
                  editField.selectAll()
                }
              }

              onVisibleChanged: {
                if (visible) {
                  text = noteItem.text || ""
                  editField.forceActiveFocus()
                  editField.selectAll()
                }
              }

              Keys.onReturnPressed: root.commitEdit(realIndex, editField.text)
              Keys.onEnterPressed: root.commitEdit(realIndex, editField.text)
              Keys.onEscapePressed: root.cancelEdit()
            }
          }
        }
      }
    }

    // --- FOOTER HUD ---
    Item {
      width: parent.width
      height: root.footerHeight

      Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: 1
        color: root.dividerColor
      }

      Item {
        anchors.fill: parent
        anchors.leftMargin: 2
        anchors.rightMargin: 2

        Row {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: 12

          Row {
            spacing: 4; anchors.verticalCenter: parent.verticalCenter
            Rectangle { height: 18; width: kbdNav.implicitWidth+8; radius:3; color: Util.alpha(root.foreground, 0.1); Text { id: kbdNav; anchors.centerIn: parent; text: "j/k"; font.family: root.monoFamily; font.pixelSize: 10; color: root.mutedText } }
            Text { text: "nav"; font.family: root.fontFamily; font.pixelSize: 11; color: root.mutedText; anchors.verticalCenter: parent.verticalCenter }
          }
          Row {
            spacing: 4; anchors.verticalCenter: parent.verticalCenter
            Rectangle { height: 18; width: kbdDone.implicitWidth+8; radius:3; color: Util.alpha(root.foreground, 0.1); Text { id: kbdDone; anchors.centerIn: parent; text: "spc"; font.family: root.monoFamily; font.pixelSize: 10; color: root.mutedText } }
            Text { text: "done"; font.family: root.fontFamily; font.pixelSize: 11; color: root.mutedText; anchors.verticalCenter: parent.verticalCenter }
          }
          Row {
            spacing: 4; anchors.verticalCenter: parent.verticalCenter
            Rectangle { height: 18; width: kbdSort.implicitWidth+8; radius:3; color: Util.alpha(root.foreground, 0.1); Text { id: kbdSort; anchors.centerIn: parent; text: "s"; font.family: root.monoFamily; font.pixelSize: 10; color: root.mutedText } }
            Text { text: root.newestFirst ? "newest" : "oldest"; font.family: root.fontFamily; font.pixelSize: 11; color: root.mutedText; anchors.verticalCenter: parent.verticalCenter }
          }
        }

        Row {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: 12
          
          Row {
            spacing: 4; anchors.verticalCenter: parent.verticalCenter
            Rectangle { height: 18; width: kbdCopy.implicitWidth+8; radius:3; color: Util.alpha(root.foreground, 0.1); Text { id: kbdCopy; anchors.centerIn: parent; text: "c"; font.family: root.monoFamily; font.pixelSize: 10; color: root.mutedText } }
            Text { text: "copy"; font.family: root.fontFamily; font.pixelSize: 11; color: root.mutedText; anchors.verticalCenter: parent.verticalCenter }
          }
          Row {
            spacing: 4; anchors.verticalCenter: parent.verticalCenter
            Rectangle { height: 18; width: kbdNew.implicitWidth+8; radius:3; color: Util.alpha(root.foreground, 0.1); Text { id: kbdNew; anchors.centerIn: parent; text: "a"; font.family: root.monoFamily; font.pixelSize: 10; color: root.mutedText } }
            Text { text: "new"; font.family: root.fontFamily; font.pixelSize: 11; color: root.mutedText; anchors.verticalCenter: parent.verticalCenter }
          }
          Row {
            spacing: 4; anchors.verticalCenter: parent.verticalCenter
            Rectangle { height: 18; width: kbdClose.implicitWidth+8; radius:3; color: Util.alpha(root.foreground, 0.1); Text { id: kbdClose; anchors.centerIn: parent; text: "esc"; font.family: root.monoFamily; font.pixelSize: 10; color: root.mutedText } }
            Text { text: "close"; font.family: root.fontFamily; font.pixelSize: 11; color: root.mutedText; anchors.verticalCenter: parent.verticalCenter }
          }
        }
      }
    }
  }
}
