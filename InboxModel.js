// InboxModel.js — Pure JS parser & serializer for Markdown checkbox inboxes (~/notes/inbox.md)
.pragma library

function parseInbox(raw) {
  if (!raw || typeof raw !== "string") return [];
  var lines = raw.split(/\r?\n/);
  var items = [];
  var currentItem = null;

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i];
    if (!line.trim() && !currentItem) continue;

    // Match markdown checkbox format: "- [ ] 2026-08-18 01:18 text..." or "- [x] text..."
    var match = line.match(/^(\s*-\s*\[([ xX])\]\s*)(?:(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}|\d{2}-\d{2}\s+\d{2}:\d{2})\s+)?(.*)$/);
    if (match) {
      if (currentItem) items.push(currentItem);
      var isChecked = match[2].toLowerCase() === "x";
      var ts = match[3] || "";
      var content = match[4] || "";
      currentItem = {
        id: items.length,
        checked: isChecked,
        timestamp: ts,
        text: content,
        extra: "",
        isTask: true,
        rawPrefix: match[1]
      };
    } else if (currentItem && /^\s{2,}/.test(line)) {
      // Indented continuation line
      var cleanSub = line.replace(/^\s{2}/, "");
      if (currentItem.extra) currentItem.extra += "\n" + cleanSub;
      else currentItem.extra = cleanSub;
    } else if (line.trim()) {
      // Plain non-task markdown line
      if (currentItem) items.push(currentItem);
      currentItem = {
        id: items.length,
        checked: false,
        timestamp: "",
        text: line,
        extra: "",
        isTask: false,
        rawPrefix: ""
      };
    }
  }
  if (currentItem) items.push(currentItem);
  return items;
}

function serializeInbox(items) {
  if (!items || !items.length) return "";
  var lines = [];
  for (var i = 0; i < items.length; i++) {
    var item = items[i];
    if (item.isTask) {
      var box = item.checked ? "[x]" : "[ ]";
      var ts = item.timestamp ? (" " + item.timestamp) : "";
      var mainLine = "- " + box + ts + (item.text ? (" " + item.text) : "");
      lines.push(mainLine);
      if (item.extra) {
        var subLines = item.extra.split("\n");
        for (var s = 0; s < subLines.length; s++) {
          lines.push("  " + subLines[s]);
        }
      }
    } else {
      lines.push(item.text || "");
    }
  }
  return lines.join("\n") + "\n";
}

function toggleItemAt(items, index) {
  if (!items || index < 0 || index >= items.length) return items;
  var copy = items.slice();
  var target = Object.assign({}, copy[index]);
  target.checked = !target.checked;
  copy[index] = target;
  return copy;
}

function updateItemTextAt(items, index, newText) {
  if (!items || index < 0 || index >= items.length) return items;
  var copy = items.slice();
  var target = Object.assign({}, copy[index]);
  target.text = String(newText || "").trim();
  copy[index] = target;
  return copy;
}

function deleteItemAt(items, index) {
  if (!items || index < 0 || index >= items.length) return items;
  var copy = items.slice();
  copy.splice(index, 1);
  // re-index
  for (var i = 0; i < copy.length; i++) {
    copy[i].id = i;
  }
  return copy;
}

function formatCurrentTimestamp() {
  var d = new Date();
  var pad = function(n) { return n < 10 ? '0' + n : n; };
  var year = d.getFullYear();
  var month = pad(d.getMonth() + 1);
  var day = pad(d.getDate());
  var hours = pad(d.getHours());
  var mins = pad(d.getMinutes());
  return year + "-" + month + "-" + day + " " + hours + ":" + mins;
}

function createNewItem(text, timestamp) {
  var ts = timestamp !== undefined ? timestamp : formatCurrentTimestamp();
  return {
    id: 0,
    checked: false,
    timestamp: ts,
    text: String(text || "").trim(),
    extra: "",
    isTask: true,
    rawPrefix: "- [ ] "
  };
}

function countPending(items) {
  if (!items) return 0;
  var count = 0;
  for (var i = 0; i < items.length; i++) {
    if (items[i].isTask && !items[i].checked) count++;
  }
  return count;
}

function countCompleted(items) {
  if (!items) return 0;
  var count = 0;
  for (var i = 0; i < items.length; i++) {
    if (items[i].isTask && items[i].checked) count++;
  }
  return count;
}
