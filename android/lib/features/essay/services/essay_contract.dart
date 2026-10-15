void requireEssaySchema(dynamic data) {
  if (data is! Map || data['essay_schema_version'] != 2) {
    throw StateError('请先更新后端，以支持随笔标题、标签层级和隐藏回顾规则');
  }
}
