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
northstar:
可以之后考虑一下要不要存到appdata里, 或者是应用目录里. (稍微清理一下appdata的northstar数据, 有15份).
comics 封面图可替换, northstar+monarch同步更改.

## 数据库:
postgres:
删去comic_summary 数据表.
可考虑删去comic_books.chapter_count/imagecount和comic_chapters.image_count字段. 而采用实时计算.





--------------
zx1360.github.io
问ds, 也许加点网页功能.



# 提示词模板:

[改动描述]
请帮我完成以下跨项目改动：
1. backend: 
2. android: 

项目结构参考各目录下的 AGENTS.md，
契约文件参考 backend/references/api/。

项目结构和协同契约见：
- 总览: AGENTS.md
- backend: backend/AGENTS.md, backend/references/
- android: android/AGENTS.md
- desktop: desktop/AGENTS.md


