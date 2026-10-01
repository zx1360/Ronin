// pHash 近重复：分组展示、组内多选、标记软删除、标记「非重复」与恢复。
//
// 分组计算是内存全量扫描，代价不低，因此与桌面端一致：由用户点击触发。
// 软删除只改数据库标记，磁盘文件仍在（真正落盘由 Gallery CLI 的 execute 执行）。

import { ref, computed } from '../../vue.js';
import { api, assetUrl } from '../../api.js';
import { toast, confirmAction } from '../../store.js';
import { Card, Placeholder, MediaTile } from '../../ui.js';
import { baseName, num, revealMedia, thumbUrl } from './shared.js';

export default {
  components: { Card, Placeholder, MediaTile },
  props: {
    aiDisabled: { type: Boolean, default: false },
  },
  setup(props) {
    const loaded = ref(false);
    const loading = ref(false);
    const busy = ref(false);
    const error = ref('');
    const groups = ref([]);
    const ignoredTotal = ref(0);
    const maxDistance = ref(4);
    const selected = ref([]);
    const showIgnored = ref(false);
    const ignoredItems = ref([]);
    const ignoredError = ref('');
    const ignoredLoading = ref(false);

    const isSelected = (id) => selected.value.indexOf(id) >= 0;

    const toggle = (id) => {
      const next = selected.value.slice();
      const position = next.indexOf(id);
      if (position >= 0) next.splice(position, 1);
      else next.push(id);
      selected.value = next;
    };

    const selectedInGroup = (group) => group.items
      .filter((item) => isSelected(item.id))
      .map((item) => item.id);

    const load = async () => {
      loaded.value = true;
      loading.value = true;
      error.value = '';
      try {
        const distance = Math.min(4, Math.max(1, num(maxDistance.value) || 4));
        const data = await api.get(
          '/API/ai/duplicates?max_distance=' + distance + '&min_group=2',
          { timeoutMs: 600000 },
        );
        const list = Array.isArray(data && data.groups) ? data.groups : [];
        groups.value = list.map((group) => {
          const ids = Array.isArray(group.media_ids) ? group.media_ids : [];
          const files = Array.isArray(group.files) ? group.files : [];
          return {
            distance: num(group.distance),
            items: ids.map((id, index) => ({
              id,
              file: files[index] || '',
              name: baseName(files[index]) || String(id).slice(0, 8),
              thumb: thumbUrl(id),
            })),
          };
        });
        ignoredTotal.value = num(data && data.ignored_total);
        selected.value = selected.value.filter((id) => groups.value.some(
          (group) => group.items.some((item) => item.id === id),
        ));
      } catch (err) {
        error.value = err.message;
        groups.value = [];
        ignoredTotal.value = 0;
      } finally {
        loading.value = false;
      }
    };

    /** 标记软删除：可在「已删除」页恢复，但仍是破坏性动作，需要二次确认。 */
    const markDeleted = async (ids) => {
      if (!ids.length) return;
      const ok = await confirmAction(
        '把选中的 ' + ids.length + ' 张媒体标记为软删除？\n'
        + '文件仍在磁盘上，可在「已删除」页取消该标记；真正落盘删除走「任务管理」里的 Gallery execute。',
        { title: '确认标记软删除', danger: true },
      );
      if (!ok) return;
      busy.value = true;
      try {
        const data = await api.patch('/API/gallery/media', { media_ids: ids, is_deleted: true });
        const count = data && Array.isArray(data.media_assets) ? data.media_assets.length : 0;
        toast('已标记软删除 ' + count + ' 张（可在「已删除」页取消）', 'success');
        selected.value = selected.value.filter((id) => ids.indexOf(id) < 0);
        await load();
      } catch (err) {
        toast('标记失败: ' + err.message, 'error');
      } finally {
        busy.value = false;
      }
    };

    const markIgnored = async (ids) => {
      if (!ids.length) return;
      busy.value = true;
      try {
        const data = await api.post('/API/ai/duplicates/ignore', { media_ids: ids });
        toast('已把 ' + ids.length + ' 张标记为非重复（共 ' + num(data && data.total) + ' 张）', 'success');
        selected.value = selected.value.filter((id) => ids.indexOf(id) < 0);
        await load();
      } catch (err) {
        toast('标记失败: ' + err.message, 'error');
      } finally {
        busy.value = false;
      }
    };

    const revealSelected = (group) => {
      const item = group.items.find((entry) => isSelected(entry.id) && entry.file);
      if (!item) {
        toast('请先选中一张带路径的媒体', 'error');
        return;
      }
      revealMedia(item.file);
    };

    const loadIgnored = async () => {
      showIgnored.value = true;
      ignoredLoading.value = true;
      ignoredError.value = '';
      try {
        const data = await api.get('/API/ai/duplicates/ignored', { timeoutMs: 600000 });
        ignoredItems.value = (Array.isArray(data && data.media_assets) ? data.media_assets : []).map((item) => ({
          id: item.id || '',
          name: baseName(item.file_path) || String(item.id || '').slice(0, 8),
          filePath: item.file_path || '',
          thumb: thumbUrl(item.id),
        }));
      } catch (err) {
        ignoredError.value = err.message;
        ignoredItems.value = [];
      } finally {
        ignoredLoading.value = false;
      }
    };

    const restoreIgnored = async (ids) => {
      if (!ids.length) return;
      busy.value = true;
      try {
        await api.post('/API/ai/duplicates/unignore', { media_ids: ids });
        toast('已恢复 ' + ids.length + ' 张到近重复分组', 'success');
        await load();
        await loadIgnored();
      } catch (err) {
        toast('恢复失败: ' + err.message, 'error');
      } finally {
        busy.value = false;
      }
    };

    const groupCards = computed(() => groups.value.map((group, index) => {
      const chosen = selectedInGroup(group);
      const first = group.items.find((item) => item.id === chosen[0]);
      return {
        index: index + 1,
        distance: group.distance,
        count: group.items.length,
        items: group.items,
        selectedCount: chosen.length,
        // 预览走 gallery 文件流：只读查看，不进画廊页
        preview: first ? assetUrl('/API/gallery/' + first.id + '/file') : '',
      };
    }));

    const ignoredIds = computed(() => ignoredItems.value.map((item) => item.id));
    const aiDisabled = computed(() => props.aiDisabled);

    return {
      loaded, loading, busy, error, groups, groupCards, ignoredTotal, maxDistance,
      selected, isSelected, toggle, selectedInGroup,
      showIgnored, ignoredItems, ignoredIds, ignoredError, ignoredLoading, aiDisabled,
      load, markDeleted, markIgnored, revealSelected, loadIgnored, restoreIgnored,
    };
  },
  template: `
    <div>
      <Card title="近重复分组（pHash）">
        <template #actions>
          <span class="small muted" v-if="loading">计算中…</span>
          <span class="small muted" v-if="loaded && !loading">共 {{ groupCards.length }} 组</span>
          <button v-if="ignoredTotal > 0" class="ghost sm" @click="loadIgnored()">已忽略 {{ ignoredTotal }} 张</button>
          <label class="field" style="min-width: 150px">
            最大差异位数（1-4）
            <input type="number" min="1" max="4" v-model.number="maxDistance" />
          </label>
          <button class="primary sm" :disabled="loading" @click="load()">
            {{ loaded ? '重新计算' : '计算近重复分组' }}
          </button>
        </template>

        <div class="small muted">
          汉明距离不超过设定值的图片会被归为一组，可识别同一张图的缩放、转码、加水印等变体。
          「标记删除」是软删除（可在「已删除」页取消）；「标记非重复」用于同组里其实不是重复的图，标记后不再参与分组。
        </div>
        <div class="small" style="color: var(--warning)" v-if="aiDisabled">
          AI 处理层已通过 AI_ENABLED=false 关闭，近重复接口可能不可用。
        </div>

        <Placeholder v-if="error" :error="'获取 /API/ai/duplicates 失败: ' + error" />
        <Placeholder v-else-if="!loaded" text="点击「计算近重复分组」开始（全量扫描，需要一些时间）" />
        <Placeholder v-else-if="!groupCards.length" text="未发现近重复图片" />
        <div class="col" v-else style="gap: 12px">
          <div v-for="group in groupCards" :key="group.index" style="border-top: 1px solid var(--surface-variant); padding-top: 10px">
            <div class="row between">
              <span class="small">
                第 {{ group.index }} 组 · {{ group.count }} 张 · 最大差异 {{ group.distance }} 位
                <span class="muted"> · 组内已选 {{ group.selectedCount }} 张</span>
              </span>
              <span class="row">
                <a
                  v-if="group.preview"
                  class="badge primary"
                  style="text-decoration: none"
                  :href="group.preview"
                  target="_blank"
                  rel="noreferrer"
                >预览所选</a>
                <button class="ghost sm" :disabled="busy || !group.selectedCount" @click="revealSelected(group)">打开所在目录</button>
                <button class="ghost sm" :disabled="busy || !group.selectedCount" @click="markIgnored(selectedInGroup(group))">标记非重复</button>
                <button class="danger sm" :disabled="busy || !group.selectedCount" @click="markDeleted(selectedInGroup(group))">标记删除</button>
              </span>
            </div>
            <div class="media-grid" style="margin-top: 8px">
              <MediaTile
                v-for="item in group.items"
                :key="item.id"
                :src="item.thumb"
                :caption="item.name"
                :selected="isSelected(item.id)"
                @click="toggle(item.id)"
              />
            </div>
          </div>
        </div>
      </Card>

      <Card v-if="showIgnored" title="已标记为非重复">
        <template #actions>
          <span class="small muted" v-if="ignoredLoading">加载中…</span>
          <button class="ghost sm" @click="showIgnored = false">关闭</button>
        </template>
        <Placeholder v-if="ignoredError" :error="'获取失败: ' + ignoredError" />
        <Placeholder v-else-if="!ignoredItems.length && !ignoredLoading" text="暂无记录" />
        <template v-else>
          <div class="row">
            <button
              class="ghost sm"
              :disabled="busy || !ignoredIds.length"
              @click="restoreIgnored(ignoredIds)"
            >全部恢复</button>
          </div>
          <table class="data" style="margin-top: 8px">
            <tbody>
              <tr v-for="item in ignoredItems" :key="item.id">
                <td style="width: 80px"><img :src="item.thumb" alt="" style="width: 64px; border-radius: 4px" /></td>
                <td>
                  {{ item.name }}
                  <div class="small muted mono">{{ item.filePath }}</div>
                </td>
                <td class="row">
                  <button class="ghost sm" @click="restoreIgnored([item.id])">恢复</button>
                </td>
              </tr>
            </tbody>
          </table>
        </template>
      </Card>
    </div>`,
};
