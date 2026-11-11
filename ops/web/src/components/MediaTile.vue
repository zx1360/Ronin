<script>
export default {
  props: {
    src: { type: String, required: true },
    caption: { type: String, default: '' },
    selected: { type: Boolean, default: false },
  },
  emits: ['click'],
};
</script>

<template>
  <div class="media-tile" :class="{ selected }" @click="$emit('click')">
    <img :src="src" loading="lazy" alt="" />
    <div class="meta" v-if="caption">{{ caption }}</div>
  </div>
</template>
