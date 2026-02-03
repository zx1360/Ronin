import 'package:flutter/material.dart';

/// PS: 请协助实现一个折叠式树形标签列表组件，需满足以下核心需求：
/// 1. 展示本地sqlfite数据库中tags表的树状标签（支持层级缩进、展开/收起）；
/// 2. 标签管理+媒体文件打标签: 传入mediaId, 支持标签的更名、添加、删除、拖拽移动（可移至其他标签下/作为根节点），显示删除/拖拽按钮；点击选择若干标签为该媒体文件id记录关联标签记入media_tag_links表；
/// 3. 组件设计, 保持展开/收起、层级缩进等核心UI逻辑统一，仅适配操作按钮和交互反馈.
/// 4. 交互要求：操作有视觉反馈（如选中状态、拖拽提示），避免标签循环层级（移动时校验）；
/// 5. 性能：长列表懒加载，适配状态管理（Riverpod_annotation）。
/// 请提供完整可运行的组件代码，包含数据模型、核心UI、场景适配逻辑，并标注关键改造点和复用方式。
class LabelList extends StatelessWidget {
  const LabelList({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text("标签管理页面"),
    );
  }
}