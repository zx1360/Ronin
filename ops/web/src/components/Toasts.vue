<script>
import { state } from '../store.js';
export default {
  setup() {
    return { state };
  },
};
</script>

<template>
  <div class="toast-host">
    <div v-for="item in state.toasts" :key="item.id" class="toast" :class="item.kind">{{ item.message }}</div>
  </div>
</template>
