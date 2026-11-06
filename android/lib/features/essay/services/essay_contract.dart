const essaySchemaVersion = 3;

void requireEssaySchema(dynamic data) {
  if (data is! Map || data['essay_schema_version'] != essaySchemaVersion) {
    throw StateError('请先更新后端，以支持随笔编辑与标签独立同步');
  }
}
