/** 将轻量进度合入诊断快照，保留就绪信息、候选模型与媒体统计。 */
export function mergeProgress(previous, progress) {
  const queue = new Map((progress.queue || []).map((item) => [item.capability, item]));
  const sidecars = new Map((progress.sidecars || []).map((item) => [item.capability, item]));
  return {
    ...previous, ...progress,
    ollama: { ...previous?.ollama, ...progress.ollama },
    capabilities: (previous?.capabilities || []).map((cap) => {
      const stat = queue.get(cap.capability);
      const sidecar = sidecars.get(cap.capability);
      return {
        ...cap,
        pending: (stat?.pending || 0) + (stat?.running || 0),
        failed: stat?.failed || 0,
        done: stat?.done || 0,
        ...(sidecar ? { sidecar: { ...cap.sidecar, ...sidecar } } : {}),
      };
    }),
  };
}
