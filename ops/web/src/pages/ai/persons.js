// 人物分组：改名、合并、删除、查看人脸、人工纠正与增量/重新聚类。

import { ref, computed, onMounted } from '../../vue.js';
import { api } from '../../api.js';
import { toast, confirmAction } from '../../store.js';
import { Card, Placeholder, MediaTile } from '../../ui.js';
import { num, thumbUrl } from './shared.js';

export default {
  components: { Card, Placeholder, MediaTile },
  props: {
    aiDisabled: { type: Boolean, default: false },
  },
  setup(props) {
    const persons = ref([]);
    const error = ref('');
    const loading = ref(false);
    const busy = ref(false);
    const selected = ref([]);
    const mergeTarget = ref('');
    const editingId = ref('');
    const editName = ref('');
    const facesOf = ref('');
    const faces = ref([]);
    const faceTotal = ref(0);
    const faceError = ref('');
    const faceLoading = ref(false);
    const faceSelected = ref([]);
    const moveTarget = ref('');

    const load = async () => {
      loading.value = true;
      try {
        const data = await api.get('/API/ai/persons');
        persons.value = Array.isArray(data && data.persons) ? data.persons : [];
        error.value = '';
        const alive = persons.value.map((item) => item.id);
        selected.value = selected.value.filter((id) => alive.indexOf(id) >= 0);
      } catch (err) {
        error.value = err.message;
      } finally {
        loading.value = false;
      }
    };

    onMounted(() => {
      load();
    });

    const cards = computed(() => persons.value.map((person) => ({
      id: person.id || '',
      name: person.name || '',
      displayName: person.name || '未命名',
      faceCount: num(person.face_count),
      caption: (person.name || '未命名') + ' · ' + num(person.face_count) + ' 张',
      thumb: thumbUrl(person.cover_media_id),
      selected: selected.value.indexOf(person.id) >= 0,
    })));

    const selectedCards = computed(() => cards.value.filter((item) => item.selected));
    const mergeOptions = computed(() => selectedCards.value.map((item) => ({
      id: item.id,
      label: item.displayName + '（' + item.faceCount + ' 张）',
    })));
    const otherPersons = computed(() => cards.value
      .filter((item) => item.id !== facesOf.value)
      .map((item) => ({ id: item.id, label: item.displayName + '（' + item.faceCount + ' 张）' })));

    const editingCard = computed(() => cards.value.find((item) => item.id === editingId.value) || null);
    const facesOwner = computed(() => cards.value.find((item) => item.id === facesOf.value) || null);

    const faceCards = computed(() => faces.value.map((face) => ({
      id: face.id || '',
      mediaId: face.media_id || '',
      personId: face.person_id || '',
      thumb: thumbUrl(face.media_id),
      caption: face.id ? String(face.id).slice(0, 8) : '',
      detail: '质量 ' + num(face.quality).toFixed(2) + ' · 检测 ' + num(face.det_score).toFixed(2),
      selected: faceSelected.value.indexOf(face.id) >= 0,
    })));

    const toggleSelect = (id) => {
      const next = selected.value.slice();
      const position = next.indexOf(id);
      if (position >= 0) next.splice(position, 1);
      else next.push(id);
      selected.value = next;
      if (mergeOptions.value.length && mergeOptions.value.every((item) => item.id !== mergeTarget.value)) {
        mergeTarget.value = mergeOptions.value[0].id;
      }
    };

    const clearSelection = () => {
      selected.value = [];
      mergeTarget.value = '';
    };

    const startRename = (card) => {
      editingId.value = card.id;
      editName.value = card.name;
    };

    const cancelRename = () => {
      editingId.value = '';
      editName.value = '';
    };

    const saveRename = async () => {
      const id = editingId.value;
      if (!id) return;
      busy.value = true;
      try {
        await api.patch('/API/ai/persons/' + id, { name: editName.value });
        toast('已更新人物名称', 'success');
        cancelRename();
        await load();
      } catch (err) {
        toast('命名失败: ' + err.message, 'error');
      } finally {
        busy.value = false;
      }
    };

    const removePerson = async (card) => {
      const ok = await confirmAction(
        '删除「' + card.displayName + '」分组？\n分组内的人脸会回到未分配状态，媒体文件与标签不受影响。',
        { title: '确认删除人物分组', danger: true },
      );
      if (!ok) return;
      busy.value = true;
      try {
        await api.del('/API/ai/persons/' + card.id);
        toast('已删除分组', 'success');
        if (facesOf.value === card.id) closeFaces();
        await load();
      } catch (err) {
        toast('删除失败: ' + err.message, 'error');
      } finally {
        busy.value = false;
      }
    };

    const mergeSelected = async () => {
      const sources = selectedCards.value.map((item) => item.id).filter((id) => id !== mergeTarget.value);
      if (!mergeTarget.value || !sources.length) {
        toast('请选择至少两个分组并指定合并目标', 'error');
        return;
      }
      busy.value = true;
      try {
        const data = await api.post('/API/ai/persons/merge', {
          source_ids: sources,
          target_id: mergeTarget.value,
        });
        toast('已合并 ' + num(data && data.moved_faces) + ' 张人脸', 'success');
        clearSelection();
        await load();
      } catch (err) {
        toast('合并失败: ' + err.message, 'error');
      } finally {
        busy.value = false;
      }
    };

    const recluster = async (reset) => {
      if (reset) {
        const ok = await confirmAction(
          '重新聚类会清空全部分组：现有人物分组与人工命名都会被删除，随后按人脸特征重新分组。\n'
          + '如果只是想归并新的人脸，请使用「增量聚类」。',
          { title: '确认清空并重新聚类', danger: true },
        );
        if (!ok) return;
      }
      busy.value = true;
      toast('正在聚类，请稍候…', 'info');
      try {
        const data = await api.post('/API/ai/recluster', { reset: !!reset }, { timeoutMs: 1800000 });
        toast(
          '聚类完成：归入 ' + num(data && data.assigned) + ' 张，新建 '
          + num(data && data.new_person) + ' 组，暂未成组 ' + num(data && data.pending) + ' 张',
          'success',
        );
        clearSelection();
        closeFaces();
        await load();
      } catch (err) {
        toast('聚类失败: ' + err.message, 'error');
      } finally {
        busy.value = false;
      }
    };

    const loadFaces = async (card) => {
      facesOf.value = card.id;
      faces.value = [];
      faceTotal.value = 0;
      faceSelected.value = [];
      moveTarget.value = '';
      faceError.value = '';
      faceLoading.value = true;
      try {
        const data = await api.get('/API/ai/persons/' + card.id + '/faces?limit=200&offset=0');
        faces.value = Array.isArray(data && data.faces) ? data.faces : [];
        faceTotal.value = num(data && data.total);
      } catch (err) {
        faceError.value = err.message;
      } finally {
        faceLoading.value = false;
      }
    };

    const closeFaces = () => {
      facesOf.value = '';
      faces.value = [];
      faceSelected.value = [];
      moveTarget.value = '';
      faceError.value = '';
    };

    const toggleFace = (id) => {
      const next = faceSelected.value.slice();
      const position = next.indexOf(id);
      if (position >= 0) next.splice(position, 1);
      else next.push(id);
      faceSelected.value = next;
    };

    /** 人工纠正：把选中人脸移到另一分组，或移出分组（person_id = null）。 */
    const assignFaces = async (personId) => {
      const ids = faceSelected.value.slice();
      if (!ids.length) return;
      busy.value = true;
      try {
        await api.post('/API/ai/faces/assign', { face_ids: ids, person_id: personId });
        toast(personId ? '已移动到所选分组' : '已移出分组', 'success');
        faceSelected.value = [];
        const ownerId = facesOf.value;
        await load();
        // 移出全部人脸后服务端会清理空分组，此时关闭人脸面板
        if (persons.value.some((item) => item.id === ownerId)) {
          const owner = cards.value.find((item) => item.id === ownerId);
          if (owner) await loadFaces(owner);
        } else {
          closeFaces();
        }
      } catch (err) {
        toast('纠正失败: ' + err.message, 'error');
      } finally {
        busy.value = false;
      }
    };

    return {
      persons, error, loading, busy, selected, mergeTarget, cards,
      selectedCards, mergeOptions, otherPersons, editingCard, editName,
      facesOf, facesOwner, faceCards, faceError, faceLoading, faceTotal, faceSelected, moveTarget,
      toggleSelect, clearSelection, startRename, cancelRename, saveRename, removePerson,
      mergeSelected, recluster, loadFaces, closeFaces, toggleFace, assignFaces, load,
    };
  },
  template: `
    <div>
      <Card title="人物分组">
        <template #actions>
          <span class="small muted" v-if="loading">加载中…</span>
          <span class="small muted" v-if="cards.length">共 {{ cards.length }} 组</span>
          <button class="ghost sm" :disabled="busy" @click="load()">刷新</button>
          <button class="ghost sm" :disabled="busy" @click="recluster(false)">增量聚类（保留现有人物）</button>
          <button class="danger sm" :disabled="busy" @click="recluster(true)">重新聚类（清空分组）</button>
        </template>

        <div class="small muted">
          点击卡片选中后可将多个分组合并；增量聚类只处理尚未归属的人脸，不影响已命名的人物；重新聚类会清空全部分组。
        </div>
        <div class="small" style="color: var(--warning)" v-if="aiDisabled">
          AI 处理层已通过 AI_ENABLED=false 关闭，分组接口可能不可用。
        </div>

        <div class="row" style="margin: 10px 0" v-if="selectedCards.length >= 2">
          <span class="small">合并到</span>
          <select v-model="mergeTarget" style="min-width: 200px">
            <option v-for="item in mergeOptions" :key="item.id" :value="item.id">{{ item.label }}</option>
          </select>
          <button class="primary sm" :disabled="busy" @click="mergeSelected()">合并所选 {{ selectedCards.length }} 组</button>
          <button class="ghost sm" @click="clearSelection()">取消选择</button>
        </div>

        <div class="row" style="margin: 10px 0" v-if="editingCard">
          <span class="small">命名「{{ editingCard.displayName }}」</span>
          <input v-model="editName" placeholder="例如：家人 / 朋友 / 昵称" style="min-width: 220px" @keyup.enter="saveRename()" />
          <button class="primary sm" :disabled="busy" @click="saveRename()">保存</button>
          <button class="ghost sm" @click="cancelRename()">取消</button>
          <span class="small muted">留空保存即清除名称</span>
        </div>

        <Placeholder v-if="error" :error="'获取 /API/ai/persons 失败: ' + error" />
        <Placeholder v-else-if="!cards.length" text="暂无人物分组：请先处理人脸能力，再执行增量聚类" />
        <div class="media-grid" v-else>
          <div class="col" v-for="card in cards" :key="card.id">
            <MediaTile :src="card.thumb" :caption="card.caption" :selected="card.selected" @click="toggleSelect(card.id)" />
            <div class="row">
              <button class="ghost sm" :disabled="busy" @click="startRename(card)">命名</button>
              <button class="ghost sm" :disabled="busy" @click="loadFaces(card)">人脸 {{ card.faceCount }}</button>
              <button class="danger sm" :disabled="busy" @click="removePerson(card)">删除</button>
            </div>
          </div>
        </div>
      </Card>

      <Card v-if="facesOf" :title="'「' + (facesOwner ? facesOwner.displayName : facesOf) + '」的人脸'">
        <template #actions>
          <span class="small muted" v-if="faceLoading">加载中…</span>
          <span class="small muted">共 {{ faceTotal }} 张</span>
          <button class="ghost sm" @click="closeFaces()">关闭</button>
        </template>

        <Placeholder v-if="faceError" :error="'获取人脸失败: ' + faceError" />
        <Placeholder v-else-if="!faceCards.length && !faceLoading" text="该分组暂无已归属的人脸" />
        <template v-else>
          <div class="row" style="margin-bottom: 10px">
            <span class="small muted">已选 {{ faceSelected.length }} 张</span>
            <button class="ghost sm" :disabled="busy || !faceSelected.length" @click="assignFaces(null)">移出分组</button>
            <span class="small">移到</span>
            <select v-model="moveTarget" style="min-width: 180px">
              <option value="">选择分组…</option>
              <option v-for="item in otherPersons" :key="item.id" :value="item.id">{{ item.label }}</option>
            </select>
            <button
              class="primary sm"
              :disabled="busy || !faceSelected.length || !moveTarget"
              @click="assignFaces(moveTarget)"
            >应用</button>
          </div>
          <div class="media-grid">
            <div class="col" v-for="face in faceCards" :key="face.id">
              <MediaTile
                :src="face.thumb"
                :caption="face.caption"
                :selected="face.selected"
                @click="toggleFace(face.id)"
              />
              <div class="small muted">{{ face.detail }}</div>
            </div>
          </div>
        </template>
      </Card>
    </div>`,
};
