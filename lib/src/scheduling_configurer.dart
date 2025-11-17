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
import 'package:jetleaf_logging/logging.dart';
import 'package:jetleaf_pod/pod.dart';

import 'task/concurrent_task_scheduler.dart';
import 'task/scheduled_task.dart';
import 'task/scheduled_task_holder.dart';
import 'task/simple_scheduled_task.dart';
import 'task/task_scheduler.dart';
import 'trigger/trigger.dart';
import 'trigger/trigger_builder.dart';
import 'scheduling_annotation_pod_procesor.dart';

/// {@template SchedulingConfigurer}
/// Interface for programmatically configuring scheduled tasks in the JetLeaf framework.
/// 
/// This interface allows for programmatic registration of scheduled tasks alongside
/// or as an alternative to annotation-based scheduling. Implementations can register
/// tasks, configure triggers, and set up task-related infrastructure through the
/// provided [SchedulingTaskRegistrar].
/// 
/// ## Usage Patterns
/// 
/// ### Programmatic Task Registration
/// Implement this interface to register tasks that cannot be easily expressed
/// with annotations, or to dynamically configure tasks based on runtime conditions.
/// 
/// ### Configuration Class Integration
/// Typically implemented by `@Configuration` classes that need to set up
/// scheduled tasks as part of application initialization.
/// 
/// ### Conditional Scheduling
/// Useful for registering tasks conditionally based on environment, features flags,
/// or other runtime factors.
/// 
/// ## Implementation Example
/// 
/// ```dart
/// @Configuration
/// class MySchedulingConfig implements SchedulingConfigurer {
///   final UserRepository userRepository;
///   final ReportService reportService;
/// 
///   MySchedulingConfig(this.userRepository, this.reportService);
/// 
///   @override
///   void configure(SchedulingTaskRegistrar schedulingTaskRegistrar) {
///     // Register a fixed-rate task
///     schedulingTaskRegistrar.addFixedRateTask(
///       () => userRepository.cleanupInactiveUsers(),
///       Duration(hours: 1),
///       name: 'user-cleanup'
///     );
/// 
///     // Register a cron-based task
///     schedulingTaskRegistrar.addCronTask(
///       () => reportService.generateDailyReport(),
///       '0 0 6 * * *', // 6 AM daily
///       zone: 'America/New_York',
///       name: 'daily-report'
///     );
/// 
///     // Register a task with custom trigger
///     schedulingTaskRegistrar.addTriggerTask(
///       () => reportService.sendWeeklySummary(),
///       CustomBusinessDayTrigger(),
///       name: 'weekly-summary'
///     );
///   }
/// }
/// ```
/// 
/// ## Integration with Application Context
/// 
/// The framework automatically detects implementations of this interface
/// and invokes them during application context refresh:
/// 
/// ```dart
/// @EnableScheduling
/// @Configuration
/// @Import(MySchedulingConfig)
/// class AppConfig {
///   // Application configuration...
/// }
/// 
/// void main() async {
///   final context = AnnotationConfigApplicationContext();
///   context.register(AppConfig);
///   await context.refresh(); // MySchedulingConfig.configure() will be called
/// }
/// ```
/// 
/// ## Advanced Usage
/// 
/// ### Dynamic Task Registration
/// ```dart
/// @Configuration
/// class DynamicSchedulingConfig implements SchedulingConfigurer {
///   final FeatureFlags featureFlags;
///   final Environment environment;
/// 
///   @override
///   void configure(SchedulingTaskRegistrar schedulingTaskRegistrar) {
///     // Only register in production environment
///     if (environment.activeProfiles.contains('prod')) {
///       schedulingTaskRegistrar.addFixedRateTask(
///         () => MetricsCollector.collect(),
///         Duration(minutes: 5),
///         name: 'production-metrics'
///       );
///     }
/// 
///     // Register based on feature flags
///     if (featureFlags.isEnabled('advanced-reporting')) {
///       schedulingTaskRegistrar.addCronTask(
///         () => AdvancedReportService.generate(),
///         '0 0 2 * * *', // 2 AM daily
///         name: 'advanced-reports'
///       );
///     }
///   }
/// }
/// ```
/// 
/// ### Task Dependencies and Ordering
/// ```dart
/// @Configuration
/// class OrderedSchedulingConfig implements SchedulingConfigurer {
///   final DataService dataService;
///   final AnalyticsService analyticsService;
/// 
///   @override
///   void configure(SchedulingTaskRegistrar schedulingTaskRegistrar) {
///     // Ensure data refresh completes before analytics
///     schedulingTaskRegistrar.addFixedRateTask(
///       () => dataService.refreshCache(),
///       Duration(minutes: 30),
///       name: 'data-refresh'
///     );
/// 
///     schedulingTaskRegistrar.addFixedDelayTask(
///       () => analyticsService.processData(),
///       Duration(minutes: 5), // Wait 5 minutes after data refresh
///       name: 'analytics-process'
///     );
///   }
/// }
/// ```
/// 
/// ### Custom Trigger Configuration
/// ```dart
/// @Configuration
/// class CustomTriggerConfig implements SchedulingConfigurer {
///   @override
///   void configure(SchedulingTaskRegistrar schedulingTaskRegistrar) {
///     // Register task with complex custom trigger
///     schedulingTaskRegistrar.addTriggerTask(
///       () => MaintenanceService.run(),
///       CompositeTrigger([
///         CronTrigger('0 0 2 * * *'), // Daily at 2 AM
///         BusinessDayTrigger(),        // Only on business days
///         LowLoadTrigger()             // Only when system load is low
///       ]),
///       name: 'smart-maintenance'
///     );
///   }
/// }
/// ```
/// 
/// ## Testing Strategies
/// 
/// ### Unit Testing Configurer
/// ```dart
/// test('should register expected tasks', () {
///   final mockRegistrar = MockSchedulingTaskRegistrar();
///   final configurer = MySchedulingConfig(mockUserRepo, mockReportService);
/// 
///   configurer.configure(mockRegistrar);
/// 
///   verify(mockRegistrar.addFixedRateTask(
///     any, 
///     Duration(hours: 1), 
///     name: 'user-cleanup'
///   )).called(1);
///   
///   verify(mockRegistrar.addCronTask(
///     any,
///     '0 0 6 * * *',
///     zone: 'America/New_York',
///     name: 'daily-report'
///   )).called(1);
/// });
/// ```
/// 
/// ### Integration Testing
/// ```dart
/// test('should schedule tasks in application context', () async {
///   final context = AnnotationConfigApplicationContext();
///   context.register(TestSchedulingConfig);
///   
///   await context.refresh();
/// 
///   final taskHolder = context.getPod<ScheduledTaskHolder>();
///   expect(taskHolder.hasScheduledTasks(), isTrue);
///   
///   await context.close();
/// });
/// ```
/// 
/// ## Best Practices
/// 
/// - Use descriptive task names for better monitoring and debugging
/// - Consider task execution time when choosing trigger intervals
/// - Use appropriate timezones for business-hour sensitive tasks
/// - Register related tasks together in the same configurer
/// - Consider task dependencies and execution order
/// - Use conditional registration for environment-specific tasks
/// - Document the purpose and schedule of each registered task
/// 
/// ## Error Handling
/// 
/// - Exceptions during configuration will prevent application startup
/// - Validate trigger configurations before registration
/// - Handle missing dependencies gracefully
/// - Consider fallback strategies for critical tasks
/// 
/// ## Performance Considerations
/// 
/// - Task registration occurs during application startup
/// - Consider the total number of scheduled tasks and their frequency
/// - Use appropriate thread pool sizes for concurrent task execution
/// - Monitor task execution times to identify performance issues
/// {@endtemplate}
abstract interface class SchedulingConfigurer {
  /// {@template SchedulingConfigurer.configure}
  /// Configures scheduled tasks by registering them with the provided registrar.
  /// 
  /// This method is called by the framework during application context
  /// initialization. Implementations should use the registrar to add
  /// scheduled tasks, configure triggers, and set up any task-related
  /// infrastructure.
  /// 
  /// @param schedulingTaskRegistrar The registrar used to add scheduled tasks
  ///        and configure scheduling behavior. Provides methods for registering
  ///        tasks with various trigger types and configurations.
  /// 
  /// Example:
  /// ```dart
  /// @override
  /// void configure(SchedulingTaskRegistrar schedulingTaskRegistrar) {
  ///   // Register multiple task types
  ///   schedulingTaskRegistrar.addFixedRateTask(
  ///     () => cacheService.refresh(),
  ///     Duration(minutes: 10),
  ///   );
  /// 
  ///   schedulingTaskRegistrar.addCronTask(
  ///     () => reportService.generate(),
  ///     '0 0 * * * *', // Hourly
  ///     name: 'hourly-report'
  ///   );
  /// 
  ///   // Register with custom trigger
  ///   schedulingTaskRegistrar.addTriggerTask(
  ///     () => maintenanceService.run(),
  ///     CustomMaintenanceTrigger(),
  ///     name: 'custom-maintenance'
  ///   );
  /// }
  /// ```
  /// 
  /// Implementation Notes:
  /// - This method is called exactly once during application startup
  /// - The registrar should not be retained beyond this method call
  /// - Task registration is additive - multiple configurers can register tasks
  /// - The order of configurer execution is not guaranteed
  /// {@endtemplate}
  void configure(SchedulingTaskRegistrar schedulingTaskRegistrar);
}

/// {@template scheduling_task_registrar}
/// A core JetLeaf component responsible for discovering, preparing, and registering
/// scheduled tasks for execution within the framework’s task scheduler.
///
/// The [SchedulingTaskRegistrar] serves as a bridge between JetLeaf’s dependency
/// injection lifecycle and its scheduling subsystem. It gathers all [Runnable] and
/// [RunnableScheduler] instances annotated or registered for scheduling, resolves
/// their triggers, and submits them to the internal [TaskScheduler].
///
/// ## Overview
/// JetLeaf’s scheduling model is designed for high concurrency and fine-grained control.
/// This registrar ensures that all tasks are properly configured, respecting concurrency,
/// queue capacity, and timezone configurations drawn from the [Environment].
///
/// ### Example
/// ```dart
/// void main() async {
///   final environment = Environment();
///   final registrar = SchedulingTaskRegistrar(environment)
///     ..addSchedulingTask(() async => print('Hello from JetLeaf!'), CronTrigger('*/1 * * * *'), 'printJob'))
///
///   await registrar.onReady();
///
///   print('Registered tasks: ${registrar.getScheduledTasks().length}');
///
///   // Shutdown gracefully
///   await registrar.onDestroy();
/// }
/// ```
///
/// This class is part of JetLeaf’s internal lifecycle and is automatically managed
/// by the framework. However, developers extending JetLeaf or building custom scheduling
/// plugins may interact with it directly.
///
/// {@endtemplate}
final class SchedulingTaskRegistrar implements InitializingPod, DisposablePod, ScheduledTaskHolder {
  /// The central JetLeaf [TaskScheduler] instance responsible for executing
  /// registered and resolved tasks.
  ///
  /// By default, JetLeaf initializes this field with an instance of
  /// [ConcurrentTaskScheduler] unless a custom scheduler is supplied.
  /// 
  /// This component is the backbone of JetLeaf’s scheduling infrastructure,
  /// handling concurrency, task queuing, and graceful shutdowns.
  ///
  /// Developers can assign their own scheduler implementation if they
  /// need specialized behavior such as clustered task coordination or
  /// distributed scheduling.
  ///
  /// ### Example
  /// ```dart
  /// registrar.scheduler = ConcurrentTaskScheduler(
  ///   maxConcurrency: 8,
  ///   queueCapacity: 200,
  /// );
  /// ```
  ///
  /// When not explicitly set, JetLeaf automatically initializes a default
  /// scheduler instance during the `onReady` lifecycle phase.
  TaskScheduler? scheduler;

  /// Defines the maximum number of tasks JetLeaf’s scheduler may execute concurrently.
  ///
  /// This property directly controls JetLeaf’s concurrency limit and can be tuned
  /// based on system capabilities or application requirements. Increasing this value
  /// allows more tasks to run simultaneously, while lowering it helps prevent
  /// resource exhaustion.
  ///
  /// The value may be loaded from JetLeaf’s [Environment] using the key:
  /// `SchedulingAnnotationPodProcessor.MAX_CONCURRENCY_PROPERTY_NAME`.
  ///
  /// ### Example
  /// ```dart
  /// registrar.maxConcurrency = 10;
  /// // or via environment property:
  /// // jetleaf.scheduling.max-concurrency=10
  /// ```
  ///
  /// JetLeaf’s [ConcurrentTaskScheduler] uses this value to determine the size
  /// of its worker pool.
  int? maxConcurrency;

  /// The maximum capacity of JetLeaf’s internal task queue before
  /// new tasks are temporarily blocked or rejected.
  ///
  /// This property helps prevent overloading the scheduler by limiting how many
  /// tasks can be enqueued at once. When the queue reaches its capacity,
  /// JetLeaf may either pause task submissions or discard lower-priority ones,
  /// depending on the configured scheduler policy.
  ///
  /// The value can be configured through the JetLeaf [Environment] using:
  /// `SchedulingAnnotationPodProcessor.QUEUE_CAPACITY_PROPERTY_NAME`.
  ///
  /// ### Example
  /// ```dart
  /// registrar.queueCapacity = 500;
  /// // or via environment property:
  /// // jetleaf.scheduling.queue-capacity=500
  /// ```
  ///
  /// Adjusting this value can help maintain system stability under heavy load.
  int? queueCapacity;

  /// The timezone context JetLeaf uses when evaluating time-based [Trigger]s,
  /// such as cron or interval expressions.
  ///
  /// This setting affects how scheduled tasks interpret their timing definitions,
  /// ensuring that triggers align with the correct local or regional timezone.
  ///
  /// If unspecified, JetLeaf defaults to the system timezone.
  ///
  /// The value can be configured via JetLeaf’s [Environment] using:
  /// `SchedulingAnnotationPodProcessor.ZONE_PROPERTY_NAME`.
  ///
  /// ### Example
  /// ```dart
  /// registrar.timezone = 'America/New_York';
  /// // or via environment property:
  /// // jetleaf.scheduling.zone=America/New_York
  /// ```
  ///
  /// Setting this value ensures that time-based tasks execute consistently,
  /// even in distributed or multi-region deployments.
  String? timezone;

  /// An optional prefix applied to automatically generated task names
  /// within JetLeaf’s scheduling subsystem.
  ///
  /// When defined, this prefix is prepended to all task names generated
  /// by [generateName], providing a convenient way to differentiate
  /// scheduled tasks across environments, modules, or application instances.
  ///
  /// The value of this property can also be automatically loaded from
  /// JetLeaf’s [Environment] using the key defined in
  /// [SchedulingAnnotationPodProcessor.NAME_PREFIX_PROPERTY_NAME].
  ///
  /// ### Example
  /// ```dart
  /// registrar.namePrefix = 'production';
  /// final name = registrar.generateName(CronTrigger('*/15 * * * *'));
  /// print(name);
  /// // Output: "production-crontrigger-task-1739548452903-2"
  /// ```
  ///
  /// This property is particularly useful in multi-tenant or clustered
  /// JetLeaf deployments where task identifiers must remain unique and
  /// clearly scoped by application context.
  String? namePrefix;

  /// A set of all successfully registered and active [ScheduledTask]s.
  final Set<ScheduledTask> _scheduledTasks = {};

  /// A temporary set of [RunnableTaskHolder] instances representing
  /// tasks to be scheduled.
  final Map<String, RunnableTaskHolder> _runnableTaskHolders = {};

  /// A temporary set of [RunnableTaskHolder] instances representing
  /// tasks that could not be resolved or scheduled yet.
  final Map<String, ScheduledTask> _unresolvedRunnableTaskHolders = {};

  /// {@macro scheduling_task_registrar}
  /// 
  /// Creates a new [SchedulingTaskRegistrar].
  SchedulingTaskRegistrar();

  /// Logger instance for tracking annotation processing and scheduling activities.
  /// 
  /// Used for:
  /// - Tracing annotation discovery and processing
  /// - Warning about misconfigured scheduling annotations  
  /// - Debugging scheduling trigger configuration
  /// - Monitoring scheduling registration success/failure
  final Log _logger = LogFactory.getLog(SchedulingAnnotationPodProcessor);
  
  @override
  String getPackageName() => PackageNames.CORE;
  
  @override
  Future<void> onReady() async {
    scheduler ??= ConcurrentTaskScheduler(maxConcurrency: maxConcurrency, queueCapacity: queueCapacity);

    if (_runnableTaskHolders.isNotEmpty) {
      for (final holder in _runnableTaskHolders.entries) {
        _addTask(await scheduleTask(holder.value));
      }
    }
  }

  /// Adds a [ScheduledTask] to the active JetLeaf task registry.
  ///
  /// The [scheduledTask] is ignored if `null`.
  Future<void> _addTask(ScheduledTask? scheduledTask) async {
    if (scheduledTask != null) {
      _scheduledTasks.add(scheduledTask);
    }
  }

  /// Attempts to schedule a given [RunnableTaskHolder] using the current [TaskScheduler].
  ///
  /// If the scheduler is not yet initialized, the holder is added to the unresolved list
  /// and retried later during JetLeaf’s readiness phase.
  ///
  /// Returns a [ScheduledTask] instance or `null` if the task already exists.
  Future<ScheduledTask?> scheduleTask(RunnableTaskHolder holder) async {
    final key = holder.scheduling.name;
    ScheduledTask? existing = _unresolvedRunnableTaskHolders.remove(key);
    bool newTask = existing == null;

    if (existing == null) {
      existing = SimpleScheduledTask(holder.run, holder.scheduling.trigger, key);

      if (_logger.getIsTraceEnabled()) {
        _logger.trace("Creating new scheduled task to the registrar [$runtimeType]: $key");
      }
    }

    ScheduledTask? task;

    if (scheduler != null) {
      if (_logger.getIsTraceEnabled()) {
        _logger.trace("Adding new scheduled task to the registrar [$runtimeType]: $key");
      }

      task = await scheduler!.schedule(holder.run, holder.scheduling.trigger, key);
    } else {
      _unresolvedRunnableTaskHolders.add(key, existing);
    }

    return newTask ? task : null;
  }

  /// Registers a [Runnable] instance with a specific [Trigger] and optional [name].
  ///
  /// This method is used when registering JetLeaf-managed task objects
  /// that implement the [Runnable] interface. These are often created through
  /// annotated components or programmatic configuration.
  ///
  /// The provided [trigger] defines when and how the task should execute,
  /// while the optional [name] can help identify the task in the JetLeaf
  /// scheduling dashboard or logs.
  ///
  /// ### Example
  /// ```dart
  /// final task = MyRunnableTask();
  /// registrar.addRunnableTask(task, CronTrigger('*/5 * * * *'), 'fiveMinJob');
  /// ```
  void addRunnableTask(Runnable runnable, Trigger trigger, String name) {
    _runnableTaskHolders.add(name, RunnableTaskHolder(runnable, (name: name, trigger: trigger)));
  }

  /// Registers a [RunnableScheduler] function as a scheduled JetLeaf task.
  ///
  /// This is a convenience method for function-based tasks instead of class-based
  /// [Runnable]s. JetLeaf will automatically wrap the provided function into a
  /// [_SimplifiedRunnable] so it can be managed consistently by the scheduler.
  ///
  /// ### Example
  /// ```dart
  /// registrar.addSchedulingTask(
  ///   () async => print('Running periodic cleanup...'),
  ///   CronTrigger('0 0 * * *'),
  ///   'dailyCleanup',
  /// );
  /// ```
  void addSchedulingTask(RunnableScheduler scheduler, Trigger trigger, String name) {
    _runnableTaskHolders.add(name, RunnableTaskHolder(_SimplifiedRunnable(scheduler), (name: name, trigger: trigger)));
  }

  /// Registers a cron-based task defined by a [RunnableScheduler] function.
  ///
  /// This method is a shortcut for creating cron triggers using JetLeaf’s
  /// [TriggerBuilder]. The provided [expression] defines the cron schedule
  /// (e.g., `'0 * * * *'` for every hour).
  ///
  /// The [timezone] configured in this registrar is automatically applied.
  ///
  /// ### Example
  /// ```dart
  /// registrar.addCronTask(
  ///   () async => print('Hourly data sync'),
  ///   '0 * * * *',
  ///   'hourlySync',
  /// );
  /// ```
  void addCronTask(RunnableScheduler scheduler, String expression, String name) {
    final trigger = TriggerBuilder(expression: expression, zone: timezone).getTrigger();
    _runnableTaskHolders.add(name, RunnableTaskHolder(_SimplifiedRunnable(scheduler), (name: name, trigger: trigger)));
  }

  /// Registers a cron-based task implemented as a [Runnable] instance.
  ///
  /// This variant is intended for cases where the task is an instantiated JetLeaf
  /// component rather than a function. The cron [expression] defines the schedule.
  ///
  /// ### Example
  /// ```dart
  /// final task = DataBackupTask();
  /// registrar.addRunnableCronTask(task, '0 2 * * *', 'nightlyBackup');
  /// ```
  void addRunnableCronTask(Runnable runnable, String expression, String name) {
    final trigger = TriggerBuilder(expression: expression, zone: timezone).getTrigger();
    _runnableTaskHolders.add(name, RunnableTaskHolder(runnable, (name: name, trigger: trigger)));
  }

  /// Registers a fixed-rate repeating task from a [RunnableScheduler].
  ///
  /// The [fixedRate] defines the duration between the *start times* of each execution,
  /// regardless of how long the previous run took. Optionally, [initialDelay]
  /// can specify how long to wait before the first execution.
  ///
  /// ### Example
  /// ```dart
  /// registrar.addFixedRateTask(
  ///   () async => print('Checking heartbeat...'),
  ///   Duration(seconds: 30),
  ///   'heartbeatCheck',
  ///   initialDelay: Duration(seconds: 5),
  /// );
  /// ```
  void addFixedRateTask(RunnableScheduler scheduler, Duration fixedRate, String name, [Duration? initialDelay]) {
    final trigger = TriggerBuilder(fixedRate: fixedRate, zone: timezone, delayPeriod: initialDelay).getTrigger();
    _runnableTaskHolders.add(name, RunnableTaskHolder(_SimplifiedRunnable(scheduler), (name: name, trigger: trigger)));
  }

  /// Registers a fixed-rate repeating task implemented as a [Runnable] class.
  ///
  /// Similar to [addFixedRateTask], but used for JetLeaf components implementing [Runnable].
  ///
  /// ### Example
  /// ```dart
  /// final task = HealthCheckTask();
  /// registrar.addRunnableFixedRateTask(
  ///   task,
  ///   Duration(minutes: 1),
  ///   'healthCheck',
  /// );
  /// ```
  void addRunnableFixedRateTask(Runnable runnable, Duration fixedRate, String name, [Duration? initialDelay]) {
    final trigger = TriggerBuilder(fixedRate: fixedRate, zone: timezone, delayPeriod: initialDelay).getTrigger();
    _runnableTaskHolders.add(name, RunnableTaskHolder(runnable, (name: name, trigger: trigger)));
  }

  /// Registers a fixed-delay task from a [RunnableScheduler].
  ///
  /// Unlike fixed-rate tasks, fixed-delay tasks wait until the previous execution
  /// finishes, then delay by [fixedDelay] before starting the next one.
  /// Optionally, [initialDelay] specifies the startup delay.
  ///
  /// ### Example
  /// ```dart
  /// registrar.addFixedDelayTask(
  ///   () async => await cleanupTempFiles(),
  ///   Duration(minutes: 10),
  ///   name: 'cleanupTempFiles',
  /// );
  /// ```
  void addFixedDelayTask(RunnableScheduler scheduler, Duration fixedDelay, String name, [Duration? initialDelay]) {
    final trigger = TriggerBuilder(fixedDelay: fixedDelay, zone: timezone, delayPeriod: initialDelay).getTrigger();
    _runnableTaskHolders.add(name, RunnableTaskHolder(_SimplifiedRunnable(scheduler), (name: name, trigger: trigger)));
  }

  /// Registers a fixed-delay task using a [Runnable] JetLeaf component.
  ///
  /// ### Example
  /// ```dart
  /// final task = LogCompactorTask();
  /// registrar.addRunnableFixedDelayTask(
  ///   task,
  ///   Duration(minutes: 15),
  ///   name: 'logCompactor',
  /// );
  /// ```
  void addRunnableFixedDelayTask(Runnable runnable, Duration fixedDelay, String name, [Duration? initialDelay]) {
    final trigger = TriggerBuilder(fixedDelay: fixedDelay, zone: timezone, delayPeriod: initialDelay).getTrigger();
    _runnableTaskHolders.add(name, RunnableTaskHolder(runnable, (name: name, trigger: trigger)));
  }

  /// Registers a periodic task using a [RunnableScheduler] function.
  ///
  /// The [period] determines how frequently the task repeats.
  /// This is often used for simple repeating jobs that don't require
  /// complex trigger logic.
  ///
  /// ### Example
  /// ```dart
  /// registrar.addPeriodicTask(
  ///   () async => print('Performing routine health check...'),
  ///   Duration(seconds: 45),
  ///   'routineCheck',
  /// );
  /// ```
  void addPeriodicTask(RunnableScheduler scheduler, Duration period, String name) {
    final trigger = TriggerBuilder(period: period, zone: timezone).getTrigger();
    _runnableTaskHolders.add(name, RunnableTaskHolder(_SimplifiedRunnable(scheduler), (name: name, trigger: trigger)));
  }

  /// Registers a periodic task implemented as a [Runnable] component.
  ///
  /// This allows existing JetLeaf-managed [Runnable] pods to be scheduled
  /// at a fixed [period].
  ///
  /// ### Example
  /// ```dart
  /// final task = MetricsReporter();
  /// registrar.addRunnablePeriodicTask(task, Duration(minutes: 2), 'metricsReporter');
  /// ```
  void addRunnablePeriodicTask(Runnable runnable, Duration period, String name) {
    final trigger = TriggerBuilder(period: period, zone: timezone).getTrigger();
    _runnableTaskHolders.add(name, RunnableTaskHolder(runnable, (name: name, trigger: trigger)));
  }

  @override
  Future<void> onDestroy() async {
    for (final task in _scheduledTasks) {
      await task.cancel(false);
    }

    if (scheduler != null) {
      await scheduler!.shutdown(false);
    }
  }

  @override
  List<ScheduledTask> getScheduledTasks() => List<ScheduledTask>.unmodifiable(_scheduledTasks);

  @override
  bool hasScheduledTasks() => _scheduledTasks.isNotEmpty;

  /// Checks whether any runnable tasks have been registered for scheduling.
  ///
  /// Returns `true` if [_runnableTaskHolders] contains entries.
  bool hasTasks() => _runnableTaskHolders.isNotEmpty;
}

/// {@template runnable_task_holder}
/// A private internal container class used within the JetLeaf scheduling subsystem
/// to encapsulate a [Runnable] task along with its associated [SchedulingTrigger].
///
/// This class provides equality and hash-code semantics based on
/// the scheduling trigger details and the runtime type of the contained runnable,
/// enabling JetLeaf’s internal task scheduler to efficiently deduplicate or compare tasks.
///
/// ## Usage in JetLeaf
/// In JetLeaf, tasks are often wrapped by the framework for delayed or repeated execution.
/// `_RunnableTaskHolder` ensures that each scheduled task can be compared, stored, and managed
/// within JetLeaf’s execution context.
///
/// ### Example
/// ```dart
/// final runnable = _SimplifiedRunnable(() async => print('Running task'));
/// final scheduling = (trigger: CronTrigger('*/5 * * * *'), name: 'fiveMinTask');
///
/// final holder = _RunnableTaskHolder(runnable, scheduling);
///
/// // When triggered by JetLeaf:
/// await holder.run();
/// ```
///
/// This class is typically used internally by JetLeaf’s scheduling components
/// and not intended for direct use by most application developers.
/// {@endtemplate}
final class RunnableTaskHolder with EqualsAndHashCode implements Runnable {
  /// The runnable task to be executed within JetLeaf’s task runtime.
  final Runnable _runnable;

  /// The trigger configuration defining when this task should be executed.
  ///
  /// This includes both the [Trigger] instance (such as cron-based, interval-based, etc.)
  /// and an optional name used for identification in JetLeaf’s scheduling dashboard.
  final SchedulingTrigger scheduling;

  /// {@macro runnable_task_holder}
  /// 
  /// Creates a new instance of [RunnableTaskHolder].
  ///
  /// This constructor binds a [Runnable] with its corresponding [SchedulingTrigger],
  /// forming a unified scheduling unit recognized by JetLeaf’s scheduler.
  RunnableTaskHolder(this._runnable, this.scheduling);

  /// Executes the wrapped [Runnable]’s [run] method.
  ///
  /// This method is invoked by JetLeaf’s task execution pipeline when
  /// the associated [SchedulingTrigger] fires.
  @override
  FutureOr<void> run() => _runnable.run();

  /// Returns the list of properties used to determine equality and hash code.
  ///
  /// JetLeaf uses this to identify tasks uniquely within the scheduling subsystem.
  /// It includes trigger zone, runtime types, and trigger names.
  @override
  List<Object?> equalizedProperties() => [
    scheduling.trigger.getZone(),
    scheduling.name,
    _runnable
  ];

  @override
  String toString() => "RunnableTaskHolder($_runnable, ${scheduling.name}, ${scheduling.trigger})";
}

/// {@template simplified_runnable}
/// A simplified adapter that allows a [RunnableScheduler] function to be executed
/// as a [Runnable] within JetLeaf.
///
/// This lightweight wrapper is often used internally when developers schedule
/// raw asynchronous or synchronous functions through JetLeaf’s scheduler API,
/// converting them into [Runnable] objects compatible with JetLeaf’s runtime.
///
/// ### Example
/// ```dart
/// final simpleTask = _SimplifiedRunnable(() async {
///   print('Executing JetLeaf task...');
/// });
///
/// await simpleTask.run();
/// ```
///
/// This class bridges the gap between Dart functions and JetLeaf’s structured
/// scheduling mechanism, providing a unified interface for all runnable tasks.
/// {@endtemplate}
final class _SimplifiedRunnable with EqualsAndHashCode implements Runnable {
  /// The scheduler callback that defines what the runnable executes.
  ///
  /// Typically, this is a function passed by JetLeaf when a developer registers
  /// a task using the JetLeaf scheduler APIs.
  final RunnableScheduler scheduler;

  /// {@macro simplified_runnable}
  /// 
  /// Creates a new [_SimplifiedRunnable] that wraps the provided [RunnableScheduler].
  ///
  /// This allows JetLeaf’s scheduler to execute bare Dart functions
  /// within the framework’s standardized task execution pipeline.
  _SimplifiedRunnable(this.scheduler);

  /// Executes the [scheduler] function.
  ///
  /// JetLeaf invokes this method when it runs a task wrapped by this class.
  @override
  FutureOr<void> run() => scheduler();

  @override
  List<Object?> equalizedProperties() => [scheduler, runtimeType];
}

/// A record type representing a JetLeaf scheduling trigger configuration.
///
/// It pairs a [Trigger] object, defining the scheduling conditions (like cron or fixed-rate),
/// with an optional `name` that serves as a descriptive identifier.
///
/// Example:
/// ```dart
/// final trigger = (trigger: CronTrigger('0 0 * * *'), name: 'dailyMidnightJob');
/// print(trigger.name); // dailyMidnightJob
/// ```
typedef SchedulingTrigger = ({Trigger trigger, String name});