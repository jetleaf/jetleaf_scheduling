import 'scheduled_task.dart';

/// {@template ScheduledTaskHolder}
/// Interface for components that hold and manage a collection of scheduled tasks.
/// 
/// This interface defines the contract for objects that maintain references
/// to scheduled tasks and provide access to them for monitoring, management,
/// and lifecycle operations. Implementations can range from simple task
/// collections to complex task management systems with additional capabilities.
/// 
/// ## Purpose
/// 
/// The `ScheduledTaskHolder` interface enables:
/// - **Task Discovery**: Access to all managed scheduled tasks
/// - **Monitoring**: Inspection of task states and execution metrics
/// - **Lifecycle Management**: Coordinated start/stop of task groups
/// - **Dependency Injection**: Clean abstraction for task container access
/// - **Testing**: Mockable interface for unit testing task-dependent code
/// 
/// ## Implementation Guidelines
/// 
/// When implementing this interface, consider:
/// 
/// - **Thread Safety**: Ensure thread-safe access to the task collection
/// - **Immutability**: Return defensive copies or unmodifiable lists if appropriate
/// - **Lifecycle Awareness**: Coordinate with task lifecycle events
/// - **Performance**: Consider lazy loading or caching for large task collections
/// 
/// ## Usage Examples
/// 
/// ### Basic Implementation
/// ```dart
/// final class SimpleTaskHolder implements ScheduledTaskHolder {
///   final List<ScheduledTask> _tasks = [];
/// 
///   void addTask(ScheduledTask task) {
///     _tasks.add(task);
///   }
/// 
///   @override
///   List<ScheduledTask> getScheduledTasks() => List.unmodifiable(_tasks);
/// 
///   @override
///   bool hasScheduledTasks() => _tasks.isNotEmpty;
/// }
/// ```
/// 
/// ### Usage in Application Services
/// ```dart
/// @Service
/// class TaskMonitoringService {
///   final ScheduledTaskHolder _taskHolder;
///   final MetricsCollector _metrics;
/// 
///   TaskMonitoringService(this._taskHolder, this._metrics);
/// 
///   void collectTaskMetrics() {
///     if (_taskHolder.hasScheduledTasks()) {
///       for (final task in _taskHolder.getScheduledTasks()) {
///         final metrics = {
///           'task_name': task.toString(),
///           'execution_count': task.getExecutionCount(),
///           'last_execution': task.getLastExecutionTime(),
///           'next_execution': task.getNextExecutionTime(),
///           'is_executing': task.getIsExecuting(),
///           'is_canceled': task.getIsCanceled(),
///         };
///         _metrics.record('scheduled_task', metrics);
///       }
///     }
///   }
/// }
/// ```
/// 
/// ### Integration with Task Scheduler
/// ```dart
/// final class ManagedTaskScheduler implements ScheduledTaskHolder {
///   final Map<String, ScheduledTask> _scheduledTasks = {};
///   final TaskScheduler _delegate;
/// 
///   ManagedTaskScheduler(this._delegate);
/// 
///   Future<void> scheduleTask(
///     String taskName, 
///     Function task, 
///     Trigger trigger
///   ) async {
///     final scheduledTask = SimpleScheduledTask(task, trigger, taskName);
///     _scheduledTasks[taskName] = scheduledTask;
///     await scheduledTask.start();
///   }
/// 
///   Future<void> cancelTask(String taskName) async {
///     final task = _scheduledTasks[taskName];
///     if (task != null) {
///       await task.cancel();
///       _scheduledTasks.remove(taskName);
///     }
///   }
/// 
///   @override
///   List<ScheduledTask> getScheduledTasks() => 
///       List.unmodifiable(_scheduledTasks.values);
/// 
///   @override
///   bool hasScheduledTasks() => _scheduledTasks.isNotEmpty;
/// 
///   ScheduledTask? getTask(String taskName) => _scheduledTasks[taskName];
/// }
/// ```
/// 
/// ### Testing with Mock Implementation
/// ```dart
/// class MockScheduledTaskHolder implements ScheduledTaskHolder {
///   final List<ScheduledTask> mockTasks = [];
/// 
///   @override
///   List<ScheduledTask> getScheduledTasks() => mockTasks;
/// 
///   @override
///   bool hasScheduledTasks() => mockTasks.isNotEmpty;
/// }
/// 
/// test('should handle empty task holder', () {
///   final holder = MockScheduledTaskHolder();
///   final monitor = TaskMonitoringService(holder, MockMetricsCollector());
/// 
///   expect(() => monitor.collectTaskMetrics(), returnsNormally);
///   expect(holder.hasScheduledTasks(), isFalse);
/// });
/// ```
/// 
/// ## Common Implementation Patterns
/// 
/// ### Composite Task Holder
/// ```dart
/// final class CompositeTaskHolder implements ScheduledTaskHolder {
///   final List<ScheduledTaskHolder> _holders = [];
/// 
///   void addHolder(ScheduledTaskHolder holder) {
///     _holders.add(holder);
///   }
/// 
///   @override
///   List<ScheduledTask> getScheduledTasks() {
///     return _holders.expand((holder) => holder.getScheduledTasks()).toList();
///   }
/// 
///   @override
///   bool hasScheduledTasks() {
///     return _holders.any((holder) => holder.hasScheduledTasks());
///   }
/// }
/// ```
/// 
/// ### Filtered Task Holder
/// ```dart
/// final class FilteredTaskHolder implements ScheduledTaskHolder {
///   final ScheduledTaskHolder _delegate;
///   final bool Function(ScheduledTask) _filter;
/// 
///   FilteredTaskHolder(this._delegate, this._filter);
/// 
///   @override
///   List<ScheduledTask> getScheduledTasks() {
///     return _delegate.getScheduledTasks().where(_filter).toList();
///   }
/// 
///   @override
///   bool hasScheduledTasks() {
///     return _delegate.getScheduledTasks().any(_filter);
///   }
/// }
/// 
/// // Usage: Get only active (non-canceled) tasks
/// final activeTasksHolder = FilteredTaskHolder(
///   mainHolder, 
///   (task) => !task.getIsCanceled()
/// );
/// ```
/// 
/// ## Performance Considerations
/// 
/// - **Large Collections**: For implementations with many tasks, consider
///   lazy iteration or pagination in `getScheduledTasks()`
/// - **Frequent Access**: Cache the task list if it doesn't change often
/// - **Memory Usage**: Be mindful of retaining references to completed tasks
/// - **Concurrent Modification**: Use appropriate synchronization for
///   collections that can be modified while being iterated
/// 
/// ## Error Handling
/// 
/// Implementations should handle:
/// - **Concurrent modifications** to the task collection
/// - **Null safety** when tasks are removed during iteration
/// - **Task lifecycle exceptions** when accessing task properties
/// - **Memory leaks** from retaining completed or canceled tasks
/// 
/// ## Extension Points
/// 
/// Common extensions to this interface include:
/// - Adding methods for task lookup by name or criteria
/// - Supporting task grouping or categorization
/// - Providing bulk operations (start all, cancel all)
/// - Adding lifecycle event listeners
/// - Supporting task persistence and restoration
/// {@endtemplate}
abstract interface class ScheduledTaskHolder {
  /// {@template ScheduledTaskHolder.getScheduledTasks}
  /// Returns a list of all scheduled tasks managed by this holder.
  /// 
  /// The returned list should contain all currently scheduled tasks,
  /// including those that are executing, waiting, or canceled. The
  /// order of tasks in the list is implementation-defined but should
  /// be consistent across multiple calls.
  /// 
  /// Implementations should consider:
  /// - Returning an unmodifiable list to prevent external modification
  /// - Providing a defensive copy if the internal collection is mutable
  /// - Maintaining thread safety if the holder is accessed concurrently
  /// - Handling cases where tasks are added or removed during the call
  /// 
  /// @return A list of all managed scheduled tasks. Returns an empty
  ///         list if no tasks are currently managed.
  /// 
  /// Example:
  /// ```dart
  /// final taskHolder = getTaskHolder();
  /// final allTasks = taskHolder.getScheduledTasks();
  /// 
  /// for (final task in allTasks) {
  ///   print('Task: ${task.toString()}');
  ///   print('  Executions: ${task.getExecutionCount()}');
  ///   print('  Next run: ${task.getNextExecutionTime()}');
  ///   print('  Is executing: ${task.getIsExecuting()}');
  /// }
  /// ```
  /// {@endtemplate}
  List<ScheduledTask> getScheduledTasks();

  /// {@template ScheduledTaskHolder.hasScheduledTasks}
  /// Returns whether this holder manages any scheduled tasks.
  /// 
  /// This method provides an efficient way to check for the presence
  /// of scheduled tasks without retrieving the entire collection.
  /// It's particularly useful for conditional logic and early returns.
  /// 
  /// Implementations should optimize this method to avoid unnecessary
  /// collection creation or iteration when possible.
  /// 
  /// @return `true` if this holder manages one or more scheduled tasks,
  ///         `false` if no tasks are currently managed.
  /// 
  /// Example:
  /// ```dart
  /// final taskHolder = getTaskHolder();
  /// 
  /// if (taskHolder.hasScheduledTasks()) {
  ///   // Perform expensive operation only when tasks exist
  ///   await performTaskMaintenance();
  /// } else {
  ///   print('No scheduled tasks to maintain');
  /// }
  /// ```
  /// {@endtemplate}
  bool hasScheduledTasks();
}