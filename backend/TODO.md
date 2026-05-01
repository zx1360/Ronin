我正在使用Go开发http服务器以支持我的自用的应用.
当前我是
在理解的基础上做出如下修改:
1. 


硬性要求:
考虑到可能的特殊以及边界情况, 做好应对防止异常.
除非明确要求, 否则不对已有功能引入任何破坏性或者可能导致不可预知影响的修改.
修改直到项目无错且能正确按照我的预期运行.
注意代码可维护性.
另外注意, 当前工作区的http服务器(当前项目)和cli程序(/gizmos/目录下)是项目协同间的"唯一真理", 其供给别的项目做参考的产物目录是"/references". 所以如有改 Go 接口或 CLI, 在 monarch 根目录执行：
powershell -ExecutionPolicy Bypass -File generate_refs.ps1
(/references/architecture/目录下是维护的宏观参考, 如果你的改动含有较大的breaking change, 则可一并增改其内内容, 我稍后会过目, 选择是否采纳.)
https://api.immich.app/endpoints
http://localhost:2283/api/spec.json
http://localhost:2283/doc




--prompt:
我正在使用Go开发http服务器以支持我的自用的应用, 你能分析出我现有项目的这个模块___现有逻辑吗? 在理解的基础上做出如下漏洞修复或修改:
1. 

附加说明: 对于漏洞修复类问题, 如果找出问题所在, 请一并返回是什么原因导致了这个问题, 如果不能给出合理确信的理由, 则暂时搁置并告诉我你的推测.

硬性要求:
考虑到可能的特殊以及边界情况, 做好应对防止异常.
除非明确要求, 否则不对已有功能引入任何破坏性或者可能导致不可预知影响的修改.
修改直到项目无错且能正确按照我的预期运行.
注意代码可维护性.
另外注意, 当前工作区的http服务器(当前项目)和cli程序(/gizmos/目录下)是项目协同间的"唯一真理", 其供给别的项目做参考的产物目录是"/references". 所以如有改 Go 接口或 CLI, 在 monarch 根目录执行：
powershell -ExecutionPolicy Bypass -File generate_refs.ps1
(/references/architecture/目录下是维护的宏观参考, 如果你的改动含有较大的breaking change, 则可一并增改其内内容, 我稍后会过目, 选择是否采纳.)


--更新"真理"流程":
改 Go 接口或 CLI。
在 monarch 根目录执行：
powershell -ExecutionPolicy Bypass -File generate_refs.ps1
提交时把代码改动和 references 产物一起提交。
Flutter 工作区更新后，优先看 swagger.json 和 routes.json 的差异。
按最新契约改客户端并联调。
若是跨栈策略变化，再更新 architecture 下的手写说明。
