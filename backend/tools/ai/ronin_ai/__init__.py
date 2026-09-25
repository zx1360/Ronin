"""Ronin 本地 AI 侧车。

以 NDJSON 协议与 Go 服务通信（每行一个 JSON 对象）：

    请求首行  {"v":1,"capability":"embed","count":3,"params":{...}}
    请求条目  {"id":"<媒体ID>","path":"<绝对路径>"}     # 或 {"id":"1","text":"..."}
    响应条目  {"id":"<媒体ID>","ok":true,"result":{...}}
    就绪响应  {"ready":true,"models":["siglip_vision",...]}   # count=0 的预热请求

模型全部懒加载：进程启动时不加载任何模型，收到对应能力的请求才加载；
stdin 关闭即退出，因此"空闲即退出、退出即释放内存"由 Go 侧的进程监管保证。
"""

__all__ = ["__version__"]

__version__ = "1.0.0"
