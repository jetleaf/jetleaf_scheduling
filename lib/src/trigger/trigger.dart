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

/// {@template trigger}
/// Determines the next execution time for a scheduled task.
///
/// This is the core abstraction for scheduling logic. Implementations
/// define when a task should be executed next based on the execution context.
/// Triggers can implement various scheduling strategies including time-based,
/// event-based, or conditional execution patterns.
///
/// Common implementations include:
/// - [CronTrigger] - Cron expression-based scheduling
/// - [FixedRateTrigger] - Fixed rate execution
/// - [FixedDelayTrigger] - Fixed delay between executions
/// - [PeriodicTrigger] - Simple periodic execution
///
/// **Example:**
/// ```dart
/// class CustomTrigger implements Trigger {
///   @override
///   ZonedDateTime? nextExecutionTime(TaskExecutionContext context) {
///     // Custom logic to determine next execution
///     final lastRun = context.getLastActualExecutionTime();
///     if (lastRun == null) {
///       return ZonedDateTime.now(); // First execution in system timezone
///     }
///     return lastRun.plusHours(1); // Every hour
///   }
///
///   @override
///   ZoneId getZone() => ZoneId.of('America/New_York');
/// }
/// 
/// // Using triggers with the scheduler
/// final cronTrigger = CronTrigger('0 0 * * * *', ZoneId.of('Europe/Paris'));
/// final fixedRateTrigger = FixedRateTrigger(
///   period: Duration(minutes: 30),
///   zone: ZoneId.of('Asia/Tokyo'),
/// );
/// final fixedDelayTrigger = FixedDelayTrigger(
///   delay: Duration(seconds: 60),
///   zone: ZoneId.UTC,
/// );
/// 
/// // Schedule tasks with different triggers
/// await scheduler.schedule(() => hourlyTask(), cronTrigger);
/// await scheduler.schedule(() => halfHourTask(), fixedRateTrigger);
/// await scheduler.schedule(() => delayedTask(), fixedDelayTrigger);
/// ```
/// {@endtemplate}
abstract interface class Trigger {
  /// {@macro nextExecutionTime}
  /// Returns the next execution time based on the given [context].
  ///
  /// The method uses the execution context to determine the next appropriate
  /// execution time based on previous executions, completion status, and
  /// any exceptions that may have occurred.
  ///
  /// **Example:**
  /// ```dart
  /// final trigger = CronTrigger('0 0 * * * *', ZoneId.of('Europe/Paris'));
  /// final nextRun = trigger.nextExecutionTime(context);
  /// if (nextRun != null) {
  ///   print('Next execution scheduled for: $nextRun'); // In Paris timezone
  /// } else {
  ///   print('No future executions scheduled');
  /// }
  /// 
  /// // Custom trigger that skips execution if last run failed
  /// class SmartTrigger implements Trigger {
  ///   @override
  ///   ZonedDateTime? nextExecutionTime(TaskExecutionContext context) {
  ///     if (context.getLastException() != null) {
  ///       // Skip next execution if last run failed
  ///       return null;
  ///     }
  ///     return ZonedDateTime.now(getZone()).plusMinutes(10);
  ///   }
  ///
  ///   @override
  ///   ZoneId getZone() => ZoneId.systemDefault();
  /// }
  /// ```
  /// Returns [ZonedDateTime] representing the next execution time, or [null] 
  /// if the task should not be scheduled again.
  ZonedDateTime? nextExecutionTime(TaskExecutionContext context);

  /// Returns the timezone in which this trigger operates.
  ///
  /// All date-time calculations for this trigger are performed in the
  /// specified timezone, ensuring consistent scheduling behavior regardless
  /// of the system's default timezone.
  ///
  /// **Example:**
  /// ```dart
  /// final trigger = CronTrigger('0 0 9 * * 1', ZoneId.of('America/New_York'));
  /// print(trigger.getZone().id); // 'America/New_York'
  /// 
  /// // Create a trigger for business hours in Tokyo
  /// final tokyoTrigger = FixedRateTrigger(
  ///   period: Duration(hours: 1),
  ///   zone: ZoneId.of('Asia/Tokyo'),
  /// );
  /// print(tokyoTrigger.getZone().id); // 'Asia/Tokyo'
  /// 
  /// // UTC trigger for global operations
  /// final utcTrigger = FixedDelayTrigger(
  ///   delay: Duration(minutes: 30),
  ///   zone: ZoneId.UTC,
  /// );
  /// print(utcTrigger.getZone().id); // 'UTC'
  /// ```
  ZoneId getZone();
}