<script>
import { ref } from 'vue';
import { navigate } from '../store.js';
import Card from '../components/Card.vue';
import Placeholder from '../components/Placeholder.vue';
import { FILTERS, TABS } from './comix/helpers.js';
import { useComixBoard } from './comix/board.js';

export default {
  components: { Card, Placeholder },
  setup() {
    const board = useComixBoard();
    const tab = ref('url');

    const selectTab = (name) => {
      tab.value = name;
      board.onTabChange(name);
    };

    return { ...board, navigate, tab, selectTab, TABS, FILTERS };
  },
};
</script>

<template>
  <div>
    <div class="tabs">
      <button v-for="item in TABS" :key="item.value"
              :class="{ active: tab === item.value }" @click="selectTab(item.value)">
        {{ item.label }}
      </button>
      <button @click="navigate('/tasks')">任务与日志 ↗</button>
    </div>

    <!-- ============ 网址下载 ============ -->
    <template v-if="tab === 'url'">
      <Card title="网址下载">
        <div class="col">
          <div class="small muted">粘贴漫画详情页网址，自动识别站点并下载（每行一个，按提交顺序排队下载）</div>
          <textarea v-model="urlInput" rows="6" placeholder="https://www.xmanhua.net/m27836/"></textarea>
          <div class="row">
            <label class="field" style="width: 220px">
              仅下载最新 N 章（留空=全部）
              <input v-model="latestInput" placeholder="例如 20" />
            </label>
            <span class="small muted" style="flex: 1; min-width: 240px">
              留空将下载全部未完成章节（大章节漫画耗时较长，建议先限量试跑）
            </span>
          </div>
          <div class="row">
            <button class="primary" :disabled="submitting || !comixAvailable" @click="submitUrls()">
              {{ submitting ? '提交中…' : '开始下载' }}
            </button>
            <span class="small" style="color: var(--warning)" v-if="!comixAvailable">
              comix 不可用，无法提交下载
            </span>
          </div>
        </div>

        <Placeholder v-if="tasksError" :error="tasksError" />
        <div v-if="submitResults.length" style="margin-top: 16px">
          <h2 class="section-title">提交结果</h2>
          <table class="data">
            <thead>
              <tr><th>网址</th><th>站点</th><th>任务</th><th>状态</th><th>说明</th></tr>
            </thead>
            <tbody>
              <tr v-for="(item, index) in submitResults" :key="index">
                <td class="mono">{{ item.url }}</td>
                <td>{{ item.site || '—' }}</td>
                <td><button v-if="item.taskId" class="ghost sm" @click="navigate('/tasks?task=' + encodeURIComponent('comix:' + item.taskId))">{{ item.taskId }} ↗</button><span v-else>—</span></td>
                <td><span class="badge" :class="item.kind">{{ item.text }}</span></td>
                <td class="small">
                  <div v-if="item.reason" style="color: var(--error)">{{ item.reason }}</div>
                  <div class="muted" v-if="item.summary">{{ item.summary }}</div>
                  <span class="muted" v-if="!item.reason && !item.summary">—</span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </Card>
      <details :open="!comixAvailable || !!configError">
        <summary>运行环境与支持站点</summary>
        <Card title="comix 集成">
          <template #actions>
            <span class="badge" :class="comixAvailable ? 'success' : 'error'">
              {{ comixAvailable ? '可用' : '不可用' }}
            </span>
            <button class="ghost sm" :disabled="initRunning" @click="runInit()">
              {{ initRunning ? '初始化中…' : '初始化（建表并注册站点）' }}
            </button>
          </template>
          <Placeholder v-if="configError" :error="'获取 comix 配置失败: ' + configError" />
          <div class="col" v-else>
            <div class="small" style="color: var(--warning)" v-if="!comixAvailable">
              comix 不可用{{ comixMessage ? '：' + comixMessage : '：请检查服务端 COMIX_PYTHON / COMIX_ROOT 配置' }}
            </div>
            <div class="small muted" v-else>comix 已就绪{{ comixMessage ? '：' + comixMessage : '' }}</div>
            <div class="small muted">
              Python: <span class="mono">{{ comixPython }}</span>
              · 根目录: <span class="mono">{{ comixRoot }}</span>
            </div>
          </div>
        </Card>

        <Card title="支持站点">
          <template #actions>
            <button class="ghost sm" @click="loadSites()">刷新</button>
          </template>
          <Placeholder v-if="sitesError"
                       :error="'站点列表不可用: ' + sitesError + '（comix 表可能尚未初始化，可执行上方「初始化」）'" />
          <Placeholder v-else-if="!sites.length" text="暂无已注册站点" />
          <div class="row" v-else>
            <span v-for="site in sites" :key="site.code" class="badge" :class="site.enabled ? 'info' : ''">
              {{ site.name }} ({{ site.code }}){{ site.enabled ? '' : ' · 已停用' }}
            </span>
          </div>
        </Card>
      </details>
    </template>

    <!-- ============ 漫画库 ============ -->
    <template v-else-if="tab === 'library'">
      <Card title="漫画库">
        <template #actions>
          <button class="ghost sm" @click="loadComics()">刷新</button>
        </template>
        <div class="row">
          <label class="field" style="min-width: 240px">
            搜索标题 / 站点 / ID
            <input v-model="keyword" placeholder="关键字" />
          </label>
          <label class="field">
            状态过滤
            <select v-model="statusFilter">
              <option v-for="item in FILTERS" :key="item.value" :value="item.value">{{ item.label }}</option>
            </select>
          </label>
          <label class="row small muted" style="gap: 6px; padding-top: 16px">
            <input type="checkbox" v-model="checkDownload" /> 追更检查后自动下载新章节
          </label>
          <label class="field" style="width: 180px" v-if="checkDownload">
            仅取最新 N 章（留空=全部）
            <input v-model="checkLatest" placeholder="例如 5" />
          </label>
          <span class="spacer"></span>
          <button @click="runUpdateCheck(null, true)">全站追更检查</button>
          <button class="ghost" @click="runClean()">孤儿回收</button>
        </div>
        <div class="small muted">
          共 {{ comics.length }} 部 · 匹配 {{ filteredComics.length }} 部
        </div>

        <Placeholder v-if="comicsError" :error="'漫画库加载失败: ' + comicsError" />
        <Placeholder v-else-if="comicsLoading && !comics.length" text="正在加载漫画库…" />
        <Placeholder v-else-if="!filteredComics.length"
                     :text="comics.length ? '没有匹配的漫画' : '暂无已登记漫画'" />
        <div class="media-grid" v-else style="grid-template-columns: repeat(auto-fill, minmax(220px, 1fr))">
          <div class="media-tile" v-for="comic in filteredComics" :key="comic.comic_id">
            <img v-if="comic.coverPath" :src="comic.coverPath" loading="lazy" alt="" style="height: 180px" />
            <div v-else style="height: 180px; display: flex; align-items: center; justify-content: center; background: #111; color: var(--on-surface-variant); font-size: 12px">
              无封面
            </div>
            <div class="meta">
              <div style="font-size: 12px; font-weight: 600; color: var(--on-surface)">{{ comic.title }}</div>
              <div>{{ comic.site_name || comic.site || '未知站点' }} · #{{ comic.comic_id }}</div>
              <div class="row" style="gap: 4px; margin: 4px 0">
                <span class="badge">{{ comic.chapter_count }} 章 / {{ comic.image_count }} 图</span>
                <span class="badge" :class="comic.pending > 0 ? 'warning' : 'success'">
                  {{ comic.downloaded }}/{{ comic.total_chapters }}
                </span>
                <span class="badge error" v-if="comic.failed > 0">失败 {{ comic.failed }}</span>
                <span class="badge" :class="comic.is_public ? 'success' : 'warning'">
                  {{ comic.is_public ? '公开' : '隐藏' }}
                </span>
                <span class="badge info" v-if="comic.readed">已读</span>
                <span class="badge" v-if="comic.is_legacy">legacy</span>
              </div>
              <div class="progress" :title="comic.downloaded + '/' + comic.total_chapters">
                <div :style="{ width: comic.percent + '%' }"></div>
              </div>
              <div class="row" style="gap: 4px; margin-top: 6px">
                <button class="sm" @click="openDownload(comic)">下载</button>
                <button class="sm" :disabled="comic.is_legacy"
                        :title="comic.is_legacy ? 'legacy 资源不参与追更' : '追更检查'"
                        @click="runUpdateCheck(comic, false)">追更</button>
                <button class="sm" @click="openChapters(comic)">章节</button>
                <button class="sm" @click="togglePublic(comic)">{{ comic.is_public ? '隐藏' : '公开' }}</button>
                <button class="sm" @click="toggleReaded(comic)">{{ comic.readed ? '标未读' : '标已读' }}</button>
                <button class="sm danger" @click="removeComic(comic)">删除</button>
              </div>
            </div>
          </div>
        </div>
      </Card>

      <Card v-if="downloadTarget" :title="'增量下载：' + downloadTarget.title">
        <div class="col">
          <div class="small muted">
            已下载 {{ downloadTarget.downloaded }}/{{ downloadTarget.total_chapters }} 章，未下载 {{ downloadTarget.pending }} 章
            <span v-if="downloadTarget.failed > 0">，失败 {{ downloadTarget.failed }} 章（会重试）</span>
          </div>
          <div class="grid cols-3">
            <label class="field">
              仅下载最新 N 章（留空=全部待下载章节）
              <input v-model="downloadForm.latest" placeholder="例如 10" />
            </label>
            <label class="field">
              章节区间（如 1-5,8，与最新 N 章二选一）
              <input v-model="downloadForm.range" placeholder="1-5,8" />
            </label>
            <label class="row small muted" style="gap: 6px; padding-top: 16px">
              <input type="checkbox" v-model="downloadForm.noRetryFailed" /> 不重试失败章节
            </label>
          </div>
          <div class="small" style="color: var(--error)" v-if="downloadError">{{ downloadError }}</div>
          <div class="row">
            <button class="primary" @click="submitDownload()">开始下载</button>
            <button class="ghost" @click="downloadTarget = null">取消</button>
          </div>
        </div>
      </Card>

      <Card v-if="chaptersComic" :title="'章节：' + chaptersComic.title">
        <template #actions>
          <button class="ghost sm" @click="closeChapters()">关闭</button>
        </template>
        <Placeholder v-if="chaptersError" :error="'加载章节失败: ' + chaptersError" />
        <Placeholder v-else-if="chaptersLoading" text="正在加载章节…" />
        <template v-else>
          <div class="row">
            <div class="small muted">
              共 {{ chapters.length }} 章 · 已下载 {{ chapterDoneCount }} · 失败 {{ chapterFailedCount }}
            </div>
            <label class="field" style="min-width: 220px; margin-left: auto">
              过滤（标题 / 章节号 / 状态）
              <input v-model="chapterKeyword" />
            </label>
          </div>
          <table class="data" v-if="filteredChapters.length">
            <thead>
              <tr><th>章节</th><th>标题</th><th>状态</th><th>页数</th><th>目录 / 错误</th></tr>
            </thead>
            <tbody>
              <tr v-for="chapter in filteredChapters" :key="chapter.id">
                <td>{{ chapter.chapter_no }}</td>
                <td>{{ chapter.title || '—' }}</td>
                <td><span class="badge" :class="chapter.statusKind">{{ chapter.statusText }}</span></td>
                <td>{{ chapter.page_count }}</td>
                <td class="small mono">
                  {{ chapter.status === 'failed' && chapter.error ? chapter.error : (chapter.rel_dir || '—') }}
                </td>
              </tr>
            </tbody>
          </table>
          <Placeholder v-else text="没有匹配的章节" />
        </template>
      </Card>
    </template>

  </div>
</template>
