// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum FocusLockState {
  disconnected,
  idle_unlocked,
  waiting_phone,
  grace_period,
  locked_focus,
  break_unlocked,
  emergency_released;

  // Alias en camelCase para compatibilidad ergonómica en Dart
  static const FocusLockState idleUnlocked = FocusLockState.idle_unlocked;
  static const FocusLockState waitingPhone = FocusLockState.waiting_phone;
  static const FocusLockState gracePeriod = FocusLockState.grace_period;
  static const FocusLockState lockedFocus = FocusLockState.locked_focus;
  static const FocusLockState breakUnlocked = FocusLockState.break_unlocked;
  static const FocusLockState emergencyReleased = FocusLockState.emergency_released;

  /// Mapea el string devuelto por el daemon Python (`FSMState`) a `FocusLockState`
  static FocusLockState fromBackendString(String raw) {
    switch (raw.toUpperCase()) {
      case 'IDLE':
      case 'IDLE_UNLOCKED':
        return FocusLockState.idle_unlocked;
      case 'WAITING_PHONE':
        return FocusLockState.waiting_phone;
      case 'GRACE_PERIOD':
        return FocusLockState.grace_period;
      case 'LOCKED_FOCUS':
        return FocusLockState.locked_focus;
      case 'BREAK_OPEN':
      case 'BREAK_UNLOCKED':
        return FocusLockState.break_unlocked;
      case 'EMERGENCY_UNLOCKED':
      case 'EMERGENCY_RELEASED':
        return FocusLockState.emergency_released;
      default:
        return FocusLockState.disconnected;
    }
  }

  String get label {
    switch (this) {
      case FocusLockState.disconnected:
        return 'Desconectado';
      case FocusLockState.idle_unlocked:
        return 'Listo / Desbloqueado';
      case FocusLockState.waiting_phone:
        return 'Esperando Smartphone';
      case FocusLockState.grace_period:
        return 'Ventana de Gracia (5s)';
      case FocusLockState.locked_focus:
        return 'Enfoque Bloqueado';
      case FocusLockState.break_unlocked:
        return 'Descanso / Liberado';
      case FocusLockState.emergency_released:
        return 'Apertura de Emergencia';
    }
  }

  String get subtitle {
    switch (this) {
      case FocusLockState.disconnected:
        return 'Conecta la app a la Raspberry Pi Zero W';
      case FocusLockState.idle_unlocked:
        return 'Configura el temporizador y presiona Iniciar';
      case FocusLockState.waiting_phone:
        return 'Deposita tu teléfono en la base de sensado';
      case FocusLockState.grace_period:
        return 'Retira la mano y baja la tapa ahora';
      case FocusLockState.locked_focus:
        return 'Cerrojo accionado. Mantén el enfoque total.';
      case FocusLockState.break_unlocked:
        return '¡Excelente sesión! Puedes retirar tu teléfono.';
      case FocusLockState.emergency_released:
        return 'El cerrojo ha sido liberado manualmente.';
    }
  }

  Color get color {
    switch (this) {
      case FocusLockState.disconnected:
        return AppColors.textMuted;
      case FocusLockState.idle_unlocked:
        return AppColors.primarySage;
      case FocusLockState.waiting_phone:
        return AppColors.primarySageDark;
      case FocusLockState.grace_period:
        return AppColors.graceChipText;
      case FocusLockState.locked_focus:
        return AppColors.focusChipText;
      case FocusLockState.break_unlocked:
        return AppColors.breakChipText;
      case FocusLockState.emergency_released:
        return AppColors.terracottaBrown;
    }
  }

  Color get chipBgColor {
    switch (this) {
      case FocusLockState.disconnected:
        return AppColors.surfaceMuted;
      case FocusLockState.idle_unlocked:
        return AppColors.surfaceMuted;
      case FocusLockState.waiting_phone:
        return AppColors.surfaceMuted;
      case FocusLockState.grace_period:
        return AppColors.graceChipBg;
      case FocusLockState.locked_focus:
        return AppColors.focusChipBg;
      case FocusLockState.break_unlocked:
        return AppColors.breakChipBg;
      case FocusLockState.emergency_released:
        return AppColors.peachCream;
    }
  }

  IconData get icon {
    switch (this) {
      case FocusLockState.disconnected:
        return Icons.wifi_off_rounded;
      case FocusLockState.idle_unlocked:
        return Icons.lock_open_rounded;
      case FocusLockState.waiting_phone:
        return Icons.phone_android_rounded;
      case FocusLockState.grace_period:
        return Icons.timer_outlined;
      case FocusLockState.locked_focus:
        return Icons.lock_rounded;
      case FocusLockState.break_unlocked:
        return Icons.coffee_rounded;
      case FocusLockState.emergency_released:
        return Icons.warning_amber_rounded;
    }
  }

  bool get isLocked => this == FocusLockState.locked_focus;
}
