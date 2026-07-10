enum PingStatus { idle, pinging, success, failed }

class PingState {
  final PingStatus status;
  final int? latencyMs;
  final DateTime? lastPingTime;
  final int successCount;
  final int failCount;
  final bool isInFlight;
  final bool isActive;

  const PingState({
    this.status = PingStatus.idle,
    this.latencyMs,
    this.lastPingTime,
    this.successCount = 0,
    this.failCount = 0,
    this.isInFlight = false,
    this.isActive = false,
  });

  PingState copyWith({
    PingStatus? status,
    int? latencyMs,
    DateTime? lastPingTime,
    int? successCount,
    int? failCount,
    bool? isInFlight,
    bool? isActive,
    bool clearLatency = false,
  }) {
    return PingState(
      status: status ?? this.status,
      latencyMs: clearLatency ? null : (latencyMs ?? this.latencyMs),
      lastPingTime: lastPingTime ?? this.lastPingTime,
      successCount: successCount ?? this.successCount,
      failCount: failCount ?? this.failCount,
      isInFlight: isInFlight ?? this.isInFlight,
      isActive: isActive ?? this.isActive,
    );
  }
}
