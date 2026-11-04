import 'package:flutter/foundation.dart';
import '../models/session_config.dart';
import '../models/session_status.dart';

/// Interfaz abstracta que desacopla el origen de datos de la UI Flutter.
/// Implementada por [MockFocusLockService] y [HttpFocusLockService].
abstract class FocusLockService {
  /// Stream que emite el estado segundo a segundo o ante eventos de la FSM
  Stream<FocusLockStatus> get statusStream;

  /// ValueNotifier reactivo para enlazar directamente con ValueListenableBuilder / UI
  ValueListenable<FocusLockStatus> get statusNotifier;

  /// Estado actual instantáneo
  FocusLockStatus get currentStatus;

  /// Conecta al hardware o inicializa el servicio
  Future<void> connect({String host = 'focuslock.local', int port = 8000});

  /// Desconecta la sesión de red
  Future<void> disconnect();

  /// Inicia el flujo Pomodoro (espera de celular)
  Future<void> startSession(PomodoroSessionConfig config);

  /// Cancela la sesión activa (si está permitido)
  Future<void> cancelSession();

  /// Apertura manual de emergencia
  Future<void> emergencyUnlock(String token);

  /// Simula la colocación física del celular (útil en Mock)
  Future<void> simulatePhonePlaced();

  /// Simula el retiro del celular
  Future<void> simulatePhoneRemoved();

  /// Libera recursos
  void dispose();
}

/// Alias para compatibilidad
typedef IFocusLockService = FocusLockService;


