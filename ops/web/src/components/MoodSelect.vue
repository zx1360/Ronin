<script>
import { moods } from '../pages/user-data.js';
export default {
  props: ['modelValue'], emits: ['update:modelValue'],
  setup: () => ({ moods }),
};
</script>

<template>
  <select aria-label="心情" :value="modelValue || ''" @change="$emit('update:modelValue', $event.target.value || null)">
    <option value="">不记录心情</option>
    <option v-for="m in moods" :value="m.value">{{ m.label }}</option>
  </select>
</template>
