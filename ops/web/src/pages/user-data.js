import { ref, onMounted } from 'vue';
import { useApi, assetUrl } from '../api.js';
import { toast } from '../store.js';
import { applySyncDelta } from './user-data-sync.js';

export const moods = [
  { value: 'happy', label: '🥳 开心' }, { value: 'calm', label: '😌 平静' },
  { value: 'sad', label: '😢 难过' }, { value: 'angry', label: '😤 生气' }, { value: 'tired', label: '😴 疲惫' },
];
export const moodText = (value) => moods.find((m) => m.value === value)?.label || '';
export const clone = (value) => JSON.parse(JSON.stringify(value));
export const day = (date = new Date()) => `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
export const stamp = (row) => new Date(Math.max(Date.now(), Date.parse(row?.updated_at || '') + 1 || 0)).toISOString();
export const imageUrl = (path) => {
  const relative = path?.replace(/^\//, '');
  return relative?.startsWith('img_storage/') ? assetUrl('/static/' + relative.split('/').map(encodeURIComponent).join('/')) : '';
};

export function useUserData(module) {
  const api = useApi();
  const names = module === 'essay' ? ['labels', 'essays'] : ['styles', 'records'];
  const data = ref(Object.fromEntries(names.map((name) => [name, []])));
  const loading = ref(false), busy = ref(false), error = ref('');
  let cursor = 0;
  async function pull() {
    let result;
    const path = `/API/user-data/sync/${module}?sync_version=2`;
    try {
      result = await api.get(`${path}&after=${cursor}`);
    } catch (e) {
      if (!cursor || e.status !== 409) throw e;
      cursor = 0;
      result = await api.get(path);
    }
    if (api.signal.aborted) return;
    const next = applySyncDelta(module, data.value, result, cursor);
    data.value = next.data;
    cursor = next.cursor;
  }
  async function refresh() {
    if (api.signal.aborted || loading.value || busy.value) return;
    loading.value = true;
    error.value = '';
    try { await pull(); } catch (e) {
      if (!api.signal.aborted) error.value = e.message;
    }
    finally { loading.value = false; }
  }
  async function save(changes, files = new Map(), { checkLabels = true, baseCursor = cursor } = {}) {
    if (api.signal.aborted || busy.value || loading.value) return false;
    busy.value = true;
    error.value = '';
    try {
      const payload = { sync_version: 2, ...changes, base_cursor: baseCursor };
      let body = payload;
      if (files.size) {
        body = new FormData();
        body.append('jsonData', JSON.stringify(payload));
        for (const [name, file] of files) body.append('files', file, name);
      }
      const essays = changes.essays || [];
      const response = await api.post(`/API/user-data/edit/${module}${essays.length ? '?receipt=1' : ''}`, body);
      await pull();
      if (api.signal.aborted) return false;
      if (essays.length) {
        const receipts = response?.essay_receipts;
        const results = essays.map((row) => Array.isArray(receipts) && receipts.find((item) => item?.id === row.id));
        if (results.some((item) => typeof item?.content_saved !== 'boolean' || typeof item?.labels_saved !== 'boolean')) {
          throw new Error('服务器未确认随笔合并结果，请更新后端并核对草稿');
        }
        if (results.some((item) => !item.content_saved || (checkLabels && !item.labels_saved))) {
          const contentSaved = results.every((item) => item.content_saved);
          toast(contentSaved ? '正文已保存，标签有冲突，草稿已保留' : '正文有冲突，请核对另一端的版本', 'warning');
          return false;
        }
      }
      const accepted = names.filter((name) => name !== 'essays').every((name) => (changes[name] || []).every((row) => data.value[name].some((current) => current.id === row.id && Date.parse(current.updated_at) === Date.parse(row.updated_at))))
        && (changes.tombstones || []).every((item) => !data.value[item.collection].some((row) => row.id === item.id));
      if (!accepted) toast('另一端已有更新版本，请刷新编辑内容后重试', 'warning');
      return accepted;
    } catch (e) {
      if (api.signal.aborted) return false;
      error.value = e.status === 404 ? '后端尚不支持安全在线编辑，请更新并重启 Monarch 后再保存' : e.message;
      toast(error.value, 'error');
      return false;
    }
    finally { busy.value = false; }
  }
  onMounted(refresh);
  return { data, loading, busy, error, refresh, save, snapshotCursor: () => cursor };
}

export function labelTree(labels) {
  const byID = new Map(labels.map((l) => [l.id, l]));
  const path = (label) => {
    const names = [], seen = new Set();
    for (let row = label; row && !seen.has(row.id); row = byID.get(row.parent_id)) { seen.add(row.id); names.unshift(row.name); }
    return names.join(' / ');
  };
  return [...labels].map((l) => ({ ...l, path: path(l) })).sort((a, b) => a.path.localeCompare(b.path, 'zh-CN'));
}

export function descendants(labels, root) {
  if (!root) return new Set();
  const children = new Map();
  for (const label of labels) {
    const siblings = children.get(label.parent_id);
    if (siblings) siblings.push(label.id);
    else children.set(label.parent_id, [label.id]);
  }
  const ids = new Set([root]);
  for (const id of ids) {
    for (const child of children.get(id) || []) ids.add(child);
  }
  return ids;
}

export const hiddenLabels = (labels) => new Set(labels.filter((l) => l.id === '00000000-0000-4000-8000-000000000001' || (l.name === '隐藏' && !l.parent_id)).flatMap((l) => [...descendants(labels, l.id)]));
