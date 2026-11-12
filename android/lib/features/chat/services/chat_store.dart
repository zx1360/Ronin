import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/services/storage/app_database.dart';
import 'package:torrid/features/chat/models/chat_models.dart';
import 'package:torrid/features/chat/models/review_models.dart';

final chatStoreProvider = Provider(
  (ref) => ChatStore(ref.watch(appDatabaseProvider)),
);

class ChatStore {
  ChatStore(this.db);

  final AppDatabase db;

  Future<List<ChatConversation>> conversations() async => [
    for (final row in await (db.select(
      db.chatConversations,
    )..orderBy([(row) => OrderingTerm.desc(row.updatedAt)])).get())
      ChatConversation(
        id: row.id,
        title: row.title,
        createdAt: row.createdAt.toLocal(),
        updatedAt: row.updatedAt.toLocal(),
        messages: [
          for (final value in jsonDecode(row.messages) as List)
            ChatMessage.fromJson(value as Map<String, dynamic>),
        ],
      ),
  ];

  Future<void> save(ChatConversation conversation) => db
      .into(db.chatConversations)
      .insertOnConflictUpdate(
        ChatConversationRow(
          id: conversation.id,
          title: conversation.title,
          createdAt: conversation.createdAt,
          updatedAt: conversation.updatedAt,
          messages: jsonEncode(conversation.messages),
        ),
      );

  Future<void> newConversation(
    ChatConversation conversation,
    List<String> emptyIds,
  ) => db.transaction(() async {
    await (db.delete(
      db.chatConversations,
    )..where((row) => row.id.isIn(emptyIds))).go();
    await save(conversation);
  });

  Future<void> deleteConversation(String id) =>
      (db.delete(db.chatConversations)..where((row) => row.id.equals(id))).go();

  Future<void> clearConversations() => db.delete(db.chatConversations).go();

  Future<List<ReviewPreset>> presets() async => [
    for (final row in await (db.select(
      db.reviewPresets,
    )..orderBy([(row) => OrderingTerm.asc(row.name)])).get())
      ReviewPreset(id: row.id, name: row.name, role: row.role, tone: row.tone),
  ];

  Future<void> replacePresets(List<ReviewPreset> presets) => db.batch((batch) {
    batch.deleteAll(db.reviewPresets);
    batch.insertAll(db.reviewPresets, [
      for (final item in presets)
        ReviewPresetRow(
          id: item.id,
          name: item.name,
          role: item.role,
          tone: item.tone,
        ),
    ]);
  });

  Stream<List<ReviewRecord>> watchHistory() =>
      (db.select(
        db.reviewHistory,
      )..orderBy([(row) => OrderingTerm.desc(row.createdAt)])).watch().map(
        (rows) => [
          for (final row in rows)
            ReviewRecord(
              id: row.id,
              presetName: row.presetName,
              span: row.span,
              createdAt: row.createdAt.toLocal(),
              content: row.content,
              stats: row.stats,
            ),
        ],
      );

  Future<void> addReview(ReviewRecord record) => db
      .into(db.reviewHistory)
      .insert(
        ReviewHistoryRow(
          id: record.id,
          presetName: record.presetName,
          span: record.span,
          createdAt: record.createdAt,
          content: record.content,
          stats: record.stats,
        ),
      );

  Future<void> removeReview(String id) =>
      (db.delete(db.reviewHistory)..where((row) => row.id.equals(id))).go();

  Future<void> clearReviewHistory() => db.delete(db.reviewHistory).go();
}
