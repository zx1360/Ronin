import { readFileSync } from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';

const read = (path) => JSON.parse(readFileSync(new URL(path, import.meta.url), 'utf8'));
const load = (path) => import(`data:text/javascript;base64,${readFileSync(new URL(path, import.meta.url)).toString('base64')}`);
const { applySyncDelta } = await load('../web/src/pages/user-data-sync.js');
const { mergeProgress } = await load('../web/src/pages/ai/state.js');
const fixture = read('../../contracts/user_data.json');

for (const item of fixture.merge_cases) {
  test(item.name, () => {
    const deletions = [...item.server.tombstones, ...item.client.tombstones].sort((a, b) => Date.parse(b.updated_at) - Date.parse(a.updated_at));
    const response = { sync_version: 2, cursor: 2, labels: item.expected ? [item.expected] : [], essays: [], tombstones: item.expected ? [] : deletions.slice(0, 1) };
    const before = JSON.stringify(item.server);
    const result = applySyncDelta('essay', item.server, response, 1);
    assert.deepEqual(result.data.labels, response.labels);
    assert.equal(result.cursor, 2);
    assert.equal(JSON.stringify(item.server), before);
    assert.deepEqual(applySyncDelta('essay', result.data, response, 2), result);
  });
}
test('整批验证失败不改变数据或游标', () => {
  const current = { data: fixture.merge_cases[0].server, cursor: 1 };
  const before = JSON.stringify(current);
  for (const change of [{ cursor: -1 }, { cursor: 0 }, { cursor: 1.5 }, { labels: null }, { essays: [{ id: fixture.id, updated_at: 'bad' }] }, { labels: [current.data.labels[0], current.data.labels[0]] }, { tombstones: [{ id: fixture.id, collection: 'wrong', updated_at: '2026-01-01T00:00:00Z' }] }]) {
    assert.throws(() => { Object.assign(current, applySyncDelta('essay', current.data, { ...current.data, ...change }, current.cursor)); });
    assert.equal(JSON.stringify(current), before);
  }
});
test('完整读取清除旧缓存', () => {
  const result = applySyncDelta('essay', fixture.merge_cases[0].server, { sync_version: 2, cursor: 0, labels: [], essays: [], tombstones: [] }, 0);
  assert.deepEqual(result.data, { labels: [], essays: [] });
});
test('进度更新保留诊断、模型与就绪信息', () => {
  const { diagnostics, progress } = read('../../contracts/ai.json');
  const result = mergeProgress(diagnostics, progress);
  assert.equal(result.media_total, 100);
  assert.equal(result.person_count, 7);
  assert.equal(result.capabilities[0].ready, true);
  assert.equal(result.capabilities[0].missing_media, 9);
  assert.equal(result.capabilities[0].pending, 4);
  assert.equal(result.capabilities[0].done, 80);
  assert.equal(result.capabilities[0].sidecar.probe_ok, true);
  assert.equal(result.capabilities[0].sidecar.running, true);
  assert.equal(result.ollama.model_ready, true);
  assert.equal(result.ollama.active_model, progress.ollama.active_model);
  assert.deepEqual(mergeProgress(result, progress), result);
});
