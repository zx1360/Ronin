const uuid = /^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/i;

/** 整批验证后返回新快照；调用方成功应用后才能推进游标。 */
export function applySyncDelta(module, current, payload, after) {
  const names = module === 'essay' ? ['labels', 'essays'] : ['styles', 'records'];
  if (payload?.sync_version !== 2) throw new Error('请先更新后端以支持增量合并');
  if (!Number.isSafeInteger(payload.cursor) || payload.cursor < after || payload.cursor < 0) throw new Error('同步游标无效');
  if (!Array.isArray(payload.tombstones)) throw new Error('删除标记无效');
  const validRow = (row) => row && uuid.test(row.id) && Number.isFinite(Date.parse(row.updated_at));
  for (const name of names) {
    const rows = payload[name];
    if (!Array.isArray(rows) || rows.some((row) => !validRow(row)) || new Set(rows.map((row) => row.id)).size !== rows.length) throw new Error('同步数据 ID 或更新时间无效');
  }
  if (payload.tombstones.some((row) => !validRow(row) || !names.includes(row.collection))) throw new Error('删除标记无效');
  const data = {};
  for (const name of names) {
    const rows = new Map(after ? current[name].map((row) => [row.id, row]) : []);
    for (const row of payload[name]) rows.set(row.id, row);
    for (const item of payload.tombstones) {
      if (item.collection === name && (!rows.has(item.id) || Date.parse(rows.get(item.id).updated_at) <= Date.parse(item.updated_at))) rows.delete(item.id);
    }
    data[name] = [...rows.values()];
  }
  return { data, cursor: payload.cursor };
}
