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

  property color foreground: Color.menu.text
  property color background: Color.menu.background
  property color selectedBg: Color.menu.selectedBackground
  property color selectedFg: Color.menu.selectedText
  property color mutedText: "#71717A"
  property color dividerColor: Qt.rgba(1, 1, 1, 0.07)
  property color accentColor: Color.accent
  property string fontFamily: Style.font.menuFamily
  property string monoFamily: Style.font.monoFamily || "monospace"

  readonly property int headerHeight: 42
  readonly property int filterHeight: 34
  readonly property int footerHeight: 34
  readonly property int baseRowHeight: 38
  readonly property int maxListHeight: 320

  readonly property int calculatedListHeight: {
    if (visibleIndices.length === 0) return 72
    var h = 0
    for (var i = 0; i < visibleIndices.length; i++) {
      var item = items[visibleIndices[i]]
      if (item && item.extra) h += 52
      else h += baseRowHeight
      if (h >= maxListHeight) return maxListHeight
    }
    return Math.max(baseRowHeight, h)
  }

  readonly property int preferredHeight: headerHeight + filterHeight + calculatedListHeight + footerHeight

  signal requestSave()
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
    root.items = InboxModel.toggleItemAt(root.items, index)
    root.requestSave()
  }

  function deleteItem(index) {
    if (index < 0 || index >= items.length) return
    root.items = InboxModel.deleteItemAt(root.items, index)
    if (root.selectedIndex >= root.visibleIndices.length) {
      root.selectedIndex = Math.max(0, root.visibleIndices.length - 1)
    }
    root.requestSave()
  }

  function commitEdit(index, newText) {
    if (index >= 0 && index < root.items.length) {
      root.items = InboxModel.updateItemTextAt(root.items, index, newText)
      root.requestSave()
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
    return list
  }

  readonly property int pendingCount: InboxModel.countPending(root.items)
  readonly property int completedCount: InboxModel.countCompleted(root.items)

  Column {
    anchors.fill: parent
    spacing: 0

    // --- HEADER -------------------------------------------------------------
    Item {
      width: parent.width
      height: root.headerHeight

      Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        Text {
          text: "INBOX"
          font.family: root.fontFamily
          font.pixelSize: 12
          font.weight: Font.DemiBold
          font.letterSpacing: 1.5
          color: root.foreground
          anchors.verticalCenter: parent.verticalCenter
        }

        // Pending count chip
        Rectangle {
          radius: 3
          color: root.pendingCount > 0 ? Qt.rgba(59/255, 130/255, 246/255, 0.14) : Qt.rgba(1, 1, 1, 0.05)
          border.width: 1
          border.color: root.pendingCount > 0 ? Qt.rgba(59/255, 130/255, 246/255, 0.3) : root.dividerColor
          height: 20
          width: pendingText.implicitWidth + 10
          anchors.verticalCenter: parent.verticalCenter

          Text {
            id: pendingText
            anchors.centerIn: parent
            text: root.pendingCount + " PENDING"
            font.family: root.monoFamily
            font.pixelSize: 10
            font.weight: Font.Medium
            color: root.pendingCount > 0 ? "#60A5FA" : root.mutedText
          }
        }

        // Done count chip
        Rectangle {
          visible: root.completedCount > 0
          radius: 3
          color: Qt.rgba(74/255, 222/255, 128/255, 0.12)
          border.width: 1
          border.color: Qt.rgba(74/255, 222/255, 128/255, 0.25)
          height: 20
          width: doneText.implicitWidth + 10
          anchors.verticalCenter: parent.verticalCenter

          Text {
            id: doneText
            anchors.centerIn: parent
            text: root.completedCount + " DONE"
            font.family: root.monoFamily
            font.pixelSize: 10
            font.weight: Font.Medium
            color: "#4ADE80"
          }
        }
      }

      // Mode switch tab hint
      Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 22
        radius: 3
        color: tabHover.hovered ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.05)
        border.width: 1
        border.color: root.dividerColor
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

    // --- SEARCH / FILTER BAR ------------------------------------------------
    Item {
      width: parent.width
      height: root.filterHeight

      Row {
        anchors.fill: parent
        anchors.leftMargin: 2
        anchors.rightMargin: 2
        spacing: 8

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
          font.pixelSize: 12
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
            text: "Filter notes (press / to focus)..."
            font.family: root.fontFamily
            font.pixelSize: 12
            color: root.mutedText
            opacity: 0.5
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

    // --- LIST VIEW CONTAINER ------------------------------------------------
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
          spacing: 4

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.items.length === 0 ? "No notes in inbox." : "No matching notes."
            font.family: root.fontFamily
            font.pixelSize: 13
            color: root.mutedText
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Press 'a' or [Tab] to capture a thought."
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
        anchors.topMargin: 2
        anchors.bottomMargin: 2
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

          height: isRowEditing ? 40 : (noteItem.extra ? 50 : root.baseRowHeight)

          Rectangle {
            anchors.fill: parent
            radius: 4
            color: isSelected ? Qt.rgba(1, 1, 1, 0.06) : (rowHover.hovered ? Qt.rgba(1, 1, 1, 0.02) : "transparent")

            Rectangle {
              anchors.left: parent.left
              anchors.top: parent.top
              anchors.bottom: parent.bottom
              anchors.margins: 4
              width: 2
              radius: 1
              color: root.accentColor
              visible: isSelected
            }
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
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            visible: !isRowEditing

            // Checkbox
            Rectangle {
              id: checkbox
              width: 15
              height: 15
              radius: 3
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              color: noteItem.checked ? Qt.rgba(74/255, 222/255, 128/255, 0.18) : "transparent"
              border.width: 1
              border.color: noteItem.checked ? "#4ADE80" : root.mutedText

              Text {
                anchors.centerIn: parent
                text: "✓"
                font.pixelSize: 10
                font.weight: Font.Bold
                color: "#4ADE80"
                visible: noteItem.checked
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleDone(realIndex)
              }
            }

            // Right Meta (Timestamp + Action pills)
            Row {
              id: rightMeta
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: 8

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
                spacing: 4
                visible: isSelected

                Rectangle {
                  height: 18
                  radius: 3
                  color: Qt.rgba(1, 1, 1, 0.08)
                  width: editHint.implicitWidth + 8
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
                  height: 18
                  radius: 3
                  color: Qt.rgba(239/255, 68/255, 68/255, 0.15)
                  width: delHint.implicitWidth + 8
                  Text {
                    id: delHint
                    anchors.centerIn: parent
                    text: "[d] del"
                    font.family: root.monoFamily
                    font.pixelSize: 10
                    color: "#EF4444"
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
              anchors.leftMargin: 10
              anchors.right: rightMeta.left
              anchors.rightMargin: 10
              anchors.verticalCenter: parent.verticalCenter
              spacing: 1

              Text {
                width: parent.width
                text: noteItem.text || ""
                font.family: root.fontFamily
                font.pixelSize: 13
                font.strikeout: Boolean(noteItem.checked)
                color: noteItem.checked ? root.mutedText : root.foreground
                opacity: noteItem.checked ? 0.45 : 1.0
                elide: Text.ElideRight
                textFormat: Text.PlainText
              }

              Text {
                width: parent.width
                text: noteItem.extra || ""
                font.family: root.fontFamily
                font.pixelSize: 11
                font.strikeout: Boolean(noteItem.checked)
                color: root.mutedText
                opacity: noteItem.checked ? 0.35 : 0.7
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
            color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1
            border.color: root.accentColor
            visible: isRowEditing

            TextInput {
              id: editField
              anchors.fill: parent
              anchors.leftMargin: 8
              anchors.rightMargin: 8
              verticalAlignment: TextInput.AlignVCenter
              font.family: root.fontFamily
              font.pixelSize: 13
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

    // --- FOOTER HUD ---------------------------------------------------------
    Item {
      width: parent.width
      height: root.footerHeight

      Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: 1
        color: root.dividerColor
      }

      Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Row {
          spacing: 3
          anchors.verticalCenter: parent.verticalCenter
          Rectangle {
            height: 16; width: 24; radius: 3; color: Qt.rgba(1,1,1,0.06); border.width: 1; border.color: root.dividerColor
            Text { anchors.centerIn: parent; text: "j/k"; font.family: root.monoFamily; font.pixelSize: 9; color: root.mutedText }
          }
          Text { anchors.verticalCenter: parent.verticalCenter; text: "nav"; font.family: root.monoFamily; font.pixelSize: 10; color: root.mutedText }
        }

        Row {
          spacing: 3
          anchors.verticalCenter: parent.verticalCenter
          Rectangle {
            height: 16; width: 34; radius: 3; color: Qt.rgba(1,1,1,0.06); border.width: 1; border.color: root.dividerColor
            Text { anchors.centerIn: parent; text: "space"; font.family: root.monoFamily; font.pixelSize: 9; color: root.mutedText }
          }
          Text { anchors.verticalCenter: parent.verticalCenter; text: "done"; font.family: root.monoFamily; font.pixelSize: 10; color: root.mutedText }
        }

        Row {
          spacing: 3
          anchors.verticalCenter: parent.verticalCenter
          Rectangle {
            height: 16; width: 14; radius: 3; color: Qt.rgba(1,1,1,0.06); border.width: 1; border.color: root.dividerColor
            Text { anchors.centerIn: parent; text: "e"; font.family: root.monoFamily; font.pixelSize: 9; color: root.mutedText }
          }
          Text { anchors.verticalCenter: parent.verticalCenter; text: "edit"; font.family: root.monoFamily; font.pixelSize: 10; color: root.mutedText }
        }

        Row {
          spacing: 3
          anchors.verticalCenter: parent.verticalCenter
          Rectangle {
            height: 16; width: 14; radius: 3; color: Qt.rgba(1,1,1,0.06); border.width: 1; border.color: root.dividerColor
            Text { anchors.centerIn: parent; text: "d"; font.family: root.monoFamily; font.pixelSize: 9; color: root.mutedText }
          }
          Text { anchors.verticalCenter: parent.verticalCenter; text: "del"; font.family: root.monoFamily; font.pixelSize: 10; color: root.mutedText }
        }

        Row {
          spacing: 3
          anchors.verticalCenter: parent.verticalCenter
          Rectangle {
            height: 16; width: 14; radius: 3; color: Qt.rgba(1,1,1,0.06); border.width: 1; border.color: root.dividerColor
            Text { anchors.centerIn: parent; text: "a"; font.family: root.monoFamily; font.pixelSize: 9; color: root.mutedText }
          }
          Text { anchors.verticalCenter: parent.verticalCenter; text: "new"; font.family: root.monoFamily; font.pixelSize: 10; color: root.mutedText }
        }

        Row {
          spacing: 3
          anchors.verticalCenter: parent.verticalCenter
          Rectangle {
            height: 16; width: 14; radius: 3; color: Qt.rgba(1,1,1,0.06); border.width: 1; border.color: root.dividerColor
            Text { anchors.centerIn: parent; text: "/"; font.family: root.monoFamily; font.pixelSize: 9; color: root.mutedText }
          }
          Text { anchors.verticalCenter: parent.verticalCenter; text: "find"; font.family: root.monoFamily; font.pixelSize: 10; color: root.mutedText }
        }
      }

      Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Rectangle {
          height: 16; width: 24; radius: 3; color: Qt.rgba(1,1,1,0.06); border.width: 1; border.color: root.dividerColor
          Text { anchors.centerIn: parent; text: "esc"; font.family: root.monoFamily; font.pixelSize: 9; color: root.mutedText }
        }
        Text { anchors.verticalCenter: parent.verticalCenter; text: "close"; font.family: root.monoFamily; font.pixelSize: 10; color: root.mutedText }
      }
    }
  }
}
