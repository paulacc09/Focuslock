import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/focus_lock_provider.dart';
import '../../../connection/presentation/screens/connection_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final baseUrl = context.read<FocusLockProvider>().baseUrl;
      final auth = context.read<AuthProvider>();
      auth.refreshProfile(baseUrl);
      auth.fetchLeaderboard(baseUrl);
    });
  }

  void _showAuthDialog(BuildContext context) {
    final focusProvider = context.read<FocusLockProvider>();
    final authProvider = context.read<AuthProvider>();
    final usernameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool isRegister = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final authWatch = ctx.watch<AuthProvider>();
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '🦫 Cuenta FocusLock',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Iniciar Sesión'),
                          selected: !isRegister,
                          onSelected: (_) => setSheetState(() => isRegister = false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Crear Cuenta'),
                          selected: isRegister,
                          onSelected: (_) => setSheetState(() => isRegister = true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (isRegister) ...[
                    TextField(
                      controller: usernameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de usuario',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: isRegister ? 'Correo electrónico' : 'Correo o usuario',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (authWatch.errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      authWatch.errorMessage!,
                      style: const TextStyle(
                        color: AppColors.terracottaDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primarySage,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: authWatch.isLoading
                        ? null
                        : () async {
                            bool ok;
                            if (isRegister) {
                              ok = await authProvider.register(
                                baseUrl: focusProvider.baseUrl,
                                username: usernameCtrl.text,
                                email: emailCtrl.text,
                                password: passCtrl.text,
                              );
                            } else {
                              ok = await authProvider.login(
                                baseUrl: focusProvider.baseUrl,
                                identifier: emailCtrl.text,
                                password: passCtrl.text,
                              );
                            }
                            if (ok && sheetCtx.mounted) {
                              await authProvider.fetchLeaderboard(focusProvider.baseUrl);
                              if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                            }
                          },
                    child: Text(
                      authWatch.isLoading
                          ? 'Conectando...'
                          : (isRegister ? 'Registrarme' : 'Entrar'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FocusLockProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          'Perfil y Ajustes',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar datos',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              auth.refreshProfile(provider.baseUrl);
              auth.fetchLeaderboard(provider.baseUrl);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // 1. Tarjeta de Identidad del Estudiante / Usuario
            _buildStudentCard(context, auth),

            const SizedBox(height: 18),

            // 2. Resumen Horizontal de Logros (3 micro-tarjetas)
            _buildAchievementsRow(auth),

            const SizedBox(height: 18),

            // 2b. Ranking en la nube
            _buildLeaderboardCard(auth),

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

  // 1. Tarjeta de Identidad del Usuario
  Widget _buildStudentCard(BuildContext context, AuthProvider auth) {
    final pts = auth.points;
    final level = (pts ~/ 200) + 1;
    final xpInLevel = pts % 200;
    final double xpProgress = (xpInLevel / 200.0).clamp(0.0, 1.0);
    final initials = auth.isLoggedIn && auth.username.isNotEmpty
        ? auth.username.substring(0, auth.username.length >= 2 ? 2 : 1).toUpperCase()
        : 'FL';

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
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.terracottaDark,
                      ),
                    ),
                  ),
                  if (auth.isLoggedIn)
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

              // Información del usuario
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      auth.username,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      auth.email,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      auth.isLoggedIn
                          ? '🌟 Nivel $level — $pts pts acumulados'
                          : '🔓 Sin cuenta vinculada',
                      style: const TextStyle(
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

          const SizedBox(height: 14),

          if (!auth.isLoggedIn)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primarySage,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.login_rounded, size: 18),
                label: const Text(
                  'Iniciar Sesión o Crear Cuenta',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                onPressed: () => _showAuthDialog(context),
              ),
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Progreso de Nivel',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '$xpInLevel / 200 pts para Nivel ${level + 1}',
                  style: const TextStyle(
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
              child: LinearProgressIndicator(
                value: xpProgress,
                minHeight: 8,
                backgroundColor: AppColors.surfaceMuted,
                color: AppColors.primarySage,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => auth.logout(),
                icon: const Icon(Icons.logout_rounded, size: 16, color: AppColors.terracottaDark),
                label: const Text(
                  'Cerrar Sesión',
                  style: TextStyle(
                    color: AppColors.terracottaDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 2. Resumen Horizontal de Logros
  Widget _buildAchievementsRow(AuthProvider auth) {
    return Row(
      children: [
        Expanded(
          child: _buildAchievementTile(
            icon: Icons.timer_rounded,
            value: '${auth.sessionsCompleted}',
            label: 'Completadas',
            color: AppColors.primarySage,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildAchievementTile(
            icon: Icons.schedule_rounded,
            value: '${auth.totalFocusMinutes}m',
            label: 'Enfoque Total',
            color: AppColors.terracottaBrown,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildAchievementTile(
            icon: Icons.emoji_events_rounded,
            value: '${auth.points}',
            label: 'Puntos',
            color: AppColors.breakChipText,
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardCard(AuthProvider auth) {
    final rows = auth.leaderboard;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderSubtle, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🏆 Ranking de Enfoque (Cloud)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            const Text(
              'Aún no hay usuarios en el ranking o sin conexión.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            )
          else
            ...rows.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final u = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(
                      '#$idx',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.primarySageDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        (u['username'] ?? 'Usuario').toString(),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      '${u['points'] ?? 0} pts',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.breakChipText,
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
