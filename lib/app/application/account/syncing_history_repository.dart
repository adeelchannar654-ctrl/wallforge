import '../../../domain/models/match_record.dart';
import '../../../domain/repositories/repositories.dart';

/// A [MatchHistoryRepository] decorator (Phase 16.6, Part E):
/// delegates everything, and reports each *newly recorded*
/// match so the cloud profile can sync it — at most one profile
/// write per finished match, debounced inside the sync service.
///
/// Wired only when the accounts feature is compiled in (a
/// compile-time branch in the persistence factory and the online
/// lobby), so a flag-off build's history path is byte-for-byte
/// the pre-phase one. Duplicates refused by the gate do not
/// notify: only a real finish can trigger a sync.
class SyncingHistoryRepository implements MatchHistoryRepository {
  SyncingHistoryRepository(this.inner, {required this.onRecorded});

  /// The wrapped store.
  final MatchHistoryRepository inner;

  /// Called once per newly recorded match.
  final void Function() onRecorded;

  @override
  Future<List<MatchRecord>> load() => inner.load();

  @override
  Future<bool> recordIfNew(MatchRecord record) async {
    final added = await inner.recordIfNew(record);
    if (added) onRecorded();
    return added;
  }

  @override
  Future<void> delete(String id) => inner.delete(id);

  @override
  Future<void> clear() => inner.clear();

  @override
  Future<Set<String>?> recordedIds() => inner.recordedIds();

  @override
  Future<void> absorbRecordedIds(Set<String> ids) =>
      inner.absorbRecordedIds(ids);
}
