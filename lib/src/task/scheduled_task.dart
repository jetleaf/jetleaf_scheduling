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

import 'package:jetleaf_lang/lang.dart';

import '../trigger/trigger.dart';
import 'task_execution_context.dart';

/// {@template scheduledTask}
/// Represents a scheduled task that can be queried and canceled.
///
/// This interface provides control over a scheduled task's lifecycle,
/// allowing you to check its status and cancel it if needed.
///
/// Example:
/// ```dart
/// final task = await scheduler.schedule(
///   () => print('Task'),
///   trigger,
/// );
///
/// // Check if canceled
/// if (!task.getIsCanceled()) {
///   // Cancel the task
///   await task.cancel();
/// }
/// ```
/// {@endtemplate}
abstract interface class ScheduledTask {
  /// Returns true if this task has been canceled.
  ///
  /// A canceled task will not execute again, but may complete
  /// its current execution if already running.
  ///
  /// **Example:**
  /// ```dart
  /// if (task.getIsCanceled()) {
  ///   print('Task has been canceled');
  /// } else {
  ///   print('Task is still active');
  /// }
  /// ```
  bool getIsCanceled();

  /// Returns the name of this task.
  ///
  /// The name should be consistent across application restarts and
  /// suitable for use in logging, monitoring, and management interfaces.
  /// 
  /// This should be a unique, descriptive name for the scheduled task.
  ///
  /// **Example:**
  /// ```dart
  /// print(task.getName());
  /// ```
  String getName();

  /// Returns true if this task is currently executing.
  ///
  /// This method can be used to check if a task is actively running
  /// at the moment of the call.
  ///
  /// **Example:**
  /// ```dart
  /// if (task.getIsExecuting()) {
  ///   print('Task is currently running');
  /// } else {
  ///   print('Task is idle');
  /// }
  /// ```
  bool getIsExecuting();

  /// Returns the number of times this task has been executed.
  ///
  /// The count includes all successful and failed executions,
  /// but does not include skipped executions due to cancellation.
  ///
  /// **Example:**
  /// ```dart
  /// final count = task.getExecutionCount();
  /// print('Task has executed $count times');
  /// ```
  int getExecutionCount();

  /// Returns the last execution time, or null if not yet executed.
  ///
  /// This provides the timestamp of the most recent execution,
  /// regardless of whether it succeeded or failed.
  ///
  /// **Example:**
  /// ```dart
  /// final lastRun = task.getLastExecutionTime();
  /// if (lastRun != null) {
  ///   print('Last executed: $lastRun');
  /// } else {
  ///   print('Never executed');
  /// }
  /// ```
  ZonedDateTime? getLastExecutionTime();

  /// Returns the next scheduled execution time, or null if canceled.
  ///
  /// For one-time tasks, this may return null after execution.
  /// For recurring tasks, this returns the next scheduled run time.
  ///
  /// **Example:**
  /// ```dart
  /// final nextRun = task.getNextExecutionTime();
  /// if (nextRun != null) {
  ///   print('Next execution: $nextRun');
  /// } else {
  ///   print('No future executions scheduled');
  /// }
  /// ```
  ZonedDateTime? getNextExecutionTime();

  /// Returns the timezone in which this task is scheduled.
  ///
  /// This is derived from the trigger's timezone and ensures all
  /// scheduling calculations are performed in the correct timezone.
  ///
  /// **Example:**
  /// ```dart
  /// final task = await scheduler.schedule(
  ///   () => print('Task'),
  ///   CronTrigger('0 0 9 * * *', ZoneId.of('Europe/Paris')),
  /// );
  /// 
  /// print('Task timezone: ${task.getZone().id}'); // 'Europe/Paris'
  /// ```
  ZoneId getZone();

  /// Returns the trigger associated with this task.
  ///
  /// This provides access to the scheduling logic and configuration
  /// used by this task.
  ///
  /// **Example:**
  /// ```dart
  /// final trigger = task.getTrigger();
  /// if (trigger is CronTrigger) {
  ///   print('Cron expression: ${trigger.getExpression()}');
  /// }
  /// print('Trigger zone: ${trigger.getZone().id}');
  /// ```
  Trigger getTrigger();

  /// Returns the execution context for this task.
  ///
  /// The execution context provides detailed information about the
  /// task's execution history, including timing, exceptions, and metrics.
  ///
  /// **Example:**
  /// ```dart
  /// final context = task.getExecutionContext();
  /// print('Total executions: ${context.getExecutionCount()}');
  /// print('Last exception: ${context.getLastException()}');
  /// print('Last completion: ${context.getLastCompletionTime()}');
  /// ```
  TaskExecutionContext getExecutionContext();

  /// Starts the task execution.
  ///
  /// This method should be called to begin the task execution process.
  /// It is typically used in conjunction with a trigger to schedule
  /// the task's execution at regular intervals.
  ///
  /// **Example:**
  /// ```dart
  /// final task = await scheduler.schedule(
  ///   () => print('Task'),
  ///   trigger,
  /// );
  /// 
  /// // Start the task
  /// await task.start();
  /// ```
  FutureOr<void> start();

  /// {@macro cancelTask}
  /// Cancels this scheduled task.
  ///
  /// If [mayInterruptIfRunning] is true and the task is currently executing,
  /// an attempt will be made to interrupt it.
  ///
  /// Returns [true] if the task was successfully canceled, [false] otherwise.
  /// A task that has already completed or was previously canceled will return [false].
  ///
  /// **Example:**
  /// ```dart
  /// // Cancel without interrupting if running
  /// final canceled = await task.cancel();
  /// if (canceled) {
  ///   print('Task canceled successfully');
  /// }
  ///
  /// // Cancel and attempt to interrupt if running
  /// final forcedCancel = await task.cancel(true);
  /// if (forcedCancel) {
  ///   print('Task canceled, may have been interrupted');
  /// }
  /// ```
  FutureOr<bool> cancel([bool mayInterruptIfRunning = false]);
}