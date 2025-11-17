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

import 'dart:async';

import '../trigger/trigger.dart';
import 'scheduled_task.dart';

/// A type alias representing a function signature for JetLeaf’s schedulable tasks.
///
/// This defines the standard function form accepted by JetLeaf’s scheduler.
/// It may perform synchronous or asynchronous work.
///
/// Example:
/// ```dart
/// Future<void> sampleTask() async {
///   await Future.delayed(Duration(seconds: 1));
///   print('Task completed.');
/// }
///
/// final scheduler = sampleTask;
/// await scheduler();
/// ```
typedef RunnableScheduler = FutureOr<void> Function();

/// {@template taskScheduler}
/// Main interface for scheduling and managing asynchronous tasks.
///
/// The TaskScheduler provides methods to schedule one-time and recurring tasks
/// with various timing strategies. It manages the lifecycle of all scheduled
/// tasks and provides shutdown capabilities.
///
/// **Example:**
/// ```dart
/// final scheduler = TaskScheduler();
/// 
/// // Schedule a one-time task
/// final oneTimeTask = await scheduler.schedule(
///   () => print('One-time task executed'),
///   ImmediateTrigger(),
/// );
/// 
/// // Schedule a fixed rate task
/// final fixedRateTask = await scheduler.scheduleAtFixedRate(
///   () => print('Fixed rate task'),
///   Duration(minutes: 5),
///   initialDelay: Duration(seconds: 10),
/// );
/// 
/// // Schedule a fixed delay task
/// final fixedDelayTask = await scheduler.scheduleWithFixedDelay(
///   () async {
///     await someAsyncOperation();
///     print('Fixed delay task completed');
///   },
///   Duration(seconds: 30),
/// );
/// 
/// // Later, shutdown the scheduler
/// await scheduler.shutdown();
/// ```
/// {@endtemplate}
abstract interface class TaskScheduler {
  /// {@macro scheduleTask}
  /// Schedules a task for execution according to the given [trigger].
  ///
  /// The [trigger] determines when and how often the task (if named [taskName]) should execute.
  /// Returns a [ScheduledTask] that can be used to cancel or query the task.
  ///
  /// **Example:**
  /// ```dart
  /// // Schedule with a cron trigger
  /// final cronTask = await scheduler.schedule(
  ///   () => updateCache(),
  ///   CronTrigger('0 0 * * *'), // Daily at midnight
  /// );
  /// 
  /// // Schedule with a one-time trigger
  /// final oneTimeTask = await scheduler.schedule(
  ///   () => sendNotification(),
  ///   OneTimeTrigger(DateTime.now().add(Duration(hours: 1))),
  /// );
  /// ```
  FutureOr<ScheduledTask> schedule(RunnableScheduler task, Trigger trigger, String taskName);

  /// {@macro scheduleAtFixedRate}
  /// Schedules a task for repeated execution at a fixed rate.
  ///
  /// The task (if named [taskName]) will be executed every [period], starting after [initialDelay].
  /// Execution starts from the beginning of each invocation, regardless of
  /// whether the previous execution has completed.
  ///
  /// **Example:**
  /// ```dart
  /// // Schedule a task to run every 5 minutes, starting after 10 seconds
  /// final task = await scheduler.scheduleAtFixedRate(
  ///   () => collectMetrics(),
  ///   Duration(minutes: 5),
  ///   initialDelay: Duration(seconds: 10),
  /// );
  /// 
  /// // Schedule with no initial delay
  /// final immediateTask = await scheduler.scheduleAtFixedRate(
  ///   () => print('Running immediately and every 30 seconds'),
  ///   Duration(seconds: 30),
  /// );
  /// ```
  FutureOr<ScheduledTask> scheduleAtFixedRate(RunnableScheduler task, Duration period, String taskName, [Duration? initialDelay]);

  /// {@macro scheduleWithFixedDelay}
  /// Schedules a task for repeated execution with a fixed delay.
  ///
  /// The task (if named [taskName]) will be executed with [delay] between the completion of one
  /// execution and the start of the next. This ensures that each execution
  /// completes before the next one begins.
  ///
  /// **Example:**
  /// ```dart
  /// // Schedule a task with 1-minute delay between completions
  /// final task = await scheduler.scheduleWithFixedDelay(
  ///   () async {
  ///     await processBatch();
  ///     print('Batch processing completed');
  ///   },
  ///   Duration(minutes: 1),
  ///   initialDelay: Duration(seconds: 5),
  /// );
  /// 
  /// // Database cleanup with guaranteed completion between runs
  /// final cleanupTask = await scheduler.scheduleWithFixedDelay(
  ///   () => performCleanup(),
  ///   Duration(hours: 24),
  /// );
  /// ```
  FutureOr<ScheduledTask> scheduleWithFixedDelay(RunnableScheduler task, Duration delay, String taskName, [Duration? initialDelay]);

  /// {@macro shutdownScheduler}
  /// Shuts down the scheduler, canceling all scheduled tasks.
  ///
  /// If [force] is true, tasks will be canceled immediately, potentially
  /// interrupting currently executing tasks. If [force] is false, the
  /// scheduler will wait for currently executing tasks to complete.
  ///
  /// **Example:**
  /// ```dart
  /// // Graceful shutdown - wait for current tasks to complete
  /// await scheduler.shutdown();
  /// print('Scheduler shutdown gracefully');
  /// 
  /// // Forceful shutdown - interrupt all tasks immediately
  /// await scheduler.shutdown(force: true);
  /// print('Scheduler shutdown forcefully');
  /// ```
  FutureOr<void> shutdown([bool force = false]);
}