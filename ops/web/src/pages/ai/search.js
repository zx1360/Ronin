// 检索：文本搜图 / 以图搜图（本地上传或库内相似媒体），带结构化筛选与媒体 AI 结果详情。
//
// 筛选口径与后端 /API/ai/search 一致：tag_ids 为人工标签、vlm_tags 为 AI 标签
// （只读，与人工标签物理隔离）、person_ids、mime_type、from/to。

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
    const hits = ref([]);
    const total = ref(0);
    const resultMode = ref('');
    const searched = ref(false);
    const loading = ref(false);
    const uploading = ref(false);
    const error = ref('');
    const imageName = ref('');
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
    const buildQuery = (withText) => {
      const params = ['mode=' + encodeURIComponent(mode.value || 'auto'), 'limit=60', 'offset=0'];
      if (withText && query.value.trim()) params.push('q=' + encodeURIComponent(query.value.trim()));
      if (filters.value.tagIds.length) params.push('tag_ids=' + encodeURIComponent(filters.value.tagIds.join(',')));
      if (filters.value.vlmTags.length) params.push('vlm_tags=' + encodeURIComponent(filters.value.vlmTags.join(',')));
      if (filters.value.personIds.length) params.push('person_ids=' + encodeURIComponent(filters.value.personIds.join(',')));
      if (filters.value.mimeType) params.push('mime_type=' + encodeURIComponent(filters.value.mimeType));
      if (filters.value.from) params.push('from=' + encodeURIComponent(filters.value.from));
      if (filters.value.to) params.push('to=' + encodeURIComponent(filters.value.to));
      return params.join('&');
    };

    const applyResult = (data) => {
      hits.value = Array.isArray(data && data.hits) ? data.hits : [];
      total.value = num(data && data.total);
      resultMode.value = (data && data.mode) || '';
      searched.value = true;
      selectedId.value = '';
      detail.value = null;
      detailError.value = '';
    };

    const search = async () => {
      loading.value = true;
      error.value = '';
      try {
        const data = await api.get('/API/ai/search?' + buildQuery(true), { timeoutMs: 600000 });
        applyResult(data);
      } catch (err) {
        error.value = err.message;
      } finally {
        loading.value = false;
      }
    };

    const similarTo = async (id) => {
      loading.value = true;
      error.value = '';
      try {
        const data = await api.get('/API/ai/similar/' + id + '?limit=40', { timeoutMs: 600000 });
        applyResult(data);
        toast('已按所选图片查找相似媒体', 'success');
      } catch (err) {
        error.value = err.message;
      } finally {
        loading.value = false;
      }
    };

    const clearResult = () => {
      hits.value = [];
      total.value = 0;
      resultMode.value = '';
      searched.value = false;
      error.value = '';
      selectedId.value = '';
      detail.value = null;
      detailError.value = '';
      imageName.value = '';
    };

    const pickImage = () => {
      if (imageInput.value) imageInput.value.click();
    };

    /** 以图搜图：multipart 上传（字段名 image，与后端一致），查询条件走 URL。 */
    const onImagePicked = async (event) => {
      const file = event.target.files && event.target.files[0];
      if (!file) return;
      imageName.value = file.name;
      uploading.value = true;
      error.value = '';
      try {
        const form = new FormData();
        form.append('image', file, file.name);
        const url = assetUrl('/API/ai/search/image?' + buildQuery(false));
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
        applyResult(payload);
      } catch (err) {
        error.value = err && err.message ? err.message : String(err);
      } finally {
        uploading.value = false;
        event.target.value = '';
      }
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
      query, mode, filters, hits, total, resultMode, searched, loading, uploading, error,
      imageName, imageInput, tagOptions, vlmTagOptions, personOptions, filterError,
      hitCards, selectedHit, detail, detailError, MODES, MIME_TYPES,
      search, similarTo, clearResult, pickImage, onImagePicked, selectHit, loadFilters, baseName,
      reveal: revealMedia,
    };
  },
  template: `
    <div>
      <Card title="检索">
        <div class="row">
          <input
            v-model="query"
            style="flex: 1; min-width: 240px"
            :placeholder="mode === 'filename' ? '文件名或扩展名，例如：IMG_2024、.mp4' : '用自然语言描述想要的画面，例如：可爱的猫娘、夜景街道'"
            @keyup.enter="search()"
          />
          <select v-model="mode" style="min-width: 200px">
            <option v-for="item in MODES" :key="item.value" :value="item.value">{{ item.label }}</option>
          </select>
          <button class="primary sm" :disabled="loading" @click="search()">{{ loading ? '检索中…' : '搜索' }}</button>
          <button class="ghost sm" @click="clearResult()">清空</button>
          <button class="ghost sm" :disabled="uploading" @click="pickImage()">
            {{ uploading ? '上传检索中…' : '以图搜图（本地上传）' }}
          </button>
          <input ref="imageInput" type="file" accept="image/*" style="display: none" @change="onImagePicked" />
        </div>
        <div class="small muted" style="margin-top: 6px">
          智能模式有文本即走语义检索并把 OCR/描述/关键词命中加权；文字模式只匹配 OCR/描述/AI 关键词；
          文件名模式只匹配文件路径。以图搜图上传的图片只用于本次查询，不落库。
          <span v-if="imageName"> 已选文件：<span class="mono">{{ imageName }}</span></span>
        </div>

        <div class="grid cols-3" style="margin-top: 12px">
          <label class="field">
            人工标签（任一命中，可多选）
            <select multiple size="4" v-model="filters.tagIds">
              <option v-for="item in tagOptions" :key="item.id" :value="item.id">{{ item.label }}（{{ item.count }}）</option>
            </select>
          </label>
          <label class="field">
            AI 标签（只读，与人工标签隔离）
            <select multiple size="4" v-model="filters.vlmTags">
              <option v-for="item in vlmTagOptions" :key="item.id" :value="item.id">{{ item.label }}（{{ item.count }}）</option>
            </select>
          </label>
          <label class="field">
            人物分组
            <select multiple size="4" v-model="filters.personIds">
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
        <div class="small" style="color: var(--warning)" v-if="filterError">{{ filterError }}</div>
        <div class="small" style="color: var(--warning)" v-if="aiDisabled">
          AI 处理层已通过 AI_ENABLED=false 关闭，检索接口可能不可用。
        </div>
      </Card>

      <Card v-if="searched" title="结果">
        <template #actions>
          <span class="small muted">命中 {{ total }} 条 · 模式 {{ resultMode || '—' }}</span>
        </template>
        <Placeholder v-if="error" :error="'检索失败: ' + error" />
        <Placeholder v-else-if="!hitCards.length" text="没有命中的媒体" />
        <div class="media-grid" v-else>
          <MediaTile
            v-for="card in hitCards"
            :key="card.id"
            :src="card.thumb"
            :caption="card.name + (card.scoreText ? ' · ' + card.scoreText : '')"
            :selected="card.selected"
            @click="selectHit(card)"
          />
        </div>
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
