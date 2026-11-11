<script>
export default {
  props: { title: { type: String, default: '' } },
};
</script>

<template>
  <section class="card">
    <div class="row between" v-if="title || $slots.actions">
      <h2 class="section-title" v-if="title">{{ title }}</h2>
      <div class="row" v-if="$slots.actions"><slot name="actions" /></div>
    </div>
    <slot />
  </section>
</template>
