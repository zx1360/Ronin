// poll.js —— 按需轮询。
//
// 只做两件事：
//   - start()/stop()：持续的"有运行中任务时才轮询"；
//   - kick(n)：提交任务后的宽限轮询（新任务在服务端注册需要一小段时间）。
// 没有观察者（live=false 且 graceLeft<=0）时定时器会被彻底清掉，不会空转。

export function createPoller(run, { interval = 2000, grace = 15 } = {}) {
  let timer = null;
  let live = false;
  let graceLeft = 0;
  let busy = false;
  const defaultGrace = grace;

  function ensureTimer() {
    if (timer === null && (live || graceLeft > 0)) {
      timer = setInterval(() => { void tick(); }, interval);
    }
  }

  function maybeStopTimer() {
    if (!live && graceLeft <= 0 && timer !== null) {
      clearInterval(timer);
      timer = null;
    }
  }

  async function tick() {
    if (busy) return;
    busy = true;
    try {
      await run();
    } catch (err) {
      console.warn('[poll]', err);
    } finally {
      busy = false;
    }
    if (graceLeft > 0) graceLeft -= 1;
    maybeStopTimer();
  }

  return {
    start() {
      live = true;
      ensureTimer();
    },
    stop() {
      live = false;
      graceLeft = 0;
      maybeStopTimer();
    },
    /** 提交后宽限轮询：即使当前没有运行中任务，也继续跑若干轮。 */
    kick(rounds = defaultGrace) {
      graceLeft = Math.max(graceLeft, rounds);
      ensureTimer();
    },
    /** 宽限期是否还在：宽限未结束时不要急着 stop()，否则新任务会看不到。 */
    get graceActive() {
      return graceLeft > 0;
    },
    dispose() {
      live = false;
      graceLeft = 0;
      maybeStopTimer();
    },
  };
}
