// 已软删除：清单与取消软删除。
//
// 本页只改数据库标记，不碰任何文件——真正的删除仍由 Gallery CLI 的 execute 执行。
// 软删除项可能有几百上千条，所以按批累加加载：单批条数写清、总量与已加载量都显示出来。

import { ref, computed } from '../../vue.js';
import { api } from '../../api.js';
import { toast } from '../../store.js';
import { Card, Placeholder } from '../../ui.js';
import { formatTime } from '../../utils.js';
import { baseName, num, revealMedia, thumbUrl } from './shared.js';

const PAGE_SIZE = 60;

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
    const allSelected = computed(() => items.value.length > 0 && selected.value.length === items.value.length);
    const unloadedCount = computed(() => Math.max(0, total.value - items.value.length));
    const rangeText = computed(
      () => '每批 ' + PAGE_SIZE + ' 条 · 已加载 ' + items.value.length + ' / 共 ' + total.value + ' 项',
    );

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

    /** 只作用于已加载的条目：未加载的还没进 DOM，不替用户做看不见的选择。 */
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
      allSelected, unloadedCount, rangeText, PAGE_SIZE,
      load, toggle, isSelected, clearSelection, selectAll, restore, revealMedia,
    };
  },
  template: `
    <div>
      <Card title="已软删除媒体">
        <template #actions>
          <span class="small muted" v-if="loading">加载中…</span>
          <span class="small muted" v-if="loaded">共 {{ total }} 项 · 已选 {{ selected.length }}</span>
        </template>

        <div class="small muted">
          这些文件只有数据库里的软删除标记，磁盘文件仍在。取消标记即恢复；确认删除请走「任务管理」里的 Gallery execute。
        </div>
        <div class="small" style="color: var(--warning)" v-if="aiDisabled">
          提示：AI 处理层已关闭，但本页只依赖 gallery 接口，仍可正常使用。
        </div>

        <div class="toolbar">
          <button class="ghost sm" :disabled="loading" @click="load(false)">{{ loaded ? '刷新' : '加载已删除媒体' }}</button>
          <template v-if="items.length">
            <button class="ghost sm" v-if="hasMore" :disabled="loading" @click="load(true)">
              加载更多（每批 {{ PAGE_SIZE }} 条）
            </button>
            <button class="ghost sm" :disabled="busy || allSelected" @click="selectAll()">
              全选已加载的 {{ items.length }} 项
            </button>
            <button class="ghost sm" :disabled="busy || !selected.length" @click="clearSelection()">
              取消选择（{{ selected.length }}）
            </button>
            <button class="primary sm" :disabled="busy || !selected.length" @click="restore(selected)">
              取消软删除（{{ selected.length }}）
            </button>
            <span class="grow"></span>
            <span class="small muted" style="padding-bottom: 8px">{{ rangeText }}</span>
          </template>
        </div>

        <Placeholder v-if="error" :error="'获取 /API/gallery/media?only_deleted=true 失败: ' + error" />
        <Placeholder v-else-if="!loaded" text="点击「加载已删除媒体」拉取清单" />
        <Placeholder v-else-if="!items.length && !loading" text="没有被软删除的媒体" />
        <template v-else>
          <div class="small muted" style="margin-bottom: 8px">
            选择范围仅限已加载的 {{ items.length }} 项<span v-if="unloadedCount">；还有 {{ unloadedCount }} 项未加载，需先「加载更多」才能选中</span>。
          </div>

          <div class="media-grid wide">
            <div
              v-for="item in items"
              :key="item.id"
              class="media-tile"
              :class="{ selected: isSelected(item.id) }"
              @click="toggle(item.id)"
            >
              <img :src="item.thumb" alt="" loading="lazy" />
              <div class="meta">
                <div :title="item.filePath">{{ item.name }}</div>
                <div class="small muted">{{ item.captured }}</div>
                <div class="small muted mono">{{ item.mimeType || '—' }}</div>
                <div class="row" style="margin-top: 4px">
                  <button class="ghost sm" :disabled="busy" @click.stop="restore([item.id])">取消软删除</button>
                  <button class="ghost sm" @click.stop="revealMedia(item.filePath)">打开目录</button>
                </div>
              </div>
            </div>
          </div>

          <div class="pager" v-if="hasMore">
            <button class="ghost sm" :disabled="loading" @click="load(true)">
              加载更多（已显示 {{ items.length }} / {{ total }}）
            </button>
            <span class="small muted">{{ rangeText }}</span>
          </div>
        </template>
      </Card>
    </div>`,
};
