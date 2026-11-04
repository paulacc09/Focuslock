import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/locky_mascot.dart';

enum MetricsPeriod { week, month }

class MetricsScreen extends StatefulWidget {
  const MetricsScreen({super.key});

  @override
  State<MetricsScreen> createState() => _MetricsScreenState();
}

class _MetricsScreenState extends State<MetricsScreen> {
  MetricsPeriod _period = MetricsPeriod.week;

  @override
  Widget build(BuildContext context) {
    final isWeek = _period == MetricsPeriod.week;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          'Métricas de Productividad',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // Subtítulo
            const Text(
              'Estadísticas y rendimiento de tus bloques de enfoque con Locky',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 18),

            // Selector de Periodo: [Esta Semana] / [Este Mes]
            _buildPeriodSelector(),

            const SizedBox(height: 20),

            // Grid 2x2 de KPIs Principales
            _buildKpiGrid(isWeek),

            const SizedBox(height: 24),

            // Gráfico de Barras de Actividad
            _buildActivityChartCard(isWeek),

            const SizedBox(height: 24),

            // Distribución por Materia / Categoría
            _buildCategoryDistributionCard(isWeek),

            const SizedBox(height: 24),

            // Consejo de Enfoque de Locky
            _buildLockyTipCard(),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // 1. Selector de Periodo (Cápsula)
  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildPeriodTab(
              label: 'Esta Semana',
              isSelected: _period == MetricsPeriod.week,
              onTap: () => setState(() => _period = MetricsPeriod.week),
            ),
          ),
          Expanded(
            child: _buildPeriodTab(
              label: 'Este Mes',
              isSelected: _period == MetricsPeriod.month,
              onTap: () => setState(() => _period = MetricsPeriod.month),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodTab({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySage : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primarySage.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  // 2. Grid 2x2 de KPIs Principales
  Widget _buildKpiGrid(bool isWeek) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Tiempo Total',
                value: isWeek ? '28.5 hrs' : '114.0 hrs',
                badgeText: isWeek ? '+12% vs anterior' : '+18% vs anterior',
                icon: Icons.timer_rounded,
                accentColor: AppColors.primarySage,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildMetricCard(
                title: 'Sesiones',
                value: isWeek ? '47' : '188',
                badgeText: 'completadas',
                icon: Icons.check_circle_outline_rounded,
                accentColor: AppColors.breakChipText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Racha Actual',
                value: isWeek ? '5 Días' : '12 Días',
                badgeText: isWeek ? 'consecutivos 🔥' : 'récord del mes 🔥',
                icon: Icons.local_fire_department_rounded,
                accentColor: AppColors.terracottaBrown,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildMetricCard(
                title: 'Puntos Locky',
                value: isWeek ? '1,240 XP' : '4,960 XP',
                badgeText: 'Nivel 8 Experta',
                icon: Icons.stars_rounded,
                accentColor: AppColors.graceChipText,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String badgeText,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primarySageDark.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
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
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            badgeText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }

  // 3. Gráfico de Barras de Actividad Semanal
  Widget _buildActivityChartCard(bool isWeek) {
    final bars = isWeek
        ? [
            {'label': 'L', 'full': 'Lun', 'hours': 4.0, 'isPeak': false},
            {'label': 'M', 'full': 'Mar', 'hours': 3.5, 'isPeak': false},
            {'label': 'M', 'full': 'Mié', 'hours': 5.0, 'isPeak': true},
            {'label': 'J', 'full': 'Jue', 'hours': 2.0, 'isPeak': false},
            {'label': 'V', 'full': 'Vie', 'hours': 4.5, 'isPeak': false},
            {'label': 'S', 'full': 'Sáb', 'hours': 3.0, 'isPeak': false},
            {'label': 'D', 'full': 'Dom', 'hours': 1.5, 'isPeak': false},
          ]
        : [
            {'label': 'S1', 'full': 'Sem 1', 'hours': 26.0, 'isPeak': false},
            {'label': 'S2', 'full': 'Sem 2', 'hours': 30.0, 'isPeak': true},
            {'label': 'S3', 'full': 'Sem 3', 'hours': 29.5, 'isPeak': false},
            {'label': 'S4', 'full': 'Sem 4', 'hours': 28.5, 'isPeak': false},
          ];

    final maxHours = isWeek ? 5.5 : 34.0;

    return Container(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isWeek ? 'Actividad Semanal' : 'Actividad Mensual',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isWeek ? 'Promedio: 4.1h / día' : 'Promedio: 28.5h / semana',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primarySageLight.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.show_chart_rounded, size: 14, color: AppColors.primarySageDark),
                    const SizedBox(width: 4),
                    Text(
                      isWeek ? 'Pico: Mié (5h)' : 'Pico: Sem 2 (30h)',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primarySageDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),

          // Barras Verticales Proporcionales
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: bars.map((b) {
              final hours = b['hours'] as double;
              final isPeak = b['isPeak'] as bool;
              const double chartHeight = 120;
              final barHeight = (hours / maxHours * chartHeight).clamp(16.0, chartHeight);

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Horas encima de la barra
                  Text(
                    isWeek ? '${hours.toStringAsFixed(hours.truncateToDouble() == hours ? 0 : 1)}h' : '${hours.toInt()}h',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isPeak ? FontWeight.w800 : FontWeight.w600,
                      color: isPeak ? AppColors.primarySageDark : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Barra vertical estilizada
                  Container(
                    width: isWeek ? 28 : 46,
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: isPeak ? AppColors.primarySage : AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isPeak ? AppColors.primarySageDark : AppColors.borderSubtle,
                        width: isPeak ? 1.5 : 1.0,
                      ),
                      boxShadow: isPeak
                          ? [
                              BoxShadow(
                                color: AppColors.primarySage.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Etiqueta del día
                  Text(
                    b['label'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isPeak ? FontWeight.w800 : FontWeight.w600,
                      color: isPeak ? AppColors.primarySageDark : AppColors.textSecondary,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // 4. Distribución por Materia / Categoría
  Widget _buildCategoryDistributionCard(bool isWeek) {
    return Container(
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
          const Text(
            'Distribución por Categoría',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Proporción de tiempo invertido en tus áreas de enfoque',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),

          // Barra continua segmentada
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 12,
              child: Row(
                children: const [
                  Expanded(flex: 55, child: ColoredBox(color: AppColors.catUniversityText)),
                  SizedBox(width: 2),
                  Expanded(flex: 30, child: ColoredBox(color: AppColors.catFreelanceText)),
                  SizedBox(width: 2),
                  Expanded(flex: 15, child: ColoredBox(color: AppColors.catPersonalText)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Desglose con porcentajes y horas exactas de Figma
          _buildCategoryRow(
            name: 'Universidad',
            percentage: '55%',
            hours: isWeek ? '15.7 hrs' : '62.7 hrs',
            color: AppColors.catUniversityText,
            bgColor: AppColors.catUniversityBg,
          ),
          const SizedBox(height: 12),
          _buildCategoryRow(
            name: 'Proyectos / Freelance',
            percentage: '30%',
            hours: isWeek ? '8.5 hrs' : '34.2 hrs',
            color: AppColors.catFreelanceText,
            bgColor: AppColors.catFreelanceBg,
          ),
          const SizedBox(height: 12),
          _buildCategoryRow(
            name: 'Desarrollo Personal',
            percentage: '15%',
            hours: isWeek ? '4.3 hrs' : '17.1 hrs',
            color: AppColors.catPersonalText,
            bgColor: AppColors.catPersonalBg,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow({
    required String name,
    required String percentage,
    required String hours,
    required Color color,
    required Color bgColor,
  }) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            percentage,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          hours,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // 5. Consejo de Enfoque de Locky
  Widget _buildLockyTipCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderSubtle, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primarySage.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          LockyMascot(pose: LockyPose.ready, size: 58),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Consejo de Enfoque de Locky',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  '¡Tus mañanas son tu momento más productivo! Mantén el ritmo antes de las 11:00 AM ☀️',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
