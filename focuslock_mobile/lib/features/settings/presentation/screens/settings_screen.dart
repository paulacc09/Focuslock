import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(title: const Text('Calibración de Hardware')),
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
            'Calibración de servomotor SG90 (GPIO 18) y sensor TCRT5000 (GPIO 17)',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ),
      ),
    );
  }
}
