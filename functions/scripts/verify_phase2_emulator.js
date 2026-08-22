const assert = require("node:assert/strict");

const host = process.env.FIRESTORE_EMULATOR_HOST;
if (!host) {
  throw new Error("verify:phase2:emulator 只能在 Firestore Emulator 中執行。");
}

const baseUrl =
  `http://${host}/v1/projects/food-9a095/databases/(default)/documents`;

async function verify() {
  const activeRestaurant = await fetch(`${baseUrl}/restaurants/island-tea-lab`);
  assert.equal(activeRestaurant.status, 200);

  const mergedRestaurant = await fetch(
    `${baseUrl}/restaurants/old-island-tea-lab`,
  );
  assert.equal(mergedRestaurant.status, 200);

  const removedRestaurant = await fetch(
    `${baseUrl}/restaurants/removed-seed-restaurant`,
  );
  assert.equal(removedRestaurant.status, 403);

  const unconstrainedList = await fetch(`${baseUrl}/restaurants?pageSize=20`);
  assert.equal(unconstrainedList.status, 403);

  const activeQuery = await fetch(`${baseUrl}:runQuery`, {
    method: "POST",
    headers: {"content-type": "application/json"},
    body: JSON.stringify({
      structuredQuery: {
        from: [{collectionId: "restaurants"}],
        where: {
          fieldFilter: {
            field: {fieldPath: "status"},
            op: "EQUAL",
            value: {stringValue: "active"},
          },
        },
        orderBy: [
          {
            field: {fieldPath: "createdAt"},
            direction: "DESCENDING",
          },
        ],
        limit: 20,
      },
    }),
  });
  assert.equal(activeQuery.status, 200);
  const queryResults = await activeQuery.json();
  const documents = queryResults.filter((result) => result.document);
  assert.equal(documents.length, 10);

  const photo = await fetch(
    `${baseUrl}/restaurants/island-tea-lab/photos/seed-photo-one`,
  );
  assert.equal(photo.status, 200);

  const review = await fetch(
    `${baseUrl}/restaurants/island-tea-lab/reviews/seed-reviewer-one`,
  );
  assert.equal(review.status, 200);

  const forbiddenWrite = await fetch(
    `${baseUrl}/restaurants/forbidden-client-write`,
    {
      method: "PATCH",
      headers: {"content-type": "application/json"},
      body: JSON.stringify({
        fields: {
          name: {stringValue: "不應建立"},
          status: {stringValue: "active"},
        },
      }),
    },
  );
  assert.equal(forbiddenWrite.status, 403);

  process.stdout.write(
    "Phase 2 Emulator seed data and readonly rules verified.\n",
  );
}

verify().catch((error) => {
  process.stderr.write(`${error.stack ?? error}\n`);
  process.exitCode = 1;
});
