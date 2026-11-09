**Ronin 三端业务审计 · 2026-11-09**

本次检查覆盖 Monarch、Torrid、Northstar，以及 Gallery Go CLI、comix Python CLI。结论来自调用链审查、现有验收、临时数据库接口验收和故障注入。下文保留初查时的复现记录；本轮处理结果见文末。

**结论与优先级**

现有分层、数据权威划分和跨端协议适合当前个人使用场景，建议继续沿用。发现 10 项可以复现的问题，其中 2 项优先处理：同名漫画离线文件冲突、聊天切换会话后漏存回复。最值得优先做的效率改进是减少 Hive 全量重写和重复通知。

P1 表示应优先修复的文件或本地历史完整性问题；P2 表示功能缺陷、失败恢复问题或有明确证据的效率问题。优先级不代表生产数据已发生损坏。

| 编号 | 优先级 | 模块 | 问题 |
| --- | --- | --- | --- |
| 01 | P1 | Android Comic | 同名漫画共用离线文件，删除一本会影响另一本 |
| 02 | P1 | Android Chat | 生成期间切换会话，后续回复没有保存到原会话 |
| 03 | P2 | Android Booklet | 写入成功前原地修改共享记录，失败后内存状态仍改变 |
| 04 | P2 | Android Gallery | 文件下载失败仍报成功，重试无法补齐缺失文件 |
| 05 | P2 | Backend AI / Ops 去重 | 合法的负数图片指纹被排除，重复图片漏检 |
| 06 | P2 | Android Chat | 纯图片消息被请求过滤器丢弃 |
| 07 | P2 | Android Chat / Backend | 正常长对话第 51 轮超过服务端消息上限 |
| 08 | P2 | Android Essay / Booklet | 单条编辑全量重写历史并产生逐项全量读取 |
| 09 | P2 | Ops Essay | 无法保存 Android、后端均支持的纯图片随笔 |
| 10 | P2 | Android AI 回顾 | 生成期间打开历史会解除运行标志，允许请求重叠并丢失取消能力 |

**01 · 同名漫画的离线文件冲突**

位置：[下载及路径生成](D:/products/Ronin/android/lib/features/others/comic/provider/download_task_provider.dart:342)、[存在即复用](D:/products/Ronin/android/lib/features/others/comic/provider/download_task_provider.dart:368)、[删除目录](D:/products/Ronin/android/lib/features/others/comic/provider/download_task_provider.dart:176)。

目录使用 `comics/漫画名/章节显示名/文件名`，身份没有包含漫画 ID、章节 ID。同名作品或同名的不同站点资源可以拥有不同 ID；它们的章节显示名、页码文件名却可能相同。下载会把已有非空文件当作当前漫画文件，删除也按漫画名清整个目录。

复现：漫画 101、102 采用相同书名、相同章节名，服务端图片地址不同。下载后两个章节指向同一文件，两本合计只请求了一次图片；删除 102 的本地文件后，101 的元数据仍存在，但其图片已不存在。

建议改用稳定的漫画 ID、章节 ID 组织目录，名称只用于展示。处理旧缓存时先备份元数据；无法判断归属的共享文件应提示重新下载，不能直接批量搬移并认定内容正确。

**02 · 切换会话后回复漏存**

位置：[切换会话](D:/products/Ronin/android/lib/features/chat/providers/chat_providers.dart:123)、[流结束保存](D:/products/Ronin/android/lib/features/chat/providers/chat_providers.dart:272)。

流事件按开始时的 `conversationId` 更新内存，结束时却调用 `_persistActive()` 保存此时正在查看的会话。生成期间抽屉允许切换，新建会话也会改变活动会话。

复现：A 回复 `first` 后切到 B，再收到 `second`。A 的内存回复为 `firstsecond`，Hive 中只有 `first`；重启会丢掉后半段。

建议按本轮固定的会话 ID 保存，并用本轮身份校验清理取消令牌、运行状态。删除、清空会话时一并终止对应请求，避免旧请求影响新请求。

**03 · 打卡写入失败后共享记录已改变**

位置：[直接修改记录](D:/products/Ronin/android/lib/features/booklet/pages/booklet_page.dart:63)、[绑定持久化实例](D:/products/Ronin/android/lib/features/booklet/pages/booklet_page.dart:121)。

任务勾选、留言和心情直接修改 provider 返回的 Hive 对象，然后再调用写入服务。失败恢复日志取得快照时，对象可能已经变化；页面回调也没有相应的失败恢复与提示。

复现：向 `putRecord` 注入写入失败，勾选调用抛错后，`recordsBox.get()` 取得的共享记录仍显示已完成。此项验证的是内存缓存污染，未把它等同于磁盘已成功写入。

建议编辑副本，复制可变的 `taskCompletion` Map；服务在串行写入边界读取当前记录并提交变更，成功后更新显示，失败时保留原记录并提示。保留已有多 Box 恢复机制。

**04 · Gallery 缺失缓存无法重试补齐**

位置：[先保存元数据](D:/products/Ronin/android/lib/features/others/gallery/services/gallery_sync_service.dart:164)、[吞掉文件下载异常](D:/products/Ronin/android/lib/features/others/gallery/services/gallery_sync_service.dart:295)、[按元数据 ID 排除已缓存项目](D:/products/Ronin/android/lib/features/others/gallery/services/gallery_api_service.dart:224)。

元数据先写入本地数据库；缩略图、预览图失败只记录日志，完成计数照常增长，批次仍返回成功。下次下载只判断数据库是否存在该 ID，因此不会修复这些文件。仅清理文件而保留数据库的操作也会遇到同样的补齐问题。

复现：缩略图和预览图全部请求失败，批次返回 `true`、状态为 success、本地元数据 1 条、成功保存文件 0 个；再次下载没有增加任何文件请求。

建议区分尝试完成与下载成功，提供按本地实际文件缺失情况补齐的路径。修复文件时保留元数据和待回传操作，不以删除工作副本的方式重试。

**05 · 去重过滤了合法的负数指纹**

位置：[过滤条件](D:/products/Ronin/backend/internal/service/ai/index.go:383)、[唯一无效哨兵值](D:/products/Ronin/backend/internal/service/ai/phash.go:17)、[设置高位](D:/products/Ronin/backend/internal/service/ai/phash.go:49)。

图片指纹使用 `int64` 存储 64 位位模式，合法结果可以为负数。无效值约定为 `-1`，但去重索引用 `h < 0` 排除了所有负数。数据库载入逻辑会正常载入这些指纹，问题位于分组过滤阶段。

复现：实际生成的图片得到合法指纹 `-7053052629177583182`。两条相同指纹的距离为 0，重复组数量却为 0；换成相同正数指纹后得到 1 组。

建议只排除 `PHashUnavailable`。已有合法指纹仍在数据库中，此项修复不需要重新生成图片指纹或迁移数据。

**06 · 纯图片聊天消息被丢弃**

位置：[消息可用性判断](D:/products/Ronin/android/lib/features/chat/models/chat_models.dart:151)、[请求消息过滤](D:/products/Ronin/android/lib/features/chat/providers/chat_providers.dart:285)、[空会话判断](D:/products/Ronin/android/lib/features/chat/models/chat_models.dart:63)。

发送入口允许正文为空、附件非空，但 `usable` 只认非空正文。纯图片用户消息不会进入请求；有旧历史时，模型会收到旧历史而收不到这次的新图片。

复现：在新会话发送一个媒体附件且不填文字，实际请求消息数为 0。服务端明确拒绝空 messages。

建议把附件计入消息可用性与空会话判断，同时保持失败、被中断消息的排除规则。

**07 · 长对话缺少请求上下文上限**

位置：[全历史组装](D:/products/Ronin/android/lib/features/chat/providers/chat_providers.dart:285)、[后端 100 条消息限制](D:/products/Ronin/backend/internal/handler/ai_handler/chat_handler.go:145)。

客户端限制了重复发送图片的范围，却没有限制正文历史。50 轮正常问答累计 100 条可用消息，第 51 次提问组成 101 条请求，后端拒绝。重试仍然携带同样过长的历史。

复现：构造 50 轮本地问答，下一次发送捕获到 101 条消息；独立后端实例对 101 条消息返回 HTTP 400。

建议保留完整本地历史，请求只携带受限的近期完整轮次，并兼顾正文长度和上下文预算；界面说明模型当前使用的历史范围。不要通过无限扩大后端上限解决。

**08 · 随笔、打卡的全量写入与通知放大**

位置：[单条打卡写入](D:/products/Ronin/android/lib/features/booklet/providers/routine_service_provider.dart:34)、[随笔全量替换](D:/products/Ronin/android/lib/features/essay/providers/essay_notifier_provider.dart:58)、[所有值 putAll](D:/products/Ronin/android/lib/core/services/storage/box_replace.dart:15)、[逐通知读取全部记录](D:/products/Ronin/android/lib/features/booklet/providers/data_source_provider.dart:35)、[随笔对应订阅](D:/products/Ronin/android/lib/features/essay/providers/box_provider.dart:40)。

单次编辑会构建全量历史映射、重算统计、保存多 Box 全量恢复快照，再 `putAll` 全部历史。监听层收到每条 Box 通知都重新读取全部值，形成不必要的写入和潜在二次方级扫描。

复现：1000 条打卡记录中修改 1 条，产生 1000 次记录 Box 事件。Windows 测试环境提交约 60 ms；这个时间不能直接推断 Android 卡顿程度。随笔具有相同的写入和订阅结构，尚未单独做规模耗时测量。

建议先让提交只写实际变化的键，并合并同批通知；恢复日志也只记录本次涉及的键及原值，保留异常和进程中断后的可恢复性。统计先缩小到受影响计划/年份，避免立即引入另一套存储或复杂的增量统计系统。

**09 · Ops 不支持纯图片随笔**

位置：[正文 required](D:/products/Ronin/ops/web/src/pages/essay.js:36)、[提交校验](D:/products/Ronin/ops/web/src/pages/essay/board.js:76)、[后端允许正文或图片](D:/products/Ronin/backend/internal/repository/data_repo/sync_validation.go:47)。

复现：后端接口成功保存并同步纯图片随笔；Ops 选择标签、添加图片后仍被浏览器正文必填挡住。去掉测试页面上的 required 后，业务提交函数仍显示“正文不能为空”，没有发出保存请求。

建议与 Android、后端统一为“正文或图片至少一项”，保留 1–4 个标签规则。新增对应共享契约样例，覆盖两层前端校验。

**10 · AI 回顾切换历史后允许重叠生成**

位置：[打开历史](D:/products/Ronin/android/lib/features/chat/pages/review_page.dart:118)、[覆盖当前生成状态](D:/products/Ronin/android/lib/features/chat/providers/review_providers.dart:287)、[无条件清理取消令牌](D:/products/Ronin/android/lib/features/chat/providers/review_providers.dart:273)。

回顾生成期间可以打开历史；`show()` 将 streaming 重置为 false，却没有取消旧请求。此时允许第二次生成，两条流都更新同一个草稿状态。旧流结束时又无条件清掉新流的取消令牌。

复现：第一条流未完成时打开历史，再次生成得到 2 个未取消请求；第一条流结束后调用停止，第二条流的令牌仍未取消。

建议明确历史展示与当前生成的关系：切换前结束旧生成，或者保持生成身份与运行状态独立于展示内容。与聊天采用相同的本轮身份校验即可，无需新增常驻组件。

**其他优化建议与组织管理**

| 方向 | 证据与建议 | 实施前提 |
| --- | --- | --- |
| Gallery 图片预取 | [当前预取](D:/products/Ronin/android/lib/features/others/gallery/widgets/main_widgets/content_widget.dart:295)为前 3、后 5 张原图，通过 `precacheImage` 解码；可优先预取预览图或减少原图解码范围、限制解码尺寸 | 在 Android 真机上测峰值内存、流量、首帧耗时；目前不能断言它已经导致 OOM |
| 写入对象的组织 | Booklet 的共享可变对象与全量提交相互放大风险；先约束页面只提交副本/变更，再优化提交范围 | 修复 03、08 时一起完成，不做大规模目录搬迁 |
| 漫画下载器职责 | 目录身份、文件传输、任务状态目前集中在下载 notifier；可以在修复 01 时提取小型路径/传输函数 | 不引入通用任务框架，继续复用当前并发、重试和持久化机制 |
| 跨端契约与测试 | 现有契约偏重同步、标签、范围和生命周期；新增纯图片、长聊天、切换生成、失败重试、同名漫画等边界样例更有价值 | 修复时把必要的回归场景纳入现有测试入口；本次临时复现代码按要求清理 |
| 数据规模增长 | 向量精确扫描、文本 LIKE、漫画清单和统计全量聚合仍应关注 | 先基于实际库规模做只读性能测量；暂不引入向量数据库、FTS 迁移或新后台服务 |

后端现有单写连接、SQLite WAL、事务合并、任务进程管理值得保留。AI 空队列先检查任务再探测依赖，worker 空闲从 5 秒退避至 1 分钟，补队列空闲间隔 10 分钟，已有侧车与索引回收机制；Ops 也已有可见性、卸载和活动状态约束。此次没有发现需要新增常驻组件的理由。

**覆盖范围及实际验收**

| 范围 | 检查内容 | 结果与边界 |
| --- | --- | --- |
| Essay | 草稿/正式内容隔离、图片发布、标签树与隐藏、搜索、统计、逐行同步、独立标签时间戳、冲突与删除 | 基线及接口验收通过；发现 08、09 |
| Booklet | 计划、勾选、留言/心情、历史、统计、同步/删除、写入失败 | 基线及接口验收通过；发现 03、08 |
| Gallery | 离线批次、标签与收藏、操作队列、图库身份、回传确认、媒体组、文件缓存、媒体读取、预览链 | 基线及部分接口验收通过；发现 04；真机滚动与视频尚待验证 |
| 相册 | 标签含子孙筛选、分页、软删除/恢复、在线写入与本地缓存协调、AI 不可用降级 | 代码核对与隔离接口通过；未发现新的已复现阻断问题，不等同于全部交互通过真机验收 |
| Comic / comix | 清单与静态图片、同名资源、离线队列、并发/重试、原子下载、无效图片、事务回滚、中断恢复、路径边界 | 隔离接口及无网络下载测试通过；发现 01；没有实际爬取外网站点 |
| AI / Chat / 回顾 | NDJSON、消息/附件、历史保存、上下文上限、生成切换、模型仲裁、空闲回收、去重、失败降级 | 基线与专项复现完成；发现 02、05、06、07、10；未运行真实模型推理 |
| Ops / 通用设施 | 各页面及标签页渲染、契约、路由快照、轮询生命周期、用户数据编辑冲突、任务管理边界 | 现有自动验收通过；发现 09 |

实际执行结果：

- `go build ./...`、`go vet ./...`、`go test ./... -count=1`：通过。
- `flutter analyze`：零问题；现有 `flutter test`：34 项通过。
- `node --test ops/tests/contracts.mjs`：10 项通过。
- `pwsh -File backend/references/scripts/generate_refs.ps1 -Check`：通过。
- Ops 页面与标签页冒烟：9 个路由入口遍历，控制台错误 0，脚本发现问题 0。
- Android 临时专项测试：8 项通过，分别复现聊天附件/切换/长历史、同名漫画、回顾重叠、Gallery 失败重试、Hive 通知放大、打卡失败前修改。
- Go 临时专项测试：复现负数指纹漏检，正数对照正常。
- 独立后端的 13 项接口场景：通过，涵盖随笔同步/非法整批拒绝/过期快照拒绝/纯图片、打卡统计与删除、相册筛选/软删除恢复、Gallery 分组关系/原图、漫画清单/图片、AI 不可用状态及消息上限。
- comix 的 5 项无网络场景：通过，涵盖原子下载与复用、坏图清理、事务回滚、中断任务恢复、存储路径限制。
- Ops 纯图片随笔浏览器复现：确认原生表单和业务提交均阻止保存。

所有业务写入只发生在新建测试库和临时 Hive/文件目录中，未写入生产数据库，未替换现有后端程序。测试实例使用独立端口、关闭 AI，并在结束后停止；临时测试代码、数据库及文件均清理，仅保留本报告。

仍需的设备/环境验收：Android 真机的滚动帧率、瀑布布局稳定性、图片解码内存、视频播放/裁剪、断网重连及系统杀进程恢复；真实 Ollama/侧车的推理、显存抢占与长期空闲占用；外部漫画站点的实际可用性。本次结果不覆盖这些运行环境。

**处理结果**

以上 10 项问题已在现有架构内处理，未增加依赖、常驻服务或数据库迁移。漫画下载与重扫共用文件逻辑，新下载按漫画/章节 ID 存储，并保存名称和章节索引以支持元数据重建；旧目录保留，不批量迁移，删除时保留其他漫画仍在引用的文件。

聊天按发起会话保存回复，清空/删除与历史切换会终止对应生成并忽略旧事件；图片消息进入上下文，长对话只缩减发送内容，完整历史仍留在本机。Gallery 重试按实际缺失文件补齐，不覆盖已有标注。Ops 已通过真实表单保存纯图片随笔。

Hive 提交只写变化的键，订阅合并同批事件；1000 条打卡中修改 1 条的记录通知由 1000 次降至 1 次。保留原有完整恢复快照，避免为减少日志体积引入新的恢复格式；全量统计也继续沿用现有简单实现。

本轮已通过 Go 构建、vet、全量测试，Flutter 零问题分析、原有 34 项测试与 14 项专项场景，Ops 10 项契约测试、实际保存流程和 9 个路由页面冒烟，以及接口快照校验。专项覆盖了旧日志恢复、写入故障回滚、会话切换与旧流隔离、漫画重扫/删除/阅读偏好、共享旧文件保留、Gallery 失败补齐等情况。生产数据库未参与写入验收。

Android Debug APK 已成功构建，产物为 `android/build/app/outputs/flutter-apk/app-debug.apk`。本机 JDK 默认临时 socket 目录曾导致 Gradle 回环连接失败；仅在构建进程设置 `JAVA_TOOL_OPTIONS=-Djdk.net.unixdomain.tmpdir=D:\products\Ronin\android\.dart_tool` 后通过，未修改系统或项目配置。

专项测试代码、临时实例、数据库与排查日志均已清理；原有测试保留。真机滚动/内存、真实模型推理及外站爬取仍属于前述未覆盖范围。
