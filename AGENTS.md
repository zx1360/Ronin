# Ronin

先读[架构与数据权威](docs/architecture/instructions.md)，再读涉及端的 [Monarch](backend/AGENTS.md)、[Torrid](android/AGENTS.md) 或 [Northstar](ops/AGENTS.md) 指引。命令用 PowerShell 7。

## 验证

- 按实际影响验证。纯文档和注释核对差异。单端在对应目录选相关包的 `go test`、单文件 `flutter test --no-pub` 或局部静态检查。Ops 用 `npm.cmd test` 查逻辑，`npm.cmd run check:build` 查 Vue 编译。复用已覆盖同一风险的结果。
- 改 [跨端契约](backend/data/contracts/README.md) 时跑受影响端的用例。涉及迁移、删除或多步写入时，在临时库或一致性快照副本上检查旧数据与失败回滚。验收完成后清理临时数据。
- 整端或跨模块验收按需运行 `pwsh -File verify.ps1 -Scope backend|android|ops|all`。依赖安装、代码生成、快照校验、APK/可执行文件构建和浏览器冒烟由改动或交付要求触发。
- 验证结果简报一行，失败和关键未覆盖项单列。指引只随对应的边界、契约或验证入口更新。
