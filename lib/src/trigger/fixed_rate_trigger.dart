import 'package:jetleaf_lang/lang.dart';

import '../task/task_execution_context.dart';
import 'trigger.dart';

/// {@template fixedRateTrigger}
/// Trigger for fixed-rate task execution.
///
/// Executes a task at a fixed rate, measured from the start of each execution.
/// If a task takes longer than the period, the next execution will start
/// immediately after the current one completes. This trigger maintains
/// a consistent execution schedule regardless of individual task duration.
///
/// **Example:**
/// ```dart
/// // Execute every 10 seconds in system timezone
/// final trigger = FixedRateTrigger(
///   period: Duration(seconds: 10),
/// );
/// 
/// // With initial delay and specific timezone
/// final trigger = FixedRateTrigger(
///   period: Duration(seconds: 10),
///   initialDelay: Duration(seconds: 5),
///   zone: ZoneId.of('Asia/Tokyo'),
/// );
/// 
/// // Use in scheduler for regular polling in UTC
/// final task = await scheduler.schedule(
///   () => checkForUpdates(),
///   FixedRateTrigger(
///     period: Duration(minutes: 5),
///     zone: ZoneId.UTC,
///   ),
/// );
/// 
/// // For heartbeat or monitoring tasks in specific timezone
/// final heartbeatTask = await scheduler.schedule(
///   () => sendHeartbeat(),
///   FixedRateTrigger(
///     period: Duration(seconds: 30),
///     initialDelay: Duration(seconds: 10),
///     zone: ZoneId.of('Europe/London'),
///   ),
/// );
///
/// // For business-hour operations in New York time
/// final businessTask = await scheduler.schedule(
///   () => syncWithNYSE(),
///   FixedRateTrigger(
///     period: Duration(minutes: 15),
///     zone: ZoneId.of('America/New_York'),
///   ),
/// );
/// ```
/// {@endtemplate}
class FixedRateTrigger with EqualsAndHashCode implements Trigger {
  /// The fixed period between successive executions.
  ///
  /// This duration represents the interval between the scheduled start times
  /// of consecutive executions. The actual time between executions may be
  /// longer if task execution exceeds the period duration.
  final Duration period;

  /// Optional initial delay before the first execution.
  ///
  /// If provided, the first execution will be delayed by this duration
  /// from the time the task is scheduled. If not provided, the first
  /// execution will occur immediately.
  final Duration? initialDelay;

  /// The timezone in which this trigger operates.
  ///
  /// All scheduling calculations are performed in this timezone.
  final ZoneId zone;

  /// {@macro fixedRateTrigger}
  const FixedRateTrigger(this.period, this.zone, [this.initialDelay]);

  @override
  ZonedDateTime? nextExecutionTime(TaskExecutionContext context) {
    final lastScheduled = context.getLastScheduledExecutionTime();
    
    if (lastScheduled == null) {
      // First execution - use current time in trigger's timezone
      final now = ZonedDateTime.now(zone);
      return initialDelay != null ? now.plus(initialDelay!) : now;
    }
    
    // Convert last scheduled to trigger's timezone for consistent calculation
    final lastScheduledInZone = lastScheduled.withZoneSameInstant(zone);
    
    // Next execution is period after last scheduled time
    return lastScheduledInZone.plus(period);
  }

  @override
  ZoneId getZone() => zone;

  @override
  List<Object?> equalizedProperties() => [zone, period, initialDelay];

  @override
  String toString() => 'FixedRateTrigger(period: $period, initialDelay: $initialDelay, zone: ${zone.id})';
}