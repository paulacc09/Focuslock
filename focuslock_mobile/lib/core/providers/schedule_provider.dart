import 'package:flutter/material.dart';
import '../models/task_item.dart';

class ScheduleProvider extends ChangeNotifier {
  DateTime _selectedDate = DateTime.now();
  TaskCategory? _selectedCategory; // null = Todos

  final List<TaskItem> _tasks = [
    TaskItem(
      id: 'task-1',
      title: 'Taller Señales - Convolución',
      category: TaskCategory.university,
      date: DateTime.now(),
      startTime: '08:00 AM',
      endTime: '09:30 AM',
      durationMinutes: 90,
      isCompleted: true,
      useFocusLockBox: true,
    ),
    TaskItem(
      id: 'task-2',
      title: 'FSM Digital III - Diseño y VHDL',
      category: TaskCategory.university,
      date: DateTime.now(),
      startTime: '10:00 AM',
      endTime: '11:30 AM',
      durationMinutes: 90,
      isCompleted: true,
      useFocusLockBox: true,
    ),
    TaskItem(
      id: 'task-3',
      title: 'Lectura Paper Arquitectura ARM',
      category: TaskCategory.personal,
      date: DateTime.now(),
      startTime: '02:00 PM',
      endTime: '02:45 PM',
      durationMinutes: 45,
      isCompleted: false,
      useFocusLockBox: true,
    ),
    TaskItem(
      id: 'task-4',
      title: 'Propuesta UI App Cliente',
      category: TaskCategory.freelance,
      date: DateTime.now(),
      startTime: '03:30 PM',
      endTime: '04:30 PM',
      durationMinutes: 60,
      isCompleted: false,
      useFocusLockBox: false,
    ),
    TaskItem(
      id: 'task-5',
      title: 'Calibrar Sensor TCRT5000',
      category: TaskCategory.university,
      date: DateTime.now(),
      startTime: '05:00 PM',
      endTime: '05:45 PM',
      durationMinutes: 45,
      isCompleted: false,
      useFocusLockBox: true,
    ),
  ];

  // Getters
  DateTime get selectedDate => _selectedDate;
  TaskCategory? get selectedCategory => _selectedCategory;
  List<TaskItem> get allTasks => List.unmodifiable(_tasks);

  List<TaskItem> get filteredTasks {
    return _tasks.where((task) {
      final sameDay = task.date.year == _selectedDate.year &&
          task.date.month == _selectedDate.month &&
          task.date.day == _selectedDate.day;
      if (!sameDay) return false;

      if (_selectedCategory != null && task.category != _selectedCategory) {
        return false;
      }
      return true;
    }).toList();
  }

  // Meta Diaria (Daily Target Goal)
  double get dailyTargetHours => 4.0;

  double get dailyFocusedHours {
    final todayCompleted = _tasks.where((t) {
      final sameDay = t.date.year == _selectedDate.year &&
          t.date.month == _selectedDate.month &&
          t.date.day == _selectedDate.day;
      return sameDay && t.isCompleted;
    });

    final totalMinutes = todayCompleted.fold<int>(0, (sum, t) => sum + t.durationMinutes);
    return totalMinutes / 60.0;
  }

  double get dailyGoalProgress {
    if (dailyTargetHours <= 0) return 0.0;
    return (dailyFocusedHours / dailyTargetHours).clamp(0.0, 1.0);
  }

  int get dailyGoalPercentage => (dailyGoalProgress * 100).round();

  String get dailyGoalSubtitle {
    final focusedStr = dailyFocusedHours.toStringAsFixed(dailyFocusedHours.truncateToDouble() == dailyFocusedHours ? 0 : 1);
    final targetStr = dailyTargetHours.toStringAsFixed(0);
    return 'Meta Diaria: ${focusedStr}h de ${targetStr}h enfocadas ($dailyGoalPercentage%)';
  }

  // Acciones
  void selectDate(DateTime date) {
    if (_selectedDate.year == date.year &&
        _selectedDate.month == date.month &&
        _selectedDate.day == date.day) {
      return;
    }
    _selectedDate = date;
    notifyListeners();
  }

  void setCategoryFilter(TaskCategory? category) {
    if (_selectedCategory == category) return;
    _selectedCategory = category;
    notifyListeners();
  }

  void toggleTaskCompleted(String id) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      final current = _tasks[index];
      _tasks[index] = current.copyWith(isCompleted: !current.isCompleted);
      notifyListeners();
    }
  }

  void addTask(TaskItem task) {
    _tasks.add(task);
    notifyListeners();
  }

  void deleteTask(String id) {
    _tasks.removeWhere((t) => t.id == id);
    notifyListeners();
  }
}

