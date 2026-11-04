import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/focus_lock_state.dart';
import '../models/session_config.dart';
import '../models/session_status.dart';
import 'focus_lock_service.dart';

class MockFocusLockService implements FocusLockService {
  final _controller = StreamController<FocusLockStatus>.broadcast();
  final ValueNotifier<FocusLockStatus> _notifier =
      ValueNotifier<FocusLockStatus>(FocusLockStatus.initial());

  FocusLockStatus _current = FocusLockStatus.initial();
  PomodoroSessionConfig _lastConfig = const PomodoroSessionConfig(focusMinutes: 25, breakMinutes: 5);

  Timer? _fsmTimer;
  Timer? _autoDetectionTimer;

  @override
  Stream<FocusLockStatus> get statusStream => _controller.stream;

  @override
  ValueListenable<FocusLockStatus> get statusNotifier => _notifier;

  @override
  FocusLockStatus get currentStatus => _current;

  void _emit(FocusLockStatus newStatus) {
    _current = newStatus;
    _notifier.value = _current;
    if (!_controller.isClosed) {
      _controller.add(_current);
    }
  }

  @override
  Future<void> connect({String host = 'focuslock.local', int port = 8000}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _emit(_current.copyWith(isConnected: true, state: FocusLockState.idleUnlocked));
  }

  @override
  Future<void> disconnect() async {
    _fsmTimer?.cancel();
    _autoDetectionTimer?.cancel();
    _emit(FocusLockStatus.disconnected());
  }

  @override
  Future<void> startSession(PomodoroSessionConfig config) async {
    _fsmTimer?.cancel();
    _autoDetectionTimer?.cancel();
    _lastConfig = config;

    _emit(_current.copyWith(
      state: FocusLockState.waitingPhone,
      phoneDetected: false,
      remainingSeconds: config.focusTotalSeconds,
      totalSeconds: config.focusTotalSeconds,
      sessionId: 'mock-${DateTime.now().millisecondsSinceEpoch}',
    ));

    // Simulación: auto-detecta celular tras 4 segundos si el usuario no pulsa el botón manual
    _autoDetectionTimer = Timer(const Duration(seconds: 4), () {
      if (_current.state == FocusLockState.waitingPhone) {
        simulatePhonePlaced();
      }
    });
  }

  @override
  Future<void> simulatePhonePlaced() async {
    if (_current.state != FocusLockState.waitingPhone) return;
    _autoDetectionTimer?.cancel();

    // Entra en ventana de gracia de 5 segundos
    int graceSeconds = 5;
    _emit(_current.copyWith(
      state: FocusLockState.gracePeriod,
      phoneDetected: true,
      remainingSeconds: graceSeconds,
      totalSeconds: graceSeconds,
    ));

    _fsmTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      graceSeconds--;
      if (graceSeconds > 0) {
        _emit(_current.copyWith(remainingSeconds: graceSeconds));
      } else {
        timer.cancel();
        _startLockedFocus();
      }
    });
  }

  void _startLockedFocus() {
    int remaining = _lastConfig.focusTotalSeconds;
    _emit(_current.copyWith(
      state: FocusLockState.lockedFocus,
      phoneDetected: true,
      remainingSeconds: remaining,
      totalSeconds: remaining,
    ));

    _fsmTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remaining > 0) {
        remaining--;
        _emit(_current.copyWith(remainingSeconds: remaining));
      } else {
        timer.cancel();
        _startBreakPeriod();
      }
    });
  }

  void _startBreakPeriod() {
    int breakRemaining = _lastConfig.breakTotalSeconds;
    _emit(_current.copyWith(
      state: FocusLockState.breakUnlocked,
      phoneDetected: true,
      remainingSeconds: breakRemaining,
      totalSeconds: breakRemaining,
    ));

    _fsmTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (breakRemaining > 0) {
        breakRemaining--;
        _emit(_current.copyWith(remainingSeconds: breakRemaining));
      } else {
        timer.cancel();
        _emit(_current.copyWith(
          state: FocusLockState.idleUnlocked,
          remainingSeconds: 0,
          totalSeconds: 0,
        ));
      }
    });
  }

  @override
  Future<void> simulatePhoneRemoved() async {
    _emit(_current.copyWith(phoneDetected: false));
  }

  @override
  Future<void> cancelSession() async {
    _fsmTimer?.cancel();
    _autoDetectionTimer?.cancel();
    _emit(_current.copyWith(
      state: FocusLockState.idleUnlocked,
      remainingSeconds: 0,
      totalSeconds: 0,
    ));
  }

  @override
  Future<void> emergencyUnlock(String token) async {
    _fsmTimer?.cancel();
    _autoDetectionTimer?.cancel();
    _emit(_current.copyWith(
      state: FocusLockState.emergencyReleased,
      remainingSeconds: 0,
    ));
  }

  @override
  void dispose() {
    _fsmTimer?.cancel();
    _autoDetectionTimer?.cancel();
    _notifier.dispose();
    _controller.close();
  }
}

