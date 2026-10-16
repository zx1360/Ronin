import { ref, computed, watch, onMounted, onUnmounted } from '../../vue.js';
import { confirmAction, toast } from '../../store.js';
import { useUserData, clone, day, stamp, labelTree, hiddenLabels, descendants } from '../user-data.js';
import { draftStore } from './drafts.js';

const hiddenID = '00000000-0000-4000-8000-000000000001';
const editable = (e) => JSON.stringify([e.date, e.title, e.content, e.labels, e.imgs, e.mood]);

export function useEssayBoard() {
  const board = useUserData('essay'), { data, save, busy } = board;
  const tab = ref('browse'), query = ref(''), year = ref(''), labelFilter = ref(''), sort = ref('descending'), showHidden = ref(false), limit = ref(20), detailId = ref('');
  const labels = computed(() => labelTree(data.value.labels));
  const hidden = computed(() => hiddenLabels(data.value.labels));
  const visible = computed(() => data.value.essays.filter((e) => showHidden.value || !e.labels.some((id) => hidden.value.has(id))));
  const years = computed(() => [...new Set(visible.value.map((e) => new Date(e.date).getFullYear().toString()))].sort().reverse());
  const searchIndex = computed(() => new Map(visible.value.map((e) => [e.id, [e.title, e.content, ...e.messages.map((m) => m.content)].join('\n').toLocaleLowerCase()])));
  const filtered = computed(() => {
    const terms = query.value.trim().toLocaleLowerCase().split(/\s+/).filter(Boolean);
    const ids = labelFilter.value ? descendants(data.value.labels, labelFilter.value) : null;
    return visible.value.filter((e) => (!year.value || new Date(e.date).getFullYear().toString() === year.value) && (!ids || e.labels.some((id) => ids.has(id))) && terms.every((term) => searchIndex.value.get(e.id).includes(term))).sort((a, b) => (sort.value === 'ascending' ? 1 : -1) * (Date.parse(a.date) - Date.parse(b.date)));
  });
  const page = computed(() => filtered.value.slice(0, limit.value));
  const detail = computed(() => visible.value.find((e) => e.id === detailId.value));
  watch([query, year, labelFilter, showHidden, sort], () => { limit.value = 20; });
  const labelName = (id) => labels.value.find((l) => l.id === id)?.path || '已删除标签';
  const labelCount = (id) => data.value.essays.filter((e) => e.labels.includes(id)).length;

  const drafts = ref([]), draftError = ref(''), editor = ref(null), original = ref(null), draftStatus = ref(''), preview = ref(false), files = ref(new Map()), publishing = ref(false);
  let timer, draftWrites = Promise.resolve(), disposed = false, pending = false, revision = 0;
  async function loadDrafts() {
    try { drafts.value = (await draftStore('getAll')).sort((a, b) => b.saved_at - a.saved_at); draftError.value = ''; }
    catch (e) { draftError.value = `无法读取本机草稿：${e.message}`; }
  }
  function persist() {
    clearTimeout(timer);
    if (!editor.value) return draftWrites.then(() => true);
    const essay = clone(editor.value), savedRevision = revision;
    if (!essay.title.trim() && !essay.content.trim() && !essay.imgs.length && !essay.labels.length && !essay.mood) { pending = false; return Promise.resolve(true); }
    const refs = new Set(essay.imgs.map((path) => path.split('/').pop()));
    const snapshot = { id: essay.id, essay, original: clone(original.value), files: [...files.value].filter(([name]) => refs.has(name)), saved_at: Date.now() };
    const run = draftWrites.then(() => draftStore('put', snapshot));
    draftWrites = run.catch(() => {});
    return run.then(async () => { if (revision === savedRevision) { pending = false; draftStatus.value = '草稿已存本机'; } if (!disposed) await loadDrafts(); return true; }, (e) => { draftStatus.value = `草稿保存失败：${e.message}`; return false; });
  }
  watch(editor, () => {
    if (!editor.value) return;
    revision++; pending = true; draftStatus.value = '正在保存草稿…';
    clearTimeout(timer); timer = setTimeout(persist, 500);
  }, { deep: true });
  async function openEditor(row = null, draft = null) {
    if (!await persist()) return;
    original.value = clone(draft?.original || row);
    files.value = new Map(draft?.files || []);
    editor.value = clone(draft?.essay || row || { id: crypto.randomUUID(), date: new Date().toISOString(), title: '', content: '', imgs: [], labels: [], messages: [], mood: null, word_count: 0 });
    preview.value = false;
  }
  async function closeEditor() { if (await persist()) editor.value = null; }
  async function discardDraft(draft) {
    if (!await confirmAction('丢弃这份本机草稿及草稿图片？', { danger: true })) return;
    if (editor.value?.id === draft.id) { clearTimeout(timer); editor.value = null; pending = false; }
    await draftWrites;
    try { await draftStore('delete', draft.id); await loadDrafts(); } catch (e) { toast(e.message, 'error'); }
  }
  async function publish() {
    if (publishing.value || busy.value || board.loading.value) return;
    publishing.value = true;
    try {
      if (!editor.value.content.trim() || !editor.value.labels.length || editor.value.labels.length > 4) { toast('正文不能为空，请选择 1 至 4 个标签', 'error'); return; }
      if (!await persist()) return;
      await board.refresh();
      if (board.error.value) return;
      const current = data.value.essays.find((e) => e.id === editor.value.id);
      if (original.value && (!current || editable(current) !== editable(original.value))) { toast('原随笔已被另一端修改或删除，草稿已保留，请核对原文；也可另存为新随笔', 'error'); return; }
      const essay = clone(editor.value);
      essay.title = essay.title.trim(); essay.content = essay.content.trim(); essay.word_count = essay.content.length;
      essay.messages = current?.messages || essay.messages;
      essay.updated_at = stamp(current || essay);
      const refs = new Set(essay.imgs.map((path) => path.split('/').pop()));
      if (await save({ essays: [essay] }, new Map([...files.value].filter(([name]) => refs.has(name))))) {
        clearTimeout(timer); editor.value = null;
        await draftWrites;
        try { await draftStore('delete', essay.id); await loadDrafts(); } catch (e) { toast(`随笔已保存，草稿清理失败：${e.message}`, 'warning'); }
        detailId.value = essay.id; tab.value = 'browse'; toast('随笔已保存', 'success');
      }
    } finally { publishing.value = false; }
  }

  async function saveAsNew() {
    if (!await persist()) return;
    editor.value.id = crypto.randomUUID(); editor.value.date = new Date().toISOString(); editor.value.messages = [];
    original.value = null;
    toast('已建立新草稿，原草稿仍保留');
  }
  async function removeEssay(row) {
    if (!await confirmAction(`删除随笔「${row.title || '无标题'}」？`, { danger: true })) return;
    if (await save({ tombstones: [{ collection: 'essays', id: row.id, updated_at: stamp(row) }] })) { detailId.value = ''; toast('随笔已删除', 'success'); }
  }
  const message = ref('');
  async function appendMessage() {
    if (!message.value.trim() || !detail.value) return;
    const row = clone(detail.value);
    row.messages.push({ timestamp: new Date().toISOString(), content: message.value.trim() }); row.updated_at = stamp(row);
    if (await save({ essays: [row] })) { message.value = ''; toast('留言已添加', 'success'); }
  }
  function toggleLabel(id) {
    const selected = editor.value.labels;
    if (selected.includes(id)) editor.value.labels = selected.filter((value) => value !== id);
    else if (selected.length < 4) selected.push(id);
    else toast('最多选择 4 个标签', 'warning');
  }
  const labelForm = ref(null);
  function editLabel(label = null) { labelForm.value = label ? clone(label) : { id: crypto.randomUUID(), name: '', parent_id: null, essay_count: 0 }; }
  const parentOptions = computed(() => labels.value.filter((l) => !descendants(data.value.labels, labelForm.value?.id).has(l.id)));
  async function saveLabel() {
    const row = clone(labelForm.value);
    row.name = row.name.trim(); row.parent_id ||= null;
    if (!row.name) { toast('标签名称不能为空', 'error'); return; }
    if (data.value.labels.some((l) => l.id !== row.id && l.name === row.name && l.parent_id === row.parent_id)) { toast('同级标签已存在', 'error'); return; }
    row.updated_at = stamp(row);
    if (await save({ labels: [row] })) { labelForm.value = null; toast('标签已保存', 'success'); }
  }
  const protectedLabel = (l) => l.id === hiddenID || (l.name === '隐藏' && !l.parent_id);
  async function removeLabel(label) {
    await loadDrafts();
    if (draftError.value || protectedLabel(label) || data.value.labels.some((l) => l.parent_id === label.id) || labelCount(label.id) || drafts.value.some((d) => d.essay.labels.includes(label.id))) { toast('只能删除未被随笔或草稿使用、没有子标签的普通标签', 'error'); return; }
    if (!await confirmAction(`删除标签「${label.path}」？`, { danger: true })) return;
    if (await save({ tombstones: [{ collection: 'labels', id: label.id, updated_at: stamp(label) }] })) toast('标签已删除', 'success');
  }
  const stats = computed(() => {
    const rows = filtered.value, counts = new Map(), moods = new Map(), months = new Map();
    for (const e of rows) {
      for (const id of e.labels) counts.set(id, (counts.get(id) || 0) + 1);
      if (e.mood) moods.set(e.mood, (moods.get(e.mood) || 0) + 1);
      const key = day(new Date(e.date)).slice(0, 7); months.set(key, (months.get(key) || 0) + 1);
    }
    return { count: rows.length, words: rows.reduce((n, e) => n + e.word_count, 0), days: new Set(rows.map((e) => day(new Date(e.date)))).size,
      months: [...months].sort(([a],[b]) => a.localeCompare(b)), labels: [...counts].sort((a,b) => b[1]-a[1]), moods: [...moods] };
  });
  const seen = new Set();
  function reread() {
    const pool = data.value.essays.filter((e) => !e.labels.some((id) => hidden.value.has(id)) && day(new Date(e.date)) < day());
    if (!pool.length) { toast('还没有今天以前可回读的随笔'); return; }
    if (pool.every((e) => seen.has(e.id))) { seen.clear(); if (pool.length > 1) seen.add(detailId.value); }
    const available = pool.filter((e) => !seen.has(e.id));
    const anniversary = available.filter((e) => day(new Date(e.date)).slice(5) === day().slice(5));
    const candidates = anniversary.length ? anniversary : available;
    const picked = candidates[Math.floor(Math.random() * candidates.length)];
    seen.add(picked.id); detailId.value = picked.id; tab.value = 'browse';
  }
  const beforeUnload = (event) => { if (pending) { event.preventDefault(); event.returnValue = ''; } };
  onMounted(() => { loadDrafts(); window.addEventListener('beforeunload', beforeUnload); });
  onUnmounted(() => { disposed = true; persist(); clearTimeout(timer); window.removeEventListener('beforeunload', beforeUnload); });
  return { ...board, busy: computed(() => busy.value || publishing.value), tab, query, year, years, labelFilter, sort, showHidden, filtered, page, limit, detailId, detail, labels, labelName, labelCount,
    drafts, draftError, loadDrafts, editor, original, draftStatus, preview, files, openEditor, closeEditor, discardDraft, publish, saveAsNew, removeEssay,
    message, appendMessage, toggleLabel, labelForm, editLabel, parentOptions, saveLabel, protectedLabel, removeLabel, stats, reread };
}
