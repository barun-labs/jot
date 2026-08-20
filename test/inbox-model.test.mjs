// Pure-function tests for InboxModel.js. Run: node test/inbox-model.test.mjs
// Loads InboxModel.js by stripping the QML `.pragma library` line, then
// evaluating the plain-JS body. No framework: assert + a small runner.
import { readFileSync } from "node:fs";
import assert from "node:assert/strict";

const src = readFileSync(new URL("../InboxModel.js", import.meta.url), "utf8")
  .replace(/^\s*\.pragma\s+library.*$/m, "");

const M = {};
new Function(
  "out",
  src +
    "\n;const names=['parseInbox','serializeInbox','appendItem','toggleItemAt'," +
    "'updateItemTextAt','deleteItemAt','formatCurrentTimestamp'];" +
    "for(const n of names){out[n]=(eval('typeof '+n)==='function')?eval(n):undefined;}"
)(M);

const TS_RE = /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$/;

const tests = {
  "TP-1 appendItem adds one unchecked task in the fixed format"() {
    const items = M.appendItem(M.parseInbox(""), "buy milk");
    assert.equal(items.length, 1);
    const it = items[0];
    assert.equal(it.isTask, true);
    assert.equal(it.checked, false);
    assert.equal(it.text, "buy milk");
    assert.match(it.timestamp, TS_RE, "timestamp must be YYYY-MM-DD HH:MM");
  },

  "TP-2 appendItem preserves existing items and order, new item last"() {
    const raw = "- [ ] 2026-08-01 09:00 first\n- [x] 2026-08-02 10:00 second\n";
    const before = M.parseInbox(raw);
    const after = M.appendItem(before, "third");
    assert.equal(after.length, 3);
    assert.equal(after[0].text, "first");
    assert.equal(after[0].checked, false);
    assert.equal(after[1].text, "second");
    assert.equal(after[1].checked, true);
    assert.equal(after[2].text, "third");
  },

  "TP-3 appendItem preserves a plain non-task line verbatim"() {
    const raw = "## My notes\n- [ ] 2026-08-01 09:00 task\n";
    const after = M.appendItem(M.parseInbox(raw), "new");
    const header = after.find((i) => i.text === "## My notes");
    assert.ok(header, "plain header line must survive");
    assert.equal(header.isTask, false);
  },

  "TP-4 round-trip keeps new item present and old items intact"() {
    const raw = "- [ ] 2026-08-01 09:00 old\n";
    const out = M.serializeInbox(M.appendItem(M.parseInbox(raw), "buy milk"));
    const reparsed = M.parseInbox(out);
    assert.ok(reparsed.some((i) => i.text === "old" && i.isTask));
    assert.ok(reparsed.some((i) => i.text === "buy milk" && i.isTask && !i.checked));
  },

  "TP-5 appended timestamp reads back as a timestamp, not absorbed into text"() {
    const out = M.serializeInbox(M.appendItem(M.parseInbox(""), "buy milk"));
    const it = M.parseInbox(out).find((i) => i.text === "buy milk");
    assert.ok(it, "appended item must reparse");
    assert.match(it.timestamp, TS_RE, "timestamp field must be populated");
    assert.ok(it.displayTime, "displayTime must be set (timestamp recognized)");
  },

  "TP-6 empty or whitespace text returns items unchanged"() {
    const before = M.parseInbox("- [ ] 2026-08-01 09:00 keep\n");
    assert.equal(M.appendItem(before, "").length, 1);
    assert.equal(M.appendItem(before, "   ").length, 1);
  },

  "TP-7 multiline capture: first line is text, rest is indented extra"() {
    const it = M.appendItem(M.parseInbox(""), "line one\nline two\nline three")[0];
    assert.equal(it.text, "line one");
    assert.equal(it.extra, "line two\nline three");
    // round-trip: continuation lines come back as extra, not new items
    const reparsed = M.parseInbox(M.serializeInbox([it]));
    assert.equal(reparsed.length, 1);
    assert.equal(reparsed[0].extra, "line two\nline three");
  },
};

let failed = 0;
for (const [name, fn] of Object.entries(tests)) {
  try {
    fn();
    console.log("PASS  " + name);
  } catch (e) {
    failed++;
    console.log("FAIL  " + name + "\n      " + e.message.split("\n")[0]);
  }
}
console.log(`\n${Object.keys(tests).length - failed} passed, ${failed} failed`);
process.exit(failed ? 1 : 0);
