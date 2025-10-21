import 'package:jetleaf_lang/lang.dart';

/// {@template taskExecutionContext}
/// Provides contextual information about a task's execution history and state.
///
/// This interface offers access to execution metrics and timing information
/// that can be used for monitoring, logging, and conditional task logic.
///
/// **Example:**
/// ```dart
/// final task = (TaskExecutionContext context) {
///   final lastRun = context.getLastActualExecutionTime();
///   final exception = context.getLastException();
///   
///   if (exception != null) {
///     print('Previous execution failed: $exception');
///   }
///   
///   if (lastRun != null) {
///     final timeSinceLastRun = DateTime.now().difference(lastRun.toDateTime());
///     print('Time since last run: $timeSinceLastRun');
///   }
///   
///   print('Total executions: ${context.getExecutionCount()}');
/// };
/// ```
/// {@endtemplate}
abstract interface class TaskExecutionContext {
  /// Returns the last time the task was scheduled to execute.
  ///
  /// This represents the planned execution time, which may differ from
  /// the actual execution time due to system load or delays.
  ///
  /// **Example:**
  /// ```dart
  /// final scheduledTime = context.getLastScheduledExecutionTime();
  /// if (scheduledTime != null) {
  ///   final delay = ZonedDateTime.now().compareTo(scheduledTime);
  ///   if (delay > Duration(seconds: 5)) {
  ///     print('Task started with significant delay: $delay');
  ///   }
  /// }
  /// ```
  ZonedDateTime? getLastScheduledExecutionTime();

  /// Returns the last time the task actually started executing.
  ///
  /// This timestamp represents when the task's execution logic began,
  /// which may be later than the scheduled time due to various factors.
  ///
  /// **Example:**
  /// ```dart
  /// final actualStart = context.getLastActualExecutionTime();
  /// final scheduled = context.getLastScheduledExecutionTime();
  /// 
  /// if (actualStart != null && scheduled != null) {
  ///   final startupDelay = actualStart.toEpochMilli() - scheduled.toEpochMilli();
  ///   print('Task startup delay: ${Duration(milliseconds: startupDelay)}');
  /// }
  /// ```
  ZonedDateTime? getLastActualExecutionTime();

  /// Returns the last time the task completed execution.
  ///
  /// This represents when the task finished, regardless of whether
  /// it completed successfully or with an exception.
  ///
  /// **Example:**
  /// ```dart
  /// final completionTime = context.getLastCompletionTime();
  /// final startTime = context.getLastActualExecutionTime();
  /// 
  /// if (completionTime != null && startTime != null) {
  ///   final duration = Duration(
  ///     milliseconds: completionTime.toEpochMilli() - startTime.toEpochMilli()
  ///   );
  ///   print('Last execution duration: $duration');
  /// }
  /// ```
  ZonedDateTime? getLastCompletionTime();

  /// Returns the exception thrown during the last execution, if any.
  ///
  /// This provides access to the most recent failure, allowing for
  /// error handling, retry logic, or logging of execution failures.
  ///
  /// **Example:**
  /// ```dart
  /// final lastException = context.getLastException();
  /// if (lastException != null) {
  ///   // Implement retry logic or special handling for failures
  ///   if (lastException is NetworkException) {
  ///     print('Network error occurred in previous execution');
  ///   }
  /// }
  /// ```
  Object? getLastException();

  /// Returns the number of times this task has been executed.
  ///
  /// This count includes all execution attempts, both successful
  /// and failed, providing a total execution history.
  ///
  /// **Example:**
  /// ```dart
  /// final executionCount = context.getExecutionCount();
  /// if (executionCount > 100) {
  ///   print('Task has run $executionCount times - consider maintenance');
  /// }
  /// ```
  int getExecutionCount();
}