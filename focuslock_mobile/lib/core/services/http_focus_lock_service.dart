import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/focus_lock_state.dart';
import '../models/session_config.dart';
import '../models/session_status.dart';
import 'focus_lock_service.dart';

/// Implementación HTTP REST para comunicarse con el daemon FastAPI en la Raspberry Pi Zero W
/// (Por defecto mDNS: http://focuslock.local:8000)
class HttpFocusLockService implements FocusLockService {
  final _controller = StreamController<FocusLockStatus>.broadcast();
  final ValueNotifier<FocusLockStatus> _notifier =
      ValueNotifier<FocusLockStatus>(FocusLockStatus.disconnected());

  FocusLockStatus _current = FocusLockStatus.disconnected();
  String _baseUrl = 'http://focuslock.local:8000';
  Timer? _pollingTimer;
  final http.Client _client;

  HttpFocusLockService({http.Client? client}) : _client = client ?? http.Client();

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
    _baseUrl = 'http://$host:$port';
    _pollingTimer?.cancel();

    await _fetchStatus();
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _fetchStatus();
    });
  }

  Future<void> _fetchStatus() async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/api/status'))
          .timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final payload = decoded.containsKey('data')
            ? decoded['data'] as Map<String, dynamic>
            : decoded;

        final rawState = payload['state'] as String? ?? 'IDLE';
        final phoneDetected = payload['phone_detected'] as bool? ?? false;
        final remainingSeconds = payload['remaining_seconds'] as int? ?? 0;
        final totalSeconds = payload['total_seconds'] as int? ?? remainingSeconds;
        final sessionId = payload['session_id'] as String?;

        _emit(FocusLockStatus(
          state: FocusLockState.fromBackendString(rawState),
          phoneDetected: phoneDetected,
          remainingSeconds: remainingSeconds,
          totalSeconds: totalSeconds,
          sessionId: sessionId,
          isConnected: true,
        ));
      } else {
        _emit(_current.copyWith(
          isConnected: false,
          errorMessage: 'HTTP ${response.statusCode}',
        ));
      }
    } catch (e) {
      _emit(FocusLockStatus.disconnected().copyWith(
        errorMessage: 'Sin conexión a $_baseUrl',
      ));
    }
  }

  @override
  Future<void> disconnect() async {
    _pollingTimer?.cancel();
    _emit(FocusLockStatus.disconnected());
  }

  @override
  Future<void> startSession(PomodoroSessionConfig config) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/api/session/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(config.toJson()),
      );
      if (response.statusCode == 200) {
        await _fetchStatus();
      }
    } catch (e) {
      _emit(_current.copyWith(errorMessage: 'Error al iniciar sesión: $e'));
    }
  }

  @override
  Future<void> cancelSession() async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/api/session/cancel'),
      );
      if (response.statusCode == 200) {
        await _fetchStatus();
      }
    } catch (e) {
      _emit(_current.copyWith(errorMessage: 'Error al cancelar sesión: $e'));
    }
  }

  @override
  Future<void> emergencyUnlock(String token) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/api/hardware/unlock'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'auth_token': token}),
      );
      if (response.statusCode == 200) {
        await _fetchStatus();
      }
    } catch (e) {
      _emit(_current.copyWith(errorMessage: 'Error en apertura de emergencia: $e'));
    }
  }

  @override
  Future<void> simulatePhonePlaced() async {
    try {
      await _client.post(
        Uri.parse('$_baseUrl/api/hardware/mock_phone'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'detected': true}),
      );
      await _fetchStatus();
    } catch (_) {}
  }

  @override
  Future<void> simulatePhoneRemoved() async {
    try {
      await _client.post(
        Uri.parse('$_baseUrl/api/hardware/mock_phone'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'detected': false}),
      );
      await _fetchStatus();
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _client.close();
    _notifier.dispose();
    _controller.close();
  }
}

