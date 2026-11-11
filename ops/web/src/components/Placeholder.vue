<script>
export default {
  props: { text: { type: String, default: '暂无数据' }, error: { type: String, default: '' } },
};
</script>

<template>
  <div class="placeholder" :class="{ error: !!error }">{{ error || text }}</div>
</template>
