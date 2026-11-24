import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_item.dart';

class ScheduleProvider extends ChangeNotifier {
  static const _kTasksKey = 'focuslock_schedule_tasks';
  DateTime _selectedDate = DateTime.now();
  TaskCategory? _selectedCategory; // null = Todos

  final List<TaskItem> _tasks = [];

  ScheduleProvider() {
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kTasksKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _tasks
          ..clear()
          ..addAll(decoded.map((item) {
            final m = item as Map<String, dynamic>;
            final catIdx = (m['category'] as num?)?.toInt() ?? 0;
            return TaskItem(
              id: m['id'].toString(),
              title: m['title'].toString(),
              category: TaskCategory.values[catIdx.clamp(0, TaskCategory.values.length - 1)],
              date: DateTime.tryParse(m['date'].toString()) ?? DateTime.now(),
              startTime: m['startTime'].toString(),
              endTime: m['endTime'].toString(),
              durationMinutes: (m['durationMinutes'] as num?)?.toInt() ?? 25,
              isCompleted: m['isCompleted'] == true,
              useFocusLockBox: m['useFocusLockBox'] != false,
            );
          }));
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _saveTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_tasks.map((t) => {
        'id': t.id,
        'title': t.title,
        'category': t.category.index,
        'date': t.date.toIso8601String(),
        'startTime': t.startTime,
        'endTime': t.endTime,
        'durationMinutes': t.durationMinutes,
        'isCompleted': t.isCompleted,
        'useFocusLockBox': t.useFocusLockBox,
      }).toList());
      await prefs.setString(_kTasksKey, encoded);
    } catch (_) {}
  }

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
      _saveTasks();
      notifyListeners();
    }
  }

  void addTask(TaskItem task) {
    _tasks.add(task);
    _saveTasks();
    notifyListeners();
  }

  void deleteTask(String id) {
    _tasks.removeWhere((t) => t.id == id);
    _saveTasks();
    notifyListeners();
  }
}

