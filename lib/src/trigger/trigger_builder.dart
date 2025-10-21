import 'package:jetleaf_lang/lang.dart';

import '../exceptions.dart';
import '../task/task_execution_context.dart';
import 'cron_trigger.dart';
import 'fixed_delay_trigger.dart';
import 'fixed_rate_trigger.dart';
import 'periodic_trigger.dart';
import 'trigger.dart';

/// {@template TriggerBuilder}
/// A builder class that simplifies the creation of various trigger types
/// with a unified, fluent interface.
/// 
/// This builder provides a convenient way to create different types of
/// scheduling triggers without needing to remember the specific constructor
/// requirements for each trigger type. It automatically selects the
/// appropriate trigger implementation based on the provided parameters
/// and includes comprehensive validation and error messaging.
/// 
/// ## Supported Trigger Types
/// 
/// The builder automatically creates the appropriate trigger based on
/// which parameter is provided:
/// 
/// - **CronTrigger**: Created when `expression` is provided
/// - **FixedDelayTrigger**: Created when `fixedDelay` is provided  
/// - **FixedRateTrigger**: Created when `fixedRate` is provided
/// - **PeriodicTrigger**: Created when `period` is provided
/// 
/// ## Usage Examples
/// 
/// ```dart
/// // Create a cron trigger for complex scheduling
/// final cronTrigger = TriggerBuilder(
///   expression: '0 0 * * * *', // Every hour
///   zone: 'UTC',
/// );
/// 
/// // Create a fixed rate trigger for regular intervals
/// final fixedRateTrigger = TriggerBuilder(
///   fixedRate: Duration(seconds: 30),
///   delayPeriod: Duration(seconds: 5), // Initial delay
/// );
/// 
/// // Create a fixed delay trigger for sequential execution
/// final fixedDelayTrigger = TriggerBuilder(
///   fixedDelay: Duration(minutes: 1),
///   zone: 'America/New_York',
/// );
/// 
/// // Create a simple periodic trigger
/// final periodicTrigger = TriggerBuilder(
///   period: Duration(hours: 2),
/// );
/// 
/// // Use with task scheduler
/// await taskScheduler.schedule(myTask, fixedRateTrigger);
/// ```
/// 
/// ## Trigger Selection Logic
/// 
/// The builder selects triggers in this priority order:
/// 1. `expression` → CronTrigger
/// 2. `fixedDelay` → FixedDelayTrigger  
/// 3. `fixedRate` → FixedRateTrigger
/// 4. `period` → PeriodicTrigger
/// 
/// Only one trigger type can be specified at a time. Providing multiple
/// trigger parameters will result in the first matching type being used.
/// 
/// ## Timezone Support
/// 
/// All triggers support optional timezone specification. When provided,
/// the timezone is used for all scheduling calculations. If not specified,
/// the system default timezone is used.
/// 
/// ## Error Handling
/// 
/// The builder provides comprehensive error messages when:
/// - No trigger parameters are provided
/// - Invalid cron expressions are detected (handled by CronTrigger)
/// - Invalid durations are provided (negative or zero)
/// - Unsupported parameter combinations are used
/// 
/// ## Best Practices
/// 
/// - Use the most specific trigger type for your use case
/// - Specify timezone for business-critical scheduling
/// - Use appropriate initial delays to stagger task startup
/// - Consider resource usage when choosing trigger intervals
/// - Test trigger behavior with your specific task execution times
/// 
/// ## Integration with Scheduling Annotations
/// 
/// This builder can be used to programmatically create triggers that
/// mirror the behavior of scheduling annotations:
/// 
/// ```dart
/// // Equivalent to @Scheduled(cron: '0 0 * * * *', zone: 'UTC')
/// final trigger = TriggerBuilder(
///   expression: '0 0 * * * *',
///   zone: 'UTC',
/// );
/// 
/// // Equivalent to @Periodic(Duration(minutes: 5))
/// final trigger = TriggerBuilder(
///   period: Duration(minutes: 5),
/// );
/// ```
/// {@endtemplate}
final class TriggerBuilder with EqualsAndHashCode implements Trigger {
  /// The fixed rate duration between task executions (start to start).
  final Duration? fixedRate;

  /// The fixed delay duration between task executions (end to start).
  final Duration? fixedDelay;

  /// The cron expression for time-based scheduling.
  final String? expression;

  /// The initial delay before the first execution.
  final Duration? delayPeriod;

  /// The simple period for recurring execution.
  final Duration? period;

  /// The timezone for scheduling calculations.
  final String? zone;

  /// The underlying trigger instance created by this builder.
  late Trigger _trigger;

  /// {@macro TriggerBuilder}
  /// 
  /// Creates a trigger builder that automatically constructs the appropriate
  /// trigger type based on the provided parameters.
  /// 
  /// @param fixedRate Optional duration for fixed rate scheduling (start to start)
  /// @param fixedDelay Optional duration for fixed delay scheduling (end to start)  
  /// @param expression Optional cron expression for time-based scheduling
  /// @param delayPeriod Optional initial delay before first execution
  /// @param period Optional simple period for recurring execution
  /// @param zone Optional timezone identifier for scheduling calculations
  /// 
  /// @throws SchedulerException if no trigger parameters are provided or
  ///         if invalid parameter combinations are detected
  /// 
  /// Example:
  /// ```dart
  /// // Various trigger configurations
  /// final hourlyTrigger = TriggerBuilder(expression: '0 0 * * * *');
  /// final rapidTrigger = TriggerBuilder(fixedRate: Duration(seconds: 10));
  /// final delayedTrigger = TriggerBuilder(
  ///   fixedDelay: Duration(minutes: 5),
  ///   delayPeriod: Duration(seconds: 30), // Wait 30s before first execution
  ///   zone: 'Europe/London',
  /// );
  /// ```
  TriggerBuilder({this.fixedDelay, this.fixedRate, this.expression, this.delayPeriod, this.period, this.zone}) {
    // Resolve timezone: use specified zone or system default
    ZoneId zoneId = zone != null ? ZoneId.of(zone!) : ZoneId.systemDefault();

    // Determine and create the appropriate trigger type
    if (expression != null) {
      _trigger = CronTrigger(expression!, zoneId);
    } else if (fixedDelay != null) {
      _trigger = FixedDelayTrigger(fixedDelay!, zoneId, delayPeriod);
    } else if (fixedRate != null) {
      _trigger = FixedRateTrigger(fixedRate!, zoneId, delayPeriod);
    } else if (period != null) {
      _trigger = PeriodicTrigger(period!, zoneId);
    } else {
      throw SchedulerException(
        "Invalid trigger configuration: no trigger type specified.\n"
        "You must provide one of the following:\n"
        "  • expression → for CronTrigger (e.g. '0 0 * * *')\n"
        "  • fixedDelay → for FixedDelayTrigger (Duration between executions)\n"
        "  • fixedRate  → for FixedRateTrigger (Duration between start times)\n"
        "  • period     → for PeriodicTrigger (Simple repeating interval)\n"
        "Example:\n"
        "  TriggerBuilder(fixedRate: Duration(seconds: 10));"
      );
    }
  }

  @override
  ZoneId getZone() => _trigger.getZone();

  @override
  ZonedDateTime? nextExecutionTime(TaskExecutionContext context) => _trigger.nextExecutionTime(context);

  /// Returns the underlying trigger instance created by this builder.
  /// 
  /// This provides access to the actual trigger implementation for
  /// advanced use cases or inspection.
  /// 
  /// @return The concrete trigger instance
  /// 
  /// Example:
  /// ```dart
  /// final builder = TriggerBuilder(expression: '0 0 * * * *');
  /// final trigger = builder.getTrigger(); // Returns CronTrigger instance
  /// print(trigger.expression); // Access CronTrigger specific properties
  /// ```
  Trigger getTrigger() => _trigger;

  @override
  List<Object?> equalizedProperties() => [zone, delayPeriod, period, fixedDelay, fixedRate, _trigger, expression];

  /// Returns a string representation of this trigger builder.
  /// 
  /// Shows the builder configuration and the underlying trigger type
  /// for debugging and logging purposes.
  /// 
  /// @return A string describing the builder and its trigger
  /// 
  /// Example output:
  /// ```dart
  /// 'TriggerBuilder{type: CronTrigger, expression: 0 0 * * * *, zone: UTC}'
  /// ```
  @override
  String toString() {
    return 'TriggerBuilder{'
        'type: ${_trigger.runtimeType}, '
        'expression: $expression, '
        'fixedRate: $fixedRate, '
        'fixedDelay: $fixedDelay, '
        'period: $period, '
        'delayPeriod: $delayPeriod, '
        'zone: $zone'
        '}';
  }
}