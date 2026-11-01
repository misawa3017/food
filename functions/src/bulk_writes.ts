import type {BulkWriter} from "firebase-admin/firestore";

/**
 * 送出批次寫入並等待每一筆的結果。
 *
 * `BulkWriter.close()` 不會因單筆寫入失敗而 reject，只檢查它會把失敗當成成功，
 * 因此必須同時等待每筆寫入回傳的 Promise。
 */
export async function commitBulkWrites(
  writer: Pick<BulkWriter, "close">,
  writes: Promise<unknown>[],
): Promise<void> {
  await Promise.all([...writes, writer.close()]);
}
