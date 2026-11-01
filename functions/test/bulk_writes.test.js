const assert = require("node:assert/strict");
const test = require("node:test");

const {commitBulkWrites} = require("../lib/bulk_writes");

test("commitBulkWrites closes the writer and resolves after every write", async () => {
  let closed = false;
  const writer = {
    close: async () => {
      closed = true;
    },
  };

  await commitBulkWrites(writer, [Promise.resolve(), Promise.resolve()]);

  assert.equal(closed, true);
});

test("commitBulkWrites rejects when one write fails even though close resolves", async () => {
  let closed = false;
  const writer = {
    close: async () => {
      closed = true;
    },
  };

  await assert.rejects(
    commitBulkWrites(writer, [
      Promise.resolve(),
      Promise.reject(new Error("write failed")),
    ]),
    /write failed/,
  );
  assert.equal(closed, true);
});
