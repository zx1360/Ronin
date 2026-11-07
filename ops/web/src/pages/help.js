import { state } from '../store.js';
import { Card } from '../ui.js';

export default {
  components: { Card },
  setup: () => ({ state }),
  template: `
    <div>
      <Card title="从哪里开始">
        <div class="col">
          <p>「工作台」查看服务是否可用；「任务中心」统一查看媒体与漫画任务的状态、结果和日志，也可提交媒体导入与修复。</p>
          <p>「AI 与检索」管理模型与处理队列；「漫画管理」负责搜索、下载、追更与漫画库整理。任务完成前可离开页面，Monarch 会继续处理。</p>
        </div>
      </Card>
      <Card title="手机与电脑共同编辑">
        <div class="col">
          <p>正式随笔、标签、打卡样式和记录由后端保存。手机支持离线编辑，连接后手动同步；网页直接在线编辑。</p>
          <p>网页提交时若另一端已有更新，本次修改会被拒绝。先保留输入、刷新并核对最新版本，再决定如何保存。随笔冲突时可保留本机草稿，或另存为新随笔。</p>
          <p>手机离线数据按更新时间合并，同一条记录较新的版本生效，删除也会传播。请保持设备时钟准确；在另一端继续编辑前先同步手机。</p>
          <p>网页随笔草稿与草稿图片只存在当前浏览器，手机草稿与对话只存在手机。清理浏览器数据或卸载应用前，请先保存需要保留的内容。</p>
        </div>
      </Card>
      <Card title="任务与资源">
        <div class="col">
          <p>媒体库同一时间只执行一个维护任务。漫画写任务按提交顺序排队，排队时可直接取消。重启服务会清空这些任务的历史与日志，库内数据会保留。</p>
          <p>AI 队列保存在数据库中，暂停后保留待办；继续处理时从队列接续。模型按需加载并在空闲后释放。</p>
          <p>媒体导入完成后会清理对应 Raw 文件；执行媒体变更会应用编辑并将软删除文件移入 Deleted。操作前请核对说明和目标目录。</p>
        </div>
      </Card>
      <Card title="备份与迁移">
        <div class="col">
          <p>迁移前停止 Monarch 和相关下载任务，完整备份数据库、媒体库、用户附件与配置。单独复制数据库无法保留图片和漫画原件。</p>
          <div>数据库：<span class="mono">{{ state.paths.dbFile }}</span></div>
          <div>媒体库：<span class="mono">{{ state.paths.galleryDir }}</span></div>
          <div>用户附件与配置：<span class="mono">{{ state.settingsPath }}</span> 所在目录</div>
          <p class="muted">完整路径与组件状态可在「设置与连接」核对。本页面仅供本机访问。</p>
        </div>
      </Card>
    </div>`,
};
