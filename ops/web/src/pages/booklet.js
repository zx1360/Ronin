import { ref, computed, watch } from '../vue.js';
import { Card, Placeholder } from '../ui.js';
import { confirmAction, toast } from '../store.js';
import { useUserData, MoodSelect, ImagePicker, day, stamp, clone, imageUrl, moodText } from './user-data.js';

function statistics(records) {
  let longest = 0, longestFull = 0, streak = 0, fullStreak = 0, full = 0, previous = '', previousFull = '';
  const complete = (r) => Object.values(r.task_completion).every(Boolean);
  const consecutive = (a, b) => Date.parse(b) - Date.parse(a) === 86400000;
  for (const row of [...records].sort((a, b) => a.date.localeCompare(b.date))) {
    streak = consecutive(previous, row.date) ? streak + 1 : 1;
    previous = row.date;
    longest = Math.max(longest, streak);
    if (complete(row)) {
      full++;
      fullStreak = consecutive(previousFull, row.date) ? fullStreak + 1 : 1;
      previousFull = row.date;
      longestFull = Math.max(longestFull, fullStreak);
    }
  }
  return { count: records.length, full, longest, longestFull };
}

export default {
  components: { Card, Placeholder, MoodSelect, ImagePicker },
  setup() {
    const board = useUserData('booklet');
    const { data, save } = board;
    const tab = ref('today'), date = ref(day()), form = ref(null), dirty = ref(false);
    const styles = computed(() => [...data.value.styles].sort((a, b) => b.start_date.localeCompare(a.start_date) || Date.parse(b.updated_at) - Date.parse(a.updated_at) || a.id.localeCompare(b.id)));
    const current = computed(() => styles.value.find((s) => s.start_date <= date.value));
    const selectedId = ref('');
    const selected = computed(() => styles.value.find((s) => s.id === selectedId.value) || styles.value[0]);
    const related = computed(() => data.value.records.filter((r) => r.style_id === selected.value?.id));
    const stats = computed(() => statistics(related.value));
    function loadRecord() {
      const style = current.value;
      const saved = data.value.records.find((r) => r.style_id === style?.id && r.date === date.value);
      form.value = style ? clone(saved || { id: crypto.randomUUID(), style_id: style.id, date: date.value, message: '', mood: null, task_completion: Object.fromEntries(style.tasks.map((t) => [t.id, false])) }) : null;
      dirty.value = false;
    }
    watch([date, () => current.value?.id], loadRecord);
    const progress = computed(() => current.value?.tasks.filter((t) => form.value?.task_completion[t.id]).length || 0);
    async function saveRecord() {
      if (!form.value) return;
      const row = clone(form.value);
      row.updated_at = stamp(row);
      const empty = !row.message.trim() && !row.mood && !Object.values(row.task_completion).some(Boolean);
      const payload = empty ? { tombstones: [{ collection: 'records', id: row.id, updated_at: row.updated_at }] } : { records: [row] };
      if (await save(payload)) { loadRecord(); toast(empty ? '已撤销这一天的打卡' : '打卡已保存', 'success'); }
    }
    const creating = ref(false), newStyle = ref(null), files = new Map();
    function addTask() {
      if (newStyle.value.tasks.length < 5) newStyle.value.tasks.push({ id: crypto.randomUUID(), title: '', description: '', image: '' });
    }
    function createStyle() {
      files.clear();
      newStyle.value = { id: crypto.randomUUID(), start_date: day(), valid_check_in: 0, fully_done: 0, longest_streak: 0, longest_fully_streak: 0, tasks: [] };
      addTask(); creating.value = true;
    }
    async function saveStyle() {
      const row = clone(newStyle.value);
      if (!row.tasks.every((t) => t.title.trim())) { toast('请填写每个任务的标题', 'error'); return; }
      const replaced = styles.value.filter((s) => s.start_date === day());
      const removed = data.value.records.filter((r) => r.date === day() || replaced.some((s) => s.id === r.style_id));
      if ((replaced.length || removed.length) && !await confirmAction(`今天已有 ${replaced.length} 套样式、${removed.length} 条打卡。创建新样式将替换它们，继续吗？`, { danger: true })) return;
      const updated = stamp([...replaced, ...removed].sort((a,b) => Date.parse(b.updated_at)-Date.parse(a.updated_at))[0]);
      row.updated_at = updated;
      const tombstones = [...replaced.map((s) => ({ collection: 'styles', id: s.id, updated_at: updated })), ...removed.map((r) => ({ collection: 'records', id: r.id, updated_at: updated }))];
      const refs = new Set(row.tasks.map((t) => t.image.split('/').pop()));
      if (await save({ styles: [row], tombstones }, new Map([...files].filter(([name]) => refs.has(name))))) {
        creating.value = false; date.value = day(); tab.value = 'today'; loadRecord(); toast('新样式已启用', 'success');
      }
    }
    async function removeStyle() {
      const style = selected.value;
      if (!style || !await confirmAction(`删除 ${style.start_date} 的样式及其 ${related.value.length} 条打卡记录？`, { danger: true })) return;
      const latest = [style, ...related.value].sort((a,b) => Date.parse(b.updated_at)-Date.parse(a.updated_at))[0];
      if (await save({ tombstones: [{ collection: 'styles', id: style.id, updated_at: stamp(latest) }] })) { loadRecord(); toast('样式已删除', 'success'); }
    }
    const month = ref(day().slice(0, 7)), taskFilter = ref('');
    watch(() => selected.value?.id, () => { taskFilter.value = ''; });
    function moveMonth(amount) {
      const d = new Date(`${month.value}-01T12:00:00`); d.setMonth(d.getMonth() + amount); month.value = day(d).slice(0, 7);
    }
    const calendar = computed(() => {
      const first = new Date(`${month.value}-01T12:00:00`), offset = (first.getDay() + 6) % 7;
      const byDate = new Map(related.value.map((record) => [record.date, record]));
      return Array.from({ length: 42 }, (_, i) => {
        const d = new Date(first); d.setDate(i - offset + 1);
        const key = day(d), record = byDate.get(key);
        const checked = record && (taskFilter.value ? !!record.task_completion[taskFilter.value] : Object.values(record.task_completion).every(Boolean));
        return { date: key, number: d.getDate(), outside: key.slice(0, 7) !== month.value, record, checked };
      });
    });
    const historyQuery = ref(''), historyStyle = ref(''), limit = ref(30);
    const history = computed(() => data.value.records.filter((r) => (!historyStyle.value || r.style_id === historyStyle.value) && (!historyQuery.value || r.message.toLowerCase().includes(historyQuery.value.toLowerCase()))).sort((a, b) => b.date.localeCompare(a.date)));
    watch([historyQuery, historyStyle], () => { limit.value = 30; });
    const visibleHistory = computed(() => history.value.slice(0, limit.value));
    const styleName = (id) => styles.value.find((s) => s.id === id)?.start_date || '已删除样式';
    const doneCount = (r) => Object.values(r.task_completion).filter(Boolean).length;
    function openDay(value) { date.value = value; tab.value = 'today'; loadRecord(); }
    const refresh = async () => { await board.refresh(); if (!dirty.value) loadRecord(); };
    return { ...board, refresh, tab, date, today: day(), form, dirty, styles, current, progress, loadRecord, saveRecord,
      selectedId, selected, related, stats, creating, newStyle, files, createStyle, addTask, saveStyle, removeStyle,
      month, moveMonth, taskFilter, calendar, historyQuery, historyStyle, history, visibleHistory, limit, styleName, doneCount, openDay, imageUrl, moodText };
  },
  template: `
    <div class="user-page">
      <div class="row between user-toolbar">
        <span class="muted">把日常的小事，积成看得见的变化。</span>
        <div class="row">
          <button :disabled="loading || busy" @click="refresh">刷新</button>
          <button class="primary" :disabled="loading || busy" @click="createStyle">新建样式</button>
        </div>
      </div>
      <Placeholder v-if="error" :error="error" />
      <div class="tabs">
        <button :class="{active:tab==='today'}" @click="tab='today'">每日打卡</button>
        <button :class="{active:tab==='overview'}" @click="tab='overview'">样式与日历</button>
        <button :class="{active:tab==='history'}" @click="tab='history'">历史记录</button>
      </div>
      <Placeholder v-if="loading && !styles.length" text="正在加载积微…" />
      <Card v-if="creating" title="新建打卡样式">
        <form class="col" @submit.prevent="saveStyle">
          <p class="muted small">从今天开始生效，保留过去样式和历史记录。每套样式包含 1 至 5 个任务。</p>
          <div v-for="(task,i) in newStyle.tasks" :key="task.id" class="user-task-editor col">
            <div class="row between">
              <strong>任务 {{ i+1 }}</strong>
              <button type="button" class="sm danger" :disabled="newStyle.tasks.length===1" @click="newStyle.tasks.splice(i,1)">移除任务</button>
            </div>
            <label class="field">
              标题
              <input v-model="task.title" required maxlength="120" />
            </label>
            <label class="field">
              说明
              <textarea v-model="task.description" rows="2"></textarea>
            </label>
            <ImagePicker :images="task.image ? [task.image] : []" :files="files" module="booklet" :max="1" @update:images="task.image=$event[0] || ''" @file="files.set($event.name,$event.file)" />
          </div>
          <div class="row">
            <button type="button" :disabled="newStyle.tasks.length>=5" @click="addTask">添加任务</button>
            <span class="spacer"></span>
            <button type="button" :disabled="busy" @click="creating=false">取消</button>
            <button class="primary" :disabled="busy">{{busy?'保存中…':'启用样式'}}</button>
          </div>
        </form>
      </Card>
      <template v-if="tab==='today'">
        <Card title="每日打卡">
          <template #actions>
            <input type="date" aria-label="打卡日期" v-model="date" :max="today" />
            <button class="sm" @click="date=today">今天</button>
          </template>
          <Placeholder v-if="!current" text="这一天还没有打卡样式。点击「新建样式」开始今天的积微。" />
          <form v-else-if="form" class="col" @submit.prevent="saveRecord" @input="dirty=true" @change="dirty=true">
            <div class="row between">
              <span class="muted small">样式始于 {{current.start_date}}</span>
              <strong>{{progress}} / {{current.tasks.length}} 项完成</strong>
            </div>
            <label v-for="task in current.tasks" :key="task.id" class="user-check-task">
              <input type="checkbox" v-model="form.task_completion[task.id]" />
              <span>
                <strong>{{task.title}}</strong>
                <span v-if="task.description" class="user-task-description">{{task.description}}</span>
                <a v-if="task.image" :href="imageUrl(task.image)" target="_blank" rel="noopener" @click.stop>
                  <img :src="imageUrl(task.image)" loading="lazy" alt="任务图片" />
                </a>
              </span>
            </label>
            <label class="field">
              这一天的留言
              <textarea v-model="form.message" rows="4" placeholder="记录做了什么、当下的感受…"></textarea>
            </label>
            <div class="row">
              <MoodSelect v-model="form.mood" />
              <span class="spacer"></span>
              <span class="small muted" v-if="dirty">有未保存的修改</span>
              <button type="button" :disabled="busy" @click="loadRecord">重置</button>
              <button class="primary" :disabled="busy || loading">{{busy?'保存中…':'保存打卡'}}</button>
            </div>
          </form>
        </Card>
      </template>
      <template v-else-if="tab==='overview'">
        <Card title="样式总览">
          <template #actions>
            <select aria-label="查看样式" v-model="selectedId">
              <option value="">最新样式</option>
              <option v-for="s in styles" :value="s.id">{{s.start_date}} · {{s.tasks.map(t=>t.title).join(' / ')}}</option>
            </select>
          </template>
          <Placeholder v-if="!selected" text="还没有打卡样式" />
          <template v-else>
            <div class="user-stats">
              <div>
                <strong>{{stats.count}}</strong>
                <span>有效打卡</span>
              </div>
              <div>
                <strong>{{stats.full}}</strong>
                <span>全部完成</span>
              </div>
              <div>
                <strong>{{stats.longest}}</strong>
                <span>最长连续天数</span>
              </div>
              <div>
                <strong>{{stats.longestFull}}</strong>
                <span>最长连续全完成</span>
              </div>
            </div>
            <div class="row">
              <span v-for="task in selected.tasks" class="badge">{{task.title}}</span>
              <span class="spacer"></span>
              <button class="sm danger" :disabled="busy" @click="removeStyle">删除此样式</button>
            </div>
          </template>
        </Card>
        <Card v-if="selected" title="打卡日历">
          <template #actions>
            <button class="sm" @click="moveMonth(-1)">上月</button>
            <input type="month" aria-label="日历月份" v-model="month" />
            <button class="sm" @click="moveMonth(1)">下月</button>
            <select aria-label="任务筛选" v-model="taskFilter">
              <option value="">全部任务</option>
              <option v-for="t in selected.tasks" :value="t.id">{{t.title}}</option>
            </select>
          </template>
          <div class="user-calendar">
            <span v-for="w in ['一','二','三','四','五','六','日']" class="muted small">{{w}}</span>
            <button v-for="d in calendar" :key="d.date" :class="{outside:d.outside, checked:d.checked, partial:d.record && !d.checked, today:d.date===today}" :disabled="d.date>today" :title="d.date + (d.record?.message ? ' · '+d.record.message : '')" @click="openDay(d.date)">
              {{d.number}}
            </button>
          </div>
          <p class="small muted">实色表示完成，浅色表示已有记录；点击日期查看或补记。</p>
        </Card>
      </template>
      <Card v-else title="历史记录">
        <template #actions>
          <select aria-label="历史样式筛选" v-model="historyStyle">
            <option value="">全部样式</option>
            <option v-for="s in styles" :value="s.id">{{s.start_date}}</option>
          </select>
          <input aria-label="搜索留言" v-model="historyQuery" placeholder="搜索留言" />
        </template>
        <Placeholder v-if="!history.length" text="没有匹配的打卡记录" />
        <div v-for="r in visibleHistory" :key="r.id" class="user-entry">
          <div class="row between">
            <button class="ghost sm" @click="openDay(r.date)">{{r.date}}</button>
            <span class="muted small">
              样式 {{styleName(r.style_id)}} · {{doneCount(r)}} / {{Object.keys(r.task_completion).length}} 项 · {{moodText(r.mood)}}
            </span>
          </div>
          <p v-if="r.message" class="user-prose">{{r.message}}</p>
        </div>
        <button v-if="limit<history.length" @click="limit+=30">加载更多（{{history.length-limit}}）</button>
      </Card>
    </div>
  `,
};
