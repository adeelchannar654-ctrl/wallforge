import '../models/board_config.dart';
import '../models/match_record.dart';
import 'app_settings.dart';
import 'match_statistics.dart';
import 'room.dart';
import 'unfinished_match.dart';

export 'app_settings.dart';
export 'auth.dart';
export 'cloud_profile.dart';
export 'match_statistics.dart';
export 'room.dart';
export 'unfinished_match.dart';

/// Local persistence contracts, declared in the domain layer and implemented in
/// `lib/data/local/`.
///
/// `architecture.md` §2.4 requires repositories to "expose domain-friendly
/// interfaces to the application layer", and `lib/data/README.md` states the
/// dependency direction as `Data -> Domain interfaces`. Keeping the contracts
/// here is what lets Phase 7 supply a Firebase implementation without the
/// application layer changing.
///
/// All methods are `Future`-returning because a real device write is async, and
/// none of them throw: a storage failure resolves to the default value, because
/// losing a setting must never stop the app from starting.
abstract interface class SettingsRepository {
  /// Loads persisted settings, or [AppSettings.defaults] when nothing is stored
  /// or the stored value is unreadable.
  Future<AppSettings> load();

  /// Persists [settings], replacing whatever was stored.
  Future<void> save(AppSettings settings);
}

/// Local match-result history.
abstract interface class StatisticsRepository {
  /// Loads accumulated statistics, or [MatchStatistics.empty].
  Future<MatchStatistics> load();

  /// Folds one finished match into the stored totals and returns the new value.
  Future<MatchStatistics> recordResult({
    required int boardSize,
    required String difficulty,
    required bool humanWon,
  });

  /// Replaces the stored totals wholesale (Phase 16.6): the
  /// cloud-profile merge adopting a snapshot that provably covers
  /// every match this device counted. Never used for ordinary
  /// recording — [recordResult] is the only way totals grow one
  /// match at a time.
  Future<void> replace(MatchStatistics value);

  /// Discards all stored statistics.
  Future<void> clear();
}

/// The single resumable match.
abstract interface class UnfinishedMatchRepository {
  /// Loads the resumable match, or null when there is none or it is unreadable.
  Future<UnfinishedMatch?> load();

  /// Stores [match] as the resumable match, replacing any previous one.
  Future<void> save(UnfinishedMatch match);

  /// Removes the resumable match. Called when a match finishes or is abandoned.
  Future<void> clear();
}

/// Per-device match history (Phase 16.5, Part E).
///
/// History is deliberately **local only**: no implementation
/// reads or writes anything online. Online matches are recorded
/// from the final snapshot the client already holds, so keeping
/// history costs no Firestore operations at all.
///
/// The store carries its own finish gate: [recordIfNew] is the
/// only way records enter, and it refuses an id that was ever
/// recorded before (the gate set survives restarts and is
/// bounded with the records), which is what makes "recorded
/// exactly once" hold even when a finish is observed repeatedly
/// (repeated snapshots, a rapid double finish, an app restart
/// between the finish and the write).
abstract interface class MatchHistoryRepository {
  /// The maximum number of records (and gate ids) retained.
  static const int maxRecords = 100;

  /// Loads the recorded matches, newest first. Tolerant: a
  /// damaged or newer-version store reads as empty and is
  /// never overwritten by a load.
  Future<List<MatchRecord>> load();

  /// Records [record] if its id was never recorded before.
  ///
  /// Returns true when the record was written (and only then
  /// may the caller fold the match into the legacy statistics —
  /// the gate is what keeps history and statistics from ever
  /// double-counting a match). Returns false for a duplicate,
  /// and for a store written by a newer schema version, which
  /// this build must not clobber.
  Future<bool> recordIfNew(MatchRecord record);

  /// Deletes one record by id. The id stays in the gate set:
  /// deleting a record must never make its match recordable
  /// again.
  Future<void> delete(String id);

  /// Discards all records. The gate set is kept for the same
  /// reason as in [delete] — "clear all" clears the list, not
  /// the past.
  Future<void> clear();

  /// The finish gate itself (Phase 16.6): every id ever recorded
  /// on this device. The cloud-profile merge compares this set
  /// against the ids a cloud statistics snapshot claims to cover,
  /// which is what makes the merge provably unable to
  /// double-count a match.
  ///
  /// Null means "the store cannot be read truthfully" (a blob
  /// written by a newer schema version): the caller must not
  /// merge against a guess, and must leave the store untouched.
  Future<Set<String>?> recordedIds();

  /// Adds [ids] to the finish gate without adding records
  /// (Phase 16.6): ids a merged cloud snapshot already counted,
  /// absorbed so those matches can never be counted again on
  /// this device. Bounded like the gate itself; a store written
  /// by a newer schema version is left alone.
  Future<void> absorbRecordedIds(Set<String> ids);
}

/// The achievement unlock store (Phase 16.5, Part F): which
/// achievements have unlocked, and when. Local only, like
/// history — achievements never leave the device.
abstract interface class AchievementsRepository {
  /// Loads the unlock map (achievement id → unlock time, epoch
  /// ms). Tolerant: a damaged store reads as no unlocks.
  Future<Map<String, int>> loadUnlocks();

  /// Persists the unlock map, replacing the stored one. A
  /// store written by a newer schema version is left alone —
  /// the write is silently skipped, as in the history store.
  Future<void> saveUnlocks(Map<String, int> unlocks);
}

/// Online room lifecycle, declared here and implemented in `lib/data/remote/`.
///
/// ## Why rooms are a repository and not application logic
///
/// `architecture.md` §10 lists "Match rooms" and "Player membership" as
/// Firestore's job, and `PRD.md` §9 warns that "the client must not assume that
/// local state is authoritative for another player". Keeping the contract behind
/// an interface is what lets Phase 9 attach move synchronisation to the same
/// abstraction, and lets tests substitute a double exactly as
/// `InMemoryFirestoreClient` already does for the Phase 6/7 repositories.
///
/// ## Contract
///
/// Every method is total: expected rejections come back as
/// [RoomResult.failure] with a specific [RoomFailureReason], and no method
/// throws. That is `rules.md` §7 applied to the data layer — "Firebase
/// unavailable", "permission denied" and "serialization failure" map to
/// application-level errors instead of propagating.
///
/// ## What "match start" means here
///
/// Per `phase.md` Phase 8, a start places both players in one shared room record
/// with an agreed [BoardConfig] and seat assignment, ready for Phase 9 to attach
/// real-time move synchronisation. **Moves are not exchanged in this phase**, and
/// nothing in this interface implies otherwise.
abstract interface class RoomRepository {
  /// Creates a room for the signed-in user with a freshly generated code.
  ///
  /// The creator takes the Blue seat because Blue moves first
  /// (`game_spec.md` R-PLAYER-07) and the existing local code already treats
  /// Blue as the first player (Q-6.2).
  ///
  /// [timeControlSeconds] is the per-move clock chosen at
  /// creation (Phase 16.5; 0 = off). It is part of the room's
  /// agreed terms, like the board config, and never changes.
  Future<RoomResult> create({
    required BoardConfig config,
    int timeControlSeconds = 0,
  });

  /// Joins the room identified by [code], taking the free seat.
  ///
  /// Rejects with a distinct reason for an unknown code, a full room, a started
  /// room, a cancelled room, and a caller who is already seated.
  Future<RoomResult> join(String code);

  /// Sets or clears the calling player's ready state.
  ///
  /// A player may only change their own readiness — `architecture.md` §12 lists
  /// "a user cannot change the opponent's identity" as a rule the security model
  /// must enforce, and this mirrors it on the client side.
  Future<RoomResult> setReady({required String code, required bool ready});

  /// Starts the match, moving the room to [RoomStatus.started].
  ///
  /// Host-only, and only once both seats are filled and both players are ready;
  /// otherwise [RoomFailureReason.playersNotReady] or
  /// [RoomFailureReason.notTheHost].
  Future<RoomResult> start(String code);

  /// Leaves the room before the match starts.
  ///
  /// Semantics are deliberate and asymmetric — see
  /// `FirestoreRoomRepository.leave`.
  Future<RoomResult> leave(String code);

  /// Reads the room once, or null when it does not exist or is unreadable.
  Future<Room?> load(String code);

  /// Watches the room, so the creator sees the opponent arrive without polling.
  ///
  /// Emits null when the room is gone.
  Stream<Room?> watch(String code);
}
