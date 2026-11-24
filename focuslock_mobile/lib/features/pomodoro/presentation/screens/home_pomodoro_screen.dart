import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/focus_lock_state.dart';
import '../../../../core/models/task_item.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/focus_lock_provider.dart';
import '../../../../core/providers/schedule_provider.dart';
import '../../../../shared/widgets/circular_pomodoro_timer.dart';
import '../../../../shared/widgets/locky_mascot.dart';
import '../../../connection/presentation/screens/connection_screen.dart';

class HomePomodoroScreen extends StatefulWidget {
  const HomePomodoroScreen({super.key});

  @override
  State<HomePomodoroScreen> createState() => _HomePomodoroScreenState();
}

class _HomePomodoroScreenState extends State<HomePomodoroScreen> {
  bool _isSettingUp = false;
  int _selectedSubjectIndex = 0;
  late final FixedExtentScrollController _hoursWheelCtrl;
  late final FixedExtentScrollController _minutesWheelCtrl;
  late final FixedExtentScrollController _breakWheelCtrl;

  @override
  void initState() {
    super.initState();
    final initialProvider = context.read<FocusLockProvider>();
    final initTotal = initialProvider.selectedFocusMinutes;
    _hoursWheelCtrl = FixedExtentScrollController(initialItem: (initTotal ~/ 60).clamp(0, 3));
    _minutesWheelCtrl = FixedExtentScrollController(initialItem: initTotal % 60);
    _breakWheelCtrl = FixedExtentScrollController(
      initialItem: (initialProvider.selectedBreakMinutes - 5).clamp(0, 10),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final baseUrl = context.read<FocusLockProvider>().baseUrl;
      final auth = context.read<AuthProvider>();
      auth.refreshProfile(baseUrl);
      auth.fetchMetricsData(baseUrl);
      context.read<ScheduleProvider>().syncCategoriesFromServer(baseUrl, auth.token);
    });
  }

  @override
  void dispose() {
    _hoursWheelCtrl.dispose();
    _minutesWheelCtrl.dispose();
    _breakWheelCtrl.dispose();
    super.dispose();
  }

  void _showCreateCategorySheet() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    int selectedIconIdx = 0;
    int selectedColorIdx = 0;

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
                        'Nueva Categoría de Enfoque',
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
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre (ej. Electrónica, Tesis, Lectura)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Subtítulo o nota (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Elige un ícono',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(CustomCategory.iconChoices.length, (i) {
                      final active = i == selectedIconIdx;
                      final chosenColor = CustomCategory.colorChoices[selectedColorIdx];
                      return InkWell(
                        onTap: () => setSheetState(() => selectedIconIdx = i),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: active ? chosenColor.withValues(alpha: 0.18) : AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: active ? chosenColor : AppColors.borderSubtle,
                              width: active ? 2 : 1,
                            ),
                          ),
                          child: Icon(
                            CustomCategory.iconChoices[i],
                            color: active ? chosenColor : AppColors.textSecondary,
                            size: 22,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Elige un color',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: List.generate(CustomCategory.colorChoices.length, (i) {
                      final c = CustomCategory.colorChoices[i];
                      final active = i == selectedColorIdx;
                      return InkWell(
                        onTap: () => setSheetState(() => selectedColorIdx = i),
                        borderRadius: BorderRadius.circular(99),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: active ? AppColors.textPrimary : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: active ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primarySage,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      final code = codeCtrl.text.trim();
                      final col = CustomCategory.colorChoices[selectedColorIdx];
                      final newCat = CustomCategory(
                        id: 'cat-${DateTime.now().millisecondsSinceEpoch}',
                        name: name,
                        subtitle: code.isEmpty ? 'Categoría personalizada' : code,
                        iconIndex: selectedIconIdx,
                        colorValue: col.toARGB32(),
                      );
                      final scheduleProv = context.read<ScheduleProvider>();
                      final baseUrl = context.read<FocusLockProvider>().baseUrl;
                      final token = context.read<AuthProvider>().token;
                      scheduleProv.createCategorySynced(baseUrl, token, newCat);
                      setState(() {
                        _selectedSubjectIndex = scheduleProv.categories.length - 1;
                      });
                      Navigator.pop(sheetCtx);
                    },
                    child: const Text('Guardar Categoría', style: TextStyle(fontWeight: FontWeight.w800)),
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
    final state = provider.state;

    // Si la sesión arranca, reseteamos el flag de setup
    if (state != FocusLockState.idleUnlocked && _isSettingUp) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _isSettingUp = false);
      });
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: _buildAppBar(context, provider),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: _buildFlowBody(context, provider, state),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, FocusLockProvider provider) {
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primarySageLight.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_clock_rounded, color: AppColors.primarySageDark, size: 20),
          ),
          const SizedBox(width: 8),
          const Text(
            'FocusLock',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 19,
              letterSpacing: -0.5,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
      actions: [
        // Chip indicador de conexión Pi 4 / Simulador (Toca para configurar IP)
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ConnectionScreen()),
            );
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: provider.isMockMode ? AppColors.graceChipText : AppColors.breakChipText,
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: provider.isMockMode ? AppColors.graceChipText : AppColors.breakChipText,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  provider.isMockMode ? 'Simulador (Conectar Pi)' : 'Pi 4 En Línea',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: provider.isMockMode ? AppColors.graceChipText : AppColors.breakChipText,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.settings_ethernet_rounded,
                  size: 14,
                  color: provider.isMockMode ? AppColors.graceChipText : AppColors.breakChipText,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFlowBody(BuildContext context, FocusLockProvider provider, FocusLockState state) {
    // PANTALLA 5: REWARD (BREAK / SESIÓN COMPLETADA)
    if (state == FocusLockState.breakUnlocked) {
      return _buildRewardScreen(context, provider);
    }

    // PANTALLA 4: FOCUS ACTIVE (LOCKED_FOCUS)
    if (state == FocusLockState.lockedFocus) {
      return _buildFocusActiveScreen(context, provider);
    }

    // SUB-ESTADOS DE TRANSICIÓN: WAITING_PHONE & GRACE_PERIOD
    if (state == FocusLockState.waitingPhone || state == FocusLockState.gracePeriod) {
      return _buildWaitingAndGraceScreen(context, provider, state);
    }

    // PANTALLA 3: SETUP DE SESIÓN (PRESETS + MATERIAS)
    if (_isSettingUp) {
      return _buildSetupScreen(context, provider);
    }

    // PANTALLA 2: WELCOME (IDLE INICIAL)
    return _buildWelcomeScreen(context, provider);
  }

  // ===========================================================================
  // PANTALLA 2: WELCOME SCREEN (EN ESPAÑOL)
  // ===========================================================================
  Widget _buildWelcomeScreen(BuildContext context, FocusLockProvider provider) {
    final auth = context.watch<AuthProvider>();
    final greeting = auth.isLoggedIn
        ? '¡Hola, ${auth.username}! 👋'
        : '¡Bienvenido a FocusLock! 👋';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Saludo y subtítulo
        Text(
          greeting,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          auth.isLoggedIn
              ? 'Tienes ${auth.points} pts y ${auth.sessionsCompleted} sesiones completadas'
              : '¿Listo para potenciar tu productividad hoy?',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),

        const SizedBox(height: 18),

        // Fila de Chips de Estado Claros (Batería, Wi-Fi, Cerrojo)
        Row(
          children: [
            _buildStatusChip(
              icon: Icons.battery_charging_full_rounded,
              label: '98%',
              color: AppColors.primarySageDark,
            ),
            const SizedBox(width: 8),
            _buildStatusChip(
              icon: Icons.wifi_rounded,
              label: provider.isMockMode ? 'Simulador' : 'Conectado',
              color: AppColors.breakChipText,
            ),
            const SizedBox(width: 8),
            _buildStatusChip(
              icon: Icons.lock_open_rounded,
              label: 'Desbloqueado',
              color: AppColors.terracottaBrown,
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Tarjeta Central de Locky en su Caja
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.borderSubtle, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: AppColors.primarySageDark.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              const LockyMascot(pose: LockyPose.inBox, size: 140),
              const SizedBox(height: 16),
              const Text(
                '¡Locky está esperando tu celular!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Deposita tu teléfono dentro de la caja FocusLock para entrar en modo de concentración profunda sin distracciones.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Botón Verde Salvia Prominente: "Configurar Sesión de Enfoque"
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _isSettingUp = true),
                  icon: const Icon(Icons.tune_rounded, size: 20),
                  label: const Text('Configurar Sesión de Enfoque'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primarySage,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Resumen rápido de hoy
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderSubtle, width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.local_fire_department_rounded, color: AppColors.terracottaBrown, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      !auth.isLoggedIn
                          ? 'Racha: Inicia sesión para registrar'
                          : (auth.currentStreakDays > 0
                              ? 'Racha de ${auth.currentStreakDays} ${auth.currentStreakDays == 1 ? "Día" : "Días"} de Enfoque 🔥'
                              : 'Racha actual: 0 días'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      !auth.isLoggedIn
                          ? 'Ve a Perfil para crear tu cuenta y sumar puntos.'
                          : (auth.sessionsCompleted > 0
                              ? '${auth.sessionsCompleted} sesiones completadas • ${auth.points} pts'
                              : 'Completa tu primera sesión hoy para iniciar tu racha.'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // PANTALLA 3: SETUP SCREEN (EN ESPAÑOL)
  // ===========================================================================
  Widget _buildSetupScreen(BuildContext context, FocusLockProvider provider) {
    final scheduleProv = context.watch<ScheduleProvider>();
    final categories = scheduleProv.categories;
    final selectedName = categories.isNotEmpty
        ? categories[_selectedSubjectIndex.clamp(0, categories.length - 1)].name
        : 'Enfoque Libre';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header con botón atrás
        Row(
          children: [
            InkWell(
              onTap: () => setState(() => _isSettingUp = false),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(width: 14),
            const Text(
              'Configurar Sesión de Enfoque',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Sección 1: Ruedita tipo reloj para elegir duración
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '1. Elige la Duración del Enfoque',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            ActionChip(
              avatar: const Icon(Icons.bolt_rounded, size: 16, color: AppColors.graceChipText),
              label: Text(
                provider.isDemoMode ? 'Demo 30s ✓' : 'Demo 30s',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
              backgroundColor: provider.isDemoMode ? AppColors.graceChipBg : AppColors.surfaceMuted,
              onPressed: () {
                provider.setFocusSeconds(30, breakSeconds: 10);
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildClockWheelPicker(provider),

        const SizedBox(height: 26),

        // Sección 2: Carrusel de Categorías (creadas por el usuario)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '2. Elige o Crea tu Categoría',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            TextButton.icon(
              onPressed: _showCreateCategorySheet,
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
              label: const Text('Crear', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length + 1,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              if (index == categories.length) {
                return InkWell(
                  onTap: _showCreateCategorySheet,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: 155,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.primarySage, width: 1.5),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded, size: 28, color: AppColors.primarySageDark),
                        SizedBox(height: 6),
                        Text(
                          'Nueva Categoría',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primarySageDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final cat = categories[index];
              final isSelected = index == _selectedSubjectIndex;
              final subColor = cat.color;

              return InkWell(
                onTap: () => setState(() => _selectedSubjectIndex = index),
                onLongPress: () {
                  final baseUrl = context.read<FocusLockProvider>().baseUrl;
                  final token = context.read<AuthProvider>().token;
                  scheduleProv.deleteCategorySynced(baseUrl, token, cat.id);
                  if (_selectedSubjectIndex >= categories.length - 1) {
                    setState(() => _selectedSubjectIndex = 0);
                  }
                },
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 175,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.surfaceCard : AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected ? subColor : AppColors.borderSubtle,
                      width: isSelected ? 2.0 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: subColor.withValues(alpha: 0.14),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(cat.icon, size: 24, color: subColor),
                          if (isSelected)
                            Icon(Icons.check_circle_rounded, size: 18, color: subColor),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cat.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            cat.subtitle.isEmpty ? 'Categoría' : cat.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 26),

        // Tarjeta informativa con Locky listo
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              const LockyMascot(pose: LockyPose.ready, size: 64),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¿Listo para $selectedName?',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Al presionar iniciar, coloca tu celular en el compartimento. El cerrojo mecánico enclavará la compuerta.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Botón Verde Salvia CTA: "Bloquear Caja e Iniciar Enfoque"
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => provider.startSession(),
            icon: const Icon(Icons.lock_rounded, size: 20),
            label: Text('Bloquear Caja e Iniciar (${provider.selectedDurationLabel})'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primarySage,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // PANTALLA 4: FOCUS ACTIVE SCREEN (EN ESPAÑOL)
  // ===========================================================================
  Widget _buildFocusActiveScreen(BuildContext context, FocusLockProvider provider) {
    final cats = context.watch<ScheduleProvider>().categories;
    final activeCategoryName = cats.isNotEmpty
        ? cats[_selectedSubjectIndex.clamp(0, cats.length - 1)].name
        : 'Enfoque FocusLock';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Chip superior de Enfoque Bloqueado
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.focusChipBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.focusChipText.withValues(alpha: 0.3)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_rounded, size: 16, color: AppColors.focusChipText),
              SizedBox(width: 8),
              Text(
                'SESIÓN DE ENFOQUE BLOQUEADA',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: AppColors.focusChipText,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Text(
          activeCategoryName,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Cerrojo físico enclavado • Cero distracciones',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),

        const SizedBox(height: 32),

        // Dial Circular con anillo primarySageLight y progreso primarySage
        CircularPomodoroTimer(
          progress: provider.progress,
          formattedTime: provider.formattedRemaining,
          state: FocusLockState.lockedFocus,
          size: 280,
          subtitle: 'TIEMPO RESTANTE',
        ),

        const SizedBox(height: 32),

        // Tarjeta de Locky durmiendo cuidando el celular
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.borderSubtle, width: 1.2),
          ),
          child: const Row(
            children: [
              LockyMascot(pose: LockyPose.sleeping, size: 70),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shhh... Locky está durmiendo 💤',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Está custodiando tu celular con seguridad. Concéntrate al 100% en tu estudio.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Botón de emergencia
        OutlinedButton.icon(
          onPressed: () => _showEmergencyDialog(context, provider),
          icon: const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.terracottaBrown),
          label: const Text(
            'Apertura de Emergencia',
            style: TextStyle(color: AppColors.terracottaBrown, fontWeight: FontWeight.w700),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AppColors.terracottaBrown.withValues(alpha: 0.4)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // PANTALLA 5: REWARD SCREEN (EN ESPAÑOL)
  // ===========================================================================
  Widget _buildRewardScreen(BuildContext context, FocusLockProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Chip de estado de descanso
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.breakChipBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.breakChipText.withValues(alpha: 0.3)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.coffee_rounded, size: 16, color: AppColors.breakChipText),
              SizedBox(width: 8),
              Text(
                '¡COMPLETADO! • DESCANSO LIBERADO',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: AppColors.breakChipText,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Tarjeta Central con Locky Celebrando
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.borderSubtle, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: AppColors.primarySage.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              const LockyMascot(pose: LockyPose.celebrating, size: 130),
              const SizedBox(height: 16),
              Builder(
                builder: (ctx) {
                  final auth = ctx.watch<AuthProvider>();
                  final ptsEarned = provider.isDemoMode ? 10 : (provider.selectedFocusMinutes * 10);
                  return Column(
                    children: [
                      Text(
                        auth.isLoggedIn ? '¡Excelente trabajo, ${auth.username}! 🎉' : '¡Excelente trabajo! 🎉',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        provider.isDemoMode
                            ? 'Completaste tu sesión demo de concentración total.'
                            : 'Completaste ${provider.selectedFocusMinutes} minutos de concentración total sin distracciones.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.peachCream,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.terracottaBrown.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.stars_rounded, color: AppColors.terracottaDark, size: 24),
                            const SizedBox(width: 10),
                            Text(
                              '+$ptsEarned Puntos de Enfoque Ganados! 🌟',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.terracottaDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Temporizador de descanso (CircularPomodoroTimer)
        CircularPomodoroTimer(
          progress: provider.progress,
          formattedTime: provider.formattedRemaining,
          state: FocusLockState.breakUnlocked,
          size: 210,
          subtitle: 'TIEMPO DE DESCANSO',
        ),

        const SizedBox(height: 28),

        // Botones de acción
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => provider.cancelSession(),
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text('Finalizar y Registrar Sesión'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primarySage,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // SUB-PANTALLA: WAITING PHONE & GRACE PERIOD (EN ESPAÑOL)
  // ===========================================================================
  Widget _buildWaitingAndGraceScreen(
    BuildContext context,
    FocusLockProvider provider,
    FocusLockState state,
  ) {
    final isGrace = state == FocusLockState.gracePeriod;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Banner de estado
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isGrace ? AppColors.graceChipBg : AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isGrace ? AppColors.graceChipText : AppColors.borderSubtle,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isGrace ? Icons.timer_rounded : Icons.phone_android_rounded,
                size: 16,
                color: isGrace ? AppColors.graceChipText : AppColors.primarySageDark,
              ),
              const SizedBox(width: 8),
              Text(
                isGrace ? 'VENTANA DE GRACIA (5 SEGUNDOS)' : 'ESPERANDO SMARTPHONE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isGrace ? AppColors.graceChipText : AppColors.primarySageDark,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Temporizador Circular
        CircularPomodoroTimer(
          progress: provider.progress,
          formattedTime: isGrace ? '00:0${provider.remainingSeconds}' : 'Listo',
          state: state,
          size: 260,
          subtitle: isGrace ? 'RETIRA LAS MANOS' : 'COLOCA EL CELULAR',
        ),

        const SizedBox(height: 32),

        // Instrucción visual
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            children: [
              Text(
                isGrace ? '⚠️ Retira tu mano de la compuerta' : 'Deposita tu celular en la base',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isGrace
                    ? 'El sensor óptico TCRT5000 confirmó presencia. El cerrojo se enclavará automáticamente.'
                    : 'El sensor de infrarrojos enclava la compuerta tras 200 ms de estabilidad continua.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Botón de simulación si está en modo Mock
        if (provider.isMockMode && state == FocusLockState.waitingPhone) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => provider.simulatePhonePlaced(),
              icon: const Icon(Icons.sensors_rounded, size: 18),
              label: const Text('Simular Detección de Celular (TCRT5000)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primarySageDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Botón de cancelar
        OutlinedButton.icon(
          onPressed: () => provider.cancelSession(),
          icon: const Icon(Icons.close_rounded, size: 18),
          label: const Text('Cancelar Sesión'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: const BorderSide(color: AppColors.borderSubtle),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // WIDGETS AUXILIARES
  // ===========================================================================
  Widget _buildStatusChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClockWheelPicker(FocusLockProvider provider) {
    final totalMins = provider.selectedFocusMinutes;
    final currentHours = (totalMins ~/ 60).clamp(0, 3);
    final currentMins = totalMins % 60;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle, width: 1.2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'Horas',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                    ),
                    SizedBox(
                      height: 125,
                      child: CupertinoPicker(
                        scrollController: _hoursWheelCtrl,
                        itemExtent: 38,
                        magnification: 1.18,
                        useMagnifier: true,
                        onSelectedItemChanged: (h) {
                          final nextTotal = (h * 60) + currentMins;
                          provider.setFocusMinutes(nextTotal < 1 ? 1 : nextTotal);
                        },
                        children: List.generate(
                          4,
                          (h) => Center(
                            child: Text(
                              '${h.toString().padLeft(2, '0')} h',
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                ':',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.primarySageDark),
              ),
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'Minutos',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                    ),
                    SizedBox(
                      height: 125,
                      child: CupertinoPicker(
                        scrollController: _minutesWheelCtrl,
                        itemExtent: 38,
                        magnification: 1.18,
                        useMagnifier: true,
                        onSelectedItemChanged: (m) {
                          final nextTotal = (currentHours * 60) + m;
                          provider.setFocusMinutes(nextTotal < 1 ? 1 : nextTotal);
                        },
                        children: List.generate(
                          60,
                          (m) => Center(
                            child: Text(
                              '${m.toString().padLeft(2, '0')} m',
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: AppColors.borderSubtle),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Descansos tipo Pomodoro',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  Text(
                    'Elige si quieres pausas (5 a 15 min)',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
              Switch(
                value: provider.breaksEnabled,
                activeThumbColor: AppColors.primarySage,
                onChanged: (val) => provider.setBreaksEnabled(val),
              ),
            ],
          ),
          if (provider.breaksEnabled) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cantidad de descansos',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [1, 2, 3, 4].map((cnt) {
                          final active = provider.breakCount == cnt;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: InkWell(
                                onTap: () => provider.setBreakCount(cnt),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: active ? AppColors.primarySage : AppColors.surfaceMuted,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: active ? AppColors.primarySageDark : AppColors.borderSubtle,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$cnt',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: active ? Colors.white : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 96,
                  child: Column(
                    children: [
                      const Text(
                        'Duración (5-15m)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                      ),
                      SizedBox(
                        height: 86,
                        child: CupertinoPicker(
                          scrollController: _breakWheelCtrl,
                          itemExtent: 32,
                          magnification: 1.15,
                          useMagnifier: true,
                          onSelectedItemChanged: (idx) {
                            provider.setBreakMinutes(idx + 5);
                          },
                          children: List.generate(
                            11,
                            (idx) => Center(
                              child: Text(
                                '${idx + 5} min',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.breakChipText,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            provider.isDemoMode
                ? 'Seleccionado: 30 seg (Demo) • ${provider.breaksEnabled ? "10 seg descanso" : "Sin descanso"}'
                : (!provider.breaksEnabled
                    ? 'Seleccionado: ${provider.selectedFocusMinutes} min enfoque • Sin descansos'
                    : 'Seleccionado: ${provider.selectedFocusMinutes} min enfoque • ${provider.breakCount}x descanso de ${provider.selectedBreakMinutes} min'),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primarySageDark,
            ),
          ),
        ],
      ),
    );
  }

  void _showEmergencyDialog(BuildContext context, FocusLockProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.focusChipText, size: 26),
            SizedBox(width: 10),
            Text('Apertura de Emergencia', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
          ],
        ),
        content: const Text(
          '¿Estás segura de que deseas forzar la apertura del cerrojo mecánico? Esto cancelará la sesión activa y liberará la compuerta de inmediato.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Continuar Enfoque', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.emergencyUnlock('emergency-manual');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.focusChipText,
              foregroundColor: Colors.white,
            ),
            child: const Text('Desbloquear Caja'),
          ),
        ],
      ),
    );
  }
}
