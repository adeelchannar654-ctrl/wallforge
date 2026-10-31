import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/match_record.dart';
import '../../domain/repositories/repositories.dart';

/// Match history stored with `shared_preferences` (Phase 16.5).
///
/// One JSON blob under a versioned key:
///
/// ```json
/// {"schemaVersion": 1, "records": [ … ], "recordedIds": [ … ]}
/// ```
///
/// * `records` — the [MatchRecord]s, newest first, bounded to
///   [MatchHistoryRepository.maxRecords].
/// * `recordedIds` — the finish gate: every id ever recorded,
///   bounded the same way. It deliberately outlives `delete`
///   and `clear` (see the interface doc).
///
/// Tolerance rules, mirroring the other local repositories: a
/// missing/corrupt blob reads as empty; individual damaged
/// records are skipped, not fatal; a blob from a NEWER schema
/// version reads as empty and is never overwritten by this
/// build (a downgrade must not destroy a newer history).
class SharedPreferencesHistoryRepository implements MatchHistoryRepository {
  const SharedPreferencesHistoryRepository({this.key = 'wallforge.history.v1'});

  /// Versioned storage key.
  final String key;

  /// The blob schema this build reads and writes.
  static const int blobSchemaVersion = 1;

  @override
  Future<List<MatchRecord>> load() async {
    final blob = await _readBlob();
    return blob?.records ?? const <MatchRecord>[];
  }

  @override
  Future<bool> recordIfNew(MatchRecord record) async {
    try {
      final blob = await _readBlob();
      if (blob == null) {
        // Unreadable or newer-version store: do not write.
        if (await _hasNewerBlob()) return false;
        // Nothing stored yet (or corrupt): start fresh.
        await _writeBlob(records: [record], recordedIds: [record.id]);
        return true;
      }
      if (blob.recordedIds.contains(record.id)) return false;
      final records = [record, ...blob.records];
      final ids = [record.id, ...blob.recordedIds];
      await _writeBlob(
        records: records.take(MatchHistoryRepository.maxRecords).toList(),
        recordedIds: ids.take(MatchHistoryRepository.maxRecords).toList(),
      );
      return true;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      final blob = await _readBlob();
      if (blob == null) return;
      await _writeBlob(
        records: blob.records.where((r) => r.id != id).toList(),
        recordedIds: blob.recordedIds,
      );
    } on Object {
      // Nothing to do; the record simply remains.
    }
  }

  @override
  Future<void> clear() async {
    try {
      final blob = await _readBlob();
      if (blob == null) return;
      await _writeBlob(records: const [], recordedIds: blob.recordedIds);
    } on Object {
      // Nothing to do; the records simply remain.
    }
  }

  @override
  Future<Set<String>?> recordedIds() async {
    // A newer-schema blob must not be merged against a guess.
    if (await _hasNewerBlob()) return null;
    final blob = await _readBlob();
    // Missing or corrupt reads as an empty gate: recordIfNew
    // would start fresh from the same state, so the merge may
    // treat this device as having counted nothing.
    if (blob == null) return <String>{};
    return blob.recordedIds.toSet();
  }

  @override
  Future<void> absorbRecordedIds(Set<String> ids) async {
    if (ids.isEmpty) return;
    try {
      if (await _hasNewerBlob()) return;
      final blob = await _readBlob();
      if (blob == null) {
        // Nothing stored yet (or corrupt): start the gate with
        // the absorbed ids, exactly as recordIfNew starts fresh.
        await _writeBlob(
          records: const [],
          recordedIds: ids.take(MatchHistoryRepository.maxRecords).toList(),
        );
        return;
      }
      final merged = <String>[
        ...blob.recordedIds,
        for (final id in ids)
          if (!blob.recordedIds.contains(id)) id,
      ];
      await _writeBlob(
        records: blob.records,
        recordedIds: merged.take(MatchHistoryRepository.maxRecords).toList(),
      );
    } on Object {
      // A failed absorb costs the merge's protection, not play;
      // the next sign-in merge retries it.
    }
  }

  /// Whether the stored blob declares a schema newer than this
  /// build understands (and so must be left alone).
  Future<bool> _hasNewerBlob() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return false;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return false;
      final version = decoded['schemaVersion'];
      return version is int && version > blobSchemaVersion;
    } on Object {
      return false;
    }
  }

  Future<({List<MatchRecord> records, List<String> recordedIds})?>
  _readBlob() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final map = decoded.cast<String, dynamic>();
      final version = map['schemaVersion'];
      if (version is int && version > blobSchemaVersion) return null;
      final rawRecords = map['records'];
      final records = <MatchRecord>[];
      if (rawRecords is List) {
        for (final entry in rawRecords) {
          if (entry is Map) {
            final record = MatchRecord.fromJson(entry.cast<String, dynamic>());
            if (record != null) records.add(record);
          }
        }
      }
      final rawIds = map['recordedIds'];
      return (
        records: records,
        recordedIds: rawIds is List
            ? rawIds.whereType<String>().toList()
            : <String>[for (final r in records) r.id],
      );
    } on Object {
      return null;
    }
  }

  Future<void> _writeBlob({
    required List<MatchRecord> records,
    required List<String> recordedIds,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      jsonEncode(<String, dynamic>{
        'schemaVersion': blobSchemaVersion,
        'records': [for (final r in records) r.toJson()],
        'recordedIds': recordedIds,
      }),
    );
  }
}
