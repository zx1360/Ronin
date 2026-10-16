let database;

function open() {
  if (!database) database = new Promise((resolve, reject) => {
    const request = indexedDB.open('northstar-essay-drafts', 1);
    request.onupgradeneeded = () => request.result.createObjectStore('drafts', { keyPath: 'id' });
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
    request.onblocked = () => reject(new Error('草稿库被其他页面占用，请关闭旧页面后重试'));
  });
  return database;
}

export async function draftStore(action, value) {
  const db = await open();
  return new Promise((resolve, reject) => {
    const tx = db.transaction('drafts', action === 'getAll' ? 'readonly' : 'readwrite');
    const request = tx.objectStore('drafts')[action](value);
    tx.oncomplete = () => resolve(request.result);
    tx.onerror = () => reject(tx.error);
    tx.onabort = () => reject(tx.error || new Error('草稿保存已中断'));
  });
}
