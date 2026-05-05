# 此文件为待办备忘以及agent提示词模板, 不必作为上下文参考.

# TODO:
## monarch:


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
-- 漫画连载追踪页面.
可以根据设定的source字段(漫画网站的该漫画详细页url)选择某一预输入的爬虫脚本(python/或者打包的exe).增量更新. 并在安卓端如果已下载该漫画可以点击增量更新下载.(monarch->torrid).


## 数据库:



----
1. 对于booklet和essay两部分数据备份到服务器时, 目前是直接存储为json文件并将图片保存到"./static/img_storage/[模块名]/"下,为了后续能更容易实现文章的关键词模糊查询和同步/备份时的增量更新之类的, 我希望把简单的json存储方式替换为数据表存储, 图片文件保持现有逻辑.
关于这两模块的数据表我已建好,表结构参考AGENTS_DB.md中的'用户数据表'部分. (所在scheme名为user_data)
2. desktop:
ComicsPage
日志改为'不可输入但可手动复制文本.'
android:
漫画模块, 对于某漫画的详细页, 右上角按钮, 添加"标记readed"的逻辑, 表示该漫画已看完.
右上角按钮呼出的菜单加入一个"同步状态", 将本地标记为readed的漫画信息发送给后端服务器, 并检查所有已存于本地的漫画在服务器是否有更多新章节, 如果有则自动加入下载队列开始增量更新. 
(⭐当前ui不符.)
backend:

----



--------------
zx1360.github.io
问ds, 也许加点网页功能.



# 提示词模板:

[改动描述]
请帮我完成以下跨项目改动：
1. backend: 
2. android: 
