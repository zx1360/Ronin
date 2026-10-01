// 检索：文本搜图 / 以图搜图（本地上传或库内相似媒体），带结构化筛选与媒体 AI 结果详情。
//
// 筛选口径与后端 /API/ai/search 一致：tag_ids 为人工标签、vlm_tags 为 AI 标签
// （只读，与人工标签物理隔离）、person_ids、mime_type、from/to。
// 一页 60 条由服务端 limit/offset 分页，命中数可能远多于 60，故结果区自己滚动并支持续取。

import { ref, computed, onMounted } from '../../vue.js';
import { api, assetUrl } from '../../api.js';
import { toast } from '../../store.js';
import { Card, Placeholder, Badge, MediaTile } from '../../ui.js';
import { formatBytes, formatTime } from '../../utils.js';
import { baseName, num, revealMedia, thumbUrl } from './shared.js';

const MODES = [
  { value: 'auto', label: '智能（语义 + 关键词加权）' },
  { value: 'semantic', label: '语义（向量）' },
  { value: 'keyword', label: '文字（OCR/描述/关键词）' },
  { value: 'filename', label: '文件名' },
];

const MIME_TYPES = [
  { value: '', label: '全部类型' },
  { value: 'image', label: '仅图片' },
  { value: 'video', label: '仅视频' },
];

const MODE_TEXT = { auto: '智能', semantic: '语义', keyword: '文字', filename: '文件名' };

/** 单页条数：与后端默认值一致，也是「加载更多」的步长（服务端上限 200）。 */
const PAGE_SIZE = 60;
/** 相似检索接口只接受 limit（上限 200），没有 offset，因此不参与分页。 */
const SIMILAR_LIMIT = 40;

export default {
  components: { Card, Placeholder, Badge, MediaTile },
  props: {
    aiDisabled: { type: Boolean, default: false },
  },
  setup(props) {
    const query = ref('');
    const mode = ref('auto');
    const filters = ref({
      tagIds: [],
      vlmTags: [],
      personIds: [],
      mimeType: '',
      from: '',
      to: '',
    });
    const filtersOpen = ref(false);
    const hits = ref([]);
    const total = ref(0);
    const resultMode = ref('');
    /** 本次结果来自哪个接口：search / image / similar，决定能否续页。 */
    const resultSource = ref('');
    const nextOffset = ref(0);
    const lastPageFull = ref(false);
    const searched = ref(false);
    const loading = ref(false);
    const loadingMore = ref(false);
    const uploading = ref(false);
    const error = ref('');
    const imageName = ref('');
    /** 上传的图片留在内存里，续页时按同一张图重发（不落库、不缓存）。 */
    const imageFile = ref(null);
    const imageInput = ref(null);
    const selectedId = ref('');
    const detail = ref(null);
    const detailError = ref('');

    const tags = ref([]);
    const vlmTags = ref([]);
    const persons = ref([]);
    const filterError = ref('');

    const loadFilters = async () => {
      const results = await Promise.allSettled([
        api.get('/API/gallery/tags'),
        api.get('/API/ai/tags?limit=500'),
        api.get('/API/ai/persons'),
      ]);
      const [tagResult, vlmResult, personResult] = results;
      tags.value = tagResult.status === 'fulfilled' && Array.isArray(tagResult.value && tagResult.value.tags)
        ? tagResult.value.tags
        : [];
      vlmTags.value = vlmResult.status === 'fulfilled' && Array.isArray(vlmResult.value && vlmResult.value.tags)
        ? vlmResult.value.tags
        : [];
      persons.value = personResult.status === 'fulfilled' && Array.isArray(personResult.value && personResult.value.persons)
        ? personResult.value.persons
        : [];
      const failures = results.filter((item) => item.status === 'rejected');
      filterError.value = failures.length === results.length
        ? '筛选数据不可用（标签/人物接口均失败）'
        : '';
    };

    onMounted(() => {
      loadFilters();
    });

    const tagOptions = computed(() => tags.value.map((tag) => ({
      id: tag.id || '',
      label: tag.full_path || tag.name || tag.id || '',
      count: num(tag.media_count),
    })));

    const vlmTagOptions = computed(() => vlmTags.value.map((tag) => ({
      id: tag.tag || '',
      label: tag.tag || '',
      count: num(tag.count),
    })));

    const personOptions = computed(() => persons.value.map((person) => ({
      id: person.id || '',
      label: (person.name || '未命名') + '（' + num(person.face_count) + ' 张）',
    })));

    /** 组查询串：与 Dart 客户端的参数名保持一致（空值不下发）。 */
    const buildQuery = (withText, offset) => {
      const params = [
        'mode=' + encodeURIComponent(mode.value || 'auto'),
        'limit=' + PAGE_SIZE,
        'offset=' + num(offset),
      ];
      if (withText && query.value.trim()) params.push('q=' + encodeURIComponent(query.value.trim()));
      if (filters.value.tagIds.length) params.push('tag_ids=' + encodeURIComponent(filters.value.tagIds.join(',')));
      if (filters.value.vlmTags.length) params.push('vlm_tags=' + encodeURIComponent(filters.value.vlmTags.join(',')));
      if (filters.value.personIds.length) params.push('person_ids=' + encodeURIComponent(filters.value.personIds.join(',')));
      if (filters.value.mimeType) params.push('mime_type=' + encodeURIComponent(filters.value.mimeType));
      if (filters.value.from) params.push('from=' + encodeURIComponent(filters.value.from));
      if (filters.value.to) params.push('to=' + encodeURIComponent(filters.value.to));
      return params.join('&');
    };

    /** 写入结果；append 为真时续接在既有列表之后。返回本次新增条数。 */
    const applyResult = (data, append) => {
      const list = Array.isArray(data && data.hits) ? data.hits : [];
      hits.value = append ? hits.value.concat(list) : list;
      // 以服务端 total 为准；字段缺失时也不至于出现「已显示 60 / 命中 0」
      total.value = Math.max(num(data && data.total), hits.value.length);
      resultMode.value = (data && data.mode) || '';
      // 不满一页说明后面没有更多，避免 offset 不前进时反复请求同一页
      lastPageFull.value = list.length >= PAGE_SIZE;
      searched.value = true;
      if (!append) {
        selectedId.value = '';
        detail.value = null;
        detailError.value = '';
      }
      return list.length;
    };

    const failRequest = (err, append) => {
      error.value = err && err.message ? err.message : String(err);
      if (!append) {
        hits.value = [];
        total.value = 0;
        lastPageFull.value = false;
      }
    };

    const runSearch = async (offset, append) => {
      if (append) loadingMore.value = true;
      else loading.value = true;
      error.value = '';
      try {
        const data = await api.get('/API/ai/search?' + buildQuery(true, offset), { timeoutMs: 600000 });
        nextOffset.value = num(offset) + applyResult(data, append);
        resultSource.value = 'search';
        // 检索发起后收起筛选区，让结果区立刻落在视口内
        if (!append) filtersOpen.value = false;
      } catch (err) {
        failRequest(err, append);
      } finally {
        loading.value = false;
        loadingMore.value = false;
      }
    };

    const search = () => runSearch(0, false);

    /** 以图搜图：multipart 上传（字段名 image，与后端一致），条件与分页走 URL。 */
    const runImageSearch = async (offset, append) => {
      const file = imageFile.value;
      if (!file) {
        error.value = '请先选择用于检索的图片';
        return;
      }
      if (append) loadingMore.value = true;
      else uploading.value = true;
      error.value = '';
      try {
        const form = new FormData();
        form.append('image', file, file.name);
        const url = assetUrl('/API/ai/search/image?' + buildQuery(false, offset));
        const response = await fetch(url, { method: 'POST', body: form, cache: 'no-store' });
        const text = await response.text();
        let payload = null;
        try {
          payload = text ? JSON.parse(text) : null;
        } catch (err) {
          payload = null;
        }
        if (!response.ok) {
          const detailText = payload && payload.error ? ': ' + payload.error : '';
          throw new Error('HTTP ' + response.status + detailText);
        }
        nextOffset.value = num(offset) + applyResult(payload, append);
        resultSource.value = 'image';
        if (!append) filtersOpen.value = false;
      } catch (err) {
        failRequest(err, append);
      } finally {
        uploading.value = false;
        loadingMore.value = false;
      }
    };

    const similarTo = async (id) => {
      loading.value = true;
      error.value = '';
      try {
        const data = await api.get('/API/ai/similar/' + id + '?limit=' + SIMILAR_LIMIT, { timeoutMs: 600000 });
        applyResult(data, false);
        resultSource.value = 'similar';
        nextOffset.value = 0;
        toast('已按所选图片查找相似媒体', 'success');
      } catch (err) {
        failRequest(err, false);
      } finally {
        loading.value = false;
      }
    };

    const clearResult = () => {
      hits.value = [];
      total.value = 0;
      resultMode.value = '';
      resultSource.value = '';
      nextOffset.value = 0;
      lastPageFull.value = false;
      searched.value = false;
      error.value = '';
      selectedId.value = '';
      detail.value = null;
      detailError.value = '';
      imageName.value = '';
      imageFile.value = null;
    };

    const pickImage = () => {
      if (imageInput.value) imageInput.value.click();
    };

    const onImagePicked = async (event) => {
      const file = event.target.files && event.target.files[0];
      if (!file) return;
      imageFile.value = file;
      imageName.value = file.name;
      try {
        await runImageSearch(0, false);
      } finally {
        event.target.value = '';
      }
    };

    /** search / image 支持 offset 续取；similar 接口无 offset，不显示分页条。 */
    const pageable = computed(() => resultSource.value === 'search' || resultSource.value === 'image');

    const hasMore = computed(() => pageable.value && lastPageFull.value && hits.value.length < total.value);

    const resultModeText = computed(() => MODE_TEXT[resultMode.value] || resultMode.value || '—');

    const activeFilterCount = computed(() => (
      filters.value.tagIds.length
      + filters.value.vlmTags.length
      + filters.value.personIds.length
      + (filters.value.mimeType ? 1 : 0)
      + (filters.value.from ? 1 : 0)
      + (filters.value.to ? 1 : 0)
    ));

    const loadMore = () => {
      if (!hasMore.value || loading.value || loadingMore.value) return;
      if (resultSource.value === 'image') runImageSearch(nextOffset.value, true);
      else runSearch(nextOffset.value, true);
    };

    const restart = () => {
      if (resultSource.value === 'image') runImageSearch(0, false);
      else runSearch(0, false);
    };

    const toggleFilters = () => {
      filtersOpen.value = !filtersOpen.value;
    };

    const hitCards = computed(() => hits.value.map((hit) => {
      const sources = Array.isArray(hit.source) ? hit.source : [];
      return {
        id: hit.id || '',
        filePath: hit.file_path || '',
        name: baseName(hit.file_path) || String(hit.id || '').slice(0, 8),
        thumb: thumbUrl(hit.id),
        score: num(hit.score),
        scoreText: num(hit.score) > 0 ? '相关度 ' + num(hit.score).toFixed(3) : '',
        sources,
        sourceText: sources.map((item) => ({
          semantic: '语义',
          keyword: '文字',
          filename: '文件名',
          ocr: '文字',
          tag: '标签',
          person: '人物',
          caption: '描述',
          vlm_tag: 'AI标签',
        }[item] || item)).join('/'),
        isVideo: String(hit.mime_type || '').indexOf('video/') === 0,
        mimeType: hit.mime_type || '',
        size: formatBytes(hit.size_bytes),
        captured: formatTime(hit.captured_at, false),
        selected: selectedId.value === hit.id,
      };
    }));

    const selectedHit = computed(() => hitCards.value.find((item) => item.selected) || null);

    const selectHit = async (card) => {
      selectedId.value = card.id;
      detail.value = null;
      detailError.value = '';
      try {
        const data = await api.get('/API/ai/media/' + card.id);
        const source = data || {};
        const faces = Array.isArray(source.faces) ? source.faces : [];
        detail.value = {
          phash: source.phash === null || source.phash === undefined ? '—' : String(source.phash),
          ocrText: source.ocr_text || '',
          caption: source.caption || '',
          vlmTags: Array.isArray(source.vlm_tags) ? source.vlm_tags : [],
          hasVector: source.has_vector === true,
          faceCount: faces.length,
        };
      } catch (err) {
        detailError.value = err.message;
      }
    };

    return {
      query, mode, filters, hits, total, searched, loading, loadingMore, uploading, error,
      imageName, imageInput, tagOptions, vlmTagOptions, personOptions, filterError,
      hitCards, selectedHit, detail, detailError, MODES, MIME_TYPES, PAGE_SIZE,
      filtersOpen, activeFilterCount, pageable, hasMore, resultModeText,
      search, loadMore, restart, toggleFilters, similarTo, clearResult, pickImage, onImagePicked,
      selectHit, loadFilters, baseName, reveal: revealMedia,
    };
  },
  template: `
    <div>
      <Card title="检索">
        <div class="toolbar">
          <label class="field">
            检索方式
            <select v-model="mode">
              <option v-for="item in MODES" :key="item.value" :value="item.value">{{ item.label }}</option>
            </select>
          </label>
          <label class="field grow">
            关键词
            <input
              v-model="query"
              :placeholder="mode === 'filename' ? '文件名或扩展名，例如：IMG_2024、.mp4' : '用自然语言描述想要的画面，例如：可爱的猫娘、夜景街道'"
              @keyup.enter="search()"
            />
          </label>
          <button class="primary sm" :disabled="loading" @click="search()">{{ loading ? '检索中…' : '搜索' }}</button>
          <button class="ghost sm" @click="clearResult()">清空</button>
          <button class="ghost sm" :disabled="uploading" @click="pickImage()">
            {{ uploading ? '上传检索中…' : '以图搜图（本地上传）' }}
          </button>
          <button class="ghost sm" @click="toggleFilters()">
            筛选条件<span v-if="activeFilterCount">（已选 {{ activeFilterCount }} 项）</span>{{ filtersOpen ? ' ▲' : ' ▼' }}
          </button>
          <input ref="imageInput" type="file" accept="image/*" style="display: none" @change="onImagePicked" />
        </div>
        <div class="small muted">
          智能模式有文本即走语义检索并把 OCR/描述/关键词命中加权；文字模式只匹配 OCR/描述/AI 关键词；
          文件名模式只匹配文件路径。以图搜图上传的图片只用于本次查询，不落库。
          <span v-if="imageName"> 已选文件：<span class="mono">{{ imageName }}</span></span>
        </div>
        <div class="small" style="color: var(--warning)" v-if="filterError">{{ filterError }}</div>
        <div class="small" style="color: var(--warning)" v-if="aiDisabled">
          AI 处理层已通过 AI_ENABLED=false 关闭，检索接口可能不可用。
        </div>

        <div v-if="filtersOpen" style="margin-top: 12px">
          <div class="grid cols-3">
            <label class="field">
              人工标签（任一命中，可多选）
              <select multiple v-model="filters.tagIds">
                <option v-for="item in tagOptions" :key="item.id" :value="item.id">{{ item.label }}（{{ item.count }}）</option>
              </select>
            </label>
            <label class="field">
              AI 标签（只读，与人工标签隔离）
              <select multiple v-model="filters.vlmTags">
                <option v-for="item in vlmTagOptions" :key="item.id" :value="item.id">{{ item.label }}（{{ item.count }}）</option>
              </select>
            </label>
            <label class="field">
              人物分组
              <select multiple v-model="filters.personIds">
                <option v-for="item in personOptions" :key="item.id" :value="item.id">{{ item.label }}</option>
              </select>
            </label>
            <label class="field">
              媒体类型
              <select v-model="filters.mimeType">
                <option v-for="item in MIME_TYPES" :key="item.value" :value="item.value">{{ item.label }}</option>
              </select>
            </label>
            <label class="field">
              拍摄时间（从）
              <input type="date" v-model="filters.from" />
            </label>
            <label class="field">
              拍摄时间（到）
              <input type="date" v-model="filters.to" />
            </label>
          </div>
          <div class="small muted" style="margin-top: 6px">
            勾选项之间是「任一命中」；改完筛选条件后点「搜索」（或「以图搜图」）生效。
          </div>
        </div>
      </Card>

      <Card v-if="searched" title="结果">
        <template #actions>
          <span class="small muted">
            命中 {{ total }} 张 · 已显示 {{ hits.length }} 张 · 模式 {{ resultModeText }}
          </span>
        </template>
        <Placeholder v-if="error && !hitCards.length" :error="'检索失败: ' + error" />
        <Placeholder v-else-if="!hitCards.length" text="没有命中的媒体" />
        <template v-else>
          <div class="small" style="color: var(--warning)" v-if="error">本次请求失败：{{ error }}</div>
          <div class="scroll-panel tall">
            <div class="media-grid wide">
              <MediaTile
                v-for="card in hitCards"
                :key="card.id"
                :src="card.thumb"
                :caption="card.name + (card.scoreText ? ' · ' + card.scoreText : '')"
                :selected="card.selected"
                @click="selectHit(card)"
              />
            </div>
          </div>
          <div class="pager" v-if="pageable">
            <button class="ghost sm" :disabled="loading || loadingMore || !hasMore" @click="loadMore()">
              {{ loadingMore ? '加载中…' : (hasMore ? '加载更多（每批 ' + PAGE_SIZE + ' 张）' : '已全部加载') }}
            </button>
            <button class="ghost sm" :disabled="loading || loadingMore" @click="restart()">重新开始</button>
            <span class="small muted">已显示 {{ hits.length }} / {{ total }}</span>
          </div>
        </template>
      </Card>

      <Card v-else-if="error" title="检索">
        <Placeholder :error="'检索失败: ' + error" />
      </Card>

      <Card v-if="selectedHit" :title="'媒体详情 · ' + selectedHit.name">
        <template #actions>
          <Badge v-if="selectedHit.isVideo" kind="primary">视频</Badge>
          <Badge v-if="selectedHit.sourceText" kind="info">{{ selectedHit.sourceText }}</Badge>
          <button class="ghost sm" :disabled="loading" @click="similarTo(selectedHit.id)">以图搜图</button>
        </template>

        <div class="grid cols-2">
          <div class="col">
            <img :src="selectedHit.thumb" alt="" style="width: 100%; border-radius: 6px" />
            <div class="row">
              <button class="ghost sm" @click="reveal(selectedHit.filePath)">打开所在目录</button>
              <button class="ghost sm" :disabled="loading" @click="similarTo(selectedHit.id)">以图搜图</button>
            </div>
          </div>
          <div class="col">
            <div class="small">路径 <span class="mono">{{ selectedHit.filePath || '—' }}</span></div>
            <div class="small">类型 <span class="mono">{{ selectedHit.mimeType || '—' }}</span>
              · 体积 {{ selectedHit.size }}
              · 拍摄 {{ selectedHit.captured }}
              · {{ selectedHit.scoreText || '未评分' }}</div>

            <Placeholder v-if="detailError" :error="'获取 AI 结果失败: ' + detailError" />
            <Placeholder v-else-if="!detail" text="正在获取 /API/ai/media/:id…" />
            <template v-else>
              <div class="small">感知哈希 pHash <span class="mono">{{ detail.phash }}</span>
                · 向量 <span class="mono">{{ detail.hasVector ? '已有' : '无' }}</span>
                · 人脸 <span class="mono">{{ detail.faceCount }}</span> 张</div>
              <div class="small">
                AI 标签
                <span v-if="!detail.vlmTags.length" class="muted">（无）</span>
                <Badge v-for="tag in detail.vlmTags" :key="tag" kind="primary" style="margin-right: 4px">{{ tag }}</Badge>
              </div>
              <div class="small">描述</div>
              <div class="small muted" style="white-space: pre-wrap">{{ detail.caption || '（无）' }}</div>
              <div class="small">OCR 文字</div>
              <div class="small muted" style="white-space: pre-wrap">{{ detail.ocrText || '（无）' }}</div>
            </template>
          </div>
        </div>
      </Card>
    </div>`,
};
