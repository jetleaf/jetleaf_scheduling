import 'package:jetleaf_lang/lang.dart';

import '../task/task_execution_context.dart';
import 'trigger.dart';

/// {@template periodicTrigger}
/// Simple periodic trigger for regular task execution.
///
/// This is a convenience trigger that executes a task at regular intervals,
/// similar to [FixedRateTrigger] but with simpler semantics. It measures
/// intervals from the actual execution time rather than the scheduled time.
///
/// **Example:**
/// ```dart
/// // Execute every 30 seconds in system timezone
/// final trigger = PeriodicTrigger(Duration(seconds: 30));
/// 
/// // Use for simple periodic tasks in specific timezone
/// final task = await scheduler.schedule(
///   () => print('Periodic task executed'),
///   PeriodicTrigger(
///     Duration(minutes: 1),
///     zone: ZoneId.of('Europe/Paris'),
///   ),
/// );
/// 
/// // For frequent background tasks in UTC
/// final backgroundTask = await scheduler.schedule(
///   () => refreshCache(),
///   PeriodicTrigger(
///     Duration(seconds: 15),
///     zone: ZoneId.UTC,
///   ),
/// );
/// 
/// // For less frequent maintenance tasks in business timezone
/// final maintenanceTask = await scheduler.schedule(
///   () => performMaintenance(),
///   PeriodicTrigger(
///     Duration(hours: 24),
///     zone: ZoneId.of('America/Chicago'),
///   ),
/// );
///
/// // For international operations with specific timezone requirements
/// final globalTask = await scheduler.schedule(
///   () => updateGlobalMetrics(),
///   PeriodicTrigger(
///     Duration(hours: 6),
///     zone: ZoneId.of('Asia/Singapore'), // Singapore business day
///   ),
/// );
/// ```
/// {@endtemplate}
class PeriodicTrigger with EqualsAndHashCode implements Trigger {
  /// The period between successive executions.
  ///
  /// This duration represents the interval between the actual start times
  /// of consecutive executions. Unlike [FixedRateTrigger], this trigger
  /// measures from actual execution time, which can lead to drift over time
  /// if executions are delayed.
  final Duration period;

  /// The timezone in which this trigger operates.
  ///
  /// All scheduling calculations are performed in this timezone.
  final ZoneId zone;

  /// {@macro periodicTrigger}
  const PeriodicTrigger(this.period, this.zone);

  @override
  ZonedDateTime? nextExecutionTime(TaskExecutionContext context) {
    final lastExecution = context.getLastActualExecutionTime();
    
    if (lastExecution == null) {
      return ZonedDateTime.now(zone);
    }
    
    // Convert last execution to trigger's timezone for consistent calculation
    final lastExecutionInZone = lastExecution.withZoneSameInstant(zone);
    
    return lastExecutionInZone.plus(period);
  }

  @override
  ZoneId getZone() => zone;

  @override
  List<Object?> equalizedProperties() => [zone, period];

  @override
  String toString() => 'PeriodicTrigger(period: $period, zone: ${zone.id})';
}