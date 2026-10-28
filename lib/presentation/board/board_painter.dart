import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_elevation.dart';
import '../../domain/models/cell.dart';
import '../../domain/models/game_state.dart';
import '../../domain/models/player_id.dart';
import '../../domain/models/wall.dart';
import '../../domain/models/wall_orientation.dart';
import 'board_animation.dart';
import 'board_geometry.dart';

/// Preview of a ghost wall placement.
class WallPreview {
  const WallPreview({
    required this.anchor,
    required this.orientation,
    required this.isValid,
  });

  final Cell anchor;
  final WallOrientation orientation;
  final bool isValid;
}

/// Custom painter that renders a Wallforge game board.
///
/// Layers (bottom → top) from `main_gameplay_screen/code.html`:
/// 1. Board arena container (recessed obsidian, 16px radius, ambient shadow)
/// 2. Ambient underglow
/// 3. Grid surface (#090E19 inset)
/// 4. Tiles (#17233F, rounded, hairline groove)
/// 5. Goal strips (top + bottom, emerald gradient)
/// 6. Coordinate labels
/// 7. Goal-row wash
/// 8. Legal-move rings
/// 9. Walls
/// 10. Ghost wall
/// 11. Pawns (contact shadow, radial fill, specular highlight)
/// 12. Active-turn glow ring
class BoardPainter extends CustomPainter {
  BoardPainter({
    required this.state,
    required this.geometry,
    this.legalMoveTargets = const {},
    this.pathCells = const [],
    this.wallPreview,
    this.selectedCell,
    this.showCoordinates = true,
    this.activeGlow,
    this.animator,
  }) : super(repaint: animator);

  final GameState state;
  final BoardGeometry geometry;
  final Set<Cell> legalMoveTargets;

  /// The Phase 12 one-shot animation driver, or null (pre-Phase-12
  /// callers and most tests): the board then renders its state exactly,
  /// with no animation frame. Registered as the painter's repaint
  /// listenable, so animation frames repaint only this board (its
  /// `RepaintBoundary`), never the surrounding app (`rules.md` §16).
  final BoardAnimator? animator;

  /// Movement-assistance route for the player to move (Phase 11): the cells
  /// of their shortest route to the goal, drawn as a dotted trail. Empty in
  /// every pre-Phase-11 use, so existing rendering is unchanged.
  final List<Cell> pathCells;
  final WallPreview? wallPreview;
  final Cell? selectedCell;
  final bool showCoordinates;
  final PlayerId? activeGlow;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = animator?.frame() ?? const BoardAnimFrame();
    _drawBoardArena(canvas, size);
    _drawGridSurface(canvas, size);
    _drawTiles(canvas, size);
    _drawGoalStrips(canvas, size, frame);
    if (showCoordinates) _drawCoordinates(canvas, size);
    _drawLegalMoveRings(canvas, size);
    if (pathCells.isNotEmpty) _drawPathTrail(canvas, size);
    _drawConflictHalos(canvas);
    _drawWalls(canvas, size, frame);
    _drawGhostWall(canvas, size);
    _drawPawns(canvas, size, frame);
    _drawActiveGlow(canvas, size, frame);
    _drawSelectionRing(canvas, frame);
  }

  void _drawBoardArena(Canvas canvas, Size size) {
    final arenaRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final arenaRrect = RRect.fromRectAndRadius(
      arenaRect,
      const Radius.circular(16),
    );

    // Ambient shadow
    canvas.drawRRect(
      arenaRrect,
      Paint()
        ..color = const Color(0xD9000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40)
        ..shader = ui.Gradient.linear(
          Offset(size.width / 2, 0),
          Offset(size.width / 2, size.height),
          [const Color(0xD9000000), Colors.transparent],
        ),
    );

    // Board outer fill
    canvas.drawRRect(arenaRrect, Paint()..color = AppColors.boardOuter);

    // Ambient underglow top
    final topGlowRect = Rect.fromCenter(
      center: Offset(size.width / 2, -20),
      width: 256,
      height: 96,
    );
    canvas.drawOval(
      topGlowRect,
      Paint()
        ..color = AppElevation.ambientUnderglow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 48),
    );

    // Ambient underglow bottom
    final bottomGlowRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height + 20),
      width: 256,
      height: 96,
    );
    canvas.drawOval(
      bottomGlowRect,
      Paint()
        ..color = AppElevation.ambientUnderglow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 48),
    );
  }

  void _drawGridSurface(Canvas canvas, Size size) {
    final g = geometry;
    final surfaceRect = Rect.fromLTWH(
      g.padding - 2,
      g.padding - 2,
      g.boardArea + 4,
      g.boardArea + 4,
    );
    final surfaceRrect = RRect.fromRectAndRadius(
      surfaceRect,
      const Radius.circular(12),
    );
    canvas.drawRRect(surfaceRrect, Paint()..color = AppColors.gridSurface);
  }

  void _drawTiles(Canvas canvas, Size size) {
    final g = geometry;
    final tilePaint = Paint()..color = AppColors.tileColor;
    const tileRadius = Radius.circular(6);

    for (var row = 0; row < g.boardSize; row++) {
      for (var col = 0; col < g.boardSize; col++) {
        final rect = g.cellRectCentered(row, col);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, tileRadius), tilePaint);
      }
    }
  }

  void _drawGoalStrips(Canvas canvas, Size size, BoardAnimFrame frame) {
    final g = geometry;

    // Phase 12 (§7: the goal animates only on proximity and victory):
    // a one-shot swell on the strip whose pawn is close, and on the
    // winner's strip during the celebration. Otherwise boost is 0 and
    // the strips render exactly as before.
    var topBoost = 0.0;
    var bottomBoost = 0.0;
    final pulse = frame.goalPulse;
    if (pulse != null) {
      final boost = 0.6 * math.sin(math.pi * pulse.t);
      if (pulse.top) {
        topBoost = boost;
      } else {
        bottomBoost = boost;
      }
    }
    final victory = frame.victory;
    if (victory != null) {
      final boost = 0.8 * math.sin(math.pi * victory.t);
      if (victory.winner == PlayerId.blue) {
        topBoost = math.max(topBoost, boost);
      } else {
        bottomBoost = math.max(bottomBoost, boost);
      }
    }

    // Top goal strip (Blue's goal = row 0)
    _drawGoalStrip(canvas, g.topGoalStrip, true, topBoost);
    _drawGoalStripLabel(canvas, g.topGoalStrip, 'P1 GOAL STRIP', true, g);
    // Bottom goal strip (Red's goal = row size-1)
    _drawGoalStrip(canvas, g.bottomGoalStrip, false, bottomBoost);
    _drawGoalStripLabel(canvas, g.bottomGoalStrip, 'P2 GOAL STRIP', false, g);
  }

  void _drawGoalStrip(Canvas canvas, Rect rect, bool isTop, double boost) {
    double boosted(double alpha) =>
        (alpha * (1 + boost)).clamp(0.0, 1.0).toDouble();
    final gradientPaint = Paint()
      ..shader = ui.Gradient.linear(
        rect.topLeft,
        rect.topRight,
        [
          AppColors.tertiaryContainer.withValues(alpha: boosted(0.2)),
          AppColors.tertiaryContainer.withValues(alpha: boosted(0.8)),
          AppColors.tertiaryContainer.withValues(alpha: boosted(0.2)),
        ],
        [0.0, 0.5, 1.0],
      );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      gradientPaint,
    );
  }

  void _drawGoalStripLabel(
    Canvas canvas,
    Rect rect,
    String text,
    bool isTop,
    BoardGeometry g,
  ) {
    final fontSize = (9.0 * (g.boardSize / 9)).clamp(6.0, 12.0);
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w900,
          color: AppColors.onTertiaryContainer.withValues(alpha: 0.9),
          letterSpacing: 0.12,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(rect.center.dx - tp.width / 2, rect.center.dy - tp.height / 2),
    );
  }

  void _drawCoordinates(Canvas canvas, Size size) {
    final g = geometry;

    for (var col = 0; col < g.boardSize; col++) {
      // Top row (rank = boardSize)
      final topLabel = g.cellLabel(0, col);
      final topCentre = g.cellCenter(0, col);
      _drawLabel(canvas, topLabel, topCentre.translate(0, -g.cellSize * 0.35));

      // Bottom row (rank = 1)
      final bottomLabel = g.cellLabel(g.boardSize - 1, col);
      final bottomCentre = g.cellCenter(g.boardSize - 1, col);
      _drawLabel(
        canvas,
        bottomLabel,
        bottomCentre.translate(0, g.cellSize * 0.35),
      );
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset centre) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 9,
          fontFamily: 'Inter',
          color: AppColors.onSurfaceVariant.withValues(alpha: 0.3),
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, centre - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawLegalMoveRings(Canvas canvas, Size size) {
    final g = geometry;
    final p1 = state.currentPlayer == PlayerId.blue;
    final ringColor = p1 ? AppColors.bluePlayer : AppColors.redPlayer;
    final ringPaint = Paint()
      ..color = ringColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final dotPaint = Paint()..color = ringColor;

    for (final cell in legalMoveTargets) {
      final centre = g.cellCenterFromModel(cell);
      final outerR = g.cellSize * 0.35;
      canvas.drawCircle(centre, outerR, ringPaint);
      canvas.drawCircle(centre, g.cellSize * 0.12, dotPaint);
    }
  }

  /// The movement-assistance trail: a thin line from the pawn through each
  /// route cell, with a dot on every cell, in the moving player's colour at
  /// reduced opacity — visually quieter than the legal-move rings, and a
  /// different shape (a connected trail, not rings), so the two meanings are
  /// never carried by colour alone (`design.md` §26).
  void _drawPathTrail(Canvas canvas, Size size) {
    final g = geometry;
    final p1 = state.currentPlayer == PlayerId.blue;
    final color = p1 ? AppColors.bluePlayer : AppColors.redPlayer;
    final start = g.cellCenterFromModel(
      state.pawnPosition(state.currentPlayer),
    );
    final centres = <Offset>[
      start,
      for (final cell in pathCells) g.cellCenterFromModel(cell),
    ];

    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()..moveTo(centres.first.dx, centres.first.dy);
    for (final centre in centres.skip(1)) {
      path.lineTo(centre.dx, centre.dy);
    }
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = color.withValues(alpha: 0.55);
    for (final centre in centres.skip(1)) {
      canvas.drawCircle(centre, g.cellSize * 0.09, dotPaint);
    }
  }

  void _drawWalls(Canvas canvas, Size size, BoardAnimFrame frame) {
    final g = geometry;
    final animating = frame.wallIn?.wall;
    for (final wall in state.walls) {
      if (wall == animating) continue;
      _drawWall(canvas, wall, g);
    }
    // Phase 12 (§9): the just-placed wall scales/fades into its final
    // position instead of appearing at full strength in one frame.
    final wallIn = frame.wallIn;
    if (wallIn != null) {
      final rect = g.wallRectFromModel(wallIn.wall);
      final t = Curves.easeOutCubic.transform(wallIn.t);
      canvas.saveLayer(
        rect.inflate(6),
        Paint()..color = Color.fromRGBO(0, 0, 0, t),
      );
      canvas.translate(rect.center.dx, rect.center.dy);
      canvas.scale(0.7 + 0.3 * t);
      canvas.translate(-rect.center.dx, -rect.center.dy);
      _drawWall(canvas, wallIn.wall, g);
      canvas.restore();
    }
  }

  void _drawWall(Canvas canvas, Wall wall, BoardGeometry g) {
    final rect = g.wallRectFromModel(wall);
    final isP1 = wall.owner == PlayerId.blue;

    // Bevel gradient (top-left lighter, bottom-right darker)
    final gradientPaint = Paint()
      ..shader = ui.Gradient.linear(
        rect.topLeft,
        isP1 ? const Offset(1, 0) : const Offset(0, 1),
        // The wall's owner colours come from the same identity tokens
        // as the pawns (Phase 13), so colour assistance re-tints walls
        // with their owner.
        isP1
            ? [AppColors.pawnGradientBlue.first, AppColors.bluePlayer]
            : [AppColors.pawnGradientRed.first, AppColors.redPlayer],
      );

    final wallRrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    canvas.drawRRect(wallRrect, gradientPaint);

    // Bevel catchlight (1px top edge)
    final catchlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    if (wall.orientation == WallOrientation.h) {
      canvas.drawLine(
        Offset(rect.left + 4, rect.top + 1),
        Offset(rect.right - 4, rect.top + 1),
        catchlightPaint,
      );
    } else {
      canvas.drawLine(
        Offset(rect.left + 1, rect.top + 4),
        Offset(rect.left + 1, rect.bottom - 4),
        catchlightPaint,
      );
    }
  }

  void _drawGhostWall(Canvas canvas, Size size) {
    if (wallPreview == null) return;
    final g = geometry;
    final wp = wallPreview!;
    final rect = g.wallRect(wp.anchor.row, wp.anchor.column, wp.orientation);
    final ghostRrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));

    if (wp.isValid) {
      // The ghost is the current player's own wall preview, so it
      // carries that player's identity colour (Phase 13 — before, the
      // preview was always Blue's colour, even on Red's turn).
      final mine = state.currentPlayer == PlayerId.blue
          ? AppColors.bluePlayer
          : AppColors.redPlayer;
      _drawGhostFill(canvas, ghostRrect, mine, 0.35);
      _drawGhostOutline(canvas, ghostRrect, mine, 0.4);
      return;
    }

    // Stitch DESIGN.md §Components specifies only a 50% crimson invalid ghost
    // and no pattern. Phase 4.2 keeps that fill and adds a dashed centre line
    // plus a stronger outline, because a diagonal hatch merges into a solid
    // fill at the rendered bar thickness (grooveWidth * 1.5).
    _drawGhostFill(canvas, ghostRrect, AppColors.error, 0.50);
    _drawInvalidGhostDashes(canvas, ghostRrect);
    _drawGhostOutline(canvas, ghostRrect, AppColors.error, 0.95);
  }

  void _drawGhostFill(Canvas canvas, RRect bounds, Color color, double alpha) {
    canvas.drawRRect(
      bounds,
      Paint()
        ..color = color.withValues(alpha: alpha)
        ..style = PaintingStyle.fill,
    );
  }

  void _drawGhostOutline(
    Canvas canvas,
    RRect bounds,
    Color color,
    double alpha,
  ) {
    canvas.drawRRect(
      bounds,
      Paint()
        ..color = color.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawInvalidGhostDashes(Canvas canvas, RRect bounds) {
    final rect = bounds.outerRect;
    final thickness = math.min(rect.width, rect.height);
    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = math.min(1.5, thickness * 0.6)
      ..strokeCap = StrokeCap.butt;
    const dash = 4.0;
    const gap = 3.0;
    const inset = 1.0;

    if (rect.width >= rect.height) {
      final y = rect.center.dy;
      for (var x = rect.left + inset; x < rect.right - inset; x += dash + gap) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + dash, rect.right - inset), y),
          dashPaint,
        );
      }
    } else {
      final x = rect.center.dx;
      for (var y = rect.top + inset; y < rect.bottom - inset; y += dash + gap) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x, math.min(y + dash, rect.bottom - inset)),
          dashPaint,
        );
      }
    }
  }

  /// Paints an error-coloured aura behind every placed wall that the invalid
  /// ghost physically touches.
  ///
  /// This is a purely geometric highlight: it never decides legality, it only
  /// ties the visible failure to the existing wall segment involved. Walls that
  /// merely touch end-to-end do not overlap and are not marked, and because the
  /// aura is painted before the walls the placed wall stays fully visible.
  void _drawConflictHalos(Canvas canvas) {
    final wp = wallPreview;
    if (wp == null || wp.isValid) return;

    final g = geometry;
    final ghostRect = g.wallRect(
      wp.anchor.row,
      wp.anchor.column,
      wp.orientation,
    );
    final haloPaint = Paint()
      ..color = AppColors.error.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final wall in state.walls) {
      if (!g.wallRectFromModel(wall).overlaps(ghostRect)) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          g.wallRectFromModel(wall).inflate(2),
          const Radius.circular(6),
        ),
        haloPaint,
      );
    }
  }

  void _drawPawns(Canvas canvas, Size size, BoardAnimFrame frame) {
    final g = geometry;
    _drawPawn(canvas, PlayerId.blue, g, frame);
    _drawPawn(canvas, PlayerId.red, g, frame);
  }

  void _drawPawn(
    Canvas canvas,
    PlayerId player,
    BoardGeometry g,
    BoardAnimFrame frame,
  ) {
    final cell = state.pawnPosition(player);
    var centre = g.cellCenterFromModel(cell);
    var scale = 1.0;

    // Phase 12 (§8): a moved pawn translates smoothly between cells
    // with a small landing bounce in the final portion; the winner's
    // pawn additionally swells during the celebration. Without an
    // animation frame this draws exactly the pre-Phase-12 pawn.
    final move = frame.pawnMove;
    if (move != null && move.player == player) {
      final eased = Curves.easeInOutCubic.transform(move.t);
      centre = Offset.lerp(
        g.cellCenterFromModel(move.from),
        g.cellCenterFromModel(move.to),
        eased,
      )!;
      if (move.t > 0.7) {
        final u = (move.t - 0.7) / 0.3;
        scale *= 1 + 0.14 * math.sin(math.pi * u);
      }
    }
    final victory = frame.victory;
    if (victory != null && victory.winner == player) {
      scale *= 1 + 0.16 * math.sin(math.pi * victory.t);
    }

    final radius = g.cellSize * 0.28 * scale;

    final isP1 = player == PlayerId.blue;

    // Contact shadow
    final shadowRect = Rect.fromCenter(
      center: centre.translate(0, radius * 0.7),
      width: radius * 2,
      height: radius * 0.6,
    );
    canvas.drawOval(
      shadowRect,
      Paint()
        ..color = Colors.black.withValues(alpha: isP1 ? 0.8 : 0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Pawn gradient
    final pawnPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(centre.dx - radius, centre.dy - radius),
        Offset(centre.dx + radius, centre.dy + radius),
        isP1 ? AppColors.pawnGradientBlue : AppColors.pawnGradientRed,
        [0.0, 0.5, 1.0],
      );
    canvas.drawCircle(centre, radius, pawnPaint);

    // Specular highlight
    final specPaint = Paint()
      ..color = Colors.white.withValues(alpha: isP1 ? 0.9 : 0.7)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.4);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centre.dx - radius * 0.2, centre.dy - radius * 0.3),
        width: radius * 0.8,
        height: radius * 0.4,
      ),
      specPaint,
    );

    // Second specular dot
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: isP1 ? 0.7 : 0.4);
    canvas.drawCircle(
      Offset(centre.dx - radius * 0.1, centre.dy - radius * 0.15),
      radius * 0.12,
      dotPaint,
    );

    // The player's letter on the pawn itself (`design.md` §26: identity
    // is name + colour + label, never colour alone). Phase 13 added
    // this: before it, the pawn's identity on the canvas rested on its
    // colour and start position only, despite the Settings screen
    // claiming the letters existed. The letter sits at the pawn's
    // centre in near-black, legible on both gradients' mid-tones and
    // unchanged in meaning under colour assistance (B stays Blue's
    // piece even when its colour becomes the Okabe–Ito blue).
    final letter = TextPainter(
      text: TextSpan(
        text: pawnLetter(player),
        style: TextStyle(
          fontSize: radius * 0.95,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w900,
          color: Colors.black.withValues(alpha: 0.78),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    letter.paint(canvas, centre - Offset(letter.width / 2, letter.height / 2));
  }

  /// The letter drawn on [player]'s pawn (`design.md` §26's text
  /// label): `B` for Blue, `R` for Red. Exposed for the Phase 13
  /// player-identity tests.
  static String pawnLetter(PlayerId player) =>
      player == PlayerId.blue ? 'B' : 'R';

  void _drawActiveGlow(Canvas canvas, Size size, BoardAnimFrame frame) {
    if (activeGlow == null) return;
    final g = geometry;
    final cell = state.pawnPosition(activeGlow!);
    var centre = g.cellCenterFromModel(cell);
    var radius = g.cellSize * 0.35;
    var alpha = 0.25;

    // The glow follows a pawn that is still translating, and swells
    // once when the turn changes (§8's pulse as a state-change signal).
    final move = frame.pawnMove;
    if (move != null && move.player == activeGlow) {
      final eased = Curves.easeInOutCubic.transform(move.t);
      centre = Offset.lerp(
        g.cellCenterFromModel(move.from),
        g.cellCenterFromModel(move.to),
        eased,
      )!;
    }
    final pulse = frame.glowPulse;
    if (pulse != null && pulse.player == activeGlow) {
      final swell = math.sin(math.pi * pulse.t);
      alpha += 0.30 * swell;
      radius *= 1 + 0.18 * swell;
    }
    final victory = frame.victory;
    if (victory != null && victory.winner == activeGlow) {
      alpha += 0.35 * math.sin(math.pi * victory.t);
    }

    final isP1 = activeGlow == PlayerId.blue;
    final glowColor = isP1 ? AppColors.bluePlayer : AppColors.redPlayer;

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..color = glowColor.withValues(alpha: alpha.clamp(0.0, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  /// `design.md` §8's Selected state: a stronger ring around the
  /// selected cell, in the current player's colour.
  ///
  /// The plumbing for this (BoardView.selectedCell → painter) existed
  /// since Phase 4 but nothing ever drew it; Phase 12 verification
  /// found that gap and this is the ring §8 specifies. It fades/scales
  /// in over [FeedbackTiming.microFeedback] when the board is animated,
  /// and is fully present in any static render.
  void _drawSelectionRing(Canvas canvas, BoardAnimFrame frame) {
    final selected = selectedCell;
    if (selected == null) return;
    final g = geometry;
    final centre = g.cellCenterFromModel(selected);
    var t = 1.0;
    final selection = frame.selection;
    if (selection != null && selection.cell == selected) {
      t = Curves.easeOutCubic.transform(selection.t);
    }
    final isBlue = state.currentPlayer == PlayerId.blue;
    final color = isBlue ? AppColors.bluePlayer : AppColors.redPlayer;
    canvas.drawCircle(
      centre,
      g.cellSize * (0.34 + 0.04 * t),
      Paint()
        ..color = color.withValues(alpha: 0.9 * t)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(BoardPainter oldDelegate) =>
      state != oldDelegate.state ||
      legalMoveTargets != oldDelegate.legalMoveTargets ||
      pathCells != oldDelegate.pathCells ||
      wallPreview != oldDelegate.wallPreview ||
      selectedCell != oldDelegate.selectedCell ||
      showCoordinates != oldDelegate.showCoordinates ||
      activeGlow != oldDelegate.activeGlow ||
      animator != oldDelegate.animator;
}
