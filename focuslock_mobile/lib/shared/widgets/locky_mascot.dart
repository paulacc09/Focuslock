import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

enum LockyPose {
  inBox,
  ready,
  sleeping,
  celebrating,
}

class LockyMascot extends StatelessWidget {
  final LockyPose pose;
  final double size;

  const LockyMascot({
    super.key,
    this.pose = LockyPose.inBox,
    this.size = 140,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LockyPainter(pose: pose),
      ),
    );
  }
}

class _LockyPainter extends CustomPainter {
  final LockyPose pose;

  _LockyPainter({required this.pose});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final furPaint = Paint()..color = AppColors.terracottaBrown;
    final darkFurPaint = Paint()..color = AppColors.terracottaDark;
    final peachPaint = Paint()..color = AppColors.peachCream;
    final outlinePaint = Paint()
      ..color = AppColors.terracottaDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.025
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final boxPaint = Paint()..color = AppColors.surfaceMuted;
    final boxBorderPaint = Paint()
      ..color = AppColors.borderSubtle
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.03;

    final sageAccent = Paint()..color = AppColors.primarySage;

    if (pose == LockyPose.inBox) {
      // 1. DIBUJO DE LOCKY EN SU CAJA (PANTALLA WELCOME)
      // Caja base
      final boxRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.15, h * 0.52, w * 0.70, h * 0.44),
        Radius.circular(w * 0.12),
      );
      canvas.drawRRect(boxRect, boxPaint);
      canvas.drawRRect(boxRect, boxBorderPaint);

      // Cerradura en la caja
      final lockCenter = Offset(w * 0.5, h * 0.76);
      canvas.drawCircle(lockCenter, w * 0.06, Paint()..color = AppColors.surfaceCard);
      canvas.drawCircle(
        lockCenter,
        w * 0.06,
        Paint()
          ..color = AppColors.primarySage
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.02,
      );
      canvas.drawRect(
        Rect.fromCenter(center: Offset(w * 0.5, h * 0.78), width: w * 0.02, height: w * 0.04),
        Paint()..color = AppColors.terracottaDark,
      );

      // Orejas
      _drawEars(canvas, w, h * 0.95, furPaint, peachPaint, outlinePaint);

      // Cabeza
      canvas.drawCircle(Offset(w * 0.5, h * 0.38), w * 0.28, furPaint);
      canvas.drawCircle(Offset(w * 0.5, h * 0.38), w * 0.28, outlinePaint);

      // Hocico crema
      canvas.drawOval(
        Rect.fromCenter(center: Offset(w * 0.5, h * 0.44), width: w * 0.26, height: h * 0.18),
        peachPaint,
      );

      // Nariz
      canvas.drawOval(
        Rect.fromCenter(center: Offset(w * 0.5, h * 0.40), width: w * 0.08, height: h * 0.05),
        darkFurPaint,
      );

      // Ojos sonrientes
      _drawHappyEyes(canvas, w, h * 0.33);

      // Paticas apoyadas en el borde de la caja
      canvas.drawOval(
        Rect.fromCenter(center: Offset(w * 0.30, h * 0.52), width: w * 0.13, height: h * 0.09),
        peachPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(w * 0.30, h * 0.52), width: w * 0.13, height: h * 0.09),
        outlinePaint,
      );

      canvas.drawOval(
        Rect.fromCenter(center: Offset(w * 0.70, h * 0.52), width: w * 0.13, height: h * 0.09),
        peachPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(w * 0.70, h * 0.52), width: w * 0.13, height: h * 0.09),
        outlinePaint,
      );
    } else if (pose == LockyPose.sleeping) {
      // 2. DIBUJO DE LOCKY DURMIENDO (PANTALLA FOCUS ACTIVE)
      // Cuerpo redondeado
      canvas.drawOval(
        Rect.fromCenter(center: Offset(w * 0.5, h * 0.58), width: w * 0.65, height: h * 0.45),
        furPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(w * 0.5, h * 0.58), width: w * 0.65, height: h * 0.45),
        outlinePaint,
      );

      // Orejitas relajadas
      _drawEars(canvas, w, h * 1.05, furPaint, peachPaint, outlinePaint);

      // Cabeza
      canvas.drawCircle(Offset(w * 0.5, h * 0.42), w * 0.26, furPaint);
      canvas.drawCircle(Offset(w * 0.5, h * 0.42), w * 0.26, outlinePaint);

      // Hocico
      canvas.drawOval(
        Rect.fromCenter(center: Offset(w * 0.5, h * 0.47), width: w * 0.22, height: h * 0.14),
        peachPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(w * 0.5, h * 0.44), width: w * 0.06, height: h * 0.04),
        darkFurPaint,
      );

      // Ojos cerrados durmiendo (^ ^)
      _drawSleepingEyes(canvas, w, h * 0.38);

      // Zzz flotantes
      _drawZzz(canvas, w * 0.72, h * 0.20, sageAccent);
    } else if (pose == LockyPose.celebrating) {
      // 3. DIBUJO DE LOCKY CELEBRANDO (PANTALLA REWARD)
      _drawEars(canvas, w, h * 0.95, furPaint, peachPaint, outlinePaint);

      // Cabeza
      canvas.drawCircle(Offset(w * 0.5, h * 0.45), w * 0.28, furPaint);
      canvas.drawCircle(Offset(w * 0.5, h * 0.45), w * 0.28, outlinePaint);

      // Sombrerito de fiesta
      final hatPath = Path()
        ..moveTo(w * 0.42, h * 0.20)
        ..lineTo(w * 0.50, h * 0.04)
        ..lineTo(w * 0.58, h * 0.20)
        ..close();
      canvas.drawPath(hatPath, Paint()..color = AppColors.primarySage);
      canvas.drawCircle(Offset(w * 0.50, h * 0.03), w * 0.04, Paint()..color = AppColors.graceChipText);

      // Hocico y carita feliz
      canvas.drawOval(
        Rect.fromCenter(center: Offset(w * 0.5, h * 0.51), width: w * 0.26, height: h * 0.18),
        peachPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(w * 0.5, h * 0.46), width: w * 0.07, height: h * 0.05),
        darkFurPaint,
      );

      // Boca abierta feliz
      final mouthPath = Path()
        ..moveTo(w * 0.44, h * 0.53)
        ..quadraticBezierTo(w * 0.50, h * 0.60, w * 0.56, h * 0.53)
        ..close();
      canvas.drawPath(mouthPath, Paint()..color = AppColors.focusChipText);

      // Ojos brillantes
      _drawSparkleEyes(canvas, w, h * 0.38);

      // Estrellitas de confeti
      _drawStar(canvas, Offset(w * 0.18, h * 0.25), w * 0.05, AppColors.graceChipText);
      _drawStar(canvas, Offset(w * 0.82, h * 0.22), w * 0.06, AppColors.primarySage);
      _drawStar(canvas, Offset(w * 0.22, h * 0.65), w * 0.04, AppColors.terracottaBrown);
      _drawStar(canvas, Offset(w * 0.80, h * 0.62), w * 0.05, AppColors.graceChipText);
    } else {
      // 4. LOCKY READY (SETUP)
      _drawEars(canvas, w, h, furPaint, peachPaint, outlinePaint);
      canvas.drawCircle(Offset(w * 0.5, h * 0.45), w * 0.28, furPaint);
      canvas.drawCircle(Offset(w * 0.5, h * 0.45), w * 0.28, outlinePaint);

      canvas.drawOval(
        Rect.fromCenter(center: Offset(w * 0.5, h * 0.51), width: w * 0.26, height: h * 0.18),
        peachPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(w * 0.5, h * 0.46), width: w * 0.07, height: h * 0.05),
        darkFurPaint,
      );
      _drawHappyEyes(canvas, w, h * 0.40);
    }
  }

  void _drawEars(Canvas canvas, double w, double h, Paint fur, Paint peach, Paint outline) {
    // Oreja izquierda
    final leftEar = Path()
      ..moveTo(w * 0.28, h * 0.30)
      ..quadraticBezierTo(w * 0.15, h * 0.10, w * 0.35, h * 0.14)
      ..close();
    canvas.drawPath(leftEar, fur);
    canvas.drawPath(leftEar, outline);

    // Oreja derecha
    final rightEar = Path()
      ..moveTo(w * 0.72, h * 0.30)
      ..quadraticBezierTo(w * 0.85, h * 0.10, w * 0.65, h * 0.14)
      ..close();
    canvas.drawPath(rightEar, fur);
    canvas.drawPath(rightEar, outline);
  }

  void _drawHappyEyes(Canvas canvas, double w, double y) {
    final eyePaint = Paint()
      ..color = AppColors.terracottaDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.03
      ..strokeCap = StrokeCap.round;

    final leftEye = Path()
      ..moveTo(w * 0.37, y)
      ..quadraticBezierTo(w * 0.41, y - w * 0.04, w * 0.45, y);
    canvas.drawPath(leftEye, eyePaint);

    final rightEye = Path()
      ..moveTo(w * 0.55, y)
      ..quadraticBezierTo(w * 0.59, y - w * 0.04, w * 0.63, y);
    canvas.drawPath(rightEye, eyePaint);
  }

  void _drawSleepingEyes(Canvas canvas, double w, double y) {
    final eyePaint = Paint()
      ..color = AppColors.terracottaDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.025
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(w * 0.38, y), Offset(w * 0.44, y), eyePaint);
    canvas.drawLine(Offset(w * 0.56, y), Offset(w * 0.62, y), eyePaint);
  }

  void _drawSparkleEyes(Canvas canvas, double w, double y) {
    final dark = Paint()..color = AppColors.terracottaDark;
    final white = Paint()..color = Colors.white;

    canvas.drawCircle(Offset(w * 0.41, y), w * 0.045, dark);
    canvas.drawCircle(Offset(w * 0.42, y - w * 0.015), w * 0.018, white);

    canvas.drawCircle(Offset(w * 0.59, y), w * 0.045, dark);
    canvas.drawCircle(Offset(w * 0.60, y - w * 0.015), w * 0.018, white);
  }

  void _drawZzz(Canvas canvas, double x, double y, Paint paint) {
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'Zzz',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.primarySage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(x, y));
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()..color = color;
    final path = Path();
    for (int i = 0; i < 5; i++) {
      double angle = -math.pi / 2 + i * (4 * math.pi / 5);
      double x = center.dx + radius * math.cos(angle);
      double y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LockyPainter oldDelegate) => oldDelegate.pose != pose;
}
