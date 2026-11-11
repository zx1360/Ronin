"""网页运维端冒烟：逐页 + 逐标签页检查渲染与控制台错误。

用法：``python tools/smoke_ops_web.py --base http://127.0.0.1:17275``。
仅验收显式指定的隔离实例；不启动服务。
依赖 playwright + chromium（与 comix 爬虫同一套依赖）。
"""
import argparse
import os
import re
import sys

from playwright.sync_api import sync_playwright

# 由显式参数或环境变量指定，不默认连接生产服务。
BASE = ""
PAGES = ["/dashboard", "/booklet", "/essay", "/ai", "/comix", "/tasks", "/logs", "/settings", "/help"]
# 渲染瑕疵：模板未替换/字段缺失会在页面上留下这些痕迹
ARTIFACTS = re.compile(r"\bundefined\b|\bNaN\b|\[object Object\]|\{\{")


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
