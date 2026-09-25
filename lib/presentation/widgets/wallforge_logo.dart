import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Wallforge logo: a tile with two walls and two pawns.
///
/// Native CustomPainter from the SVG geometry in
/// `wallforge_strategic_logo/code.html`. ViewBox 160×160.
class WallforgeLogo extends StatelessWidget {
  const WallforgeLogo({super.key, this.size = 80});

  /// Logical width and height of the logo.
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CustomPaint(painter: _LogoPainter()),
    );
  }
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 160;
    final sy = size.height / 160;
    canvas.scale(sx, sy);

    // --- Base tile shield ---
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1E293B), Color(0xFF0B101B)],
      ).createShader(const Rect.fromLTWH(16, 16, 128, 128));
    final bgRrect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(16, 16, 128, 128),
      const Radius.circular(28),
    );
    canvas.drawRRect(bgRrect, bgPaint);
    canvas.drawRRect(
      bgRrect,
      Paint()
        ..color = AppColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // --- Grid lattice lines ---
    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 3;
    const dashPattern = <double>[4, 4];
    canvas.drawPath(_dashedLine(36, 80, 124, 80, dashPattern), gridPaint);
    canvas.drawPath(_dashedLine(80, 36, 80, 124, dashPattern), gridPaint);

    // --- Horizontal cyan wall ---
    final wallCyanPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF38BDF8), Color(0xFF00E5FF)],
      ).createShader(const Rect.fromLTWH(42, 52, 76, 10));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(42, 52, 76, 10),
        const Radius.circular(5),
      ),
      wallCyanPaint,
    );

    // --- Vertical red wall ---
    final wallRedPaint = Paint()..color = const Color(0xFFFF4B6E);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(75, 60, 10, 52),
        const Radius.circular(5),
      ),
      wallRedPaint,
    );

    // --- Cyan pawn (bottom-left area) ---
    final cyanPawnPaint = Paint()
      ..shader =
          const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
          ).createShader(
            Rect.fromCircle(center: const Offset(56, 100), radius: 14),
          );
    canvas.drawCircle(const Offset(56, 100), 14, cyanPawnPaint);
    // Specular highlight
    canvas.drawCircle(
      const Offset(53, 97),
      5,
      Paint()..color = const Color(0xCCBAE6FD),
    );

    // --- Red pawn (top-right area) ---
    final redPawnPaint = Paint()
      ..shader =
          const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF6384), Color(0xFFE11D48)],
          ).createShader(
            Rect.fromCircle(center: const Offset(104, 42), radius: 14),
          );
    canvas.drawCircle(const Offset(104, 42), 14, redPawnPaint);
    // Specular highlight
    canvas.drawCircle(
      const Offset(101, 39),
      5,
      Paint()..color = const Color(0xCCFECDD3),
    );
  }

  static Path _dashedLine(
    double x1,
    double y1,
    double x2,
    double y2,
    List<double> pattern,
  ) {
    final path = Path();
    final dx = x2 - x1;
    final dy = y2 - y1;
    final len = math.sqrt(dx * dx + dy * dy);
    final ux = dx / len;
    final uy = dy / len;
    var dist = 0.0;
    var drawing = true;
    var i = 0;
    path.moveTo(x1, y1);
    while (dist < len) {
      final seg = pattern[i % pattern.length];
      final end = (dist + seg).clamp(0.0, len);
      if (drawing) {
        path.lineTo(x1 + ux * end, y1 + uy * end);
      } else {
        path.moveTo(x1 + ux * end, y1 + uy * end);
      }
      dist = end;
      drawing = !drawing;
      i++;
    }
    return path;
  }

  @override
  bool shouldRepaint(_LogoPainter oldDelegate) => false;
}
