import { ref, computed, onMounted, onUnmounted } from '../../vue.js';
import { api } from '../../api.js';
import { toast, confirmAction } from '../../store.js';
import { Placeholder } from '../../ui.js';
import { formatTime } from '../../utils.js';
import { baseName, num, revealMedia, thumbUrl } from './shared.js';

const FAILURE_PAGE_SIZE = 60;

export default {
  components: { Placeholder },
  props: {
    capability: { type: String, required: true },
    label: { type: String, required: true },
    busy: { type: Boolean, default: false },
    run: { type: Function, required: true },
  },
  emits: ['close'],
  setup(props) {
    const controller = new AbortController();
    const failures = ref([]);
    const failureTotal = ref(0);
    const failureError = ref('');
    const failureLoading = ref(false);
    const failureSelected = ref([]);

    const failureHasMore = computed(() => failures.value.length < failureTotal.value);

    /** 取某个能力"到底哪些文件失败了"；失败项通常是个位数，按批加载即可。 */
    const loadFailures = async (more) => {
      if (controller.signal.aborted || failureLoading.value) return;
      if (more && !failureHasMore.value) return;
      failureLoading.value = true;
      failureError.value = '';
      const offset = more ? failures.value.length : 0;
      try {
        const data = await api.get(
          '/API/ai/failures?capability=' + encodeURIComponent(props.capability)
          + '&limit=' + FAILURE_PAGE_SIZE + '&offset=' + offset,
          { signal: controller.signal },
        );
        if (controller.signal.aborted) return;
        const page = (Array.isArray(data && data.failures) ? data.failures : []).map((item) => ({
          mediaId: item.media_id || '',
          name: baseName(item.file_path) || String(item.media_id || '').slice(0, 8),
          filePath: item.file_path || '',
          mimeType: item.mime_type || '',
          attempts: num(item.attempts),
          lastError: item.last_error || '',
          updated: formatTime(item.updated_at, false),
          // 没有缩略图的媒体（视频、源文件已缺失）直接给占位，省掉一次必 404 的请求
          thumb: item.thumb_path ? thumbUrl(item.media_id) : '',
          thumbFailed: !item.thumb_path,
          isDeleted: item.is_deleted === true,
        }));
        failures.value = more ? failures.value.concat(page) : page;
        failureTotal.value = num(data && data.total);
        const alive = failures.value.map((item) => item.mediaId);
        failureSelected.value = failureSelected.value.filter((id) => alive.indexOf(id) >= 0);
      } catch (err) {
        if (!controller.signal.aborted) failureError.value = err.message;
      } finally {
        failureLoading.value = false;
      }
    };

    const toggleFailure = (id) => {
      const next = failureSelected.value.slice();
      const position = next.indexOf(id);
      if (position >= 0) next.splice(position, 1);
      else next.push(id);
      failureSelected.value = next;
    };

    const isFailureSelected = (id) => failureSelected.value.indexOf(id) >= 0;

    /** 缩略图加载失败（媒体没有缩略图或源文件已缺失）：退回文字占位，别留破图。 */
    const markThumbMissing = (item) => {
      item.thumbFailed = true;
    };

    /** 只作用于已加载的条目：没进 DOM 的不替用户做看不见的选择。 */
    const selectAllFailures = () => {
      failureSelected.value = failures.value.map((item) => item.mediaId);
    };

    const clearFailureSelection = () => {
      failureSelected.value = [];
    };

    /**
     * 标记软删除：复用 gallery 的软删除标记，磁盘文件不动。
     *
     * 失败项往往就是"这个文件本身没救"（损坏、非图片、源文件缺失），
     * 标掉之后既不会再被补处理反复排队，也能在「已删除」页恢复。
     */
    const softDeleteFailures = async (ids) => {
      if (!ids.length) return;
      const ok = await confirmAction(
        '将把选中的 ' + ids.length + ' 个文件标记为软删除（只改数据库标记，磁盘文件仍在，可在「已删除」页恢复）。',
        { title: '确认标记软删除', danger: true },
      );
      if (!ok || controller.signal.aborted) return;
      await props.run('', async () => {
        await api.patch('/API/gallery/media', { media_ids: ids, is_deleted: true });
        toast('已标记软删除 ' + ids.length + ' 个文件', 'success');
        failureSelected.value = [];
        await loadFailures(false);
      });
    };

    onMounted(() => loadFailures(false));
    onUnmounted(() => controller.abort());

    return {
      failures, failureTotal, failureError, failureLoading, failureSelected,
      failureHasMore, toggleFailure, isFailureSelected, selectAllFailures,
      clearFailureSelection, softDeleteFailures, loadFailures, markThumbMissing,
      revealMedia, FAILURE_PAGE_SIZE,
    };
  },
  template: `
    <div>
      <div class="row between">
        <span class="small muted">
          处理失败的媒体清单（{{ label }}）· 每批最多 {{ FAILURE_PAGE_SIZE }} 条 ·
          已加载 {{ failures.length }} / 共 {{ failureTotal }} 项
        </span>
        <span class="row">
          <button class="ghost sm" :disabled="failureLoading" @click="loadFailures(false)">刷新</button>
          <button class="ghost sm" :disabled="failureLoading" @click="$emit('close')">关闭</button>
        </span>
      </div>

      <Placeholder v-if="failureError" :error="'获取 /API/ai/failures 失败: ' + failureError" />
      <Placeholder v-else-if="failureLoading && !failures.length" text="正在读取失败项…" />
      <Placeholder v-else-if="!failures.length" text="没有失败项" />
      <template v-else>
        <div class="row" style="margin: 6px 0">
          <button
            class="ghost sm"
            :disabled="busy"
            @click="selectAllFailures()"
          >全选已加载的 {{ failures.length }} 项</button>
          <button
            class="ghost sm"
            :disabled="busy || !failureSelected.length"
            @click="clearFailureSelection()"
          >取消选择（{{ failureSelected.length }}）</button>
          <button
            class="danger sm"
            :disabled="busy || !failureSelected.length"
            @click="softDeleteFailures(failureSelected)"
          >标记软删除（{{ failureSelected.length }}）</button>
          <span class="grow"></span>
          <button
            class="ghost sm"
            v-if="failureHasMore"
            :disabled="failureLoading"
            @click="loadFailures(true)"
          >加载更多</button>
        </div>

        <div class="media-grid wide">
          <div
            v-for="item in failures"
            :key="item.mediaId"
            class="media-tile"
            :class="{ selected: isFailureSelected(item.mediaId) }"
            @click="toggleFailure(item.mediaId)"
          >
            <img v-if="!item.thumbFailed" :src="item.thumb" alt="" loading="lazy" @error="markThumbMissing(item)" />
            <div v-else class="thumb-missing">无缩略图</div>
            <div class="meta">
              <div :title="item.filePath">{{ item.name }}</div>
              <div class="small muted">{{ item.updated }} · 尝试 {{ item.attempts }} 次</div>
              <div class="small" v-if="item.isDeleted">已标记软删除</div>
              <div class="small clamp-2" style="color: var(--warning)" :title="item.lastError">{{ item.lastError }}</div>
              <div class="row" style="margin-top: 4px">
                <button class="danger sm" :disabled="busy" @click.stop="softDeleteFailures([item.mediaId])">
                  标记软删除
                </button>
                <button class="ghost sm" @click.stop="revealMedia(item.filePath)">打开目录</button>
              </div>
            </div>
          </div>
        </div>
      </template>
    </div>`,
};
