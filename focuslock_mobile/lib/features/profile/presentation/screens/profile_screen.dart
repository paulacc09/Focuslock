import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/focus_lock_provider.dart';
import '../../../connection/presentation/screens/connection_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FocusLockProvider>();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          'Perfil y Ajustes',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // 1. Tarjeta de Identidad del Estudiante
            _buildStudentCard(),

            const SizedBox(height: 18),

            // 2. Resumen Horizontal de Logros (3 micro-tarjetas)
            _buildAchievementsRow(),

            const SizedBox(height: 24),

            const Text(
              'Ajustes de Estación y Hardware',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 12),

            // 3. Tarjeta de Opciones Configurables
            _buildHardwareSettingsCard(context, provider),

            const SizedBox(height: 28),

            // 4. Pie de Página
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_clock_rounded,
                      size: 20,
                      color: AppColors.primarySageDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'FocusLock v1.0.0 — Electrónica Digital III (2026B)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Raspberry Pi Zero W (BCM2835) + Flutter 3 Client',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // 1. Tarjeta de Identidad del Estudiante
  Widget _buildStudentCard() {
    const double xpProgress = 1240 / 1500;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderSubtle, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primarySageDark.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar con badge verificado
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: AppColors.peachCream,
                    child: const Text(
                      'PJ',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.terracottaDark,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppColors.primarySage,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 11,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),

              // Información del estudiante
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Paula Jiménez',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Ingeniería de Sistemas / Electrónica • 8vo Semestre',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '🌟 Nivel 8 — Maestra del Enfoque',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.focusChipText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Barra de progreso de XP
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Progreso de Nivel',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '1,240 / 1,500 XP para el Nivel 9',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primarySageDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: const LinearProgressIndicator(
              value: xpProgress,
              minHeight: 8,
              backgroundColor: AppColors.surfaceMuted,
              color: AppColors.primarySage,
            ),
          ),
        ],
      ),
    );
  }

  // 2. Resumen Horizontal de Logros
  Widget _buildAchievementsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildAchievementTile(
            icon: Icons.timer_rounded,
            value: '47',
            label: 'Pomodoros',
            color: AppColors.primarySage,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildAchievementTile(
            icon: Icons.local_fire_department_rounded,
            value: '5 Días',
            label: 'Racha Actual',
            color: AppColors.terracottaBrown,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildAchievementTile(
            icon: Icons.verified_rounded,
            value: '98%',
            label: 'Tasa Éxito',
            color: AppColors.breakChipText,
          ),
        ),
      ],
    );
  }

  Widget _buildAchievementTile({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle, width: 1.2),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // 3. Tarjeta de Opciones Configurables con Material
  Widget _buildHardwareSettingsCard(BuildContext context, FocusLockProvider provider) {
    return Material(
      color: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: AppColors.borderSubtle, width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Toggle 1: Alertas Acústicas del Buzzer
          SwitchListTile(
            value: provider.buzzerEnabled,
            onChanged: (val) => provider.setBuzzerEnabled(val),
            title: const Text(
              'Alertas Acústicas del Buzzer (5V)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: const Text(
              'Activa o silencia los bips de alerta en la Raspberry Pi',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            activeThumbColor: AppColors.primarySage,
          ),
          const Divider(height: 1, color: AppColors.borderSubtle),

          // Toggle 2: Reacciones de Locky
          SwitchListTile(
            value: provider.lockyReactionsEnabled,
            onChanged: (val) => provider.setLockyReactionsEnabled(val),
            title: const Text(
              'Animaciones y Reacciones de Locky',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: const Text(
              'Muestra las poses reactivas y celebraciones de la mascota',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            activeThumbColor: AppColors.primarySage,
          ),
          const Divider(height: 1, color: AppColors.borderSubtle),

          // Toggle 3: Modo Pruebas / Simulador Standalone
          SwitchListTile(
            value: provider.isMockMode,
            onChanged: (val) => provider.toggleMockMode(val),
            title: const Text(
              'Modo Pruebas / Simulador Standalone',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              provider.isMockMode
                  ? 'Activo: Simula el sensor óptico y FSM sin requerir hardware'
                  : 'Desactivado: Conectado a ${AppConstants.defaultMdnsHost}:8000',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            activeThumbColor: AppColors.primarySage,
          ),
          const Divider(height: 1, color: AppColors.borderSubtle),

          // Botón 1: Configuración de Red Raspberry Pi
          _buildActionTile(
            icon: Icons.wifi_tethering_rounded,
            title: 'Configuración de Red de la Raspberry Pi',
            subtitle: 'Gestionar dirección IP y mDNS (${AppConstants.defaultMdnsHost})',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ConnectionScreen()),
            ),
          ),
          const Divider(height: 1, color: AppColors.borderSubtle),

          // Botón 2: Calibración de Hardware
          _buildActionTile(
            icon: Icons.tune_rounded,
            title: 'Calibración de Hardware',
            subtitle: 'Ajuste de tiempos de pulso SG90 y umbral óptico TCRT5000',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: AppColors.primarySageDark),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
