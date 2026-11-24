import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/task_item.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/focus_lock_provider.dart';
import '../../../../core/providers/schedule_provider.dart';

class NewTaskModal extends StatefulWidget {
  const NewTaskModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NewTaskModal(),
    );
  }

  @override
  State<NewTaskModal> createState() => _NewTaskModalState();
}

class _NewTaskModalState extends State<NewTaskModal> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();

  CustomCategory? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  int _durationHours = 0;
  int _durationMins = 25;
  bool _useFocusLockBox = true;
  late final FixedExtentScrollController _hoursCtrl;
  late final FixedExtentScrollController _minsCtrl;

  int get _durationMinutes => ((_durationHours * 60) + _durationMins).clamp(1, 240);

  @override
  void initState() {
    super.initState();
    _hoursCtrl = FixedExtentScrollController(initialItem: _durationHours);
    _minsCtrl = FixedExtentScrollController(initialItem: _durationMins);
    final cats = context.read<ScheduleProvider>().categories;
    if (cats.isNotEmpty) {
      _selectedCategory = cats.first;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _hoursCtrl.dispose();
    _minsCtrl.dispose();
    super.dispose();
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  String _calculateEndTime(TimeOfDay start, int durationMinutes) {
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = (startMinutes + durationMinutes) % (24 * 60);
    final endHour = endMinutes ~/ 60;
    final endMinute = endMinutes % 60;
    final endTimeOfDay = TimeOfDay(hour: endHour, minute: endMinute);
    return _formatTimeOfDay(endTimeOfDay);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primarySage,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primarySage,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  void _showCreateCategoryDialog() {
    final nameCtrl = TextEditingController();
    int iconIdx = 0;
    int colorIdx = 0;

    showDialog<void>(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Nueva Categoría',
            style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de categoría',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Ícono', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(CustomCategory.iconChoices.length, (i) {
                    final active = i == iconIdx;
                    final col = CustomCategory.colorChoices[colorIdx];
                    return InkWell(
                      onTap: () => setDlgState(() => iconIdx = i),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: active ? col.withValues(alpha: 0.16) : AppColors.scaffoldBackground,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: active ? col : AppColors.borderSubtle, width: active ? 2 : 1),
                        ),
                        child: Icon(CustomCategory.iconChoices[i], size: 20, color: active ? col : AppColors.textSecondary),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                const Text('Color', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: List.generate(CustomCategory.colorChoices.length, (i) {
                    final c = CustomCategory.colorChoices[i];
                    final active = i == colorIdx;
                    return InkWell(
                      onTap: () => setDlgState(() => colorIdx = i),
                      borderRadius: BorderRadius.circular(99),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(color: active ? AppColors.textPrimary : Colors.transparent, width: 2.5),
                        ),
                        child: active ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primarySage, foregroundColor: Colors.white),
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final newCat = CustomCategory(
                  id: 'cat-${DateTime.now().millisecondsSinceEpoch}',
                  name: name,
                  iconIndex: iconIdx,
                  colorValue: CustomCategory.colorChoices[colorIdx].toARGB32(),
                );
                final baseUrl = context.read<FocusLockProvider>().baseUrl;
                final token = context.read<AuthProvider>().token;
                context.read<ScheduleProvider>().createCategorySynced(baseUrl, token, newCat);
                setState(() => _selectedCategory = newCat);
                Navigator.pop(dlgCtx);
              },
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final startStr = _formatTimeOfDay(_startTime);
    final endStr = _calculateEndTime(_startTime, _durationMinutes);

    final newTask = TaskItem(
      id: 'task-${DateTime.now().millisecondsSinceEpoch}',
      title: _titleController.text.trim(),
      customCategoryName: _selectedCategory?.name ?? 'General',
      customCategoryIconIndex: _selectedCategory?.iconIndex,
      customCategoryColorValue: _selectedCategory?.colorValue,
      date: _selectedDate,
      startTime: startStr,
      endTime: endStr,
      durationMinutes: _durationMinutes,
      isCompleted: false,
      useFocusLockBox: _useFocusLockBox,
    );

    context.read<ScheduleProvider>().addTask(newTask);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tarea "${newTask.title}" agregada con éxito.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primarySageDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 24,
        right: 24,
        bottom: bottomInset + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barra de arrastre superior
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.borderSubtle,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Encabezado
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Nueva Tarea de Estudio',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Input de Título
              const Text(
                'Título de la Tarea',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _titleController,
                autofocus: true,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Ej. Taller de Señales - Convolución',
                  hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                  filled: true,
                  fillColor: AppColors.scaffoldBackground,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.borderSubtle, width: 1.2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primarySage, width: 1.8),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.focusChipText, width: 1.2),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.focusChipText, width: 1.8),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Por favor ingresa un título para la tarea';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Selector de Categoría personalizada
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Categoría',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _showCreateCategoryDialog,
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                    label: const Text('Crear Categoría', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Builder(
                builder: (ctx) {
                  final categories = ctx.watch<ScheduleProvider>().categories;
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ...categories.map((cat) {
                          final isSelected = _selectedCategory?.id == cat.id;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              selected: isSelected,
                              onSelected: (_) => setState(() => _selectedCategory = cat),
                              avatar: Icon(cat.icon, size: 16, color: cat.color),
                              label: Text(
                                cat.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: cat.color,
                                ),
                              ),
                              backgroundColor: cat.backgroundColor.withValues(alpha: 0.5),
                              selectedColor: cat.backgroundColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isSelected ? cat.color : AppColors.borderSubtle,
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              showCheckmark: false,
                            ),
                          );
                        }),
                        ActionChip(
                          avatar: const Icon(Icons.add_rounded, size: 16, color: AppColors.primarySageDark),
                          label: Text(
                            categories.isEmpty ? 'Crear primera categoría' : 'Nueva',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primarySageDark,
                            ),
                          ),
                          backgroundColor: AppColors.scaffoldBackground,
                          side: const BorderSide(color: AppColors.primarySage),
                          onPressed: _showCreateCategoryDialog,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              // Fecha y Hora de Inicio
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Fecha',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.scaffoldBackground,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.borderSubtle, width: 1.2),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primarySage),
                                const SizedBox(width: 8),
                                Text(
                                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hora de Inicio',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: _pickTime,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.scaffoldBackground,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.borderSubtle, width: 1.2),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time_rounded, size: 18, color: AppColors.primarySage),
                                const SizedBox(width: 8),
                                Text(
                                  _formatTimeOfDay(_startTime),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Ruedita de Duración Estimada tipo reloj
              const Text(
                'Duración Estimada',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.scaffoldBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSubtle, width: 1.2),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 105,
                            child: CupertinoPicker(
                              scrollController: _hoursCtrl,
                              itemExtent: 34,
                              magnification: 1.15,
                              useMagnifier: true,
                              onSelectedItemChanged: (h) => setState(() => _durationHours = h),
                              children: List.generate(
                                5,
                                (h) => Center(
                                  child: Text(
                                    '${h.toString().padLeft(2, '0')} h',
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const Text(':', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primarySageDark)),
                        Expanded(
                          child: SizedBox(
                            height: 105,
                            child: CupertinoPicker(
                              scrollController: _minsCtrl,
                              itemExtent: 34,
                              magnification: 1.15,
                              useMagnifier: true,
                              onSelectedItemChanged: (m) => setState(() => _durationMins = m),
                              children: List.generate(
                                60,
                                (m) => Center(
                                  child: Text(
                                    '${m.toString().padLeft(2, '0')} m',
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Duración seleccionada: $_durationMinutes min',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primarySageDark),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Switch FocusLock Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.scaffoldBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _useFocusLockBox,
                  onChanged: (val) => setState(() => _useFocusLockBox = val),
                  activeThumbColor: AppColors.primarySage,
                  title: const Text(
                    '🔒 Enclavar en caja física FocusLock',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: const Text(
                    'Exige colocar el celular en el compartimento para iniciar la sesión',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ),
              const SizedBox(height: 26),

              // Botón CTA Crear Tarea
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.check_rounded, size: 20),
                  label: const Text('Crear Tarea ✓'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primarySage,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
          ),
        ),
      ),
    );
  }
}

