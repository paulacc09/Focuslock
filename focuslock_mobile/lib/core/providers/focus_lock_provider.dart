import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/focus_lock_state.dart';
import '../models/session_config.dart';
import '../models/session_status.dart';
import '../services/focus_lock_service.dart';
import '../services/mock_focus_lock_service.dart';
import '../services/http_focus_lock_service.dart';

class FocusLockProvider extends ChangeNotifier {
  IFocusLockService _service;
  StreamSubscription<FocusLockStatus>? _subscription;

  FocusLockStatus _status = FocusLockStatus.initial();
  int _selectedFocusMinutes = 25;
  int _selectedBreakMinutes = 5;
  int? _selectedFocusSeconds;
  int? _selectedBreakSeconds;
  bool _isMockMode = false;
  bool _buzzerEnabled = true;
  bool _lockyReactionsEnabled = true;
  String _host = 'https://focuslock-server-q3bw.onrender.com';
  int _port = 443;
  String? _authToken;

  FocusLockProvider({IFocusLockService? service})
      : _service = service ?? (HttpFocusLockService()..connect(host: 'https://focuslock-server-q3bw.onrender.com', port: 443)) {
    _initServiceSubscription();
  }

  void _initServiceSubscription() {
    _status = _service.currentStatus;
    _subscription?.cancel();
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
  bool get buzzerEnabled => _buzzerEnabled;
  bool get lockyReactionsEnabled => _lockyReactionsEnabled;

  int get selectedFocusMinutes => _selectedFocusMinutes;
  int get selectedBreakMinutes => _selectedBreakMinutes;
  int? get selectedFocusSeconds => _selectedFocusSeconds;
  bool get isDemoMode => _selectedFocusSeconds != null;

  String get selectedDurationLabel => _selectedFocusSeconds != null
      ? '$_selectedFocusSeconds seg (Demo)'
      : '$_selectedFocusMinutes min';

  String get host => _host;
  int get port => _port;
  String get baseUrl => HttpFocusLockService.buildBaseUrl(_host, _port);

  void setAuthToken(String? token) {
    _authToken = token;
    if (_service is HttpFocusLockService) {
      (_service as HttpFocusLockService).authToken = token;
    }
  }

  void setFocusMinutes(int minutes) {
    _selectedFocusSeconds = null;
    _selectedBreakSeconds = null;
    if (_selectedFocusMinutes == minutes) return;
    _selectedFocusMinutes = minutes;
    notifyListeners();
  }

  void setFocusSeconds(int seconds, {int breakSeconds = 10}) {
    _selectedFocusSeconds = seconds;
    _selectedBreakSeconds = breakSeconds;
    notifyListeners();
  }

  void setBreakMinutes(int minutes) {
    if (_selectedBreakMinutes == minutes) return;
    _selectedBreakMinutes = minutes;
    notifyListeners();
  }

  void toggleMockMode(bool value) {
    if (_isMockMode == value) return;
    _isMockMode = value;
    _service.dispose();

    if (_isMockMode) {
      _service = MockFocusLockService();
    } else {
      final httpServ = HttpFocusLockService(authToken: _authToken);
      httpServ.connect(host: _host, port: _port);
      _service = httpServ;
    }
    _initServiceSubscription();
    notifyListeners();
  }

  Future<void> updateNetworkEndpoint(String host, int port) async {
    _host = host.trim().isEmpty ? 'https://focuslock-server-q3bw.onrender.com' : host.trim();
    _port = port;

    if (!_isMockMode) {
      _service.dispose();
      final httpServ = HttpFocusLockService(authToken: _authToken);
      await httpServ.connect(host: _host, port: _port);
      _service = httpServ;
      _initServiceSubscription();
    }
    notifyListeners();
  }

  void setBuzzerEnabled(bool value) {
    if (_buzzerEnabled == value) return;
    _buzzerEnabled = value;
    notifyListeners();
  }

  void setLockyReactionsEnabled(bool value) {
    if (_lockyReactionsEnabled == value) return;
    _lockyReactionsEnabled = value;
    notifyListeners();
  }

  Future<void> startSession() async {
    final config = PomodoroSessionConfig(
      focusMinutes: _selectedFocusMinutes,
      breakMinutes: _selectedBreakMinutes,
      focusSeconds: _selectedFocusSeconds,
      breakSeconds: _selectedBreakSeconds,
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
