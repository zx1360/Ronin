# 此文件为待办备忘以及agent提示词模板, 不必作为上下文参考.

# TODO:
## torrid:
基于immich http的二次开发:
https://api.immich.app/endpoints/api-keys
http://localhost:2283/doc
http://localhost:2283/api/spec.json

treasure页:
与monarch联动, 以后引入photoprism, 根据tags或文本识别内容检索图片, 类似小米相册plus.
对于图片类的提供拖拽四边裁切功能, (将相关数据发送至monarch让gallery执行).

gallery模块:
对于图片, 提供裁切/涂鸦. (后端做好支持, 也许需要重构通信json结构之类的).
对于视频, 提供简单的去头去尾的剪辑, 以及选取开始帧结束帧生成新小视频片段.
添加图片旋转功能, 改变图片的方向.

## Desktop App:


## 数据库:



----
2. 对于booklet和essay两部分数据备份到服务器时, 目前是直接存储为json文件并将图片保存到"./static/img_storage/[模块名]/"下, 是否推荐改成数据库存储? 感觉这样能更容易实现文章的关键词模糊查询和同步/备份时的增量更新之类的.
如果推荐的话就这么做吧.
3. 后端数据库(涉及数据表结构变动, 先给出表结构更改sql和迁移sql我完成更改后你再执行后续操作):
删去comic_summary数据表, 如果有依赖于该表数据的地方, 替换为实时计算得出.
考虑维护难度和数据同一性方面, 是否推荐删去comic_books.chapter_count/imagecount和comic_chapters.image_count字段. 而采用实时计算?
更改漫画资源的数据表结构. 新增isPublic, readed布尔字段, 新增source的text字段.
desktop: 
任务管理页删除对于危险操作时的输入指定内容以确认运行的功能, 只需当前保留ui层对于标记为危险操作的提示即可.
新增一个ComicsPage, 漫画资源页. 由两部分组成:
一是内容是管理当前的漫画资源.
对于每个漫画可以设置其isPublic值(在安卓端, 标记为isPublic=false的漫画隐藏掉). 
选中某个漫画并点击"删除"按钮, 将从文件系统中删除该本漫画的资源, 一并删除该本漫画资源在数据库中的所有相关记录.
当前每个漫画的封面图路径cover_image值默认为该本漫画第一章节第一个图片, 添加封面图可替换的功能, 调出文件选择器实现. (该字段的值时一个相对路径, 处理好可能的问题.)
二是漫画连载追踪页面.
可以根据设定的source字段(漫画网站的该漫画详细页url)选择某一预输入的爬虫脚本(python/或者打包的exe).增量更新. 并在安卓端如果已下载该漫画可以点击增量更新下载.(monarch->torrid).
android:
漫画模块, 对于某漫画的详细页, 添加"标记readed"的逻辑, 表示该漫画已看完.
右上角按钮呼出的菜单加入一个"同步状态", 将本地标记为readed的漫画信息发送给后端服务器, 并检查所有已存于本地的漫画在服务器是否有更多新章节, 如果有则自动加入下载队列开始增量更新.
backend:
做好相应的接口和实现.
----



--------------
zx1360.github.io
问ds, 也许加点网页功能.



# 提示词模板:

项目结构参考各目录下的 AGENTS.md，
契约文件参考 backend/references/api/。

项目结构和协同契约见：
- 总览: AGENTS.md
- backend: backend/AGENTS.md, backend/references/
- android: android/AGENTS.md
- desktop: desktop/AGENTS.md

[改动描述]
请帮我完成以下跨项目改动：
1. backend: 
2. android: 
