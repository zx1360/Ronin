"""网页运维端冒烟：逐页 + 逐标签页检查渲染与控制台错误。

用法：``python tools/smoke_ops_web.py --base http://127.0.0.1:17275``。
仅验收显式指定的隔离实例；不启动服务。
依赖 playwright + chromium（与 comix 爬虫同一套依赖）。
"""
import argparse
import base64
import json
import os
import re
import sys

from playwright.sync_api import sync_playwright, expect

# 由显式参数或环境变量指定，不默认连接生产服务。
BASE = ""
PAGES = ["/dashboard", "/booklet", "/essay", "/ai", "/comix", "/tasks", "/logs", "/settings", "/help"]
# 渲染瑕疵：模板未替换/字段缺失会在页面上留下这些痕迹
ARTIFACTS = re.compile(r"\bundefined\b|\bNaN\b|\[object Object\]|\{\{")


def open_page(context, route):
    page = context.new_page()
    page.goto(f"{BASE}/ops/#{route}", wait_until="networkidle")
    expect(page.locator(".sidebar")).to_be_visible()
    return page


def reply(route, payload, status=200):
    route.fulfill(status=status, content_type="application/json", body=json.dumps(payload))


def persons_case(context):
    pending = []
    context.route("**/API/ai/persons", lambda route: pending.append(route))
    context.route("**/API/ai/persons/*/faces?*", lambda route: pending.append(route))
    context.route("**/API/gallery/*/thumb?*", lambda route: route.fulfill(content_type="image/png", body=PIXEL))
    context.add_init_script("""window.aborted = [];
      const fetchOriginal = window.fetch;
      window.fetch = (url, options = {}) => {
        options.signal?.addEventListener('abort', () => window.aborted.push(String(url)), {once:true});
        return fetchOriginal(url, options);
      };""")
    page = open_page(context, "/ai")
    page.get_by_role("button", name="人物", exact=True).click()
    page.wait_for_timeout(100)
    page.get_by_role("button", name="刷新", exact=True).click()
    page.wait_for_timeout(100)
    assert len(pending) == 2, "人物刷新未发起替换请求"
    people = [{"id": name, "name": name, "face_count": 1, "cover_media_id": name} for name in ("甲", "乙", "丙")]
    reply(pending.pop(), {"persons": people})
    reply(pending.pop(), {"persons": [{**people[0], "name": "过期响应"}]})
    expect(page.locator(".media-tile")).to_have_count(3)
    expect(page.locator(".content")).not_to_contain_text("过期响应")
    assert page.evaluate("aborted.includes('/API/ai/persons')")

    page.get_by_role("button", name="人脸 1", exact=True).nth(0).click()
    page.wait_for_timeout(100)
    page.get_by_role("button", name="人脸 1", exact=True).nth(1).click()
    page.wait_for_timeout(100)
    reply(pending.pop(), {"faces": [{"id": "new-face", "media_id": "乙"}], "total": 1})
    reply(pending.pop(), {"faces": [{"id": "old-face", "media_id": "甲"}], "total": 1})
    expect(page.locator(".content")).to_contain_text("new-face")
    expect(page.locator(".content")).not_to_contain_text("old-face")
    page.get_by_role("button", name="关闭", exact=True).click()
    page.locator(".media-tile").nth(0).click()
    page.locator(".media-tile").nth(1).click()
    expect(page.get_by_role("button", name="合并所选 2 组")).to_be_visible()
    page.get_by_role("button", name="刷新", exact=True).click()
    page.wait_for_timeout(100)
    reply(pending.pop(), {"persons": people[1:]})
    expect(page.locator(".media-tile.selected")).to_have_count(1)
    expect(page.locator(".media-tile.selected")).to_contain_text("乙")
    page.get_by_role("button", name="人脸 1", exact=True).first.click()
    page.wait_for_timeout(100)
    page.get_by_role("button", name="关闭", exact=True).click()
    reply(pending.pop(), {"faces": [], "total": 0})
    expect(page.locator(".content")).not_to_contain_text("暂无已归属的人脸")
    page.get_by_role("button", name="刷新", exact=True).click()
    page.wait_for_timeout(100)
    page.get_by_role("link", name="使用说明", exact=True).click()
    page.wait_for_function("aborted.filter(x => x === '/API/ai/persons').length >= 2")
    reply(pending.pop(), {"persons": people})
    expect(page.locator(".topbar")).to_contain_text("使用说明")


def polling_case(context):
    progress, held = [], []
    payload = {"enabled": True, "schema_ready": True, "pending_total": 1, "capabilities": []}
    context.route("**/API/ai/status*", lambda route: reply(route, payload))
    def on_progress(route):
        progress.append(route)
        if len(progress) >= 3:
            held.append(route)
        else:
            reply(route, payload)
    context.route("**/API/ai/progress", on_progress)
    context.add_init_script("""window.cancelled = [];
      const original = fetch;
      window.fetch = (url, options = {}) => {
        options.signal?.addEventListener('abort', () => cancelled.push(String(url)), {once:true});
        return original(url, options);
      };""")
    page = open_page(context, "/ai")
    for _ in range(60):
        if held:
            break
        page.wait_for_timeout(100)
    assert held, "活动队列未轮询"
    page.get_by_role("link", name="使用说明", exact=True).click()
    page.wait_for_function("cancelled.includes('/API/ai/progress')")
    count = len(progress)
    for route in held:
        reply(route, payload)
    page.wait_for_timeout(3500)
    assert len(progress) == count, "卸载后继续轮询"


PIXEL = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aE2cAAAAASUVORK5CYII=")


def essay_case(context):
    label_id, essay_id = "00000000-0000-4000-8000-000000000002", "00000000-0000-4000-8000-000000000003"
    timestamp = "2026-01-01T00:00:00Z"
    essay = {"id": essay_id, "title": "正式原文", "content": "原有正文", "date": timestamp, "updated_at": timestamp,
             "labels_updated_at": timestamp, "labels": [label_id], "imgs": [], "messages": [], "mood": None, "word_count": 4}
    payload = {"sync_version": 2, "cursor": 1, "tombstones": [], "essays": [essay],
               "labels": [{"id": label_id, "name": "日常", "parent_id": None, "updated_at": timestamp}]}
    writes = []
    context.route("**/API/user-data/sync/essay?*", lambda route: reply(route, payload))
    def conflict(route):
        writes.append(route.request.post_data_buffer)
        reply(route, {"error": "sync_conflict：另一端已修改，请刷新后核对"}, 409)
    context.route("**/API/user-data/edit/essay?*", conflict)
    context.add_init_script("""const originalPut = IDBObjectStore.prototype.put;
      IDBObjectStore.prototype.put = function(...args) {
        if (window.failDraft) throw new Error('模拟草稿存储失败');
        return originalPut.apply(this, args);
      };""")
    page = open_page(context, "/essay")
    page.locator(".essay-open").click()
    page.get_by_role("button", name="编辑", exact=True).click()
    page.locator(".essay-writing").fill("未发表的草稿正文")
    page.locator('input[type="file"]').set_input_files({"name": "draft.png", "mimeType": "image/png", "buffer": PIXEL})
    expect(page.get_by_role("status")).to_have_text("草稿已存本机")
    expect(page.locator(".essay-detail")).to_contain_text("原有正文")
    page.reload(wait_until="networkidle")
    page.get_by_role("button", name=re.compile("本机草稿")).click()
    page.get_by_role("button", name="继续写作", exact=True).click()
    expect(page.locator(".essay-writing")).to_have_value("未发表的草稿正文")
    image = page.locator("img[alt='附件图片']")
    expect(image).to_be_visible()
    assert image.evaluate("image => image.complete && image.naturalWidth === 1")
    page.get_by_role("button", name="保存随笔", exact=True).click()
    expect(page.locator(".toast-host")).to_contain_text("sync_conflict")
    assert len(writes) == 1
    expect(page.locator(".essay-writing")).to_have_value("未发表的草稿正文")
    essay["content"] = "另一端的新版原文"
    essay["updated_at"] = "2026-01-02T00:00:00Z"
    payload["cursor"] = 2
    page.get_by_role("button", name="保存随笔", exact=True).click()
    expect(page.locator(".toast-host")).to_contain_text("原随笔已被另一端修改或删除")
    assert len(writes) == 1, "已发现冲突仍然写入"
    page.evaluate("window.failDraft = true")
    page.locator(".essay-writing").fill("无法落盘的修改")
    page.get_by_role("link", name="使用说明", exact=True).click()
    expect(page.get_by_role("status")).to_contain_text("草稿保存失败")
    expect(page.locator(".topbar")).to_contain_text("随笔")
    assert page.evaluate("!window.dispatchEvent(new Event('beforeunload', {cancelable:true}))")
    page.evaluate("window.failDraft = false")
    page.get_by_role("link", name="使用说明", exact=True).click()
    expect(page.locator(".topbar")).to_contain_text("使用说明")
    page.get_by_role("link", name="积微 · 打卡", exact=True).click()
    page.get_by_role("button", name="新建样式", exact=True).click()
    page.get_by_role("link", name="使用说明", exact=True).click()
    expect(page.locator(".modal")).to_contain_text("未保存")
    page.locator(".modal").get_by_role("button", name="取消", exact=True).click()
    expect(page.locator(".topbar")).to_contain_text("打卡")
    page.get_by_role("link", name="使用说明", exact=True).click()
    page.locator(".modal").get_by_role("button", name="确认", exact=True).click()
    expect(page.locator(".topbar")).to_contain_text("使用说明")


def errors_case(context):
    current = [{"error": "模拟 HTTP 失败"}, 500]
    context.route("**/API/ai/persons", lambda route: reply(route, *current))
    page = open_page(context, "/ai")
    page.get_by_role("button", name="人物", exact=True).click()
    expect(page.locator(".placeholder.error")).to_contain_text("HTTP 500")
    for payload, message in [({"ok": False, "error": "模拟业务失败"}, "模拟业务失败"), (None, "有效 JSON")]:
        current[:] = [payload, 200]
        page.get_by_role("button", name="刷新", exact=True).click()
        expect(page.locator(".placeholder.error")).to_contain_text(message)
    current[:] = [{"persons": []}, 200]
    page.get_by_role("button", name="刷新", exact=True).click()
    expect(page.locator(".placeholder")).to_contain_text("暂无")
    context.route("**/API/ai/status*", lambda route: reply(route, {"error": "AI 暂不可用"}, 503))
    page.reload(wait_until="networkidle")
    expect(page.locator(".content")).to_contain_text("AI 暂不可用")
    assert page.evaluate("localStorage.length") == 0
    assert not context.cookies(), "密钥不应写入 cookie"


def interaction_checks(browser, problems, console):
    for case in (persons_case, polling_case, essay_case, errors_case):
        with browser.new_context(ignore_https_errors=True, viewport={"width": 1500, "height": 950}) as context:
            context.on("page", lambda page: page.on("pageerror", lambda error: problems.append(str(error))))
            def on_console(message):
                if message.type == "error" and not re.fullmatch(r"Failed to load resource: the server responded with a status of (409|500|503) \(.*\)", message.text):
                    console.append(message.text)
            context.on("console", on_console)
            try:
                case(context)
                print(f"专项通过: {case.__name__}", flush=True)
            except Exception as error:
                problems.append(f"{case.__name__}: {error}")


def run() -> int:
    problems: list[str] = []
    console: list[str] = []

    with sync_playwright() as p:
        browser = p.chromium.launch()
        context = browser.new_context(ignore_https_errors=True, viewport={"width": 1500, "height": 950})
        page = context.new_page()
        page.on("console", lambda m: console.append(f"[{m.type}] {m.text}") if m.type == "error" else None)
        page.on("pageerror", lambda e: problems.append(f"pageerror: {e}"))

        page.goto(f"{BASE}/ops/", wait_until="networkidle", timeout=30000)
        try:
            page.wait_for_selector(".sidebar", timeout=15000)
        except Exception:
            problems.append("页面未渲染出侧边栏（请确认服务已运行且通过本机地址访问）")
            browser.close()
            report(problems, console)
            return 1

        for route in PAGES:
            page.evaluate("(r) => { window.location.hash = r; }", route)
            page.wait_for_timeout(2000)

            tabs = page.query_selector_all(".tabs button")
            stops = [("(默认)", None)] + [(t.inner_text().strip(), i) for i, t in enumerate(tabs)]
            for label, index in stops:
                if index is not None:
                    page.query_selector_all(".tabs button")[index].click()
                    page.wait_for_timeout(1500)
                text = page.inner_text(".content")
                if len(text) < 20:
                    problems.append(f"{route} [{label}] 内容为空")
                found = sorted(set(ARTIFACTS.findall(text)))
                if found:
                    problems.append(f"{route} [{label}] 渲染瑕疵: {', '.join(found)}")

        context.close()
        interaction_checks(browser, problems, console)
        browser.close()

    report(problems, console)
    return 1 if problems or console else 0


def report(problems: list[str], console: list[str]) -> None:
    print(f"控制台错误: {len(console)}")
    for line in console[:10]:
        print("  " + line)
    print(f"问题: {len(problems)}")
    for line in problems[:20]:
        print("  " + line)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="验收 Go 托管的 Ops 构建产物；仅指定隔离实例。")
    parser.add_argument("--base", default=os.environ.get("OPS_SMOKE_BASE"), help="隔离 Monarch 地址，例如 http://127.0.0.1:17275")
    args = parser.parse_args()
    if not args.base:
        parser.error("必须通过 --base 或 OPS_SMOKE_BASE 显式指定隔离实例")
    from urllib.parse import urlparse
    target = urlparse(args.base)
    if target.scheme not in ("http", "https") or target.hostname not in ("127.0.0.1", "localhost", "::1") or target.path not in ("", "/") or target.query or target.fragment or target.username:
        parser.error("地址必须是无路径和凭据的本机 HTTP(S) 隔离实例")
    BASE = args.base.rstrip("/")
    sys.exit(run())
