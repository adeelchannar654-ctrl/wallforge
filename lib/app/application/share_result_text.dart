import '../../domain/models/finish_reason.dart';
import '../../domain/models/match_record.dart';
import '../../domain/models/player_id.dart';

/// The text half of a shared result (Phase 16.5, Part G).
///
/// Deliberately identifier-free: the outcome, the mode, the
/// board, the plies, the duration and the date — plus the
/// opponent description the record already carries ("AI ·
/// Hard", "Online player"). No room codes, no uids, no names
/// the player did not choose.
String buildShareText(MatchRecord record) {
  final headline = _headline(record);
  final meta = <String>[
    record.mode.label,
    record.opponentLabel,
    '${record.boardSize}×${record.boardSize}',
    '${record.plies} plies',
    _duration(record.durationMs),
    _date(record.endedAtMs),
  ].join(' · ');
  return '$headline — Wallforge\n$meta';
}

String _headline(MatchRecord record) {
  final winner = record.winnerSide;
  if (winner == null) return 'Match abandoned';
  final base = winner == PlayerId.blue ? 'Blue wins' : 'Red wins';
  return switch (record.finishReason) {
    FinishReason.goal => base,
    FinishReason.resign => '$base by resignation',
    FinishReason.timeout => '$base on time',
    FinishReason.abandon => base,
  };
}

String _duration(int durationMs) {
  final seconds = durationMs ~/ 1000;
  if (seconds < 60) return '$seconds s';
  final minutes = seconds ~/ 60;
  if (minutes < 60) return '$minutes min';
  return '${minutes ~/ 60} h ${(minutes % 60).toString().padLeft(2, '0')} min';
}

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _date(int endedAtMs) {
  final t = DateTime.fromMillisecondsSinceEpoch(endedAtMs);
  return '${_months[t.month - 1]} ${t.day}, ${t.year}';
}
