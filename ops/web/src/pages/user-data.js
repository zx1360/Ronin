import { ref, onMounted, onUnmounted } from '../vue.js';
import { api, assetUrl } from '../api.js';
import { toast } from '../store.js';

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
  const names = module === 'essay' ? ['labels', 'essays'] : ['styles', 'records'];
  const data = ref(Object.fromEntries(names.map((name) => [name, []])));
  const loading = ref(false), busy = ref(false), error = ref('');
  let cursor = 0, disposed = false;
  const controller = new AbortController();
  async function pull() {
    let result;
    const path = `/API/user-data/sync/${module}?sync_version=2`;
    try {
      result = await api.get(`${path}&after=${cursor}`, { signal: controller.signal });
    } catch (e) {
      if (!cursor || e.status !== 409) throw e;
      cursor = 0;
      result = await api.get(path, { signal: controller.signal });
    }
    if (result?.sync_version !== 2) throw new Error('请先更新后端以支持增量合并');
    if (disposed) return;
    for (const name of names) {
      const rows = new Map(cursor ? data.value[name].map((row) => [row.id, row]) : []);
      for (const row of result[name]) rows.set(row.id, row);
      for (const item of result.tombstones) {
        if (item.collection === name && (!rows.has(item.id) || Date.parse(rows.get(item.id).updated_at) <= Date.parse(item.updated_at))) rows.delete(item.id);
      }
      data.value[name] = [...rows.values()];
    }
    cursor = result.cursor;
  }
  async function refresh() {
    if (loading.value || busy.value) return;
    loading.value = true;
    error.value = '';
    try { await pull(); } catch (e) { if (!disposed) error.value = e.message; }
    finally { loading.value = false; }
  }
  async function save(changes, files = new Map()) {
    if (busy.value || loading.value) return false;
    busy.value = true;
    error.value = '';
    try {
      const payload = { sync_version: 2, ...changes };
      let body = payload;
      if (files.size) {
        body = new FormData();
        body.append('jsonData', JSON.stringify(payload));
        for (const [name, file] of files) body.append('files', file, name);
      }
      await api.post(`/API/user-data/sync/${module}`, body);
      await pull();
      const accepted = names.every((name) => (changes[name] || []).every((row) => data.value[name].some((current) => current.id === row.id && Date.parse(current.updated_at) === Date.parse(row.updated_at))))
        && (changes.tombstones || []).every((item) => !data.value[item.collection].some((row) => row.id === item.id));
      if (!accepted) toast('另一端已有更新版本，请刷新编辑内容后重试', 'warning');
      return accepted;
    } catch (e) { error.value = e.message; toast(e.message, 'error'); return false; }
    finally { busy.value = false; }
  }
  onMounted(refresh);
  onUnmounted(() => { disposed = true; controller.abort(); });
  return { data, loading, busy, error, refresh, save };
}

export const MoodSelect = {
  props: ['modelValue'], emits: ['update:modelValue'],
  setup: () => ({ moods }),
  template: `
    <select aria-label="心情" :value="modelValue || ''" @change="$emit('update:modelValue', $event.target.value || null)">
      <option value="">不记录心情</option>
      <option v-for="m in moods" :value="m.value">{{ m.label }}</option>
    </select>
  `,
};

export const ImagePicker = {
  props: { images: Array, files: Map, module: String, max: { default: 12 } },
  emits: ['update:images', 'file'],
  setup(props, { emit }) {
    const urls = new Map();
    const src = (path) => {
      const name = path.split('/').pop(), file = props.files?.get(name);
      if (!file) return imageUrl(path);
      if (!urls.has(file)) urls.set(file, URL.createObjectURL(file));
      return urls.get(file);
    };
    const pick = (event) => {
      const paths = [...props.images];
      for (const file of event.target.files) {
        if (paths.length >= props.max) break;
        if (!['image/jpeg', 'image/png', 'image/webp', 'image/gif'].includes(file.type)) { toast('请选择 JPG、PNG、WebP 或 GIF 图片', 'error'); continue; }
        const ext = { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp', 'image/gif': 'gif' }[file.type];
        const name = `${crypto.randomUUID()}.${ext}`;
        emit('file', { name, file });
        paths.push(`img_storage/${props.module}/${name}`);
      }
      emit('update:images', paths);
      event.target.value = '';
    };
    onUnmounted(() => { for (const url of urls.values()) URL.revokeObjectURL(url); });
    return { src, pick };
  },
  template: `
    <div class="col">
      <div class="user-images">
        <figure v-for="(path,i) in images" :key="path">
          <a :href="src(path)" target="_blank" rel="noopener">
            <img :src="src(path)" loading="lazy" alt="附件图片" />
          </a>
          <button type="button" class="sm danger" @click="$emit('update:images', images.filter((_,n)=>n!==i))">移除</button>
        </figure>
      </div>
      <label v-if="images.length < max" class="field">
        添加图片
        <input type="file" accept="image/jpeg,image/png,image/webp,image/gif" :multiple="max > 1" @change="pick" />
      </label>
    </div>
  `,
};

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
  const ids = new Set([root]);
  let size;
  do { size = ids.size; for (const l of labels) if (ids.has(l.parent_id)) ids.add(l.id); } while (size !== ids.size);
  return ids;
}

export const hiddenLabels = (labels) => new Set(labels.filter((l) => l.id === '00000000-0000-4000-8000-000000000001' || (l.name === '隐藏' && !l.parent_id)).flatMap((l) => [...descendants(labels, l.id)]));
