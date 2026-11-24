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

class CustomCategory {
  static const List<IconData> iconChoices = [
    Icons.school_rounded,
    Icons.menu_book_rounded,
    Icons.memory_rounded,
    Icons.calculate_rounded,
    Icons.code_rounded,
    Icons.science_rounded,
    Icons.work_rounded,
    Icons.palette_rounded,
    Icons.fitness_center_rounded,
    Icons.person_rounded,
  ];

  static const List<Color> colorChoices = [
    AppColors.primarySage,
    AppColors.terracottaBrown,
    AppColors.focusChipText,
    Color(0xFF4B8BBE),
    Color(0xFF8E6BB8),
    AppColors.graceChipText,
    Color(0xFF3C9D9B),
    AppColors.textSecondary,
  ];

  final String id;
  final String name;
  final String subtitle;
  final int iconIndex;
  final int colorValue;

  const CustomCategory({
    required this.id,
    required this.name,
    this.subtitle = '',
    required this.iconIndex,
    required this.colorValue,
  });

  IconData get icon => iconChoices[iconIndex.clamp(0, iconChoices.length - 1)];
  Color get color => Color(colorValue);
  Color get backgroundColor => color.withValues(alpha: 0.14);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'subtitle': subtitle,
        'iconIndex': iconIndex,
        'colorValue': colorValue,
      };

  factory CustomCategory.fromJson(Map<String, dynamic> m) => CustomCategory(
        id: m['id'].toString(),
        name: m['name'].toString(),
        subtitle: (m['subtitle'] ?? '').toString(),
        iconIndex: ((m['iconIndex'] ?? m['icon_index']) as num?)?.toInt() ?? 0,
        colorValue: ((m['colorValue'] ?? m['color_value']) as num?)?.toInt() ?? AppColors.primarySage.toARGB32(),
      );
}

class TaskItem {
  final String id;
  final String title;
  final TaskCategory category;
  final String? customCategoryName;
  final int? customCategoryIconIndex;
  final int? customCategoryColorValue;
  final DateTime date;
  final String startTime;
  final String endTime;
  final int durationMinutes;
  final bool isCompleted;
  final bool useFocusLockBox;

  const TaskItem({
    required this.id,
    required this.title,
    this.category = TaskCategory.personal,
    this.customCategoryName,
    this.customCategoryIconIndex,
    this.customCategoryColorValue,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    this.isCompleted = false,
    this.useFocusLockBox = true,
  });

  String get displayCategoryLabel =>
      (customCategoryName != null && customCategoryName!.isNotEmpty)
          ? customCategoryName!
          : 'General';

  Color get displayCategoryColor => customCategoryColorValue != null
      ? Color(customCategoryColorValue!)
      : AppColors.primarySageDark;

  Color get displayCategoryBgColor => displayCategoryColor.withValues(alpha: 0.14);

  IconData get displayCategoryIcon => customCategoryIconIndex != null
      ? CustomCategory.iconChoices[customCategoryIconIndex!.clamp(0, CustomCategory.iconChoices.length - 1)]
      : Icons.bookmark_rounded;

  TaskItem copyWith({
    String? id,
    String? title,
    TaskCategory? category,
    String? customCategoryName,
    int? customCategoryIconIndex,
    int? customCategoryColorValue,
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
      customCategoryName: customCategoryName ?? this.customCategoryName,
      customCategoryIconIndex: customCategoryIconIndex ?? this.customCategoryIconIndex,
      customCategoryColorValue: customCategoryColorValue ?? this.customCategoryColorValue,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isCompleted: isCompleted ?? this.isCompleted,
      useFocusLockBox: useFocusLockBox ?? this.useFocusLockBox,
    );
  }
}

