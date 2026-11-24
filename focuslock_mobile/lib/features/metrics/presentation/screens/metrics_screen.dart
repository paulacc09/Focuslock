import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/focus_lock_provider.dart';
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshAll());
  }

  Future<void> _refreshAll() async {
    if (!mounted) return;
    final baseUrl = context.read<FocusLockProvider>().baseUrl;
    final auth = context.read<AuthProvider>();
    await Future.wait([
      auth.refreshProfile(baseUrl),
      auth.fetchMetricsData(baseUrl),
    ]);
  }

  String _formatDurationMinutes(int minutes) {
    if (minutes <= 0) return '0 min';
    if (minutes < 60) return '$minutes min';
    final hrs = minutes / 60.0;
    return '${hrs.toStringAsFixed(1)} hrs';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isWeek = _period == MetricsPeriod.week;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          'Métricas de Productividad',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar métricas',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshAll,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshAll,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              Text(
                auth.isLoggedIn
                    ? 'Estadísticas reales de ${auth.username} desde PostgreSQL & MongoDB'
                    : 'Inicia sesión en Perfil para guardar y consultar tus métricas reales',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              _buildPeriodSelector(),
              const SizedBox(height: 20),
              _buildKpiGrid(auth),
              const SizedBox(height: 24),
              _buildActivityChartCard(isWeek, auth),
              const SizedBox(height: 24),
              _buildSessionsAndMongoCard(auth),
              const SizedBox(height: 24),
              _buildLockyTipCard(auth),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

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
                    color: AppColors.primarySageDark.withValues(alpha: 0.25),
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
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKpiGrid(AuthProvider auth) {
    final pts = auth.points;
    final level = (pts ~/ 200) + 1;
    final mongo = auth.mongoSummary;
    final avgAtt = mongo?['avg_attention'];
    final avgDb = mongo?['avg_decibels'];

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Tiempo Total',
                value: _formatDurationMinutes(auth.totalFocusMinutes),
                badgeText: auth.isLoggedIn ? 'enfoque acumulado' : 'modo invitado',
                icon: Icons.timer_rounded,
                accentColor: AppColors.primarySage,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildMetricCard(
                title: 'Sesiones',
                value: '${auth.sessionsCompleted}',
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
                title: 'Puntos Locky',
                value: '$pts pts',
                badgeText: 'Nivel $level',
                icon: Icons.stars_rounded,
                accentColor: AppColors.graceChipText,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildMetricCard(
                title: 'Atención (Mongo)',
                value: avgAtt != null ? '$avgAtt%' : '0%',
                badgeText: avgDb != null ? 'Ruido: $avgDb dB' : 'Sin telemetría',
                icon: Icons.visibility_rounded,
                accentColor: AppColors.terracottaBrown,
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
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
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

  Widget _buildActivityChartCard(bool isWeek, AuthProvider auth) {
    final now = DateTime.now();
    final completed = auth.userSessions
        .where((s) => (s['status'] ?? '').toString().toUpperCase() == 'COMPLETED')
        .toList();

    final List<Map<String, dynamic>> bars;
    if (isWeek) {
      const labels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
      const fullNames = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
      final minsByDay = List<int>.filled(7, 0);
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final weekStart = DateTime(monday.year, monday.month, monday.day);

      for (final s in completed) {
        final dt = DateTime.tryParse((s['created_at'] ?? '').toString());
        if (dt != null && !dt.isBefore(weekStart)) {
          final mins = (s['target_minutes'] as num?)?.toInt() ?? 0;
          minsByDay[dt.weekday - 1] += mins;
        }
      }
      final maxVal = minsByDay.reduce((a, b) => a > b ? a : b);
      bars = List.generate(7, (i) {
        return {
          'label': labels[i],
          'full': fullNames[i],
          'minutes': minsByDay[i],
          'isPeak': maxVal > 0 && minsByDay[i] == maxVal,
        };
      });
    } else {
      final minsByWeek = List<int>.filled(4, 0);
      for (final s in completed) {
        final dt = DateTime.tryParse((s['created_at'] ?? '').toString());
        if (dt != null && dt.year == now.year && dt.month == now.month) {
          final weekIdx = ((dt.day - 1) ~/ 7).clamp(0, 3);
          final mins = (s['target_minutes'] as num?)?.toInt() ?? 0;
          minsByWeek[weekIdx] += mins;
        }
      }
      final maxVal = minsByWeek.reduce((a, b) => a > b ? a : b);
      bars = List.generate(4, (i) {
        return {
          'label': 'S${i + 1}',
          'full': 'Sem ${i + 1}',
          'minutes': minsByWeek[i],
          'isPeak': maxVal > 0 && minsByWeek[i] == maxVal,
        };
      });
    }

    final totalMinsPeriod = bars.fold<int>(0, (sum, b) => sum + (b['minutes'] as int));
    final maxMins = bars.fold<int>(0, (m, b) => (b['minutes'] as int) > m ? b['minutes'] as int : m);
    final peakBar = bars.firstWhere((b) => b['isPeak'] == true, orElse: () => {});
    final avgMins = (totalMinsPeriod / bars.length).round();

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
                    isWeek ? 'Promedio: $avgMins min / día' : 'Promedio: $avgMins min / semana',
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
                      maxMins > 0
                          ? 'Pico: ${peakBar['full']} (${peakBar['minutes']}m)'
                          : 'Sin actividad aún',
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: bars.map((b) {
              final mins = b['minutes'] as int;
              final isPeak = b['isPeak'] as bool;
              const double chartHeight = 120;
              final double barHeight = maxMins > 0
                  ? (mins / maxMins * chartHeight).clamp(8.0, chartHeight)
                  : 8.0;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${mins}m',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isPeak ? FontWeight.w800 : FontWeight.w600,
                      color: isPeak ? AppColors.primarySageDark : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
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
                    ),
                  ),
                  const SizedBox(height: 8),
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

  Widget _buildSessionsAndMongoCard(AuthProvider auth) {
    final sessions = auth.userSessions;
    final mongo = auth.mongoSummary;
    final docs = (mongo?['total_telemetry_docs'] as num?)?.toInt() ?? 0;
    final alerts = (mongo?['noise_violations'] as num?)?.toInt() ?? 0;

    return Container(
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
            'Sesiones Recientes (PostgreSQL)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'MongoDB Atlas: $docs muestras de telemetría • $alerts alertas de ruido',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          if (!auth.isLoggedIn)
            const Text(
              'Inicia sesión para ver tu historial personal de sesiones.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            )
          else if (sessions.isEmpty)
            const Text(
              'Aún no tienes sesiones registradas. ¡Inicia un Pomodoro para sumar tus primeros puntos!',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            )
          else
            ...sessions.take(6).map((s) {
              final status = (s['status'] ?? '').toString();
              final isDone = status == 'COMPLETED';
              final pts = (s['points_awarded'] as num?)?.toInt() ?? 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      isDone ? Icons.check_circle_rounded : Icons.schedule_rounded,
                      size: 18,
                      color: isDone ? AppColors.breakChipText : AppColors.graceChipText,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        (s['session_name'] ?? s['id'] ?? 'Sesión').toString(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (pts > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          '+$pts pts',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.breakChipText,
                          ),
                        ),
                      ),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDone ? AppColors.breakChipText : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildLockyTipCard(AuthProvider auth) {
    final tip = auth.sessionsCompleted == 0
        ? '¡Bienvenido! Completa tu primera sesión de enfoque para ganar tus primeros puntos Locky.'
        : 'Llevas ${auth.sessionsCompleted} sesiones completadas y ${auth.points} puntos acumulados. ¡Sigue así!';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderSubtle, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const LockyMascot(pose: LockyPose.ready, size: 58),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Estado de Enfoque con Locky',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tip,
                  style: const TextStyle(
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
