// ---------------------------------------------------------------------------
// 🍃 JetLeaf Framework - https://jetleaf.hapnium.com
//
// Copyright © 2025 Hapnium & JetLeaf Contributors. All rights reserved.
//
// This source file is part of the JetLeaf Framework and is protected
// under copyright law. You may not copy, modify, or distribute this file
// except in compliance with the JetLeaf license.
//
// For licensing terms, see the LICENSE file in the root of this project.
// ---------------------------------------------------------------------------
// 
// 🔧 Powered by Hapnium — the Dart backend engine 🍃

import 'package:jetleaf_lang/lang.dart';

import '../task/task_execution_context.dart';
import 'trigger.dart';

/// {@template fixedDelayTrigger}
/// Trigger for fixed-delay task execution.
///
/// Executes a task with a fixed delay between the completion of one execution
/// and the start of the next. This ensures a minimum gap between executions,
/// making it ideal for tasks that should not overlap and where each execution
/// must complete before the next one begins.
///
/// **Example:**
/// ```dart
/// // Execute with 10 second delay after completion in system timezone
/// final trigger = FixedDelayTrigger(
///   delay: Duration(seconds: 10),
/// );
///
/// // With initial delay and specific timezone
/// final trigger = FixedDelayTrigger(
///   delay: Duration(seconds: 10),
///   initialDelay: Duration(seconds: 5),
///   zone: ZoneId.of('Europe/London'),
/// );
///
/// // Use in scheduler with UTC timezone
/// final task = await scheduler.schedule(
///   () async {
///     await processData(); // This must complete before next execution
///     print('Processing completed');
///   },
///   FixedDelayTrigger(
///     delay: Duration(minutes: 1),
///     zone: ZoneId.UTC,
///   ),
/// );
///
/// // For tasks that require specific business hours
/// final businessTask = await scheduler.schedule(
///   () => processOrders(),
///   FixedDelayTrigger(
///     delay: Duration(hours: 4),
///     zone: ZoneId.of('America/New_York'), // NY business hours
///   ),
/// );
/// ```
/// {@endtemplate}
class FixedDelayTrigger with EqualsAndHashCode implements Trigger {
  /// The delay between the completion of one execution and the start of the next.
  ///
  /// This duration represents the minimum time that must pass after a task
  /// completes before it can be executed again.
  final Duration delay;

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

  /// {@macro fixedDelayTrigger}
  const FixedDelayTrigger(this.delay, this.zone, [this.initialDelay]);

  @override
  ZonedDateTime? nextExecutionTime(TaskExecutionContext context) {
    final lastCompletion = context.getLastCompletionTime();

    if (lastCompletion == null) {
      // First execution - use current time in trigger's timezone
      final now = ZonedDateTime.now(zone);
      return initialDelay != null ? now.plus(initialDelay!) : now;
    }

    // Convert last completion to trigger's timezone for consistent calculation
    final lastCompletionInZone = lastCompletion.withZoneSameInstant(zone);
    
    // Next execution is delay after last completion
    return lastCompletionInZone.plus(delay);
  }

  @override
  ZoneId getZone() => zone;

  @override
  List<Object?> equalizedProperties() => [zone, delay, initialDelay];

  @override
  String toString() => 'FixedDelayTrigger(delay: $delay, initialDelay: $initialDelay, zone: ${zone.id})';
}