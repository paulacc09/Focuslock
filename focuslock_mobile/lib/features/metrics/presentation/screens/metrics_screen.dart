import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class MetricsScreen extends StatelessWidget {
  const MetricsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          'Métricas de Enfoque',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // Fila de Indicadores Principales
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Enfoque Total',
                    value: '18.5 h',
                    subtitle: '+2.4h vs semana anterior',
                    icon: Icons.timer_rounded,
                    accent: AppColors.primarySage,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Racha Actual',
                    value: '4 Días',
                    subtitle: 'Récord personal: 7',
                    icon: Icons.local_fire_department_rounded,
                    accent: AppColors.terracottaBrown,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Sesiones Hechas',
                    value: '37',
                    subtitle: '98% sin interrupciones',
                    icon: Icons.check_circle_outline_rounded,
                    accent: AppColors.breakChipText,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Puntos Locky',
                    value: '925',
                    subtitle: 'Nivel 4 Académica',
                    icon: Icons.stars_rounded,
                    accent: AppColors.graceChipText,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Gráfico Semanal
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.borderSubtle, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primarySageDark.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Actividad Semanal de Enfoque',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Esta Semana',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Barras Semanales
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildWeeklyBar('Lun', 2.5, false),
                      _buildWeeklyBar('Mar', 3.0, false),
                      _buildWeeklyBar('Mié', 4.5, false),
                      _buildWeeklyBar('Jue', 3.5, false),
                      _buildWeeklyBar('Vie', 2.0, false),
                      _buildWeeklyBar('Sáb', 1.0, false),
                      _buildWeeklyBar('Hoy', 2.0, true),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Distribución por Materia
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.borderSubtle, width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Distribución por Materia',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildSubjectProgress('Electrónica Digital III', 0.45, '8.3h (45%)', AppColors.primarySage),
                  const SizedBox(height: 14),
                  _buildSubjectProgress('Cálculo IV', 0.25, '4.6h (25%)', AppColors.terracottaBrown),
                  const SizedBox(height: 14),
                  _buildSubjectProgress('Señales y Sistemas', 0.20, '3.7h (20%)', AppColors.focusChipText),
                  const SizedBox(height: 14),
                  _buildSubjectProgress('Lectura e Investigación', 0.10, '1.9h (10%)', AppColors.textSecondary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderSubtle, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Icon(icon, size: 20, color: accent),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyBar(String day, double hours, bool isToday) {
    const double maxHeight = 100;
    final double barHeight = (hours / 5.0 * maxHeight).clamp(12.0, maxHeight);

    return Column(
      children: [
        Container(
          width: 24,
          height: barHeight,
          decoration: BoxDecoration(
            color: isToday ? AppColors.primarySage : AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isToday ? AppColors.primarySageDark : AppColors.borderSubtle,
              width: 1,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          day,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
            color: isToday ? AppColors.primarySageDark : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectProgress(String name, double fraction, String time, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              time,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            backgroundColor: AppColors.surfaceMuted,
            color: color,
          ),
        ),
      ],
    );
  }
}
