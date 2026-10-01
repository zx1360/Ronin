// 已软删除：清单与取消软删除。
//
// 本页只改数据库标记，不碰任何文件——真正的删除仍由 Gallery CLI 的 execute 执行。

import { ref, computed } from '../../vue.js';
import { api } from '../../api.js';
import { toast } from '../../store.js';
import { Card, Placeholder } from '../../ui.js';
import { formatTime } from '../../utils.js';
import { baseName, num, revealMedia, thumbUrl } from './shared.js';

const PAGE_SIZE = 120;

export default {
  components: { Card, Placeholder },
  props: {
    aiDisabled: { type: Boolean, default: false },
  },
  setup() {
    const items = ref([]);
    const total = ref(0);
    const loaded = ref(false);
    const loading = ref(false);
    const busy = ref(false);
    const error = ref('');
    const selected = ref([]);

    const hasMore = computed(() => items.value.length < total.value);

    const load = async (more) => {
      if (loading.value) return;
      if (more && !hasMore.value) return;
      loaded.value = true;
      loading.value = true;
      error.value = '';
      const offset = more ? items.value.length : 0;
      try {
        const data = await api.get(
          '/API/gallery/media?only_deleted=true&sort_by=captured_at&sort_order=desc'
          + '&limit=' + PAGE_SIZE + '&offset=' + offset,
        );
        const page = (Array.isArray(data && data.media_assets) ? data.media_assets : []).map((item) => ({
          id: item.id || '',
          filePath: item.file_path || '',
          name: baseName(item.file_path) || String(item.id || '').slice(0, 8),
          thumb: thumbUrl(item.id),
          captured: formatTime(item.captured_at, false),
          mimeType: item.mime_type || '',
        }));
        items.value = more ? items.value.concat(page) : page;
        total.value = num(data && data.total);
        const alive = items.value.map((item) => item.id);
        selected.value = selected.value.filter((id) => alive.indexOf(id) >= 0);
      } catch (err) {
        error.value = err.message;
      } finally {
        loading.value = false;
      }
    };

    const toggle = (id) => {
      const next = selected.value.slice();
      const position = next.indexOf(id);
      if (position >= 0) next.splice(position, 1);
      else next.push(id);
      selected.value = next;
    };

    const isSelected = (id) => selected.value.indexOf(id) >= 0;

    const clearSelection = () => {
      selected.value = [];
    };

    const selectAll = () => {
      selected.value = items.value.map((item) => item.id);
    };

    /** 取消软删除（恢复）：本页只改标记，不涉及文件。 */
    const restore = async (ids) => {
      if (!ids.length) return;
      busy.value = true;
      try {
        const data = await api.patch('/API/gallery/media', { media_ids: ids, is_deleted: false });
        const count = data && Array.isArray(data.media_assets) ? data.media_assets.length : ids.length;
        toast('已取消 ' + count + ' 个文件的软删除标记', 'success');
        selected.value = selected.value.filter((id) => ids.indexOf(id) < 0);
        await load(false);
      } catch (err) {
        toast('恢复失败: ' + err.message, 'error');
      } finally {
        busy.value = false;
      }
    };

    return {
      items, total, loaded, loading, busy, error, selected, hasMore,
      load, toggle, isSelected, clearSelection, selectAll, restore, revealMedia,
    };
  },
  template: `
    <div>
      <Card title="已软删除媒体">
        <template #actions>
          <span class="small muted" v-if="loading">加载中…</span>
          <span class="small muted" v-if="loaded">共 {{ total }} 个 · 已选 {{ selected.length }}</span>
          <button class="ghost sm" :disabled="busy || !selected.length" @click="clearSelection()">取消选择</button>
          <button class="ghost sm" :disabled="busy || !items.length" @click="selectAll()">全选本页</button>
          <button class="primary sm" :disabled="busy || !selected.length" @click="restore(selected)">
            取消软删除（{{ selected.length }}）
          </button>
          <button class="ghost sm" :disabled="loading" @click="load(false)">{{ loaded ? '刷新' : '加载已删除媒体' }}</button>
        </template>

        <div class="small muted">
          这些文件只有数据库里的软删除标记，磁盘文件仍在。取消标记即恢复；确认删除请走「任务管理」里的 Gallery execute。
        </div>
        <div class="small" style="color: var(--warning)" v-if="aiDisabled">
          提示：AI 处理层已关闭，但本页只依赖 gallery 接口，仍可正常使用。
        </div>

        <Placeholder v-if="error" :error="'获取 /API/gallery/media?only_deleted=true 失败: ' + error" />
        <Placeholder v-else-if="!loaded" text="点击「加载已删除媒体」拉取清单" />
        <Placeholder v-else-if="!items.length && !loading" text="没有被软删除的媒体" />
        <template v-else>
          <table class="data">
            <thead>
              <tr><th>缩略图</th><th>文件</th><th>拍摄时间</th><th>类型</th><th></th></tr>
            </thead>
            <tbody>
              <tr v-for="item in items" :key="item.id" :class="{ selected: isSelected(item.id) }">
                <td style="width: 72px">
                  <img
                    :src="item.thumb"
                    alt=""
                    loading="lazy"
                    style="width: 60px; height: 60px; object-fit: cover; border-radius: 4px"
                    :style="isSelected(item.id) ? 'outline: 2px solid var(--primary)' : ''"
                    @click="toggle(item.id)"
                  />
                </td>
                <td>
                  <div>{{ item.name }}</div>
                  <div class="small muted mono">{{ item.filePath }}</div>
                </td>
                <td class="small">{{ item.captured }}</td>
                <td class="small mono">{{ item.mimeType || '—' }}</td>
                <td>
                  <div class="row">
                    <button class="ghost sm" @click="revealMedia(item.filePath)">打开所在目录</button>
                    <button class="ghost sm" :disabled="busy" @click="restore([item.id])">取消软删除</button>
                    <label class="row small muted" style="gap: 4px">
                      <input type="checkbox" :checked="isSelected(item.id)" @change="toggle(item.id)" /> 选择
                    </label>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>

          <div class="row" style="margin-top: 10px" v-if="hasMore">
            <button class="ghost sm" :disabled="loading" @click="load(true)">
              加载更多（已显示 {{ items.length }} / {{ total }}）
            </button>
          </div>
        </template>
      </Card>
    </div>`,
};
