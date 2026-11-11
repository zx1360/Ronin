<script>
import { state, resolveDialog } from '../store.js';
export default {
  setup() {
    return { state, resolveDialog };
  },
};
</script>

<template>
  <div class="modal-mask" v-if="state.dialog" @click.self="resolveDialog(false)">
    <div class="modal">
      <h3>{{ state.dialog.title }}</h3>
      <p style="white-space: pre-wrap; margin: 0 0 4px">{{ state.dialog.message }}</p>
      <div class="modal-actions">
        <button @click="resolveDialog(false)">取消</button>
        <button class="primary" :class="{ danger: state.dialog.danger }" @click="resolveDialog(true)">
          确认
        </button>
      </div>
    </div>
  </div>
</template>
