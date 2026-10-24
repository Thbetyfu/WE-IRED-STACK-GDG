import 'dart:math';

/// Implements FR-SYNC-03 and N-04: Exponential backoff from 2 seconds to 5 minutes.
class RetryPolicy {
  static const Duration minBackoff = Duration(seconds: 2);
  static const Duration maxBackoff = Duration(minutes: 5);

  /// Calculates next backoff duration based on the number of previous attempts.
  /// attempts = 0 -> 2s
  /// attempts = 1 -> 4s
  /// attempts = 2 -> 8s
  /// ...
  /// capped at 5 minutes (300s).
  static Duration calculateNextBackoff(int attempts) {
    if (attempts <= 0) return minBackoff;

    final seconds = minBackoff.inSeconds * pow(2, attempts);
    final clampedSeconds = min(maxBackoff.inSeconds, seconds.toInt());

    return Duration(seconds: clampedSeconds);
  }

  /// Returns the next DateTime when an outbox item should be retried.
  static DateTime nextAttemptDateTime(int attempts) {
    return DateTime.now().add(calculateNextBackoff(attempts));
  }
}
