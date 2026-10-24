import 'package:test/test.dart';
import 'package:core/core.dart';

void main() {
  group('RetryPolicy Tests (FR-SYNC-03, N-04)', () {
    test('Calculates exponential backoff from 2 seconds to 5 minutes cap', () {
      // Attempt 0: 2s
      expect(RetryPolicy.calculateNextBackoff(0), equals(const Duration(seconds: 2)));

      // Attempt 1: 4s
      expect(RetryPolicy.calculateNextBackoff(1), equals(const Duration(seconds: 4)));

      // Attempt 2: 8s
      expect(RetryPolicy.calculateNextBackoff(2), equals(const Duration(seconds: 8)));

      // Attempt 3: 16s
      expect(RetryPolicy.calculateNextBackoff(3), equals(const Duration(seconds: 16)));

      // Attempt 4: 32s
      expect(RetryPolicy.calculateNextBackoff(4), equals(const Duration(seconds: 32)));

      // Attempt 5: 64s
      expect(RetryPolicy.calculateNextBackoff(5), equals(const Duration(seconds: 64)));

      // Attempt 6: 128s
      expect(RetryPolicy.calculateNextBackoff(6), equals(const Duration(seconds: 128)));

      // Attempt 7: 256s
      expect(RetryPolicy.calculateNextBackoff(7), equals(const Duration(seconds: 256)));

      // Attempt 8+: Capped at 300s (5 minutes)
      expect(RetryPolicy.calculateNextBackoff(8), equals(const Duration(minutes: 5)));
      expect(RetryPolicy.calculateNextBackoff(20), equals(const Duration(minutes: 5)));
    });

    test('nextAttemptDateTime generates future timestamp', () {
      final now = DateTime.now();
      final nextAttempt = RetryPolicy.nextAttemptDateTime(1);

      expect(nextAttempt.isAfter(now), isTrue);
      final diff = nextAttempt.difference(now).inSeconds;
      expect(diff, inInclusiveRange(3, 5));
    });
  });
}
