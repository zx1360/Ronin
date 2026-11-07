import { ref } from '../vue.js';
import TaskHistory from './logs.js';
import GalleryTasks from './gallery-tasks.js';

export default {
  components: { TaskHistory, GalleryTasks },
  setup() { return { tab: ref('history') }; },
  template: `
    <div>
      <div class="tabs">
        <button :class="{ active: tab === 'history' }" @click="tab = 'history'">任务与日志</button>
        <button :class="{ active: tab === 'gallery' }" @click="tab = 'gallery'">媒体库维护</button>
      </div>
      <TaskHistory v-if="tab === 'history'" />
      <GalleryTasks v-else @started="tab = 'history'" />
    </div>`,
};
