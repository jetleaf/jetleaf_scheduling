import 'package:jetleaf_lang/lang.dart';

import 'task_execution_context.dart';

/// {@template DefaultTaskExecutionContext}
/// Default implementation of [TaskExecutionContext] that provides comprehensive
/// tracking of task execution history, timing metrics, and exception handling
/// with full timezone awareness.
/// 
/// This context maintains a complete execution history for scheduled tasks,
/// including scheduled vs actual execution times, completion timestamps,
/// exception tracking, and execution counters. It serves as the foundation
/// for monitoring, debugging, and analytics of scheduled task execution.
/// 
/// ## Features
/// 
/// - **Execution Timing**: Tracks both scheduled and actual execution times
/// - **Exception Tracking**: Records and preserves exceptions from failed executions
/// - **Execution Counting**: Maintains total execution count for monitoring
/// - **Timezone Awareness**: All timestamps are timezone-aware for accurate reporting
/// - **State Management**: Automatically clears exceptions on successful completion
/// - **Comprehensive Logging**: Detailed toString() implementation for debugging
/// 
/// ## Usage Example
/// 
/// ```dart
/// final context = DefaultTaskExecutionContext();
/// final scheduledTime = ZonedDateTime.now();
/// 
/// // Record scheduled execution
/// context.recordScheduledExecution(scheduledTime);
/// 
/// try {
///   // Record actual start of execution
///   context.recordActualExecution(ZonedDateTime.now());
///   
///   // Execute the task logic
///   await performScheduledTask();
///   
///   // Record successful completion
///   context.recordCompletion(ZonedDateTime.now());
/// } catch (e) {
///   // Record failure with exception
///   context.recordException(e, ZonedDateTime.now());
/// }
/// 
/// // Access execution metrics
/// print('Execution count: ${context.getExecutionCount()}');
/// print('Last exception: ${context.getLastException()}');
/// print('Last completion: ${context.getLastCompletionTime()}');
/// ```
/// 
/// ## Integration with Task Scheduler
/// 
/// This context is typically used by task schedulers to track execution
/// metrics for monitoring and reporting:
/// 
/// ```dart
/// class MonitoringTaskScheduler implements TaskScheduler {
///   final Map<String, DefaultTaskExecutionContext> _executionContexts = {};
///   
///   @override
///   Future<void> schedule(Function task, Trigger trigger, {String? taskName}) async {
///     final context = _executionContexts[taskName] ??= DefaultTaskExecutionContext();
///     final scheduledTime = ZonedDateTime.now();
///     
///     context.recordScheduledExecution(scheduledTime);
///     
///     // Schedule the actual execution
///     await _executeWithMonitoring(task, context);
///   }
///   
///   Future<void> _executeWithMonitoring(Function task, DefaultTaskExecutionContext context) async {
///     context.recordActualExecution(ZonedDateTime.now());
///     
///     try {
///       await task();
///       context.recordCompletion(ZonedDateTime.now());
///     } catch (e, stackTrace) {
///       context.recordException(e, ZonedDateTime.now());
///       rethrow;
///     }
///   }
/// }
/// ```
/// 
/// ## Monitoring and Analytics
/// 
/// The execution context provides valuable data for monitoring systems:
/// 
/// ```dart
/// class TaskMetricsCollector {
///   void collectMetrics(DefaultTaskExecutionContext context, String taskName) {
///     final metrics = {
///       'task': taskName,
///       'execution_count': context.getExecutionCount(),
///       'last_scheduled': context.getLastScheduledExecutionTime(),
///       'last_actual': context.getLastActualExecutionTime(),
///       'last_completion': context.getLastCompletionTime(),
///       'has_failure': context.getLastException() != null,
///       'last_failure': context.getLastException()?.toString(),
///     };
///     
///     // Send to monitoring system
///     metricsSystem.record(metrics);
///   }
/// }
/// ```
/// 
/// ## Error Recovery Patterns
/// 
/// Use the context to implement smart error recovery:
/// 
/// ```dart
/// class ResilientTaskExecutor {
///   Future<void> executeWithRetry(
///     Function task, 
///     DefaultTaskExecutionContext context,
///     int maxRetries = 3
///   ) async {
///     for (int attempt = 1; attempt <= maxRetries; attempt++) {
///       try {
///         context.recordActualExecution(ZonedDateTime.now());
///         await task();
///         context.recordCompletion(ZonedDateTime.now());
///         return; // Success - exit retry loop
///       } catch (e) {
///         context.recordException(e, ZonedDateTime.now());
///         
///         if (attempt == maxRetries) {
///           rethrow; // Final attempt failed
///         }
///         
///         // Wait before retry
///         await Future.delayed(Duration(seconds: attempt * 2));
///       }
///     }
///   }
/// }
/// ```
/// 
/// ## Thread Safety Considerations
/// 
/// This implementation is not thread-safe by default. When used in
/// concurrent environments, consider:
/// 
/// - Using in single-threaded contexts only
/// - Adding synchronization for multi-threaded access
/// - Creating thread-local instances
/// - Using atomic operations for counter updates
/// 
/// ## Performance Characteristics
/// 
/// - Minimal memory footprint for execution tracking
/// - Efficient timestamp recording with ZonedDateTime
/// - Automatic exception clearing reduces memory retention
/// - Suitable for high-frequency task execution
/// {@endtemplate}
final class DefaultTaskExecutionContext implements TaskExecutionContext {
  /// The last time the task was scheduled to execute.
  ZonedDateTime? _lastScheduledExecutionTime;

  /// The last time the task actually began execution.
  ZonedDateTime? _lastActualExecutionTime;

  /// The last time the task completed execution (successfully or with failure).
  ZonedDateTime? _lastCompletionTime;

  /// The last exception that occurred during task execution, if any.
  Object? _lastException;

  /// Total number of times this task has been executed.
  int _executionCount = 0;

  /// {@macro DefaultTaskExecutionContext}
  /// 
  /// Creates a new [DefaultTaskExecutionContext] with initial empty state.
  /// 
  /// The context starts with no execution history and zero execution count,
  /// ready to track a new task execution lifecycle.
  /// 
  /// Example:
  /// ```dart
  /// // Create a fresh execution context for a new task
  /// final context = DefaultTaskExecutionContext();
  /// 
  /// // Or create multiple contexts for different tasks
  /// final dailyContext = DefaultTaskExecutionContext();
  /// final hourlyContext = DefaultTaskExecutionContext();
  /// ```
  DefaultTaskExecutionContext();

  /// Records that a task execution has been scheduled by the scheduler.
  /// 
  /// This method should be called when the task scheduler determines
  /// that a task should execute at a specific time. The scheduled time
  /// represents when the task was intended to run, which may differ
  /// from the actual execution time due to system load or other factors.
  /// 
  /// @param scheduledTime The time when the task was scheduled to execute.
  ///        Must be a timezone-aware [ZonedDateTime].
  /// 
  /// Example:
  /// ```dart
  /// final scheduledTime = ZonedDateTime.now();
  /// context.recordScheduledExecution(scheduledTime);
  /// ```
  void recordScheduledExecution(ZonedDateTime scheduledTime) {
    _lastScheduledExecutionTime = scheduledTime;
  }

  /// Records that a task execution has actually started.
  /// 
  /// This method should be called immediately before the task logic
  /// begins execution. It increments the execution counter and records
  /// the actual start time, which may differ from the scheduled time.
  /// 
  /// @param actualTime The time when the task actually began execution.
  ///        Must be a timezone-aware [ZonedDateTime].
  /// 
  /// Example:
  /// ```dart
  /// void executeTask() {
  ///   context.recordActualExecution(ZonedDateTime.now());
  ///   // ... task logic here
  /// }
  /// ```
  void recordActualExecution(ZonedDateTime actualTime) {
    _lastActualExecutionTime = actualTime;
    _executionCount++;
  }

  /// Records that a task execution has completed successfully.
  /// 
  /// This method should be called after the task logic has completed
  /// without exceptions. It records the completion time and clears
  /// any previous exception state.
  /// 
  /// @param completionTime The time when the task completed successfully.
  ///        Must be a timezone-aware [ZonedDateTime].
  /// 
  /// Example:
  /// ```dart
  /// try {
  ///   await performTask();
  ///   context.recordCompletion(ZonedDateTime.now());
  /// } catch (e) {
  ///   context.recordException(e, ZonedDateTime.now());
  /// }
  /// ```
  void recordCompletion(ZonedDateTime completionTime) {
    _lastCompletionTime = completionTime;
    _lastException = null; // Clear any previous exception on successful completion
  }

  /// Records an exception that occurred during task execution.
  /// 
  /// This method should be called when the task logic throws an exception.
  /// It preserves the exception and records the failure time. The exception
  /// will remain recorded until the next successful completion.
  /// 
  /// @param exception The exception that occurred during task execution.
  /// @param failureTime The time when the task failed with an exception.
  ///        Must be a timezone-aware [ZonedDateTime].
  /// 
  /// Example:
  /// ```dart
  /// try {
  ///   await performTask();
  ///   context.recordCompletion(ZonedDateTime.now());
  /// } catch (e) {
  ///   context.recordException(e, ZonedDateTime.now());
  ///   // Re-throw or handle as needed
  /// }
  /// ```
  void recordException(Object exception, ZonedDateTime failureTime) {
    _lastException = exception;
    _lastCompletionTime = failureTime; // Task completed (with failure)
  }

  @override
  ZonedDateTime? getLastScheduledExecutionTime() => _lastScheduledExecutionTime;

  @override
  ZonedDateTime? getLastActualExecutionTime() => _lastActualExecutionTime;

  @override
  ZonedDateTime? getLastCompletionTime() => _lastCompletionTime;

  @override
  Object? getLastException() => _lastException;

  @override
  int getExecutionCount() => _executionCount;

  @override
  String toString() => 'DefaultTaskExecutionContext{'
    'executions: $_executionCount, '
    'lastScheduled: $_lastScheduledExecutionTime, '
    'lastActual: $_lastActualExecutionTime, '
    'lastCompletion: $_lastCompletionTime, '
    'lastException: $_lastException'
    '}';
}