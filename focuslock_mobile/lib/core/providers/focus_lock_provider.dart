import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/focus_lock_state.dart';
import '../models/session_config.dart';
import '../models/session_status.dart';
import '../services/focus_lock_service.dart';
import '../services/mock_focus_lock_service.dart';

class FocusLockProvider extends ChangeNotifier {
  final IFocusLockService _service;
  StreamSubscription<FocusLockStatus>? _subscription;

  FocusLockStatus _status = FocusLockStatus.initial();
  int _selectedFocusMinutes = 25;
  int _selectedBreakMinutes = 5;
  final bool _isMockMode = true;

  FocusLockProvider({IFocusLockService? service})
      : _service = service ?? MockFocusLockService() {
    _status = _service.currentStatus;
    _subscription = _service.statusStream.listen((newStatus) {
      _status = newStatus;
      notifyListeners();
    });
  }

  // Getters
  FocusLockStatus get status => _status;
  FocusLockState get state => _status.state;
  int get remainingSeconds => _status.remainingSeconds;
  int get totalSeconds => _status.totalSeconds;
  double get progress => _status.progress;
  String get formattedRemaining => _status.formattedRemaining;
  bool get isLocked => _status.state.isLocked;
  bool get isMockMode => _isMockMode;

  int get selectedFocusMinutes => _selectedFocusMinutes;
  int get selectedBreakMinutes => _selectedBreakMinutes;

  void setFocusMinutes(int minutes) {
    if (_selectedFocusMinutes == minutes) return;
    _selectedFocusMinutes = minutes;
    notifyListeners();
  }

  void setBreakMinutes(int minutes) {
    if (_selectedBreakMinutes == minutes) return;
    _selectedBreakMinutes = minutes;
    notifyListeners();
  }

  Future<void> startSession() async {
    final config = PomodoroSessionConfig(
      focusMinutes: _selectedFocusMinutes,
      breakMinutes: _selectedBreakMinutes,
    );
    await _service.startSession(config);
  }

  Future<void> cancelSession() async {
    await _service.cancelSession();
  }

  Future<void> emergencyUnlock(String token) async {
    await _service.emergencyUnlock(token);
  }

  Future<void> simulatePhonePlaced() async {
    await _service.simulatePhonePlaced();
  }

  Future<void> simulatePhoneRemoved() async {
    await _service.simulatePhoneRemoved();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _service.dispose();
    super.dispose();
  }
}
