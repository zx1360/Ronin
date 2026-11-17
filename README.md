# Ronin

Ronin 是一套个人自托管工具，用来管理电脑上的媒体和漫画，以及手机上的随笔、打卡和时间记录。电脑运行 Monarch，Android 使用 Torrid，本机浏览器可以打开 Northstar 管理数据与任务。

| 组件 | 用途 |
| --- | --- |
| [Torrid](android/) · Flutter Android | 写随笔、用「积微」打卡、用「时迹」记录不同场景的时间。连接 Monarch 后可浏览画廊和漫画、同步个人数据，并使用已配置的 AI 对话或回顾。 |
| [Monarch](backend/) · Go + SQLite | 提供局域网 API，管理画廊、漫画库和个人数据备份。通过 Gallery CLI 处理媒体，通过 comix 管理漫画下载，可选用本机模型进行图片检索、标注和对话。 |
| [Northstar](ops/web/) · Vue + Vite | 编辑本机的随笔和打卡数据，管理媒体处理、漫画下载、AI 任务及服务状态。网页由 Monarch 托管。 |

## 数据存放

Torrid 用本机 SQLite 保存随笔、积微和时迹。随笔与打卡可同 Monarch 合并同步，时迹由手机合并后备份到 Monarch。手机上的随笔草稿和对话历史存于本机。Monarch 默认将数据库保存在 `backend/data/monarch.db`，画廊与漫画原文件位于配置的媒体目录。

Android 通过局域网 HTTPS 和 API 密钥连接 Monarch。Northstar 只接受本机回环连接。

## 从源码运行

以下命令以 Windows 和 PowerShell 7 为例。Go 版本见 [go.mod](backend/go.mod)，网页所需的 Node.js 版本见 [package.json](ops/web/package.json)。Android 需要 Flutter 和 Android SDK。

1. 在 `backend/.env` 配置存储路径、端口和自用密钥。相对路径以 `backend/` 为基准。

   ```dotenv
   STATIC_DIR=../_static
   GALLERY_DIR=../_static/gallery
   LOCAL_PORT=7274
   LOCAL_HTTP_PORT=7275
   API_KEY_SERVER=replace-with-your-own-key
   AI_ENABLED=false
   ```

2. 从仓库根目录构建 Northstar 和 Monarch，再启动服务。

   ```powershell
   npm.cmd ci --prefix ops/web
   npm.cmd run build --prefix ops/web
   Set-Location backend
   New-Item -ItemType Directory -Force cert | Out-Null
   go build ./cmd
   .\cmd.exe
   ```

   在运行 Monarch 的电脑上打开 [Northstar](http://127.0.0.1:7275/ops/)。画廊处理任务还需构建 Gallery CLI，在 `backend/` 执行 `go build -o gizmos/gallery.exe ./gizmos/cmd/gallery`。漫画下载与 AI 可按需配置。 [comix](backend/gizmos/comix/) · [AI 安装说明](backend/tools/ai/README.md)

3. 编译 Torrid 前，把 Monarch 的公开证书 `backend/cert/server.crt` 放到 `android/android/app/src/main/res/raw/server.crt`，并按 [Android 构建配置](android/android/app/build.gradle.kts) 准备自己的签名。回到仓库根目录运行 `pwsh -File verify.ps1 -Scope android`，生成可安装的调试 APK。安装后在「个人 → 网络设置」填写电脑的局域网地址、HTTPS 端口和同一 API 密钥。

## 备份与开发

- 停止 Monarch 和相关 CLI 后，可从仓库根目录运行 `python backend/tools/backup_local.py --output backend/backups/manual-001`，备份数据库、附件和配置。脚本依赖 `python-dotenv`。画廊、漫画原文件以及仅存于手机或浏览器的数据需另行备份。 [备份脚本](backend/tools/backup_local.py)
- 从仓库根目录运行 `pwsh -File verify.ps1 -Scope android` 验收 Android。也可选择 `backend`、`ops` 或 `contracts`。 [仓库约定](docs/architecture/instructions.md) · [跨端契约](contracts/README.md)

本项目采用 [MIT 许可证](LICENSE)。
