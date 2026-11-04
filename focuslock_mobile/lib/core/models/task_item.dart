import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum TaskCategory {
  university,
  freelance,
  personal;

  String get label {
    switch (this) {
      case TaskCategory.university:
        return 'Universidad';
      case TaskCategory.freelance:
        return 'Freelance';
      case TaskCategory.personal:
        return 'Personal';
    }
  }

  Color get backgroundColor {
    switch (this) {
      case TaskCategory.university:
        return AppColors.catUniversityBg;
      case TaskCategory.freelance:
        return AppColors.catFreelanceBg;
      case TaskCategory.personal:
        return AppColors.catPersonalBg;
    }
  }

  Color get textColor {
    switch (this) {
      case TaskCategory.university:
        return AppColors.catUniversityText;
      case TaskCategory.freelance:
        return AppColors.catFreelanceText;
      case TaskCategory.personal:
        return AppColors.catPersonalText;
    }
  }

  IconData get icon {
    switch (this) {
      case TaskCategory.university:
        return Icons.school_rounded;
      case TaskCategory.freelance:
        return Icons.work_rounded;
      case TaskCategory.personal:
        return Icons.person_rounded;
    }
  }
}

class TaskItem {
  final String id;
  final String title;
  final TaskCategory category;
  final DateTime date;
  final String startTime;
  final String endTime;
  final int durationMinutes;
  final bool isCompleted;
  final bool useFocusLockBox;

  const TaskItem({
    required this.id,
    required this.title,
    required this.category,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    this.isCompleted = false,
    this.useFocusLockBox = true,
  });

  TaskItem copyWith({
    String? id,
    String? title,
    TaskCategory? category,
    DateTime? date,
    String? startTime,
    String? endTime,
    int? durationMinutes,
    bool? isCompleted,
    bool? useFocusLockBox,
  }) {
    return TaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isCompleted: isCompleted ?? this.isCompleted,
      useFocusLockBox: useFocusLockBox ?? this.useFocusLockBox,
    );
  }
}

