## 项目说明

由Go语言开发, 包含两部分:

1. http服务器, 用以支持桌面和安卓端应用的网络请求.

2. 一些CLI命令工具, 用以进行资源的批量处理.
   - 全量或增量检索漫画文件并写入本地postgres数据库, 刷新删去文件系统中不存在的记录信息等.
   - 遍历指定的本地目录中的媒体文件获取信息, 生成缩略图, 写入postgres数据库, 并整理归档. 以及软删除客户端响应的被标记为删除的文件等.

## 项目结构

当前仓库已采用“单仓库 + 双模块”结构：

- `monarch/`（仓库根）: HTTP 服务端主模块。
- `monarch/gizmos/`: CLI批处理工具模块（索引、摄入、执行删除等）。

参考文档（References）生成：

```powershell
powershell -ExecutionPolicy Bypass -File .\references\scripts\generate_refs.ps1
```

## 数据库信息

本地运行PostgreSQL18.0, 数据表以及触发器相关定义可查看`./README_db.md`文件.