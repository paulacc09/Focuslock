import 'focus_lock_state.dart';

class FocusLockStatus {
  final FocusLockState state;
  final bool phoneDetected;
  final int remainingSeconds;
  final int totalSeconds;
  final String? sessionId;
  final bool isConnected;
  final String? errorMessage;

  const FocusLockStatus({
    required this.state,
    required this.phoneDetected,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.sessionId,
    this.isConnected = true,
    this.errorMessage,
  });

  factory FocusLockStatus.initial() {
    return const FocusLockStatus(
      state: FocusLockState.idleUnlocked,
      phoneDetected: false,
      remainingSeconds: 0,
      totalSeconds: 0,
      isConnected: true,
    );
  }

  factory FocusLockStatus.disconnected() {
    return const FocusLockStatus(
      state: FocusLockState.disconnected,
      phoneDetected: false,
      remainingSeconds: 0,
      totalSeconds: 0,
      isConnected: false,
    );
  }

  double get progress {
    if (totalSeconds <= 0) return 0.0;
    final elapsed = totalSeconds - remainingSeconds;
    return (elapsed / totalSeconds).clamp(0.0, 1.0);
  }

  String get formattedRemaining {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  FocusLockStatus copyWith({
    FocusLockState? state,
    bool? phoneDetected,
    int? remainingSeconds,
    int? totalSeconds,
    String? sessionId,
    bool? isConnected,
    String? errorMessage,
  }) {
    return FocusLockStatus(
      state: state ?? this.state,
      phoneDetected: phoneDetected ?? this.phoneDetected,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      sessionId: sessionId ?? this.sessionId,
      isConnected: isConnected ?? this.isConnected,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

