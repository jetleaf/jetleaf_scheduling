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

/// {@template schedulerException}
/// Exception thrown when scheduling operations fail.
///
/// This is the base exception class for all scheduling-related errors
/// in the scheduling system. It extends [RuntimeException] to provide
/// additional context about scheduling failures.
///
/// **Example:**
/// ```dart
/// try {
///   scheduler.scheduleTask(myTask);
/// } on SchedulingException catch (e) {
///   logger.error('Scheduling failed: ${e.message}');
///   rethrow;
/// }
/// ```
/// {@endtemplate}
class SchedulerException extends RuntimeException {
  /// {@macro schedulerException}
  SchedulerException(super.message, {super.cause});
}

/// {@template invalidCronExpressionException}
/// Exception thrown when a cron expression is invalid or malformed.
///
/// This exception provides detailed information about the problematic
/// cron expression and the specific validation failure.
///
/// **Example:**
/// ```dart
/// try {
///   final expression = CronExpression('* * * * * * *'); // Too many fields
/// } on InvalidCronExpressionException catch (e) {
///   print('Invalid cron expression: ${e.expression}');
///   print('Error: ${e.message}');
/// }
/// ```
/// {@endtemplate}
class InvalidCronExpressionException extends SchedulerException {
  /// The invalid cron expression that caused this exception.
  final String expression;

  /// {@macro invalidCronExpressionException}
  InvalidCronExpressionException(super.message, this.expression) : super(cause: expression);

  @override
  String toString() => 'InvalidCronExpressionException: $message\nExpression: $expression';
}

/// {@template taskExecutionException}
/// Exception thrown when a scheduled task fails during execution.
///
/// This exception captures information about the failed task including
/// its name, error message, and optional root cause. It's typically thrown
/// when a task's execution logic encounters an unexpected error.
///
/// **Example:**
/// ```dart
/// try {
///   await scheduledTask.execute();
/// } on TaskExecutionException catch (e) {
///   logger.error('Task "${e.taskName}" failed: ${e.message}');
///   if (e.cause != null) {
///     logger.error('Root cause: ${e.cause}');
///   }
/// }
/// ```
/// {@endtemplate}
class TaskExecutionException extends SchedulerException {
  /// The name of the task that failed execution.
  final String taskName;

  /// {@macro taskExecutionException}
  TaskExecutionException(this.taskName, String message, {Object? cause}) : super(message, cause: cause);

  @override
  String toString() => 'TaskExecutionException: Task "$taskName" failed: $message ${cause != null ? '\nCaused by: $cause' : ''}';
}