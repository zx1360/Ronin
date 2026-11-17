import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:torrid/core/services/storage/app_database.dart';

import 'trace_data.dart';
import 'trace_timing.dart';

typedef TraceFilters = ({String? scene, String? item, String? tag});
const traceNoItem = '-';

class TraceReport {
  const TraceReport(this.total, this.rows, this.distribution, this.buckets);

  final int total;
  final List<({TraceSession session, int duration, DateTime day})> rows;
  final List<MapEntry<String, int>> distribution;
  final List<TraceBucket> buckets;

  factory TraceReport.build(
    TraceData data,
    DateTimeRange? range,
    TraceFilters filters,
    DateTime today,
  ) {
    final from = range?.start.millisecondsSinceEpoch;
    final until = range == null
        ? null
        : traceDay(range.end, 1).millisecondsSinceEpoch;
    final buckets = _buckets(range, today);
    final distribution = <String, int>{};
    final rows = <({TraceSession session, int duration, DateTime day})>[];
    var total = 0;
    for (final session in data.history) {
      if ((filters.scene != null && session.sceneId != filters.scene) ||
          (filters.item != null &&
              (session.itemId ?? traceNoItem) != filters.item) ||
          (filters.tag != null &&
              !data.tagsFor(session).contains(filters.tag))) {
        continue;
      }
      final start = session.startedMs;
      final end = session.endedMs!;
      if (until != null && start >= until) continue;
      if (from != null && (end < from || (end == from && start < end))) {
        continue;
      }
      final duration = traceOverlap(session, from ?? start, until ?? end);
      total += duration;
      rows.add((
        session: session,
        duration: duration,
        day: traceDay(traceDate(math.max(from ?? start, start))),
      ));
      final key = filters.scene == null
          ? session.sceneId
          : session.itemId ?? traceNoItem;
      distribution.update(
        key,
        (value) => value + duration,
        ifAbsent: () => duration,
      );
      for (final bucket in buckets) {
        bucket.duration += traceOverlap(session, bucket.start, bucket.end);
      }
    }
    return TraceReport(
      total,
      rows,
      distribution.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
      buckets,
    );
  }

  static List<TraceBucket> _buckets(DateTimeRange? range, DateTime today) {
    if (range == null) {
      return [
        for (var offset = -5; offset <= 0; offset++)
          TraceBucket(
            DateTime(today.year, today.month + offset),
            DateTime(today.year, today.month + offset + 1),
            'M月',
          ),
      ];
    }
    DateTime utcDay(DateTime date) =>
        DateTime.utc(date.year, date.month, date.day);
    final days = utcDay(range.end).difference(utcDay(range.start)).inDays + 1;
    if (days == 1) {
      return [
        for (var hour = 0; hour < 24; hour += 4)
          TraceBucket(
            DateTime(
              range.start.year,
              range.start.month,
              range.start.day,
              hour,
            ),
            DateTime(
              range.start.year,
              range.start.month,
              range.start.day,
              hour + 4,
            ),
            'HH',
          ),
      ];
    }
    final step = (days / 7).ceil();
    return [
      for (var i = 0; i < days; i += step)
        TraceBucket(
          traceDay(range.start, i),
          traceDay(range.start, math.min(days, i + step)),
          'M.d',
        ),
    ];
  }
}

class TraceBucket {
  TraceBucket(DateTime from, DateTime until, String format)
    : start = from.millisecondsSinceEpoch,
      end = until.millisecondsSinceEpoch,
      label = DateFormat(format).format(from);

  final int start;
  final int end;
  final String label;
  int duration = 0;
}
