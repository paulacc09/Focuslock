import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_item.dart';

class ScheduleProvider extends ChangeNotifier {
  static const _kTasksKey = 'focuslock_schedule_tasks';
  static const _kCategoriesKey = 'focuslock_schedule_categories';
  DateTime _selectedDate = DateTime.now();
  String? _selectedCategoryName; // null = Todos

  final List<TaskItem> _tasks = [];
  final List<CustomCategory> _categories = [];

  ScheduleProvider() {
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawCats = prefs.getString(_kCategoriesKey);
      if (rawCats != null && rawCats.isNotEmpty) {
        final decodedCats = jsonDecode(rawCats) as List<dynamic>;
        _categories
          ..clear()
          ..addAll(decodedCats.map((e) => CustomCategory.fromJson(e as Map<String, dynamic>)));
      }

      final rawTasks = prefs.getString(_kTasksKey);
      if (rawTasks != null && rawTasks.isNotEmpty) {
        final decoded = jsonDecode(rawTasks) as List<dynamic>;
        _tasks
          ..clear()
          ..addAll(decoded.map((item) {
            final m = item as Map<String, dynamic>;
            final catIdx = (m['category'] as num?)?.toInt() ?? 0;
            return TaskItem(
              id: m['id'].toString(),
              title: m['title'].toString(),
              category: TaskCategory.values[catIdx.clamp(0, TaskCategory.values.length - 1)],
              customCategoryName: m['customCategoryName']?.toString(),
              customCategoryIconIndex: (m['customCategoryIconIndex'] as num?)?.toInt(),
              customCategoryColorValue: (m['customCategoryColorValue'] as num?)?.toInt(),
              date: DateTime.tryParse(m['date'].toString()) ?? DateTime.now(),
              startTime: m['startTime'].toString(),
              endTime: m['endTime'].toString(),
              durationMinutes: (m['durationMinutes'] as num?)?.toInt() ?? 25,
              isCompleted: m['isCompleted'] == true,
              useFocusLockBox: m['useFocusLockBox'] != false,
            );
          }));
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_tasks.map((t) => {
        'id': t.id,
        'title': t.title,
        'category': t.category.index,
        'customCategoryName': t.customCategoryName,
        'customCategoryIconIndex': t.customCategoryIconIndex,
        'customCategoryColorValue': t.customCategoryColorValue,
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

  Future<void> _saveCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_categories.map((c) => c.toJson()).toList());
      await prefs.setString(_kCategoriesKey, encoded);
    } catch (_) {}
  }

  // Getters
  DateTime get selectedDate => _selectedDate;
  String? get selectedCategoryName => _selectedCategoryName;
  List<TaskItem> get allTasks => List.unmodifiable(_tasks);
  List<CustomCategory> get categories => List.unmodifiable(_categories);

  List<TaskItem> get filteredTasks {
    return _tasks.where((task) {
      final sameDay = task.date.year == _selectedDate.year &&
          task.date.month == _selectedDate.month &&
          task.date.day == _selectedDate.day;
      if (!sameDay) return false;

      if (_selectedCategoryName != null &&
          task.displayCategoryLabel != _selectedCategoryName) {
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
    final focusedStr = dailyFocusedHours.toStringAsFixed(
      dailyFocusedHours.truncateToDouble() == dailyFocusedHours ? 0 : 1,
    );
    final targetStr = dailyTargetHours.toStringAsFixed(0);
    return 'Meta Diaria: ${focusedStr}h de ${targetStr}h enfocadas ($dailyGoalPercentage%)';
  }

  void selectDate(DateTime date) {
    if (_selectedDate.year == date.year &&
        _selectedDate.month == date.month &&
        _selectedDate.day == date.day) {
      return;
    }
    _selectedDate = date;
    notifyListeners();
  }

  void setCategoryFilter(String? categoryName) {
    if (_selectedCategoryName == categoryName) return;
    _selectedCategoryName = categoryName;
    notifyListeners();
  }

  void addCategory(CustomCategory cat) {
    _categories.add(cat);
    _saveCategories();
    notifyListeners();
  }

  void deleteCategory(String id) {
    _categories.removeWhere((c) => c.id == id);
    _saveCategories();
    notifyListeners();
  }

  Future<void> syncCategoriesFromServer(String baseUrl, String? token) async {
    if (token == null || token.isEmpty) return;
    try {
      final res = await http
          .get(
            Uri.parse('$baseUrl/api/categories'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final rawList = data['categories'] as List<dynamic>? ?? [];
        _categories
          ..clear()
          ..addAll(rawList.map((e) => CustomCategory.fromJson(e as Map<String, dynamic>)));
        await _saveCategories();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> createCategorySynced(
    String baseUrl,
    String? token,
    CustomCategory cat,
  ) async {
    _categories.add(cat);
    await _saveCategories();
    notifyListeners();

    if (token != null && token.isNotEmpty) {
      try {
        final res = await http
            .post(
              Uri.parse('$baseUrl/api/categories'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode({
                'id': cat.id,
                'name': cat.name,
                'subtitle': cat.subtitle,
                'icon_index': cat.iconIndex,
                'color_value': cat.colorValue,
              }),
            )
            .timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          if (data['category'] is Map) {
            final saved = CustomCategory.fromJson(Map<String, dynamic>.from(data['category'] as Map));
            final idx = _categories.indexWhere((c) => c.id == cat.id);
            if (idx != -1) {
              _categories[idx] = saved;
              await _saveCategories();
              notifyListeners();
            }
          }
        }
      } catch (_) {}
    }
  }

  Future<void> deleteCategorySynced(String baseUrl, String? token, String id) async {
    _categories.removeWhere((c) => c.id == id);
    await _saveCategories();
    notifyListeners();

    if (token != null && token.isNotEmpty) {
      try {
        await http
            .delete(
              Uri.parse('$baseUrl/api/categories/$id'),
              headers: {'Authorization': 'Bearer $token'},
            )
            .timeout(const Duration(seconds: 10));
      } catch (_) {}
    }
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
