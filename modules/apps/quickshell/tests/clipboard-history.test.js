const assert = require("node:assert/strict")
const historyModel = require("../config/ClipboardHistory.js")

assert.deepEqual(historyModel.normalizeEntry(" hello "), { type: "text", text: " hello " })
assert.equal(historyModel.normalizeEntry(" \n\t "), null)
assert.deepEqual(historyModel.normalizeEntry({ kind: "image", path: "/tmp/a.png" }), {
  type: "image",
  path: "/tmp/a.png",
  mime: "image/png"
})
assert.deepEqual(historyModel.normalizeEntry({ type: "text", text: "saved", id: "text-1" }), {
  type: "text",
  text: "saved",
  id: "text-1"
})
assert.deepEqual(
  historyModel.normalizeEntry({ type: "image", path: "/tmp/a.jpg", mime: "image/jpeg", capturedAt: "Friday 14:42" }),
  { type: "image", path: "/tmp/a.jpg", mime: "image/jpeg", capturedAt: "Friday 14:42" }
)

assert.deepEqual(historyModel.parseHistory("not json"), [])
assert.deepEqual(historyModel.parseHistory("{}"), [])
assert.equal(historyModel.isValidHistory("not json"), false)
assert.equal(historyModel.isValidHistory("{}"), false)
assert.equal(historyModel.isValidHistory("[]"), true)
assert.deepEqual(
  historyModel.parseHistory(JSON.stringify(["one", " ", null, { type: "text", text: "two" }, { type: "unknown" }])),
  [{ type: "text", text: "one" }, { type: "text", text: "two" }]
)
assert.equal(historyModel.parseEntryJson("{"), null)

const history = [
  { type: "text", text: "old", id: "old-id" },
  { type: "text", text: "new", id: "new-id" },
  { type: "image", path: "/tmp/a.png", mime: "image/png", id: "image-id" }
]
const recopied = { type: "text", text: "new", id: "new-copy-id" }
assert.deepEqual(historyModel.addEntry(history, recopied, 100), [recopied, history[0], history[2]])
assert.deepEqual(historyModel.addEntry(history, "New", 2), [
  { type: "text", text: "New" },
  history[0]
])
assert.deepEqual(historyModel.addEntry(history, "next", 0), [])
assert.deepEqual(historyModel.removeEntryAt(history, 1), [history[0], history[2]])
assert.deepEqual(historyModel.removeEntryAt(history, 20), history)
assert.deepEqual(historyModel.clearHistory(), [])

const imageRow = historyModel.displayRows([
  { type: "image", path: "/tmp/a.png", mime: "image/png", capturedAt: "Friday 14:42" }
], "friday", 50)[0]
assert.deepEqual(imageRow, {
  entryType: "image",
  fullText: "",
  previewText: "Screenshot from Friday 14:42",
  previewImage: "/tmp/a.png",
  path: "/tmp/a.png",
  mime: "image/png",
  id: undefined,
  index: 0
})

const fileRow = historyModel.displayRows([
  { type: "text", text: "file://localhost/home/me/My%20Image.gif\n" }
], "my image", 50)[0]
assert.deepEqual(fileRow, {
  entryType: "file",
  fullText: "/home/me/My Image.gif",
  previewText: "My Image.gif",
  previewImage: "/home/me/My Image.gif",
  path: "/home/me/My Image.gif",
  mime: "text/plain",
  id: undefined,
  index: 0
})
assert.equal(historyModel.displayRows([
  { type: "text", text: "file:///one.txt\nfile:///two.txt\n" }
], "2 files", 50)[0].previewText, "2 files")
assert.equal(historyModel.displayRows([
  { type: "text", text: "file:///demo.mp4\n" }
], "", 50)[0].previewImage, "")
assert.deepEqual(historyModel.filePaths({ type: "text", text: "file:///bad%ZZ\nfile://remote/a" }), ["/bad%ZZ"])

const indexedRows = historyModel.displayRows(history, "image", 50)
assert.deepEqual(indexedRows.map(row => row.index), [2])
assert.equal(historyModel.displayRows([{ type: "text", text: "line one\nline two" }], "", 50)[0].previewText, "line one line two")
assert.equal(historyModel.displayRows(history, "", 2).length, 2)
assert.deepEqual(historyModel.displayRows(history, "", 0), [])

const hugeText = "a".repeat(8192) + "needle"
assert.deepEqual(historyModel.displayRows([{ type: "text", text: hugeText }], "needle", 50), [])
const hugeRow = historyModel.displayRows([{ type: "text", text: "needle" + "z".repeat(100000) }], "needle", 50)[0]
assert.equal(hugeRow.index, 0)
assert.equal(hugeRow.fullText.length, 8192)
assert.equal(hugeRow.previewText.length, 8192)

const fileUris = []
for (let index = 0; index < 5000; index++) fileUris.push(`file:///tmp/clip-${index}.mp4`)
const hugeFileRow = historyModel.displayRows([{ type: "text", text: fileUris.join("\n") + "\n" }], "", 50)[0]
assert.equal(hugeFileRow.entryType, "file")
assert(hugeFileRow.fullText.split("\n").every(path => path.endsWith(".mp4")))

console.log("clipboard history tests passed")
