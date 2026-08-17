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
  property bool searchFocused: false

  property color foreground: Color.menu.text
  property color background: Color.menu.background
  property color selectedBg: Color.menu.selectedBackground
  property color selectedFg: Color.menu.selectedText
  property color mutedText: "#8A8A8E"
  property color dividerColor: Qt.rgba(1, 1, 1, 0.08)
  property color accentColor: Color.accent
  property string fontFamily: Style.font.menuFamily
  property string monoFamily: Style.font.monoFamily || "monospace"

  signal requestSave()
  signal requestCapture()
  signal requestDismiss()

  function resetState() {
    isEditing = false
    filterQuery = ""
    searchFocused = false
    selectedIndex = Math.min(selectedIndex, Math.max(0, items.length - 1))
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
    if (root.selectedIndex >= root.items.length) {
      root.selectedIndex = Math.max(0, root.items.length - 1)
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

  // Filtered indices mapping
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
    Rectangle {
      width: parent.width
      height: 48
      color: "transparent"

      Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        Text {
          text: "INBOX"
          font.family: root.fontFamily
          font.pixelSize: Style.font.title
          font.weight: Font.DemiBold
          font.letterSpacing: 1.5
          color: root.foreground
          anchors.verticalCenter: parent.verticalCenter
        }

        // Status pill: "3 PENDING · 1 DONE"
        Rectangle {
          radius: 4
          color: Qt.rgba(1, 1, 1, 0.06)
          border.width: 1
          border.color: root.dividerColor
          height: 22
          width: statusText.implicitWidth + 14
          anchors.verticalCenter: parent.verticalCenter

          Text {
            id: statusText
            anchors.centerIn: parent
            text: root.pendingCount + " PENDING · " + root.completedCount + " DONE"
            font.family: root.monoFamily
            font.pixelSize: 11
            font.weight: Font.Medium
            color: root.pendingCount > 0 ? "#7DA2FF" : "#75B980"
          }
        }
      }

      // Mode switch tab hint
      Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 24
        radius: 4
        color: Qt.rgba(1, 1, 1, 0.05)
        border.width: 1
        border.color: root.dividerColor
        width: tabHintText.implicitWidth + 12

        Text {
          id: tabHintText
          anchors.centerIn: parent
          text: "[TAB] CAPTURE"
          font.family: root.monoFamily
          font.pixelSize: 11
          color: root.mutedText
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.requestCapture()
        }
      }

      // Hairline divider
      Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: root.dividerColor
      }
    }

    // --- SEARCH / FILTER BAR ------------------------------------------------
    Rectangle {
      width: parent.width
      height: 36
      color: "transparent"

      Row {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        spacing: 8

        Text {
          text: "/"
          font.family: root.monoFamily
          font.pixelSize: 13
          font.weight: Font.Bold
          color: root.filterQuery ? root.accentColor : root.mutedText
          anchors.verticalCenter: parent.verticalCenter
        }

        TextInput {
          id: searchInput
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - 24
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
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
            font.pixelSize: Style.font.body
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
      height: parent.height - 48 - 36 - 40 // header, filter, footer
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
          spacing: 8

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.items.length === 0 ? "No notes in inbox." : "No matching notes."
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            color: root.mutedText
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Press 'a' or [Tab] to capture a thought."
            font.family: root.monoFamily
            font.pixelSize: 12
            color: root.mutedText
            opacity: 0.7
          }
        }
      }

      // ListView of notes
      ListView {
        id: listView
        anchors.fill: parent
        anchors.topMargin: 4
        anchors.bottomMargin: 4
        spacing: 4
        model: root.visibleIndices
        currentIndex: root.selectedIndex

        delegate: Item {
          id: rowItem
          width: listView.width
          readonly property int realIndex: modelData
          readonly property var noteItem: root.items[realIndex] || ({})
          readonly property bool isSelected: index === root.selectedIndex
          readonly property bool isRowEditing: root.isEditing && isSelected

          height: isRowEditing ? Math.max(52, editField.implicitHeight + 16) : Math.max(38, contentCol.implicitHeight + 14)

          // Row background with hover & selection state
          Rectangle {
            anchors.fill: parent
            radius: 6
            color: isSelected ? Qt.rgba(1, 1, 1, 0.07) : (rowHover.hovered ? Qt.rgba(1, 1, 1, 0.03) : "transparent")

            // Left 2px selection indicator bar
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

          // Main Row Content
          Row {
            id: mainRow
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10
            visible: !isRowEditing

            // Checkbox
            Rectangle {
              id: checkbox
              width: 16
              height: 16
              radius: 3
              anchors.verticalCenter: parent.verticalCenter
              color: noteItem.checked ? Qt.rgba(117/255, 185/255, 128/255, 0.2) : "transparent"
              border.width: 1
              border.color: noteItem.checked ? "#75B980" : root.mutedText

              Text {
                anchors.centerIn: parent
                text: "✓"
                font.pixelSize: 11
                font.weight: Font.Bold
                color: "#75B980"
                visible: noteItem.checked
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleDone(realIndex)
              }
            }

            // Timestamp (if available)
            Text {
              text: noteItem.timestamp || ""
              font.family: root.monoFamily
              font.pixelSize: 11
              color: root.mutedText
              visible: Boolean(noteItem.timestamp)
              anchors.verticalCenter: parent.verticalCenter
            }

            // Text Content Column (handles text + multi-line continuation)
            Column {
              id: contentCol
              width: parent.width - checkbox.width - (noteItem.timestamp ? 95 : 0) - (isSelected ? 110 : 0) - 20
              anchors.verticalCenter: parent.verticalCenter
              spacing: 2

              Text {
                width: parent.width
                text: noteItem.text || ""
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.strikeout: Boolean(noteItem.checked)
                color: noteItem.checked ? root.mutedText : root.foreground
                opacity: noteItem.checked ? 0.55 : 1.0
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
              }

              Text {
                width: parent.width
                text: noteItem.extra || ""
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.strikeout: Boolean(noteItem.checked)
                color: root.mutedText
                opacity: noteItem.checked ? 0.45 : 0.8
                wrapMode: Text.Wrap
                visible: Boolean(noteItem.extra)
                textFormat: Text.PlainText
              }
            }

            // Action hints on active row
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
                  text: "[e] Edit"
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
                color: Qt.rgba(229/255, 115/255, 115/255, 0.15)
                width: delHint.implicitWidth + 8
                Text {
                  id: delHint
                  anchors.centerIn: parent
                  text: "[d] Del"
                  font.family: root.monoFamily
                  font.pixelSize: 10
                  color: "#E57373"
                }
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.deleteItem(realIndex)
                }
              }
            }
          }

          // Inline Edit Mode Field
          Item {
            id: editContainer
            anchors.fill: parent
            anchors.margins: 4
            visible: isRowEditing

            TextInput {
              id: editField
              anchors.fill: parent
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
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
    Rectangle {
      width: parent.width
      height: 40
      color: "transparent"

      Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: 1
        color: root.dividerColor
      }

      Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        Row {
          spacing: 4
          anchors.verticalCenter: parent.verticalCenter
          Rectangle {
            height: 18; width: 34; radius: 3; color: Qt.rgba(1,1,1,0.06); border.width: 1; border.color: root.dividerColor
            Text { anchors.centerIn: parent; text: "J/K"; font.family: root.monoFamily; font.pixelSize: 10; color: root.mutedText }
          }
          Text { anchors.verticalCenter: parent.verticalCenter; text: "Move"; font.family: root.monoFamily; font.pixelSize: 11; color: root.mutedText }
        }

        Row {
          spacing: 4
          anchors.verticalCenter: parent.verticalCenter
          Rectangle {
            height: 18; width: 42; radius: 3; color: Qt.rgba(1,1,1,0.06); border.width: 1; border.color: root.dividerColor
            Text { anchors.centerIn: parent; text: "SPACE"; font.family: root.monoFamily; font.pixelSize: 10; color: root.mutedText }
          }
          Text { anchors.verticalCenter: parent.verticalCenter; text: "Toggle"; font.family: root.monoFamily; font.pixelSize: 11; color: root.mutedText }
        }

        Row {
          spacing: 4
          anchors.verticalCenter: parent.verticalCenter
          Rectangle {
            height: 18; width: 22; radius: 3; color: Qt.rgba(1,1,1,0.06); border.width: 1; border.color: root.dividerColor
            Text { anchors.centerIn: parent; text: "E"; font.family: root.monoFamily; font.pixelSize: 10; color: root.mutedText }
          }
          Text { anchors.verticalCenter: parent.verticalCenter; text: "Edit"; font.family: root.monoFamily; font.pixelSize: 11; color: root.mutedText }
        }

        Row {
          spacing: 4
          anchors.verticalCenter: parent.verticalCenter
          Rectangle {
            height: 18; width: 22; radius: 3; color: Qt.rgba(1,1,1,0.06); border.width: 1; border.color: root.dividerColor
            Text { anchors.centerIn: parent; text: "D"; font.family: root.monoFamily; font.pixelSize: 10; color: root.mutedText }
          }
          Text { anchors.verticalCenter: parent.verticalCenter; text: "Del"; font.family: root.monoFamily; font.pixelSize: 11; color: root.mutedText }
        }

        Row {
          spacing: 4
          anchors.verticalCenter: parent.verticalCenter
          Rectangle {
            height: 18; width: 22; radius: 3; color: Qt.rgba(1,1,1,0.06); border.width: 1; border.color: root.dividerColor
            Text { anchors.centerIn: parent; text: "A"; font.family: root.monoFamily; font.pixelSize: 10; color: root.mutedText }
          }
          Text { anchors.verticalCenter: parent.verticalCenter; text: "New"; font.family: root.monoFamily; font.pixelSize: 11; color: root.mutedText }
        }
      }

      Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Rectangle {
          height: 18; width: 30; radius: 3; color: Qt.rgba(1,1,1,0.06); border.width: 1; border.color: root.dividerColor
          Text { anchors.centerIn: parent; text: "ESC"; font.family: root.monoFamily; font.pixelSize: 10; color: root.mutedText }
        }
        Text { anchors.verticalCenter: parent.verticalCenter; text: "Close"; font.family: root.monoFamily; font.pixelSize: 11; color: root.mutedText }
      }
    }
  }
}
