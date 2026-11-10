<script>
import { taskStatusKind, taskStatusText } from '../utils.js';
export default {
  props: { status: { type: String, default: '' } },
  computed: {
    kind() {
      return taskStatusKind(this.status);
    },
    text() {
      return taskStatusText(this.status);
    },
  },
};
</script>

<template>
  <span class="badge" :class="kind">{{ text }}</span>
</template>
