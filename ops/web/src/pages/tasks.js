import { ref, onMounted, onUnmounted } from '../vue.js';
import { navigate } from '../store.js';
import TaskHistory from './logs.js';
import GalleryTasks from './gallery-tasks.js';

export default {
  components: { TaskHistory, GalleryTasks },
  setup() {
    const params = () => new URLSearchParams(location.hash.split('?')[1]);
    const tab = ref(params().get('tab') === 'gallery' ? 'gallery' : 'history');
    const form = ref({ mode: 'ingest', concurrency: 10, batch: 160, resizePreview: 0, resizeThumb: 0 });
    const syncTab = () => { tab.value = params().get('tab') === 'gallery' ? 'gallery' : 'history'; };
    const selectTab = (value) => {
      const query = params();
      if (value === 'gallery') query.set('tab', value); else query.delete('tab');
      navigate('/tasks' + (query.size ? '?' + query : ''));
    };
    onMounted(() => window.addEventListener('hashchange', syncTab));
    onUnmounted(() => window.removeEventListener('hashchange', syncTab));
    return { tab, form, selectTab };
  },
  template: `
    <div>
      <div class="tabs">
        <button :class="{ active: tab === 'history' }" @click="selectTab('history')">任务与日志</button>
        <button :class="{ active: tab === 'gallery' }" @click="selectTab('gallery')">媒体库维护</button>
      </div>
      <TaskHistory v-if="tab === 'history'" />
      <GalleryTasks v-else :form="form" />
    </div>`,
};
