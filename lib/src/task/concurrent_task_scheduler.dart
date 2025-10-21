import 'dart:async';

import 'package:jetleaf_lang/lang.dart';
import 'package:jetleaf_logging/logging.dart';

import '../exceptions.dart';
import '../trigger/trigger_builder.dart';
import 'scheduled_task.dart';
import 'simple_scheduled_task.dart';
import '../trigger/trigger.dart';
import 'task_scheduler.dart';

/// {@template concurrentTaskScheduler}
/// A [TaskScheduler] implementation that supports concurrent task execution
/// with configurable concurrency limits and task queue management.
///
/// This scheduler manages task execution with controlled concurrency,
/// preventing system overload while maintaining efficient task processing.
/// It includes features for monitoring task execution statistics and
/// graceful shutdown handling.
///
/// **Example:**
/// ```dart
/// // Create scheduler with custom concurrency limits
/// final scheduler = ConcurrentTaskScheduler(
///   maxConcurrency: 5,
///   queueCapacity: 500,
/// );
///
/// // Schedule multiple tasks - they will execute within concurrency limits
/// await scheduler.schedule(
///   () => processData(),
///   FixedRateTrigger(Duration(seconds: 30)),
/// );
///
/// await scheduler.schedule(
///   () => generateReport(),
///   CronTrigger('0 0 * * * *'),
/// );
///
/// // Monitor scheduler statistics
/// print('Active tasks: ${scheduler.getActiveTaskCount()}');
/// print('Queued tasks: ${scheduler.getQueuedTaskCount()}');
/// print('Total tasks: ${scheduler.getTotalTaskCount()}');
///
/// // Graceful shutdown
/// await scheduler.shutdown();
/// ```
/// {@endtemplate}
final class ConcurrentTaskScheduler implements TaskScheduler {  
  /// Maximum number of tasks that can execute concurrently.
  ///
  /// When this limit is reached, new task executions will be queued
  /// until execution slots become available.
  final int _maxConcurrency;
  
  /// Maximum number of pending tasks in the execution queue.
  ///
  /// When both active tasks and queued tasks reach their limits,
  /// new task submissions will be rejected with [SchedulerException].
  final int _queueCapacity;

  /// {@macro concurrentTaskScheduler}
  ConcurrentTaskScheduler({int? maxConcurrency, int? queueCapacity})
    : _maxConcurrency = maxConcurrency ?? 10, _queueCapacity = queueCapacity ?? 1000;

  /// Set of all managed scheduled tasks for lifecycle tracking.
  final Set<ScheduledTask> _tasks = {};

  /// Logger instance for scheduler operations and monitoring.
  final Log _logger = LogFactory.getLog(ConcurrentTaskScheduler);

  /// Flag indicating whether the scheduler has been shut down.
  bool _isShutdown = false;

  /// Current number of actively executing tasks.
  int _activeTasks = 0;
  
  /// Queue for tasks waiting for execution slots when concurrency limit is reached.
  final List<RunnableScheduler> _taskQueue = [];

  /// {@macro getActiveTaskCount}
  /// Returns the number of currently active tasks.
  ///
  /// This provides real-time insight into current scheduler load
  /// and can be used for monitoring and scaling decisions.
  ///
  /// **Example:**
  /// ```dart
  /// final activeCount = scheduler.getActiveTaskCount();
  /// if (activeCount >= scheduler.maxConcurrency) {
  ///   print('Scheduler at maximum concurrency');
  /// }
  /// ```
  int getActiveTaskCount() => _activeTasks;

  /// {@macro getQueuedTaskCount}
  /// Returns the number of queued tasks waiting for execution.
  ///
  /// A high queued task count indicates that the scheduler is under
  /// heavy load and tasks are waiting for execution slots.
  ///
  /// **Example:**
  /// ```dart
  /// final queuedCount = scheduler.getQueuedTaskCount();
  /// if (queuedCount > 0) {
  ///   print('$queuedCount tasks waiting for execution slots');
  /// }
  /// ```
  int getQueuedTaskCount() => _taskQueue.length;

  /// {@macro getTotalTaskCount}
  /// Returns the total number of managed tasks.
  ///
  /// This includes both active tasks and tasks waiting for their
  /// next scheduled execution time.
  ///
  /// **Example:**
  /// ```dart
  /// final totalTasks = scheduler.getTotalTaskCount();
  /// print('Scheduler managing $totalTasks total tasks');
  /// ```
  int getTotalTaskCount() => _tasks.length;

  /// Validation method for scheduler shutdown state.
  ///
  /// This template documents the shutdown state validation
  /// used to prevent operations on terminated schedulers.
  /// 
  /// Throws [SchedulerException] if the scheduler has been shut down.
  ///
  /// This method is used to prevent operations on a shutdown scheduler
  /// and ensure clean state management.
  void _failIfShutdown() {
    if (_isShutdown) {
      throw SchedulerException('Failed to schedule task: Scheduler has been shut down and cannot accept new tasks.');
    }
  }

  /// Concurrency-controlled task execution with queue management.
  ///
  /// This template documents the concurrency control mechanism
  /// that manages task execution within configured limits.
  /// 
  /// Executes a task with concurrency control and queue management.
  ///
  /// This method manages the concurrency limits by either executing
  /// the task immediately, queuing it for later execution, or rejecting
  /// it if queue capacity is exceeded.
  Future<void> _executeWithConcurrencyControl(RunnableScheduler task) async {
    // If we're at max concurrency and have queue capacity, queue the task
    if (_activeTasks >= _maxConcurrency) {
      if (_taskQueue.length >= _queueCapacity) {
        throw SchedulerException('Task queue is full. Cannot schedule additional task.');
      }
      
      final completer = Completer<void>();
      _taskQueue.add(() async {
        try {
          await _executeTaskDirectly(task);
          completer.complete();
        } catch (e) {
          completer.completeError(e);
        }
      });

      return completer.future;
    }
    
    return _executeTaskDirectly(task);
  }

  /// Direct task execution with lifecycle management.
  ///
  /// This template documents the low-level task execution
  /// and active task tracking mechanism.
  /// 
  /// Executes a task directly and manages active task count.
  ///
  /// This method handles the actual task execution, active task tracking,
  /// and processing of queued tasks when execution slots become available.
  Future<void> _executeTaskDirectly(RunnableScheduler task) async {
    _activeTasks++;
    try {
      final result = task();
      if (result is Future) {
        await result;
      }
    } finally {
      _activeTasks--;

      // Process queued tasks if any
      if (_taskQueue.isNotEmpty) {
        final nextTask = _taskQueue.removeAt(0);
        unawaited(_executeTaskDirectly(nextTask));
      }
    }
  }

  @override
  Future<ScheduledTask> schedule(RunnableScheduler task, Trigger trigger, String taskName) async {
    _failIfShutdown();

    final existing = _tasks.find((t) => t.getName() == taskName);

    if (existing != null) {
      if (_logger.getIsWarnEnabled()) {
        _logger.warn('Task with name "$taskName" is already scheduled');
      }

      return existing;
    }

    final scheduledTask = SimpleScheduledTask(() => _executeWithConcurrencyControl(task), trigger, taskName);
    
    _tasks.add(scheduledTask);
    scheduledTask.start();

    if (_logger.getIsTraceEnabled()) {
      _logger.trace('Task scheduled successfully with trigger: $trigger (total active tasks: ${_tasks.length})');
    }

    return scheduledTask;
  }

  @override
  Future<ScheduledTask> scheduleAtFixedRate(RunnableScheduler task, Duration period, String taskName, [Duration? initialDelay]) {
    _failIfShutdown();

    final trigger = TriggerBuilder(fixedRate: period, delayPeriod: initialDelay);
    return schedule(task, trigger, taskName);
  }

  @override
  Future<ScheduledTask> scheduleWithFixedDelay(RunnableScheduler task, Duration delay, String taskName, [Duration? initialDelay]) {
    _failIfShutdown();

    final trigger = TriggerBuilder(fixedDelay: delay, delayPeriod: initialDelay);
    return schedule(task, trigger, taskName);
  }

  @override
  Future<void> shutdown([bool force = false]) async {
    if (_isShutdown) return;
    
    _isShutdown = true;
    
    if (_logger.getIsTraceEnabled()) {
      _logger.trace('Shutting down scheduler with ${_tasks.length} tasks (force: $force)');
    }
    
    final cancelFutures = _tasks.map((task) => task.cancel(force));
    final cancellers = <Future<bool>>[];

    for (final futureOrBool in cancelFutures) {
      cancellers.add(Future.value(futureOrBool));
    }

    await Future.wait(cancellers);

    _tasks.clear();
    _taskQueue.clear();
    
    if (_logger.getIsTraceEnabled()) {
      _logger.trace('Scheduler shutdown completed successfully.');
    }
  }
}