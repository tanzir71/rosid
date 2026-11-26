import 'package:material_ui/material_ui.dart';
import 'package:rosid/core/theme/app_theme.dart';
import 'package:rosid/core/theme/tokens.g.dart';

enum RosidPaperKind { letter, land, certificate, id, receipt, notes }

/// Miniature schematic paper thumbnail matching Figma component `Paper` (`6:164`).
/// Always rendered on light paper tokens even in dark theme.
class RosidPaperThumbnail extends StatelessWidget {
  const RosidPaperThumbnail({
    required this.kind,
    this.width = 48,
    this.height = 60,
    super.key,
  });

  final RosidPaperKind kind;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final isLandscape = kind == RosidPaperKind.id;
    final w = isLandscape ? height : width;
    final h = isLandscape ? width * 0.85 : height;

    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: c.paperSheet,
        borderRadius: BorderRadius.circular(RosidSizeTokens.radiusPaper),
        border: Border.all(color: c.paperLine, width: 1),
        boxShadow: RosidShadowTokens.elevPaper,
      ),
      child: CustomPaint(
        painter: _PaperThumbPainter(
          kind: kind,
          ink: c.paperInk,
          line: c.paperLine,
          accent: RosidColorTokens.accentBaseLight,
        ),
      ),
    );
  }
}

class _PaperThumbPainter extends CustomPainter {
  const _PaperThumbPainter({
    required this.kind,
    required this.ink,
    required this.line,
    required this.accent,
  });

  final RosidPaperKind kind;
  final Color ink;
  final Color line;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final headerPaint = Paint()
      ..color = ink
      ..strokeCap = StrokeCap.round
      ..strokeWidth = (h * 0.055).clamp(2.0, 3.5);
    final linePaint = Paint()
      ..color = line
      ..strokeCap = StrokeCap.round
      ..strokeWidth = (h * 0.04).clamp(1.5, 2.5);
    final gridPaint = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    switch (kind) {
      case RosidPaperKind.letter:
        canvas.drawLine(
          Offset(w * 0.18, h * 0.18),
          Offset(w * 0.56, h * 0.18),
          headerPaint,
        );
        for (var i = 0; i < 5; i++) {
          final y = h * (0.32 + i * 0.11);
          final endX = i == 4 ? w * 0.62 : w * 0.82;
          canvas.drawLine(Offset(w * 0.18, y), Offset(endX, y), linePaint);
        }

      case RosidPaperKind.land:
        canvas.drawLine(
          Offset(w * 0.25, h * 0.16),
          Offset(w * 0.75, h * 0.16),
          headerPaint,
        );
        final rect = Rect.fromLTWH(w * 0.16, h * 0.28, w * 0.68, h * 0.56);
        canvas.drawRect(rect, gridPaint);
        for (var r = 1; r < 4; r++) {
          final y = rect.top + rect.height * r / 4;
          canvas.drawLine(
            Offset(rect.left, y),
            Offset(rect.right, y),
            gridPaint,
          );
        }
        for (var col = 1; col < 3; col++) {
          final x = rect.left + rect.width * col / 3;
          canvas.drawLine(
            Offset(x, rect.top),
            Offset(x, rect.bottom),
            gridPaint,
          );
        }

      case RosidPaperKind.certificate:
        final frame = Rect.fromLTWH(w * 0.1, h * 0.1, w * 0.8, h * 0.8);
        canvas.drawRect(frame, gridPaint);
        canvas.drawLine(
          Offset(w * 0.3, h * 0.24),
          Offset(w * 0.7, h * 0.24),
          headerPaint,
        );
        for (var i = 0; i < 3; i++) {
          final y = h * (0.38 + i * 0.11);
          canvas.drawLine(Offset(w * 0.22, y), Offset(w * 0.78, y), linePaint);
        }
        canvas.drawCircle(
          Offset(w * 0.68, h * 0.74),
          w * 0.11,
          Paint()
            ..color = accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );

      case RosidPaperKind.id:
        final photo = RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.12, h * 0.2, w * 0.26, h * 0.52),
          const Radius.circular(2),
        );
        canvas.drawRRect(photo, Paint()..color = line);
        canvas.drawLine(
          Offset(w * 0.46, h * 0.28),
          Offset(w * 0.84, h * 0.28),
          headerPaint,
        );
        canvas.drawLine(
          Offset(w * 0.46, h * 0.48),
          Offset(w * 0.82, h * 0.48),
          linePaint,
        );
        canvas.drawLine(
          Offset(w * 0.46, h * 0.64),
          Offset(w * 0.72, h * 0.64),
          linePaint,
        );

      case RosidPaperKind.receipt:
        canvas.drawLine(
          Offset(w * 0.25, h * 0.15),
          Offset(w * 0.75, h * 0.15),
          headerPaint,
        );
        for (var i = 0; i < 4; i++) {
          final y = h * (0.3 + i * 0.12);
          canvas.drawLine(Offset(w * 0.18, y), Offset(w * 0.54, y), linePaint);
          canvas.drawLine(Offset(w * 0.66, y), Offset(w * 0.82, y), linePaint);
        }
        canvas.drawLine(
          Offset(w * 0.18, h * 0.82),
          Offset(w * 0.46, h * 0.82),
          headerPaint,
        );
        canvas.drawLine(
          Offset(w * 0.62, h * 0.82),
          Offset(w * 0.82, h * 0.82),
          headerPaint,
        );

      case RosidPaperKind.notes:
        canvas.drawLine(
          Offset(w * 0.24, h * 0.1),
          Offset(w * 0.24, h * 0.9),
          Paint()
            ..color = accent.withValues(alpha: 0.35)
            ..strokeWidth = 1.0,
        );
        for (var i = 0; i < 5; i++) {
          final y = h * (0.22 + i * 0.14);
          canvas.drawLine(Offset(w * 0.12, y), Offset(w * 0.88, y), gridPaint);
        }
        canvas.drawLine(
          Offset(w * 0.32, h * 0.22),
          Offset(w * 0.76, h * 0.22),
          headerPaint,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _PaperThumbPainter oldDelegate) =>
      oldDelegate.kind != kind ||
      oldDelegate.ink != ink ||
      oldDelegate.line != line ||
      oldDelegate.accent != accent;
}
