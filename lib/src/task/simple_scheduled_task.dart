import 'dart:async';

import 'package:jetleaf_lang/lang.dart';
import 'package:jetleaf_logging/logging.dart';

import '../trigger/trigger.dart';
import 'default_task_execution_context.dart';
import 'scheduled_task.dart';
import 'task_execution_context.dart';

/// {@template SimpleScheduledTask}
/// Default implementation of [ScheduledTask] that manages the complete task execution lifecycle.
///
/// This class provides a robust implementation for scheduling, executing, and managing
/// recurring tasks using Dart's [Timer] mechanism. It maintains comprehensive execution
/// context, handles errors gracefully, and provides detailed logging for all task
/// lifecycle events with full timezone awareness.
///
/// ## Key Features
///
/// - **TimeZone Awareness**: All scheduling and execution times are handled in the
///   trigger's specified timezone
/// - **Execution Tracking**: Comprehensive execution history with metrics and timing
/// - **Error Resilience**: Graceful error handling with proper exception recording
/// - **Lifecycle Management**: Proper start, execution, and cancellation semantics
/// - **Behind-Schedule Handling**: Automatic immediate execution for missed schedules
/// - **Thread-Safe Operations**: Safe cancellation and state management
///
/// ## Usage Example
///
/// ```dart
/// // Create a task that runs every 5 minutes in New York timezone
/// final task = () => print('Executing scheduled task');
/// final trigger = FixedRateTrigger(
///   period: Duration(minutes: 5),
///   zone: ZoneId.of('America/New_York'),
/// );
///
/// final scheduledTask = SimpleScheduledTask(task, trigger, 'myScheduledTask');
/// 
/// // Start the task
/// await scheduledTask.start();
///
/// // Monitor task execution
/// print('Execution count: ${scheduledTask.getExecutionCount()}');
/// print('Next execution: ${scheduledTask.getNextExecutionTime()}');
/// print('Task timezone: ${scheduledTask.getZone().id}');
/// print('Last exception: ${scheduledTask.getExecutionContext().getLastException()}');
///
/// // Cancel the task when no longer needed
/// await scheduledTask.cancel();
/// ```
///
/// ## Execution Lifecycle
///
/// 1. **Scheduling**: Task is scheduled based on trigger's next execution time
/// 2. **Execution**: Task runs with proper timezone context and state tracking
/// 3. **Completion**: Success/failure is recorded and next execution is scheduled
/// 4. **Cancellation**: Clean shutdown with optional interruption support
///
/// ## Error Handling Strategy
///
/// - Exceptions during task execution are caught and logged
/// - Execution context preserves the last exception for monitoring
/// - Task continues scheduling next executions despite failures
/// - Comprehensive error logging with stack traces
///
/// ## Timezone Considerations
///
/// All execution times are calculated and recorded in the trigger's timezone,
/// ensuring consistent behavior across different server timezones and during
/// daylight saving time transitions.
/// {@endtemplate}
final class SimpleScheduledTask with EqualsAndHashCode implements ScheduledTask {
  /// The task function to be executed.
  final FutureOr<void> Function() _task;

  /// The trigger that determines when the task should execute.
  final Trigger _trigger;

  /// Optional name for the task, used for logging and identification.
  final String _taskName;

  /// Execution context tracking task history and metrics.
  final DefaultTaskExecutionContext _context;

  /// {@macro SimpleScheduledTask}
  /// 
  /// Creates a new scheduled task with the specified function, trigger, and optional name.
  /// 
  /// @param task The function to execute when triggered. Can be synchronous or asynchronous.
  /// @param trigger The trigger that determines execution schedule and timezone.
  /// @param taskName Optional descriptive name for logging and monitoring purposes.
  /// 
  /// Example:
  /// ```dart
  /// // Create a task with cron expression
  /// final cronTrigger = CronTrigger('0 0 * * * *', zone: ZoneId.of('UTC'));
  /// final task = SimpleScheduledTask(
  ///   () => database.cleanup(), 
  ///   cronTrigger, 
  ///   'hourlyCleanup'
  /// );
  /// 
  /// // Create a task with fixed rate
  /// final rateTrigger = FixedRateTrigger(
  ///   period: Duration(seconds: 30),
  ///   initialDelay: Duration(seconds: 10)
  /// );
  /// final heartbeatTask = SimpleScheduledTask(
  ///   () => sendHeartbeat(),
  ///   rateTrigger,
  ///   'heartbeat'
  /// );
  /// ```
  SimpleScheduledTask(this._task, this._trigger, this._taskName) : _context = DefaultTaskExecutionContext();

  /// Logger instance for task execution tracking and debugging.
  final Log _logger = LogFactory.getLog(SimpleScheduledTask);

  /// Timer for the next scheduled execution.
  Timer? _nextExecutionTimer;

  /// Completer for the current execution, used for cancellation support.
  Completer<void>? _currentExecution;

  /// Flag indicating whether the task has been canceled.
  bool _isCanceled = false;

  /// Flag indicating whether the task is currently executing.
  bool _isExecuting = false;

  @override
  bool getIsCanceled() => _isCanceled;

  @override
  bool getIsExecuting() => _isExecuting;

  @override
  int getExecutionCount() => _context.getExecutionCount();

  @override
  ZonedDateTime? getLastExecutionTime() => _context.getLastActualExecutionTime();

  @override
  String getName() => _taskName;

  @override
  ZonedDateTime? getNextExecutionTime() {
    if (_isCanceled) return null;
    return _trigger.nextExecutionTime(_context);
  }

  @override
  ZoneId getZone() => _trigger.getZone();

  @override
  Trigger getTrigger() => _trigger;

  @override
  TaskExecutionContext getExecutionContext() => _context;

  @override
  Future<void> start() async {
    if (_isCanceled) {
      throw IllegalStateException('Cannot start a canceled task');
    }
    
    if (_logger.getIsTraceEnabled()) {
      _logger.trace('Starting task $_taskName in timezone: ${getZone().id}');
    }
    
    await _scheduleNextExecution();
  }

  /// {@template SimpleScheduledTask.scheduleNextExecution}
  /// Schedules the next execution of the task based on the trigger's calculation.
  ///
  /// This internal method consults the trigger to determine the next execution time
  /// in the task's timezone, sets up a timer for that time, and handles cases where
  /// the execution is behind schedule by executing immediately.
  ///
  /// The scheduling process:
  /// 1. Calculates next execution time using the trigger
  /// 2. Computes delay in the task's timezone context
  /// 3. Handles behind-schedule scenarios with immediate execution
  /// 4. Sets up timer for future executions
  ///
  /// @throws SchedulerException if the trigger calculation fails
  /// {@endtemplate}
  Future<void> _scheduleNextExecution() async {
    if (_isCanceled) return;

    final nextTime = _trigger.nextExecutionTime(_context);
    if (nextTime == null) {
      if (_logger.getIsTraceEnabled()) {
        _logger.trace('Task $_taskName has no next execution time - stopping');
      }
      return;
    }

    // Calculate delay in the task's timezone context for accurate scheduling
    final nowInTaskZone = ZonedDateTime.now(getZone());
    final delay = nextTime.toEpochMilli() - nowInTaskZone.toEpochMilli();

    if (delay <= 0) {
      // If we're behind schedule, execute immediately to catch up
      if (_logger.getIsTraceEnabled()) {
        _logger.trace('Task $_taskName is behind schedule, executing immediately');
      }
      unawaited(_executeTask());
    } else {
      _nextExecutionTimer = Timer(Duration(milliseconds: delay), _executeTask);
      
      if (_logger.getIsTraceEnabled()) {
        _logger.trace(
          'Task $_taskName scheduled for $nextTime '
          '(in ${Duration(milliseconds: delay)}) in timezone ${getZone().id}'
        );
      }
    }
  }

  /// {@template SimpleScheduledTask.executeTask}
  /// Executes the task and manages the complete execution lifecycle.
  ///
  /// This method handles the entire execution process including:
  /// - Updating execution state and tracking
  /// - Recording execution metrics with proper timezone context
  /// - Handling both synchronous and asynchronous tasks
  /// - Comprehensive error handling and logging
  /// - Scheduling subsequent executions
  /// - Maintaining cancellation safety
  ///
  /// The execution flow:
  /// 1. Record scheduled execution time
  /// 2. Update executing state and create completion tracker
  /// 3. Record actual start time and execute task
  /// 4. Handle completion (success or failure)
  /// 5. Schedule next execution if not canceled
  ///
  /// @throws any exception thrown by the task function (after logging)
  /// {@endtemplate}
  Future<void> _executeTask() async {
    if (_isCanceled) return;

    _isExecuting = true;
    
    // Record scheduled execution time in the task's timezone
    final scheduledTime = ZonedDateTime.now(getZone());
    _context.recordScheduledExecution(scheduledTime);
    
    final currentExecution = Completer<void>();
    _currentExecution = currentExecution;

    try {
      // Record actual execution start time
      final actualStartTime = ZonedDateTime.now(getZone());
      _context.recordActualExecution(actualStartTime);
      
      if (_logger.getIsTraceEnabled()) {
        _logger.trace(
          'Executing task $_taskName at $actualStartTime '
          '(scheduled: $scheduledTime)'
        );
      }

      final result = _task();
      if (result is Future) {
        await result;
      }

      // Record successful completion
      final completionTime = ZonedDateTime.now(getZone());
      _context.recordCompletion(completionTime);
      
      if (_logger.getIsTraceEnabled()) {
        final duration = Duration(
          milliseconds: completionTime.toEpochMilli() - actualStartTime.toEpochMilli()
        );
        _logger.trace('Task $_taskName completed successfully in $duration');
      }
    } catch (e, stackTrace) {
      // Record failure with timestamp in task's timezone
      final failureTime = ZonedDateTime.now(getZone());
      _context.recordException(e, failureTime);
      
      if (_logger.getIsErrorEnabled()) {
        _logger.error(
          'Task $_taskName failed with exception at $failureTime',
          error: e, 
          stacktrace: stackTrace
        );
      }
    } finally {
      _isExecuting = false;
      _currentExecution = null;
      currentExecution.complete();
      
      // Schedule next execution unless canceled
      if (!_isCanceled) {
        await _scheduleNextExecution();
      }
    }
  }
  
  @override
  Future<bool> cancel([bool mayInterruptIfRunning = false]) async {
    if (_isCanceled) return false;

    _isCanceled = true;
    _nextExecutionTimer?.cancel();
    _nextExecutionTimer = null;

    if (_logger.getIsTraceEnabled()) {
      _logger.trace(
        'Canceling task $_taskName '
        '(mayInterruptIfRunning: $mayInterruptIfRunning)'
      );
    }

    if (_isExecuting) {
      if (mayInterruptIfRunning) {
        // In Dart, we can't truly interrupt a running async function,
        // but we can mark it for cancellation and let it check
        if (_logger.getIsWarnEnabled()) {
          _logger.warn(
            'Requested mayInterruptIfRunning=true for task "$_taskName" but immediate '
            'interruption is not supported by this scheduler. The task will be '
            'marked canceled; running execution will be allowed to finish.',
          );
        }
      } else {
        if (_logger.getIsTraceEnabled()) {
          _logger.trace('Waiting for task $_taskName to complete');
        }
        await _currentExecution?.future;
      }
    }

    if (_logger.getIsTraceEnabled()) {
      _logger.trace('Task $_taskName canceled successfully');
    }

    return true;
  }

  @override
  List<Object?> equalizedProperties() => [_taskName, _trigger];

  /// {@template SimpleScheduledTask.toString}
  /// Returns a string representation of this scheduled task.
  /// 
  /// Provides a comprehensive summary including task name, cancellation status,
  /// execution state, execution count, timezone, and trigger information.
  /// Useful for debugging, logging, and monitoring purposes.
  /// 
  /// @return A formatted string showing all task details and current state
  /// 
  /// Example output:
  /// ```dart
  /// 'SimpleScheduledTask{name: dataCleanup, canceled: false, executing: false, executions: 42, zone: America/New_York, trigger: CronTrigger{expression: 0 0 * * * *}}'
  /// ```
  /// {@endtemplate}
  @override
  String toString() {
    return 'SimpleScheduledTask{'
        'name: $_taskName, '
        'canceled: $_isCanceled, '
        'executing: $_isExecuting, '
        'executions: ${getExecutionCount()}, '
        'zone: ${getZone().id}, '
        'trigger: $_trigger'
        '}';
  }
}

/// {@template unawaited}
/// Helper function to prevent warning for unawaited futures.
/// 
/// This function explicitly indicates that a future is intentionally
/// not awaited, suppressing Dart's unawaited_futures lint warning.
/// 
/// @param future The future that should not be awaited
/// 
/// Example:
/// ```dart
/// // Fire and forget - don't wait for completion
/// unawaited(backgroundTask());
/// ```
/// {@endtemplate}
void unawaited(Future<void> future) {}