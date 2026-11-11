<script>
export default {
  props: { kind: { type: String, default: '' }, text: { type: String, default: '' } },
};
</script>

<template>
  <span class="badge" :class="kind"><slot>{{ text }}</slot></span>
</template>
