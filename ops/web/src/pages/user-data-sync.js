const uuid = /^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/i;
export const syncVersion = 2;
export const syncCollections = (module) => module === 'essay' ? ['labels', 'essays'] : ['styles', 'records'];

<<<<<<< HEAD
// 在完整应用增量前，调用方持有的快照和游标都不变。
export function applySyncDelta(module, current, payload, after) {
  const names = syncCollections(module);
  if (payload?.sync_version !== syncVersion) throw new Error('请先更新后端以支持增量合并');
=======
export const collectionsFor = (module) =>
  module === 'essay' ? ['labels', 'essays'] : ['styles', 'records'];

// 整批验证后应用，再由调用方推进游标。
export function applySyncDelta(module, current, payload, after) {
  const names = collectionsFor(module);
  if (payload?.sync_version !== 2) throw new Error('请先更新后端以支持增量合并');
>>>>>>> 1fc83d9 (重构瘦身+分发性.)
  if (!Number.isSafeInteger(payload.cursor) || payload.cursor < after || payload.cursor < 0) throw new Error('同步游标无效');
  if (!Array.isArray(payload.tombstones)) throw new Error('删除标记无效');
  const validRow = (row) => row && uuid.test(row.id) && Number.isFinite(Date.parse(row.updated_at));
  const byCollection = new Map();
  for (const name of names) {
    if (!Array.isArray(payload[name])) throw new Error('同步数据 ID 或更新时间无效');
    const rows = new Map(after ? current[name].map((row) => [row.id, row]) : []);
    const seen = new Set();
    for (const row of payload[name]) {
      if (!validRow(row) || seen.has(row.id)) throw new Error('同步数据 ID 或更新时间无效');
      seen.add(row.id);
      rows.set(row.id, row);
    }
    byCollection.set(name, rows);
  }
  for (const item of payload.tombstones) {
    const rows = byCollection.get(item?.collection);
    if (!rows || !validRow(item)) throw new Error('删除标记无效');
    const row = rows.get(item.id);
    if (row && Date.parse(row.updated_at) <= Date.parse(item.updated_at)) rows.delete(item.id);
  }
  const data = Object.fromEntries([...byCollection].map(([name, rows]) => [name, [...rows.values()]]));
  return { data, cursor: payload.cursor };
}
