import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(title: const Text('Historial de Sesiones')),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: const Text(
            'Registro de sesiones Pomodoro completadas',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ),
      ),
    );
  }
}
