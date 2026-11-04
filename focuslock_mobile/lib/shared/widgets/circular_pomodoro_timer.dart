import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/focus_lock_state.dart';

class CircularPomodoroTimer extends StatelessWidget {
  final double progress;
  final String formattedTime;
  final FocusLockState state;
  final double size;
  final String? subtitle;

  const CircularPomodoroTimer({
    super.key,
    required this.progress,
    required this.formattedTime,
    required this.state,
    this.size = 270,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    // Colores exactos de Figma: anillo base claro y progreso salvia
    const Color trackColor = AppColors.primarySageLight;
    final Color progressColor = state == FocusLockState.gracePeriod
        ? AppColors.graceChipText
        : AppColors.primarySage;

    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Sombra suave ambiental debajo del dial
            Container(
              width: size - 32,
              height: size - 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceCard,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primarySageDark.withValues(alpha: 0.12),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
            ),

            // Anillo base de fondo en verde salvia claro (primarySageLight)
            SizedBox(
              width: size,
              height: size,
              child: const CircularProgressIndicator(
                value: 1.0,
                strokeWidth: 14,
                color: trackColor,
              ),
            ),

            // Anillo de progreso animado en verde salvia principal (primarySage)
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: state == FocusLockState.idleUnlocked ? 0.0 : progress.clamp(0.0, 1.0),
                strokeWidth: 14,
                strokeCap: StrokeCap.round,
                color: progressColor,
              ),
            ),

            // Contenido central dentro del dial blanco
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ícono de estado
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: state.chipBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    state.icon,
                    size: 24,
                    color: state.color,
                  ),
                ),
                const SizedBox(height: 10),

                // Tiempo formateado (números en textPrimary #192A24)
                Text(
                  formattedTime,
                  style: const TextStyle(
                    fontSize: 46,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.5,
                    color: AppColors.textPrimary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),

                const SizedBox(height: 6),

                // Chip de estado
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: state.chipBgColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: state.color.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    subtitle ?? state.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: state.color,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
