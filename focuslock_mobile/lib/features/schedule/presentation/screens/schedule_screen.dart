import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/task_item.dart';
import '../../../../core/providers/schedule_provider.dart';
import '../widgets/new_task_modal.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  static const List<String> _spanishMonths = [
    '', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
  ];

  static const List<String> _spanishWeekdaysShort = [
    '', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'
  ];

  List<DateTime> _getCurrentWeekDays(DateTime anchor) {
    // Encuentra el lunes de la semana actual
    final int weekday = anchor.weekday; // 1 = Lun, 7 = Dom
    final monday = anchor.subtract(Duration(days: weekday - 1));
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    final scheduleProv = context.watch<ScheduleProvider>();
    final selectedDate = scheduleProv.selectedDate;
    final weekDays = _getCurrentWeekDays(selectedDate);
    final tasks = scheduleProv.filteredTasks;

    final formattedHeaderDate =
        'Hoy, ${selectedDate.day} de ${_spanishMonths[selectedDate.month]}';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          'Horario de Estudio',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => NewTaskModal.show(context),
        backgroundColor: AppColors.primarySage,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text(
          'Agregar Tarea',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 90),
          children: [
            // Subtítulo con fecha
            Text(
              formattedHeaderDate,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 14),

            // Widget de Meta Diaria (Daily Target Goal)
            _buildDailyGoalCard(scheduleProv),

            const SizedBox(height: 20),

            // Selector Semanal Horizontal
            _buildWeeklySelector(context, scheduleProv, weekDays, selectedDate),

            const SizedBox(height: 18),

            // Filtros por Categoría (Chips)
            _buildCategoryFilters(scheduleProv),

            const SizedBox(height: 20),

            // Encabezado de la lista
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Bloques Planificados (${tasks.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${scheduleProv.dailyFocusedHours.toStringAsFixed(1)}h completadas',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primarySageDark,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Lista de Tareas
            if (tasks.isEmpty)
              _buildEmptyState(context)
            else
              ...tasks.map((task) => _buildTaskCard(context, scheduleProv, task)),
          ],
        ),
      ),
    );
  }

  // 1. Tarjeta de Meta Diaria
  Widget _buildDailyGoalCard(ScheduleProvider prov) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderSubtle, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primarySageDark.withValues(alpha: 0.05),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySageLight.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.flag_rounded,
                      color: AppColors.primarySageDark,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Progreso de Enfoque Diario',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.breakChipBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${prov.dailyGoalPercentage}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.breakChipText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Texto exacto de Figma: "Meta Diaria: 3h de 4h enfocadas (75%)"
          Text(
            prov.dailyGoalSubtitle,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),

          // Barra horizontal estilizada
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: prov.dailyGoalProgress,
              minHeight: 10,
              backgroundColor: AppColors.surfaceMuted,
              color: AppColors.primarySage,
            ),
          ),
        ],
      ),
    );
  }

  // 2. Selector Semanal Horizontal
  Widget _buildWeeklySelector(
    BuildContext context,
    ScheduleProvider prov,
    List<DateTime> weekDays,
    DateTime selectedDate,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle, width: 1.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: weekDays.map((date) {
          final isSelected = date.year == selectedDate.year &&
              date.month == selectedDate.month &&
              date.day == selectedDate.day;

          final weekdayName = _spanishWeekdaysShort[date.weekday];

          return InkWell(
            onTap: () => prov.selectDate(date),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primarySage : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primarySage.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                children: [
                  Text(
                    weekdayName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // 3. Filtros por Categoría (Chips)
  Widget _buildCategoryFilters(ScheduleProvider prov) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Chip "Todos"
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: prov.selectedCategoryName == null,
              onSelected: (_) => prov.setCategoryFilter(null),
              label: const Text('Todos'),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: prov.selectedCategoryName == null ? FontWeight.w800 : FontWeight.w600,
                color: prov.selectedCategoryName == null ? Colors.white : AppColors.textSecondary,
              ),
              backgroundColor: AppColors.surfaceCard,
              selectedColor: AppColors.primarySage,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: prov.selectedCategoryName == null ? AppColors.primarySage : AppColors.borderSubtle,
                ),
              ),
              showCheckmark: false,
            ),
          ),

          // Chips para cada categoría creada por el usuario
          ...prov.categories.map((cat) {
            final isSelected = prov.selectedCategoryName == cat.name;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: isSelected,
                onSelected: (_) => prov.setCategoryFilter(isSelected ? null : cat.name),
                avatar: Icon(cat.icon, size: 15, color: cat.color),
                label: Text(cat.name),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: cat.color,
                ),
                backgroundColor: cat.backgroundColor.withValues(alpha: 0.5),
                selectedColor: cat.backgroundColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isSelected ? cat.color : AppColors.borderSubtle,
                    width: isSelected ? 1.6 : 1.0,
                  ),
                ),
                showCheckmark: false,
              ),
            );
          }),
        ],
      ),
    );
  }

  // 4. Tarjeta de Tarea Individual
  Widget _buildTaskCard(BuildContext context, ScheduleProvider prov, TaskItem task) {
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: AppColors.focusChipBg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.focusChipText, size: 24),
      ),
      onDismissed: (_) => prov.deleteTask(task.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: task.isCompleted
                ? AppColors.primarySage.withValues(alpha: 0.25)
                : AppColors.borderSubtle,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primarySageDark.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox circular interactivo
            InkWell(
              onTap: () => prov.toggleTaskCompleted(task.id),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Icon(
                  task.isCompleted
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: task.isCompleted ? AppColors.primarySage : AppColors.textMuted,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Contenido de la tarea
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título
                  Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: task.isCompleted ? AppColors.textMuted : AppColors.textPrimary,
                      decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Horario y duración
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '${task.startTime} - ${task.endTime}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${task.durationMinutes} min)',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Badges: Categoría y Caja FocusLock
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      // Badge de Categoría
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: task.displayCategoryBgColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          task.displayCategoryLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: task.displayCategoryColor,
                          ),
                        ),
                      ),

                      // Badge FocusLock Box
                      if (task.useFocusLockBox)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primarySageLight.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_rounded, size: 12, color: AppColors.primarySageDark),
                              SizedBox(width: 4),
                              Text(
                                'Caja FocusLock',
                                style: TextStyle(
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 5. Estado Vacío
  Widget _buildEmptyState(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_available_rounded,
              color: AppColors.primarySage,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No hay tareas para este día',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '¡Tómate un descanso o programa una nueva sesión de estudio con el botón inferior!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
