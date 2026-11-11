<script>
import { onUnmounted } from 'vue';
import { imageUrl } from '../pages/user-data.js';
import { toast } from '../store.js';
export default {
  props: { images: Array, files: Map, module: String, max: { default: 12 } },
  emits: ['update:images', 'file'],
  setup(props, { emit }) {
    const urls = new Map();
    const src = (path) => {
      const name = path.split('/').pop(), file = props.files?.get(name);
      if (!file) return imageUrl(path);
      if (!urls.has(file)) urls.set(file, URL.createObjectURL(file));
      return urls.get(file);
    };
    const pick = (event) => {
      const paths = [...props.images];
      for (const file of event.target.files) {
        if (paths.length >= props.max) break;
        if (!['image/jpeg', 'image/png', 'image/webp', 'image/gif'].includes(file.type)) { toast('请选择 JPG、PNG、WebP 或 GIF 图片', 'error'); continue; }
        const ext = { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp', 'image/gif': 'gif' }[file.type];
        const name = `${crypto.randomUUID()}.${ext}`;
        emit('file', { name, file });
        paths.push(`img_storage/${props.module}/${name}`);
      }
      emit('update:images', paths);
      event.target.value = '';
    };
    onUnmounted(() => { for (const url of urls.values()) URL.revokeObjectURL(url); });
    return { src, pick };
  },
};
</script>

<template>
  <div class="col">
    <div class="user-images">
      <figure v-for="(path,i) in images" :key="path">
        <a :href="src(path)" target="_blank" rel="noopener">
          <img :src="src(path)" loading="lazy" alt="附件图片" />
        </a>
        <button type="button" class="sm danger" @click="$emit('update:images', images.filter((_,n)=>n!==i))">移除</button>
      </figure>
    </div>
    <label v-if="images.length < max" class="field">
      添加图片
      <input type="file" accept="image/jpeg,image/png,image/webp,image/gif" :multiple="max > 1" @change="pick" />
    </label>
  </div>
</template>
