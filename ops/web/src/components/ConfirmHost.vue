<script>
import { ref, watchEffect } from 'vue';
import { state, resolveDialog } from '../store.js';
export default {
  setup() {
    const dialog = ref(null);
    watchEffect(() => {
      const element = dialog.value;
      if (!element) return;
      if (state.dialog && !element.open) element.showModal();
      else if (!state.dialog && element.open) element.close();
    }, { flush: 'post' });
    function cancelOutside(event) {
      const { left, right, top, bottom } = dialog.value.getBoundingClientRect();
      if (event.clientX < left || event.clientX > right || event.clientY < top || event.clientY > bottom) resolveDialog(false);
    }
    return { state, dialog, resolveDialog, cancelOutside };
  },
};
</script>

<template>
  <dialog ref="dialog" class="modal confirm-dialog" aria-labelledby="confirm-title"
    aria-describedby="confirm-message" @cancel.prevent="resolveDialog(false)" @click.self="cancelOutside">
    <template v-if="state.dialog">
      <h3 id="confirm-title">{{ state.dialog.title }}</h3>
      <p id="confirm-message" style="white-space: pre-wrap; margin: 0 0 4px">{{ state.dialog.message }}</p>
      <div class="modal-actions">
        <button @click="resolveDialog(false)">取消</button>
        <button class="primary" :class="{ danger: state.dialog.danger }" @click="resolveDialog(true)">
          确认
        </button>
      </div>
    </template>
  </dialog>
</template>
