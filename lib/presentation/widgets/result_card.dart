import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../app/application/share_result_text.dart';
import '../../app/application/web_download.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../domain/models/game_state.dart';
import '../../domain/models/match_record.dart';
import '../board/board_geometry.dart';
import '../board/board_painter.dart';
import '../screens/history/history_screen.dart' show formatHistoryDuration;

/// The shareable result card (Phase 16.5, Part G): the final
/// board drawn with the game's own painter, the outcome, and
/// the match's facts — the app name, and nothing else. No
/// identifiers, no room codes, no names beyond what the
/// record itself carries.
///
/// Sharing, honestly (see the Phase 16.5 ledger): Flutter has
/// no built-in cross-platform share sheet, and the package
/// that provides one could not be build-verified in the
/// environment this phase was built in, so the shipped paths
/// are the fallbacks — on web the PNG downloads and the text
/// summary is copied; on native the text is copied and the
/// card is shown so it can be screenshotted. The native share
/// sheet is the documented missing piece.
class ResultCard extends StatelessWidget {
  const ResultCard({super.key, required this.record, required this.finalState});

  final MatchRecord record;
  final GameState finalState;

  /// The card's logical size; captured at 2× for a
  /// 1200×1560 PNG.
  static const Size cardSize = Size(600, 780);

  @override
  Widget build(BuildContext context) {
    final text = buildShareText(record);
    final lines = text.split('\n');
    return Semantics(
      container: true,
      label: 'Result card. ${lines.join('. ')}',
      child: ExcludeSemantics(
        child: Container(
          width: cardSize.width,
          height: cardSize.height,
          color: AppColors.background,
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WALLFORGE',
                style: AppTypography.labelCaps.copyWith(
                  fontSize: 20,
                  letterSpacing: 4,
                  color: AppColors.tertiary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(lines.first, style: AppTypography.headlineMd),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: SizedBox(
                  width: 520,
                  height: 520,
                  child: CustomPaint(
                    painter: BoardPainter(
                      state: finalState,
                      geometry: BoardGeometry(
                        boardSize: finalState.boardConfig.size,
                        areaSize: 520,
                      ),
                      showCoordinates: false,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(lines.last, style: AppTypography.bodyBase),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Duration ${formatHistoryDuration(record.durationMs)}',
                style: AppTypography.bodyBase.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Captures [card] to PNG bytes by rendering it off-screen in
/// an overlay for two frames. Returns null when capture is
/// impossible (no overlay, no boundary) — callers fall back to
/// the text share rather than failing.
Future<Uint8List?> captureResultCardPng(
  BuildContext context,
  ResultCard card,
) async {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return null;
  final key = GlobalKey();
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      left: -10000,
      top: 0,
      child: Material(
        child: RepaintBoundary(key: key, child: card),
      ),
    ),
  );
  overlay.insert(entry);
  try {
    // Wait until the entry has been laid out and painted.
    // Each iteration schedules its own frame: awaiting
    // endOfFrame without one can stall forever in a quiescent
    // tree (a widget test, an idle app), and a single frame
    // may predate the insertion.
    RenderRepaintBoundary? boundary;
    for (var attempt = 0; attempt < 5; attempt++) {
      WidgetsBinding.instance.scheduleFrame();
      await WidgetsBinding.instance.endOfFrame;
      final candidate =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (candidate != null && candidate.hasSize) {
        boundary = candidate;
        break;
      }
    }
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  } on Object {
    return null;
  } finally {
    entry.remove();
  }
}

/// Runs the share flow for [record]: card image where the
/// platform allows it, text summary always. [finalState] is
/// the board the card draws; null (a partial move list) shares
/// the text alone and says why.
Future<void> shareMatchResult(
  BuildContext context, {
  required MatchRecord record,
  required GameState? finalState,
}) async {
  final text = buildShareText(record);
  Future<void> copyText() => Clipboard.setData(ClipboardData(text: text));

  if (finalState == null) {
    await copyText();
    if (!context.mounted) return;
    _snack(
      context,
      'Result text copied. This match\'s move list is incomplete, '
      'so no board card was made.',
    );
    return;
  }

  final png = await captureResultCardPng(
    context,
    ResultCard(record: record, finalState: finalState),
  );
  if (!context.mounted) return;
  if (png == null) {
    await copyText();
    if (!context.mounted) return;
    _snack(context, 'Result text copied. The card could not be rendered.');
    return;
  }

  if (kIsWeb) {
    final downloaded = downloadPngBytes(
      png,
      'wallforge-result-${record.id}.png',
    );
    await copyText();
    if (!context.mounted) return;
    _snack(
      context,
      downloaded
          ? 'Card downloaded · result text copied'
          : 'Result text copied',
    );
    return;
  }

  await copyText();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Your result card'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.memory(png, width: 300),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'The result text is on your clipboard. Sharing the '
            'card image directly needs the system share sheet, '
            'which this build does not include yet — screenshot '
            'the card to keep it.',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CLOSE'),
        ),
      ],
    ),
  );
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
      ?.showSnackBar(SnackBar(content: Text(message)));
}
