import { ref, computed } from './vue.js';

export function useSelection() {
  const selected = ref([]);
  const ids = computed(() => new Set(selected.value));
  const isSelected = (id) => ids.value.has(id);
  const toggle = (id) => {
    selected.value = isSelected(id)
      ? selected.value.filter((value) => value !== id) : [...selected.value, id];
  };
  const selectAll = (values) => { selected.value = [...new Set(values)]; };
  const clear = () => { selected.value = []; };
  const retain = (values) => {
    const alive = new Set(values);
    selected.value = selected.value.filter((id) => alive.has(id));
  };
  return { selected, ids, isSelected, toggle, selectAll, clear, retain };
}
