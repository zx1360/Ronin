# Ops SFC / 数据库边界续做清单

用户于 2026-11-11 要求立即收尾，额度恢复后续做。当前尚未完成全部验收；没有提交、推送或发布。开始时 Git 干净，当前改动均为本次任务。

## 已落地与验证

- Ops 全部字符串模板改为 Vue SFC，直接导入组件；Vue 手工 vendor 文件、vue.js 与 ui.js 旧入口已删除。保留 JavaScript、hash 路由、轻量 store、usePolling/useSelection、IndexedDB 草稿。
- npm 锁定 Vue 3.5.45、Vite 8.3.8、plugin-vue 6.0.10；本机 Node 24.13.1。base=/ops/，生产产物在 ops/web/dist；正式运行无需 Node/CDN。只有 build/watch，没有独立 dev server。
- api.js 增加 useApi 生命周期绑定，页面卸载时取消请求；人物列表补取消/乱序保护及选择保留。以上行为需专项验收，不能只根据构建判定正确。
- 默认 OPS_WEB_DIR 改为 ../ops/web/dist，托管检查 index.html。现有 backend/.env 可能仍显式指向 ../ops/web（route-export 输出已见旧路径），尚未修改生产配置！用户实际使用前应改成构建目录。
- 非漫画域仍在 references/db/sqlite.sql；漫画表和触发器移到 references/db/comix.sql。Monarch/Gallery 复用 Go 事务初始化及补列；Gallery InitGallery 保持 synchronous=FULL 并能初始化新库；comix init 只执行共享漫画 SQL，不再建其他域。没有实际漫画补列迁移；未来升级需单一共享入口，不能双方各写一套。
- 初始化先给旧表补列，再执行 schema，整个过程 BEGIN IMMEDIATE；去掉全局 user_version=1 重置。新增旧库保留/幂等/回滚回归测试位于原 db_test.go，均通过。
- verify.ps1 支持显式 backend/android/ops/contracts/all；默认不启动服务，OpsBase 显式指定隔离实例才跑浏览器。smoke_ops_web.py 不再默认连 7275。
- 已通过：verify.ps1 -Scope backend（go build ./...、vet、test、主程序与 Gallery 构建、references -Check）；npm ci/build；原有 10 项 Ops 契约测试。
- 已通过：verify.ps1 -Scope ops -OpsBase http://127.0.0.1:17275，在编译 exe 托管的 dist 上逐页/标签页冒烟，控制台错误 0、问题 0。

## 下次按优先级处理

1. 清理 .acceptance-ops 临时目录。隔离 cmd.exe PID 19168 已停止。目录含独立 test.db、测试配置、证书及运行输出；没有使用生产数据库/媒体写入试验。PowerShell Remove-Item 被自动审批拒绝（仅提示 blocked by policy）；尚未删除，不能提交这些文件。
2. 补完专项浏览器验收：人物列表/人脸请求乱序和取消、多选刷新保留；卸载后的请求和轮询停止；随笔草稿含图片恢复、未保存离开提醒和冲突；HTTP/ok:false/无效 JSON/空列表/AI 503。原冒烟仅逐页和标签页，不覆盖这些。
3. 检查 useApi 批量改动的边缘行为与格式：catch 中取消判断、组件卸载后异步 continuation/写入后刷新；AI 原有 inFlight/pendingRefresh 与 usePolling 是否重复、能否简化。不要再叠加请求管理层。
4. 独立 comix init 和 Gallery CLI 的真实隔离运行尚未验收；验证先 comix 初始化再 Monarch/Gallery、反向顺序、重复初始化保留数据、跨进程写锁；漫画当前仅 schema 无实际补列转换。补足必要回归到原测试，临时试验脚本用完删除。
5. 同步其余文档：docs/architecture/{README,northstar,maintenance,monarch}.md、backend/AGENTS_DB.md、backend/references/distribution.md、comix/docs/架构设计.md 等仍可能写旧无构建方案和单一 sqlite.sql。ops/AGENTS.md、ops/README.md、backend/AGENTS.md、comix/AGENTS.md 已先更新。
6. 统一入口还需验证 android/contracts/all 分支与失败退出码；本轮没有运行 Android 和完整跨端 contracts。当前 HTTP/CLI 参数未变，路由快照 -Check 通过。
7. 完成后复查完整 diff（大量 SFC 是未跟踪新文件，git diff --stat 单独看会误判删除）。更新代码增减统计、清理临时文件，交付完整验收结果。不要提交或推送。

## 使用命令

仓库根：`pwsh -File verify.ps1 -Scope backend`；`pwsh -File verify.ps1 -Scope ops -OpsBase http://127.0.0.1:<隔离端口>`；其他 Scope 同名。
构建：`npm.cmd ci --prefix ops/web`、`npm.cmd run build --prefix ops/web`；开发在 ops/web 下 `npm.cmd run watch`，通过 Monarch 刷新。
隔离实例必须在独立工作目录准备 cert 子目录（服务不会替它创建目录）、显式隔离 DATA_DIR/DB_FILE/STATIC_DIR/GALLERY_DIR/COMIC_STORAGE_ROOT，DB_SCHEMA_FILE 指向仓库 sqlite.sql（同目录须有 comix.sql），AI_ENABLED=false；用编译 exe，禁止 go run。

## 当前代码行变化

统计对比 HEAD，包含未跟踪源码，识别 pages/*.js → *.vue；不含临时目录、忽略的 dist/node_modules 和本交接文件。增加/删除是文本行，SFC 模板缩进变化计入，不能用总 churn 声称复杂度下降。

- 手写代码：+2488 / -2277（净 +211）。
- 生成代码：+1020 / -0（净 +1020）。
- 测试：+90 / -3（净 +87）。
- 构建配置：+62 / -0（净 +62）。
- 文档：+11 / -7（净 +4）。

锁文件按生成代码统计；vendor 原本被 Git 忽略，删除未计入瘦身。原测试未删除。
