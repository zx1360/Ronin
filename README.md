# Ronin
<<<<<<< HEAD
=======

Monarch 在 Windows 上维护本机媒体和 SQLite 数据，随服务提供 Northstar 运维网页。Torrid 安装在 Android 手机上，通过局域网连接 Monarch。

## 分发

- Windows x64 便携包在仓库根用 `pwsh -File backend/tools/release/build-windows.ps1` 构建，输出到 `backend/dist/`。
- Torrid 在 `android/` 配置自己的发布签名后运行 `flutter build apk --release`。发布者保管签名密钥，同一安装需使用同一签名更新。
- 将 ZIP 和 APK 交给使用者。[安装、手机配对与可选 AI 组件](backend/tools/release/使用说明.md)

## 项目组成及技术细节
>>>>>>> 1fc83d9 (重构瘦身+分发性.)

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

3. 在 `android/` 准备本地资源 `assets/fonts/kaiti.ttf`、`assets/fonts/iconfont.ttf`、`assets/icons/six.ico` 和 `assets/images/1.png`。创建 `android/android/app/src/main/res/raw/`，把 Monarch 的公开证书 `backend/cert/server.crt` 复制进去。Flutter 测试和 APK 构建都需要这些资源。按 [Android 构建配置](android/android/app/build.gradle.kts) 准备签名后，在 `android/` 运行 `flutter build apk --debug` 生成调试 APK。安装后在「个人 → 网络设置」填写电脑的局域网地址、HTTPS 端口和同一 API 密钥。

## 备份与开发

- 停止 Monarch 和相关 CLI 后，可从仓库根目录运行 `python backend/tools/backup_local.py --output backend/backups/manual-001`，备份数据库、附件和配置。脚本依赖 `python-dotenv`。画廊、漫画原文件以及仅存于手机或浏览器的数据需另行备份。 [备份脚本](backend/tools/backup_local.py)
- 依赖就绪后，可从仓库根目录运行 `pwsh -File verify.ps1 -Scope <backend|android|ops|all>` 验收对应范围。日常检查的选择见[仓库验证规则](AGENTS.md#验证)。 [跨端契约](backend/data/contracts/README.md)

<<<<<<< HEAD
本项目采用 [MIT 许可证](LICENSE)。
=======
托管在 `/ops/`, 支持随笔、积微打卡，以及资源处理、漫画库、任务与日志、AI 能力等运维操作。
仅本机回环可访问: `http://127.0.0.1:7275/ops/`(HTTP, 无证书警告) 或 `https://127.0.0.1:7274/ops/`。

## 安卓应用(Flutter)

> 多功能安卓应用.

### 一、数据安全

**隐私**

**所有用户数据存于本地不上云, 不会被外部获取**

**备份**

可通过部署本项目的backend部分运行http服务器, 实现备份到pc上.

### 二、应用干净

卸载应用即删除所有数据不留痕. 不保留任何配置信息和数据.

**==因此, 未备份的数据会在应用卸载后真正消失.==**

- 打卡/随笔等数据保存于内部应用私有目录
- 相应的图片等文件保存于外部应用私有目录

PS: 除了某些页面手动点击"保存"按钮后, 保存在外部公共空间. (为了保存的图片能够被手机自带的相册识别到).

### 三、后台友好

**CPU友好:** 只有用户操作才会进行相应的操作.

处于后台时不会运行其他行为. (指仍旧活跃的后台代码)

**内存友好: **

不知道, 感觉应该不占内存.

# 关于本项目

## 一、开源

[zx1360/Ronin: 个人资源管理pc后端+多功能安卓软件.](https://github.com/zx1360/Ronin)

业务闭环联系紧密, 所以合并了三个项目:

- [zx1360/monarch: Go编写的http服务器, 用以支持我另一个项目'torrid'的网络请求.](https://github.com/zx1360/monarch)
- [zx1360/Torrid: 仅安卓端的自用多功能软件. 打卡, 随笔, 看漫画, 与monarch项目联动查看pc库存和媒体文件等功能.](https://github.com/zx1360/Torrid)
- [zx1360/Northstar: 图形化管理http服务器和小工具.](https://github.com/zx1360/Northstar)

## 二、业务闭环

原始数据初处理、索引、后端维护、客户端消费并反馈. 

本项目分为三端, 个人用户可自行部署完整实现所有功能.

## 三、数据隐私与安全

后端与安卓应用的网络交互通过https协议实现, 并通过x-api-key再套层验证. 保证数据的隐私与安全.

> 自部署时 Monarch 首次启动会生成自签证书。手机在网络设置中录入 Northstar 显示的证书指纹。

# 其他说明

闲暇开发, 以覆盖自用场景为主.

# 反馈问题

<del>不一定会看, 也不一定会改, 因为我这么长时间用下来没问题挺顺手的 :D</del>

- `github` [Issues · zx1360/Ronin](https://github.com/zx1360/Ronin/issues)

- `3039328600@qq.com`
>>>>>>> 1fc83d9 (重构瘦身+分发性.)
