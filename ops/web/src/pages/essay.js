import { Card, Placeholder } from '../ui.js';
import { MoodSelect, ImagePicker, imageUrl, moodText } from './user-data.js';
import MarkdownText from './essay/markdown.js';
import { useEssayBoard } from './essay/board.js';

export default {
  components: { Card, Placeholder, MoodSelect, ImagePicker, MarkdownText },
  setup() {
    return { ...useEssayBoard(), imageUrl, moodText, dateText: (date) => new Date(date).toLocaleString('zh-CN', { hour12: false }) };
  },
  template: `
    <div class="user-page">
      <div class="row between user-toolbar">
        <span class="muted">留住此刻，也重逢过去。</span>
        <div class="row">
          <button :disabled="loading || busy" @click="refresh">刷新</button>
          <button :disabled="loading" @click="reread">随机回读</button>
          <button class="primary" :disabled="busy" @click="openEditor()">写随笔</button>
        </div>
      </div>
      <Placeholder v-if="error" :error="error" />
      <Card v-if="editor" :title="original ? '编辑随笔' : '写随笔'">
        <form class="col" @submit.prevent="publish">
          <label class="field">
            标题（可选）
            <input v-model="editor.title" maxlength="200" placeholder="为这段记忆起个名字" />
          </label>
          <div class="row">
            <span class="small muted">{{dateText(editor.date)}} · {{editor.content.trim().length}} 字</span>
            <span class="spacer"></span>
            <button type="button" class="sm" @click="preview=!preview">{{preview?'继续编辑':'Markdown 预览'}}</button>
          </div>
          <MarkdownText v-if="preview" :text="editor.content" />
          <label v-else class="field">
            正文
            <textarea class="essay-writing" v-model="editor.content" rows="14" placeholder="写下今天，支持 Markdown…" required></textarea>
          </label>
          <fieldset class="user-label-picker">
            <legend>标签（1 至 4 个）</legend>
            <label v-for="l in labels" :key="l.id">
              <input type="checkbox" :checked="editor.labels.includes(l.id)" @change="toggleLabel(l.id)" />
              {{l.path}}
            </label>
            <span v-if="!labels.length" class="muted">请先到标签页创建标签</span>
          </fieldset>
          <ImagePicker v-model:images="editor.imgs" :files="files" module="essay" :max="9" @file="files.set($event.name,$event.file)" />
          <div class="row">
            <MoodSelect v-model="editor.mood" />
            <span class="small muted" role="status">{{draftStatus}}</span>
            <span class="spacer"></span>
            <button v-if="original" type="button" :disabled="busy" @click="saveAsNew">另存为新随笔</button>
            <button type="button" :disabled="busy" @click="closeEditor">收起并保留草稿</button>
            <button class="primary" :disabled="busy || loading">{{busy?'保存中…':'保存随笔'}}</button>
          </div>
          <p class="small muted">草稿及草稿图片仅保存在当前浏览器。编辑期间保留正式原文，保存成功后才更新。</p>
        </form>
      </Card>
      <div class="tabs">
        <button :class="{active:tab==='browse'}" @click="tab='browse'">随笔</button>
        <button :class="{active:tab==='labels'}" @click="tab='labels'">标签</button>
        <button :class="{active:tab==='stats'}" @click="tab='stats'">写作统计</button>
        <button :class="{active:tab==='drafts'}" @click="tab='drafts';loadDrafts()">本机草稿 · {{drafts.length}}</button>
      </div>
      <div v-if="tab==='browse' || tab==='stats'" class="row user-toolbar">
        <input class="essay-search" aria-label="全文搜索" v-model="query" placeholder="搜索标题、正文、留言；多个关键词用空格分隔" />
        <select aria-label="年份筛选" v-model="year">
          <option value="">全部年份</option>
          <option v-for="y in years" :value="y">{{y}} 年</option>
        </select>
        <select aria-label="随笔排序" v-model="sort">
          <option value="descending">最新在前</option>
          <option value="ascending">最早在前</option>
        </select>
        <select aria-label="标签筛选" v-model="labelFilter">
          <option value="">全部标签</option>
          <option v-for="l in labels" :value="l.id">{{l.path}}（含子标签）</option>
        </select>
        <label class="row small">
          <input type="checkbox" v-model="showHidden" />
          显示隐藏随笔
        </label>
      </div>
      <template v-if="tab==='browse'">
        <div class="essay-layout" :class="{ 'has-detail': !!detail }">
          <Card title="随笔列表">
            <template #actions>
              <span class="muted small">共 {{filtered.length}} 篇</span>
            </template>
            <Placeholder v-if="loading && !page.length" text="正在加载随笔…" />
            <Placeholder v-else-if="!page.length" text="没有匹配的随笔。点击「写随笔」记录一刻。" />
            <article v-for="e in page" :key="e.id" class="essay-card" :class="{selected:detailId===e.id}">
              <button class="essay-open" @click="detailId=e.id">
                <span class="small muted">{{dateText(e.date)}} · {{e.word_count}} 字</span>
                <strong>{{e.title || '无标题'}}</strong>
                <span class="essay-excerpt">{{e.content.slice(0,180)}}{{e.content.length>180?'…':''}}</span>
              </button>
              <div class="row small">
                <span v-for="id in e.labels" class="badge">{{labelName(id)}}</span>
                <span class="muted">{{moodText(e.mood)}}</span>
                <span v-if="e.imgs.length" class="muted">{{e.imgs.length}} 图</span>
                <span v-if="e.messages.length" class="muted">{{e.messages.length}} 条留言</span>
              </div>
            </article>
            <button v-if="limit<filtered.length" @click="limit+=20">加载更多（{{filtered.length-limit}}）</button>
          </Card>
          <Card v-if="detail" :title="detail.title || '随笔详情'" class="essay-detail">
            <template #actions>
              <button class="sm" :disabled="busy" @click="openEditor(detail)">编辑</button>
              <button class="sm danger" :disabled="busy" @click="removeEssay(detail)">删除</button>
              <button class="sm" @click="detailId=''">收起</button>
            </template>
            <p class="small muted">{{dateText(detail.date)}} · {{detail.word_count}} 字 · {{moodText(detail.mood)}}</p>
            <div class="row">
              <span v-for="id in detail.labels" class="badge">{{labelName(id)}}</span>
            </div>
            <MarkdownText :text="detail.content" />
            <div class="user-images">
              <a v-for="path in detail.imgs" :key="path" :href="imageUrl(path)" target="_blank" rel="noopener">
                <img :src="imageUrl(path)" loading="lazy" alt="随笔图片" />
              </a>
            </div>
            <details class="user-entry">
              <summary>留言 · {{detail.messages.length}}</summary>
              <div v-for="(m,i) in detail.messages" :key="i" class="user-entry">
                <span class="small muted">{{dateText(m.timestamp)}}</span>
                <p class="user-prose">{{m.content}}</p>
              </div>
            </details>
            <form class="col" @submit.prevent="appendMessage">
              <label class="field">
                追加留言
                <textarea v-model="message" rows="3" placeholder="后来想说的话…"></textarea>
              </label>
              <button class="primary" :disabled="busy || !message.trim()">添加留言</button>
            </form>
          </Card>
        </div>
      </template>
      <template v-else-if="tab==='labels'">
        <Card title="标签管理">
          <template #actions>
            <button class="primary" :disabled="busy || loading" @click="editLabel()">新建标签</button>
          </template>
          <p class="small muted">支持层级标签。「隐藏」及其子标签下的随笔默认不展示，也不参与随机回读。</p>
          <form v-if="labelForm" class="row user-task-editor" @submit.prevent="saveLabel">
            <label class="field">
              名称
              <input v-model="labelForm.name" required maxlength="80" />
            </label>
            <label class="field">
              上级标签
              <select v-model="labelForm.parent_id">
                <option :value="null">根级</option>
                <option v-for="l in parentOptions" :value="l.id">{{l.path}}</option>
              </select>
            </label>
            <button class="primary" :disabled="busy">保存标签</button>
            <button type="button" :disabled="busy" @click="labelForm=null">取消</button>
          </form>
          <div class="table-scroll">
            <table class="data">
              <thead>
                <tr>
                  <th>标签</th>
                  <th>直接关联随笔</th>
                  <th>操作</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="l in labels" :key="l.id">
                  <td>{{l.path}}</td>
                  <td>{{labelCount(l.id)}}</td>
                  <td>
                    <div class="row">
                      <button class="sm" :disabled="busy || protectedLabel(l)" @click="editLabel(l)">编辑</button>
                      <button class="sm danger" :disabled="busy || protectedLabel(l)" @click="removeLabel(l)">删除</button>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </Card>
      </template>
      <template v-else-if="tab==='stats'">
        <Card title="写作概览">
          <p class="small muted">统计沿用当前年份、标签、搜索及隐藏筛选。</p>
          <div class="user-stats">
            <div>
              <strong>{{stats.count}}</strong>
              <span>篇随笔</span>
            </div>
            <div>
              <strong>{{stats.words}}</strong>
              <span>字</span>
            </div>
            <div>
              <strong>{{stats.days}}</strong>
              <span>写作天数</span>
            </div>
            <div>
              <strong>{{stats.count ? Math.round(stats.words/stats.count) : 0}}</strong>
              <span>平均字数</span>
            </div>
          </div>
        </Card>
        <div class="grid cols-2">
          <Card title="月度写作">
            <Placeholder v-if="!stats.months.length" text="还没有写作记录" />
            <div v-for="[m,n] in stats.months" class="user-bar-row">
              <span>{{m}}</span>
              <meter :value="n" :max="Math.max(1,...stats.months.map(v=>v[1]))"></meter>
              <strong>{{n}} 篇</strong>
            </div>
          </Card>
          <Card title="心情分布">
            <Placeholder v-if="!stats.moods.length" text="还没有心情记录" />
            <div v-for="[m,n] in stats.moods" class="user-bar-row">
              <span>{{moodText(m)}}</span>
              <meter :value="n" :max="stats.count || 1"></meter>
              <strong>{{n}} 篇</strong>
            </div>
          </Card>
        </div>
        <Card title="标签分布">
          <Placeholder v-if="!stats.labels.length" text="还没有标签统计" />
          <div v-for="[id,n] in stats.labels" class="user-bar-row">
            <span>{{labelName(id)}}</span>
            <meter :value="n" :max="stats.count || 1"></meter>
            <strong>{{n}} 篇</strong>
          </div>
        </Card>
      </template>
      <Card v-else title="本机草稿">
        <template #actions>
          <button class="sm" @click="loadDrafts">刷新草稿</button>
        </template>
        <Placeholder v-if="draftError" :error="draftError" />
        <Placeholder v-else-if="!drafts.length" text="没有本机草稿。写作过程中会自动保存。" />
        <div v-for="d in drafts" :key="d.id" class="user-entry">
          <div class="row between">
            <strong>{{d.essay.title || '未命名草稿'}}</strong>
            <span class="small muted">{{dateText(d.saved_at)}}</span>
          </div>
          <p class="essay-excerpt">{{d.essay.content.slice(0,160)}}</p>
          <div class="row">
            <span class="muted small">{{d.original?'编辑正式随笔':'新随笔'}} · {{d.essay.imgs.length}} 图</span>
            <span class="spacer"></span>
            <button :disabled="busy" @click="openEditor(null,d)">继续写作</button>
            <button class="danger" :disabled="busy" @click="discardDraft(d)">丢弃草稿</button>
          </div>
        </div>
      </Card>
    </div>
  `,
};
