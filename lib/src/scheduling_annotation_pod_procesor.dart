import 'package:jetleaf_env/env.dart';
import 'package:jetleaf_lang/lang.dart';
import 'package:jetleaf_logging/logging.dart';
import 'package:jetleaf_pod/pod.dart';
import 'package:jetleaf_core/context.dart';
import 'package:jetleaf_core/core.dart';

import 'annotations.dart';
import 'exceptions.dart';
import 'task/default_scheduling_task_name_generator.dart';
import 'task/scheduled_task.dart';
import 'task/concurrent_task_scheduler.dart';
import 'task/scheduled_task_holder.dart';
import 'task/scheduling_task_name_generator.dart';
import 'trigger/trigger.dart';
import 'trigger/trigger_builder.dart';
import 'runnable_scheduled_method.dart';
import 'task/task_scheduler.dart';
import 'scheduling_configurer.dart';

/// {@template SchedulingAnnotationPodProcessor}
/// Core processor that detects and schedules methods annotated with scheduling annotations.
/// 
/// This processor scans all pods for methods annotated with `@Scheduled`, `@Cron`, 
/// and `@Periodic` annotations, validates their configuration, and registers them
/// with the appropriate task scheduler. It handles the complete lifecycle of scheduled
/// tasks including initialization, execution, and destruction.
/// 
/// ## Key Responsibilities
/// 
/// - **Annotation Processing**: Scans for and processes scheduling annotations on methods
/// - **Trigger Configuration**: Converts annotation properties into appropriate triggers
/// - **Task Registration**: Registers scheduled methods with the task scheduler
/// - **Lifecycle Management**: Manages task startup and shutdown with application context
/// - **Configuration Integration**: Processes programmatic scheduling configuration
/// - **Error Handling**: Validates annotation configuration and provides meaningful errors
/// 
/// ## Supported Annotations
/// 
/// - `@Scheduled`: Supports cron expressions, fixed rates, and fixed delays
/// - `@Cron`: Specialized cron expression scheduling
/// - `@Periodic`: Simple fixed-period scheduling
/// 
/// ## Configuration Properties
/// 
/// The processor supports the following environment properties:
/// - `jetleaf.scheduler.maxConcurrency`: Maximum concurrent task executions
/// - `jetleaf.scheduler.queueCapacity`: Task queue capacity
/// - `jetleaf.scheduler.timezone`: Default timezone for scheduling
/// - `jetleaf.scheduler.name-prefix`: Prefix for generated task names
/// 
/// ## Integration Points
/// 
/// - Implements `ApplicationContextAware` for context access
/// - Implements `SmartInitializingSingleton` for post-construction initialization
/// - Implements `Ordered` to control processing order
/// - Implements `ApplicationEventListener` for context lifecycle events
/// - Implements `DisposablePod` for resource cleanup
/// - Implements `ScheduledTaskHolder` for task management and monitoring
/// 
/// Example:
/// ```dart
/// @EnableScheduling
/// @Configuration
/// class AppConfig {
///   @Pod
///   SchedulingAnnotationPodProcessor schedulingProcessor(TaskScheduler scheduler) {
///     return SchedulingAnnotationPodProcessor(scheduler);
///   }
/// }
/// 
/// @Service
/// class MyScheduledService {
///   @Scheduled(fixedRate: 5000)
///   void runEvery5Seconds() {
///     // This method will be automatically scheduled
///   }
/// }
/// ```
/// {@endtemplate}
final class SchedulingAnnotationPodProcessor extends PodInitializationProcessor implements PodDestructionProcessor, ApplicationContextAware, SmartInitializingSingleton, Ordered, ApplicationEventListener<ApplicationContextEvent>, DisposablePod, ScheduledTaskHolder {
  /// {@template SchedulingAnnotationPodProcessorConstants}
  /// Constants and configuration properties for the scheduling annotation processor.
  /// 
  /// This section defines all the constants, configuration property names,
  /// and internal state management structures used by the scheduling processor.
  /// These constants control the behavior and configuration of scheduled task
  /// processing throughout the JetLeaf framework.
  /// {@endtemplate}

  /// Pod name for the task scheduler pod in the application context.
  /// 
  /// This constant identifies the task scheduler pod that will be used
  /// for executing all scheduled tasks. If no custom task scheduler is
  /// provided, a default one will be created and registered with this name.
  static const String TASK_SCHEDULER_POD_NAME = "resource.taskScheduler";

  /// Pod name for this scheduling annotation processor in the application context.
  /// 
  /// This constant identifies the scheduling annotation processor pod
  /// that scans for and processes scheduling annotations throughout the
  /// application context.
  static const String SCHEDULING_ANNOTATION_AWARE_PROCESSOR_POD_NAME = "resource.schedulingAnnotationProcessor";

  /// {@template MaxConcurrencyProperty}
  /// Environment property name for configuring maximum concurrent task executions.
  /// 
  /// This property controls the maximum number of scheduled tasks that can
  /// execute simultaneously. This helps prevent resource exhaustion when
  /// many scheduled tasks are configured.
  /// 
  /// **Property Format**: `jetleaf.scheduler.maxConcurrency`
  /// **Expected Value**: Positive integer
  /// **Default**: Platform-dependent (typically based on available processors)
  /// 
  /// Example configuration:
  /// ```properties
  /// jetleaf.scheduler.maxConcurrency=10
  /// ```
  /// 
  /// Usage in code:
  /// ```dart
  /// final maxConcurrency = environment.getPropertyAs<int>(
  ///   SchedulingAnnotationPodProcessor.MAX_CONCURRENCY_PROPERTY_NAME, 
  ///   Class<int>(null, PackageNames.DART)
  /// );
  /// ```
  /// {@endtemplate}
  static const String MAX_CONCURRENCY_PROPERTY_NAME = "jetleaf.scheduler.maxConcurrency";

  /// {@template QueueCapacityProperty}
  /// Environment property name for configuring task queue capacity.
  /// 
  /// This property controls the maximum number of tasks that can be queued
  /// waiting for execution when all worker threads are busy. This helps
  /// prevent memory exhaustion under high load conditions.
  /// 
  /// **Property Format**: `jetleaf.scheduler.queueCapacity`
  /// **Expected Value**: Positive integer
  /// **Default**: Platform-dependent or unlimited if not specified
  /// 
  /// Example configuration:
  /// ```properties
  /// jetleaf.scheduler.queueCapacity=1000
  /// ```
  /// 
  /// Usage in code:
  /// ```dart
  /// final queueCapacity = environment.getPropertyAs<int>(
  ///   SchedulingAnnotationPodProcessor.QUEUE_CAPACITY_PROPERTY_NAME,
  ///   Class<int>(null, PackageNames.DART)
  /// );
  /// ```
  /// {@endtemplate}
  static const String QUEUE_CAPACITY_PROPERTY_NAME = "jetleaf.scheduler.queueCapacity";

  /// {@template TimezoneProperty}
  /// Environment property name for configuring the default scheduling timezone.
  /// 
  /// This property sets the default timezone for all scheduled tasks that
  /// don't explicitly specify a timezone in their annotations. This ensures
  /// consistent scheduling behavior across different deployment environments.
  /// 
  /// **Property Format**: `jetleaf.scheduler.timezone`
  /// **Expected Value**: IANA timezone identifier (e.g., 'UTC', 'America/New_York')
  /// **Default**: System default timezone
  /// 
  /// Example configuration:
  /// ```properties
  /// jetleaf.scheduler.timezone=UTC
  /// jetleaf.scheduler.timezone=America/New_York
  /// jetleaf.scheduler.timezone=Europe/London
  /// ```
  /// 
  /// Usage in code:
  /// ```dart
  /// final timezone = environment.getPropertyAs<String>(
  ///   SchedulingAnnotationPodProcessor.ZONE_PROPERTY_NAME,
  ///   Class<String>(null, PackageNames.DART)
  /// );
  /// ```
  /// {@endtemplate}
  static const String ZONE_PROPERTY_NAME = "jetleaf.scheduler.timezone";

  /// {@template NamePrefixProperty}
  /// Environment property name for configuring task name prefixes.
  /// 
  /// This property sets a prefix that will be added to all generated task names.
  /// This is useful for distinguishing tasks from different applications or
  /// environments in shared monitoring systems.
  /// 
  /// **Property Format**: `jetleaf.scheduler.name-prefix`
  /// **Expected Value**: String (alphanumeric with hyphens recommended)
  /// **Default**: No prefix (uses annotation-based naming)
  /// 
  /// Example configuration:
  /// ```properties
  /// jetleaf.scheduler.name-prefix=myapp-production
  /// jetleaf.scheduler.name-prefix=user-service
  /// ```
  /// 
  /// When this property is set, task names will follow the pattern:
  /// `{prefix}-{methodName}` instead of the default hierarchical naming.
  /// 
  /// Usage in code:
  /// ```dart
  /// final namePrefix = environment.getPropertyAs<String>(
  ///   SchedulingAnnotationPodProcessor.NAME_PREFIX_PROPERTY_NAME,
  ///   Class<String>(null, PackageNames.DART)
  /// );
  /// ```
  /// {@endtemplate}
  static const String NAME_PREFIX_PROPERTY_NAME = "jetleaf.scheduler.name-prefix";

  /// {@template SchedulingProcessorLogger}
  /// Logger instance for tracking annotation processing and scheduling activities.
  /// 
  /// This logger provides comprehensive logging for all scheduling-related
  /// operations, including annotation discovery, task registration, execution
  /// monitoring, and error handling. Log levels are used appropriately to
  /// balance detail with performance.
  /// 
  /// **Logging Categories**:
  /// - **TRACE**: Detailed annotation processing and task registration
  /// - **DEBUG**: Task execution starts and completions
  /// - **INFO**: Significant lifecycle events (processor ready, shutdown)
  /// - **WARN**: Configuration issues and recoverable errors
  /// - **ERROR**: Unrecoverable errors and task execution failures
  /// 
  /// Example log output:
  /// ```
  /// TRACE: Searching for scheduled methods in package:example/test.dart.UserService
  /// TRACE: Method cleanupInactiveUsers has [Scheduled] annotation
  /// DEBUG: Executing task user-cleanup at 2023-10-01T10:00:00Z
  /// INFO: Scheduling annotation processor initialized successfully
  /// ```
  /// 
  /// Configuration through logging framework:
  /// ```dart
  /// // Enable trace logging for scheduling diagnostics
  /// LogFactory.configure(level: Level.TRACE, categories: ['SchedulingAnnotationPodProcessor']);
  /// ```
  /// {@endtemplate}
  final Log _logger = LogFactory.getLog(SchedulingAnnotationPodProcessor);

  /// {@template QualifiedAnnotatedClassNames}
  /// Tracks qualified class names that have been processed for scheduling annotations.
  /// 
  /// This set prevents duplicate processing of the same classes across multiple
  /// lifecycle events or context refreshes. Each class is identified by its
  /// fully qualified name to ensure uniqueness across the application.
  /// 
  /// **Contents**: Fully qualified class names (e.g., 'package:example/test.dart.UserService')
  /// **Usage**: Prevents redundant annotation scanning
  /// **Thread Safety**: Accessed only during controlled lifecycle phases
  /// 
  /// Example:
  /// ```dart
  /// if (_qualifiedAnnotatedClassNames.add(podClass.getQualifiedName())) {
  ///   // Process this class for the first time
  ///   await _scanForScheduledMethods(podClass);
  /// }
  /// ```
  /// {@endtemplate}
  final Set<String> _qualifiedAnnotatedClassNames = {};

  /// {@template QualifiedAnnotatedClasses}
  /// Tracks class objects that have been processed for scheduling annotations.
  /// 
  /// This set provides an additional check using class identity to complement
  /// the qualified name tracking. This ensures robust duplicate prevention
  /// even in complex class loading scenarios.
  /// 
  /// **Contents**: Class metadata objects
  /// **Usage**: Secondary duplicate prevention mechanism
  /// **Thread Safety**: Accessed only during controlled lifecycle phases
  /// 
  /// Example:
  /// ```dart
  /// if (_qualifiedAnnotatedClasses.add(podClass)) {
  ///   // Process this class instance for the first time
  ///   await _processSchedulingAnnotations(podClass);
  /// }
  /// ```
  /// {@endtemplate}
  final Set<Class> _qualifiedAnnotatedClasses = {};

  /// {@template ScheduledTasksMap}
  /// Maps pod instances to their associated scheduled tasks for lifecycle management.
  /// 
  /// This mapping is essential for proper resource cleanup when pods are
  /// destroyed. Each pod that contains scheduled methods has an entry in
  /// this map linking the pod instance to its scheduled task.
  /// 
  /// **Key**: Pod instance (Object)
  /// **Value**: ScheduledTask managing the method execution
  /// **Usage**: Task cancellation during pod destruction
  /// **Thread Safety**: Single-threaded during lifecycle events
  /// 
  /// Example usage during destruction:
  /// ```dart
  /// final task = _scheduledTasks.remove(pod);
  /// if (task != null) {
  ///   await task.cancel(true); // Cancel with interruption
  /// }
  /// ```
  /// {@endtemplate}
  final Map<Object, ScheduledTask> _scheduledTasks = {};

  /// {@template UnregisteredTaskHolders}
  /// Holds tasks that couldn't be registered immediately due to scheduler unavailability.
  /// 
  /// During application startup, some tasks may be discovered before the
  /// task scheduler is fully initialized. These tasks are stored in this
  /// set and processed once the scheduler becomes available.
  /// 
  /// **Contents**: _Task objects containing task configuration and metadata
  /// **Usage**: Deferred task registration
  /// **Lifecycle**: Cleared after successful registration attempts
  /// 
  /// Example:
  /// ```dart
  /// if (_taskScheduler == null) {
  ///   // Store for later registration
  ///   _unregisteredTaskHolders.add(task);
  /// } else {
  ///   // Register immediately
  ///   await _registerTask(task);
  /// }
  /// ```
  /// {@endtemplate}
  final Set<_LocalTask> _unregisteredTaskHolders = {};

  /// {@template MaxConcurrency}
  /// Maximum concurrent task executions loaded from environment configuration.
  /// 
  /// This value is loaded from the `jetleaf.scheduler.maxConcurrency` property
  /// during processor initialization. It controls how many scheduled tasks
  /// can execute simultaneously in the task scheduler.
  /// 
  /// **Type**: Optional integer (null if not specified)
  /// **Effect**: Limits parallel task execution
  /// **Default**: Determined by the task scheduler implementation
  /// 
  /// Example:
  /// ```dart
  /// _maxConcurrency = environment.getPropertyAs<int>(
  ///   MAX_CONCURRENCY_PROPERTY_NAME, 
  ///   Class<int>(null, PackageNames.DART)
  /// );
  /// ```
  /// {@endtemplate}
  int? _maxConcurrency;

  /// {@template QueueCapacity}
  /// Task queue capacity loaded from environment configuration.
  /// 
  /// This value is loaded from the `jetleaf.scheduler.queueCapacity` property
  /// during processor initialization. It determines how many tasks can be
  /// queued when all worker threads are busy.
  /// 
  /// **Type**: Optional integer (null if not specified)
  /// **Effect**: Controls backpressure under high load
  /// **Default**: Determined by the task scheduler implementation
  /// 
  /// Example:
  /// ```dart
  /// _queueCapacity = environment.getPropertyAs<int>(
  ///   QUEUE_CAPACITY_PROPERTY_NAME,
  ///   Class<int>(null, PackageNames.DART)
  /// );
  /// ```
  /// {@endtemplate}
  int? _queueCapacity;

  /// {@template Timezone}
  /// Default timezone for scheduling loaded from environment configuration.
  /// 
  /// This value is loaded from the `jetleaf.scheduler.timezone` property
  /// during processor initialization. It provides a default timezone for
  /// all scheduled tasks that don't explicitly specify one.
  /// 
  /// **Type**: Optional string (null if not specified)
  /// **Format**: IANA timezone identifier
  /// **Default**: System default timezone
  /// 
  /// Example:
  /// ```dart
  /// _timezone = environment.getPropertyAs<String>(
  ///   ZONE_PROPERTY_NAME,
  ///   Class<String>(null, PackageNames.DART)
  /// );
  /// ```
  /// {@endtemplate}
  String? _timezone;

  /// {@template TaskScheduler}
  /// The task scheduler used to register and execute scheduled methods.
  /// 
  /// This scheduler is the core component responsible for managing the
  /// execution timing and lifecycle of all scheduled tasks. It can be
  /// either a custom scheduler provided through dependency injection
  /// or a default scheduler created by the processor.
  /// 
  /// **Responsibilities**:
  /// - Executing tasks according to their triggers
  /// - Managing thread pools and task queues
  /// - Handling task lifecycle (start, cancel, shutdown)
  /// - Providing execution statistics and monitoring
  /// 
  /// **Initialization**: Set during `_setupTaskSchedulerIfAvailable()`
  /// **Thread Safety**: Implementations must be thread-safe
  /// **Lifecycle**: Shutdown during processor destruction
  /// 
  /// Example usage:
  /// ```dart
  /// if (_taskScheduler == null) {
  ///   // Create default scheduler
  ///   _taskScheduler = ConcurrentTaskScheduler(
  ///     maxConcurrency: _maxConcurrency,
  ///     queueCapacity: _queueCapacity
  ///   );
  /// }
  /// ```
  /// {@endtemplate}
  TaskScheduler? _taskScheduler;

  /// {@template SchedulingTaskRegistrar}
  /// Registrar for programmatic task configuration through SchedulingConfigurer.
  /// 
  /// This registrar collects task registrations from all `SchedulingConfigurer`
  /// implementations and processes them during application initialization.
  /// It provides a fluent API for programmatically defining scheduled tasks.
  /// 
  /// **Features**:
  /// - Collects tasks from multiple configurers
  /// - Provides configuration inheritance from environment
  /// - Manages task registration order and dependencies
  /// - Handles both annotation-based and programmatic tasks
  /// 
  /// **Initialization**: Created during processor construction
  /// **Usage**: Populated by configurers, executed during initialization
  /// 
  /// Example configuration through registrar:
  /// ```dart
  /// _schedulingTaskRegistrar.addFixedRateTask(
  ///   () => cacheService.refresh(),
  ///   Duration(minutes: 5),
  ///   name: 'cache-refresh'
  /// );
  /// ```
  /// {@endtemplate}
  SchedulingTaskRegistrar _schedulingTaskRegistrar = SchedulingTaskRegistrar();

  /// {@template SchedulingTaskNameGenerator}
  /// Generator for creating meaningful and unique task names.
  /// 
  /// This component is responsible for generating descriptive names for
  /// scheduled tasks based on their source class and method. Names are
  /// used for logging, monitoring, and task management.
  /// 
  /// **Default Behavior**: Uses `DefaultSchedulingTaskNameGenerator`
  /// **Customization**: Can be replaced through dependency injection
  /// **Name Patterns**: Supports both hierarchical and prefix-based naming
  /// 
  /// **Initialization**: Set during `_setupTaskNameGeneratorIfAvailable()`
  /// **Fallback**: Default generator used if no custom one provided
  /// 
  /// Example name generation:
  /// ```dart
  /// final taskName = _schedulingTaskNameGenerator.generate(userServiceClass, cleanupMethod);
  /// // Result: "scheduled-userservice-cleanupinactiveusers"
  /// ```
  /// {@endtemplate}
  SchedulingTaskNameGenerator? _schedulingTaskNameGenerator;

  /// {@template ApplicationContext}
  /// The application context for pod lookup and environment access.
  /// 
  /// This reference provides access to the application context for:
  /// - Looking up pods (TaskScheduler, SchedulingTaskNameGenerator, etc.)
  /// - Accessing environment properties and configuration
  /// - Receiving application lifecycle events
  /// - Integration with other framework components
  /// 
  /// **Initialization**: Set through `ApplicationContextAware` interface
  /// **Thread Safety**: Application context implementations are thread-safe
  /// **Lifecycle**: Managed by the framework container
  /// 
  /// Example usage:
  /// ```dart
  /// if (_applicationContext != null) {
  ///   final scheduler = await _applicationContext!.get(Class<TaskScheduler>());
  ///   _taskScheduler = scheduler;
  /// }
  /// ```
  /// {@endtemplate}
  ApplicationContext? _applicationContext;

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
  String? _namePrefix;

  /// {@macro SchedulingAnnotationPodProcessor}
  SchedulingAnnotationPodProcessor();

  @override
  int getOrder() => Ordered.LOWEST_PRECEDENCE;

  @override
  void setApplicationContext(ApplicationContext applicationContext) {
    _applicationContext = applicationContext;
  }

  @override
  Future<void> onApplicationEvent(ApplicationContextEvent event) async {
    if (event.getApplicationContext() == _applicationContext) {
      if (event is ContextRefreshedEvent) {
        await _completeInitialization();
      }
    }
  }
  
  @override
  bool supportsEventOf(ApplicationEvent event) => event is ContextClosedEvent || event is ContextRefreshedEvent;
  
  @override
  String getPackageName() => PackageNames.CORE;
  
  @override
  Future<void> onSingletonReady() async {
    _qualifiedAnnotatedClassNames.clear();
    _qualifiedAnnotatedClasses.clear();
  }

  /// {@template CompleteInitialization}
  /// Completes the initialization process for the scheduling annotation processor.
  /// 
  /// This method orchestrates the complete setup sequence for the scheduling
  /// infrastructure. It loads configuration, sets up required components,
  /// processes programmatic task configurations, and handles any tasks that
  /// couldn't be registered during initial processing.
  /// 
  /// ## Initialization Sequence
  /// 
  /// 1. **Configuration Loading**: Loads scheduling properties from environment
  /// 2. **Scheduler Setup**: Configures task scheduler (custom or default)
  /// 3. **Name Generator Setup**: Configures task name generation
  /// 4. **Configurer Processing**: Processes programmatic task configurations
  /// 5. **Deferred Task Registration**: Registers tasks that were deferred
  /// 6. **Registrar Finalization**: Finalizes the scheduling task registrar
  /// 
  /// ## Error Handling
  /// 
  /// If any step fails, the initialization process stops and the error
  /// is propagated, preventing the application from starting with
  /// misconfigured scheduling.
  /// 
  /// Example:
  /// ```dart
  /// // During application startup:
  /// await schedulingProcessor._completeInitialization();
  /// // All scheduled tasks are now ready for execution
  /// ```
  /// {@endtemplate}
  Future<void> _completeInitialization() async {
    await _loadConfiguration();
    await _setupTaskSchedulerIfAvailable();
    await _setupTaskNameGeneratorIfAvailable();
    await _processSchedulingConfigurers();

    if (_unregisteredTaskHolders.isNotEmpty) {
      for (final task in _unregisteredTaskHolders) {
        await _scheduleUnregisteredTasks(task);
      }
    }

    await _schedulingTaskRegistrar.onReady();
  }

  /// {@template LoadConfiguration}
  /// Loads scheduling configuration from environment properties.
  /// 
  /// This method retrieves scheduling-specific configuration properties
  /// from the application environment and applies them to both the
  /// processor and the task registrar. Configuration is loaded in a
  /// specific order with proper fallback behavior.
  /// 
  /// ## Configuration Properties Loaded
  /// 
  /// - `jetleaf.scheduler.maxConcurrency`: Maximum concurrent executions
  /// - `jetleaf.scheduler.queueCapacity`: Task queue capacity  
  /// - `jetleaf.scheduler.timezone`: Default scheduling timezone
  /// 
  /// ## Configuration Inheritance
  /// 
  /// Properties are first loaded into the processor, then propagated
  /// to the task registrar if not already set. This allows configurers
  /// to override defaults while maintaining environment fallbacks.
  /// 
  /// Example environment configuration:
  /// ```properties
  /// jetleaf.scheduler.maxConcurrency=10
  /// jetleaf.scheduler.queueCapacity=1000
  /// jetleaf.scheduler.timezone=UTC
  /// ```
  /// {@endtemplate}
  Future<void> _loadConfiguration() async {
    if (_applicationContext != null) {
      final environment = _applicationContext!.getEnvironment();
      
      _namePrefix = _namePrefix ?? environment.getProperty(SchedulingAnnotationPodProcessor.NAME_PREFIX_PROPERTY_NAME);
      _maxConcurrency = environment.getPropertyAs<int>(MAX_CONCURRENCY_PROPERTY_NAME, Class<int>(null, PackageNames.DART));
      _queueCapacity = environment.getPropertyAs<int>(QUEUE_CAPACITY_PROPERTY_NAME, Class<int>(null, PackageNames.DART));
      _timezone = environment.getPropertyAs<String>(ZONE_PROPERTY_NAME, Class<String>(null, PackageNames.DART));
      
      _schedulingTaskRegistrar.maxConcurrency ??= _maxConcurrency;
      _schedulingTaskRegistrar.queueCapacity ??= _queueCapacity;
      _schedulingTaskRegistrar.timezone ??= _timezone;
      _schedulingTaskRegistrar.namePrefix ??= _namePrefix;
    }
  }

  /// {@template SetupTaskSchedulerIfAvailable}
  /// Sets up the task scheduler, using a custom one if available or creating a default.
  /// 
  /// This method attempts to locate a custom `TaskScheduler` pod in the
  /// application context. If found, it uses that scheduler. If no custom
  /// scheduler is available, it creates a default `ConcurrentTaskScheduler`
  /// with the configured concurrency and queue capacity.
  /// 
  /// ## Scheduler Resolution Order
  /// 
  /// 1. **Custom Scheduler**: Look for `TaskScheduler` pod in context
  /// 2. **Default Scheduler**: Create `ConcurrentTaskScheduler` with configuration
  /// 
  /// ## Integration Points
  /// 
  /// - The scheduler is shared between annotation-based and programmatic tasks
  /// - Both the processor and registrar reference the same scheduler instance
  /// - Scheduler lifecycle is managed by the processor
  /// 
  /// Example custom scheduler configuration:
  /// ```dart
  /// @Configuration
  /// class SchedulingConfig {
  ///   @Pod
  ///   TaskScheduler taskScheduler() {
  ///     return CustomTaskScheduler(
  ///       maxConcurrency: 20,
  ///       queueCapacity: 5000
  ///     );
  ///   }
  /// }
  /// ```
  /// {@endtemplate}
  Future<void> _setupTaskSchedulerIfAvailable() async {
    if (_applicationContext != null) {
      final cls = Class<TaskScheduler>(null, PackageNames.CORE);
      if (await _applicationContext!.containsType(cls)) {
        final scheduler = await _applicationContext!.get(cls);
        _taskScheduler = scheduler;
        _schedulingTaskRegistrar.scheduler = scheduler;
      }
    }
    
    // Set default scheduler if none found
    if (_taskScheduler == null) {
      _taskScheduler = ConcurrentTaskScheduler(maxConcurrency: _maxConcurrency, queueCapacity: _queueCapacity);
      _schedulingTaskRegistrar.scheduler = _taskScheduler;
    }
  }

  /// {@template SetupTaskNameGeneratorIfAvailable}
  /// Sets up the task name generator, using a custom one if available.
  /// 
  /// This method attempts to locate a custom `SchedulingTaskNameGenerator`
  /// pod in the application context. If found, it uses that generator
  /// for all task naming. If no custom generator is available, the
  /// processor will use the default generator when tasks are scheduled.
  /// 
  /// ## Name Generator Benefits
  /// 
  /// - **Consistency**: Uniform naming across all scheduled tasks
  /// - **Identification**: Meaningful names for logging and monitoring
  /// - **Customization**: Application-specific naming conventions
  /// - **Uniqueness**: Prevention of task name collisions
  /// 
  /// Example custom name generator:
  /// ```dart
  /// @Configuration
  /// class NamingConfig {
  ///   @Pod
  ///   SchedulingTaskNameGenerator taskNameGenerator() {
  ///     return CustomTaskNameGenerator(prefix: 'myapp');
  ///   }
  /// }
  /// ```
  /// {@endtemplate}
  Future<void> _setupTaskNameGeneratorIfAvailable() async {
    if (_applicationContext != null) {
      final cls = Class<SchedulingTaskNameGenerator>(null, PackageNames.CORE);
      if (await _applicationContext!.containsType(cls)) {
        final nameGenerator = await _applicationContext!.get(cls);
        _schedulingTaskNameGenerator = nameGenerator;
      }
    }
  }

  /// {@template ProcessSchedulingConfigurers}
  /// Processes all registered scheduling configurers in proper order.
  /// 
  /// This method discovers all `SchedulingConfigurer` pods in the
  /// application context, sorts them according to their `@Order` annotation
  /// or `Ordered` interface implementation, and invokes their configuration
  /// methods to register programmatic scheduled tasks.
  /// 
  /// ## Configurer Processing Flow
  /// 
  /// 1. **Discovery**: Find all `SchedulingConfigurer` pods in context
  /// 2. **Sorting**: Order configurers by priority (lowest first)
  /// 3. **Execution**: Invoke `configure()` on each configurer in order
  /// 4. **Error Handling**: Log and propagate configuration errors
  /// 
  /// ## Ordering Importance
  /// 
  /// Configurer ordering ensures that:
  /// - Infrastructure tasks are registered before application tasks
  /// - Dependent tasks can rely on previously registered tasks
  /// - Configuration overrides work predictably
  /// 
  /// Example configurer with ordering:
  /// ```dart
  /// @Configuration
  /// @Order(Ordered.HIGHEST_PRECEDENCE)
  /// class InfrastructureSchedulingConfig implements SchedulingConfigurer {
  ///   @override
  ///   void configure(SchedulingTaskRegistrar registrar) {
  ///     // Register infrastructure tasks first
  ///   }
  /// }
  /// ```
  /// {@endtemplate}
  Future<void> _processSchedulingConfigurers() async {
    if (_applicationContext != null) {
      final cls = Class<SchedulingConfigurer>(null, PackageNames.CORE);
      final schedulingPods = await _applicationContext!.getPodsOf(cls);
      final configurers = List<SchedulingConfigurer>.from(schedulingPods.values);
      AnnotationAwareOrderComparator.sort(configurers);

      for (final configurer in configurers) {
        try {
          configurer.configure(_schedulingTaskRegistrar);
          if (_logger.getIsTraceEnabled()) {
            _logger.trace('Processed configuration for ${configurer.runtimeType}');
          }
        } catch (e, stackTrace) {
          if (_logger.getIsErrorEnabled()) {
            _logger.error('Failed to process configuration for ${configurer.runtimeType}', error: e, stacktrace: stackTrace);
          }

          rethrow;
        }
      }
    }
  }

  /// {@template ScheduleUnregisteredTasks}
  /// Schedules tasks that couldn't be registered immediately due to scheduler unavailability.
  /// 
  /// During the initial annotation scanning phase, some tasks may be
  /// discovered before the task scheduler is ready. These tasks are
  /// stored in `_unregisteredTaskHolders` and processed once the
  /// scheduler becomes available during final initialization.
  /// 
  /// ## Deferred Registration Scenarios
  /// 
  /// - Tasks discovered before scheduler pod is initialized
  /// - Circular dependencies between scheduler and scheduled pods
  /// - Custom schedulers that initialize asynchronously
  /// 
  /// ## Registration Process
  /// 
  /// 1. **Check Availability**: Verify scheduler is now available
  /// 2. **Task Registration**: Register task through scheduling registrar
  /// 3. **Tracking**: Add task to scheduled tasks map for lifecycle management
  /// 4. **Logging**: Provide detailed logging for registration outcomes
  /// 
  /// Example deferred task scenario:
  /// ```dart
  /// @Service
  /// class EarlyService {
  ///   // This task may be discovered before scheduler is ready
  ///   @Scheduled(fixedRate: 5000)
  ///   void earlyTask() { ... }
  /// }
  /// ```
  /// {@endtemplate}
  Future<void> _scheduleUnregisteredTasks(_LocalTask task) async {
    final name = task.task.scheduling.name;
    final method = task.method;

    if (_taskScheduler == null) {
      if (_logger.getIsTraceEnabled()) {
        _logger.trace("Skipping ${task.type} schedule method ${method.getName()} of the unregistered task: $name since [TaskScheduler] is not enabled yet.");
      }
    } else {
      final scheduledTask = await _schedulingTaskRegistrar.scheduleTask(task.task);

      if (scheduledTask != null) {
        _scheduledTasks.add(task.pod, scheduledTask);

        if (_logger.getIsTraceEnabled()) {
          _logger.trace("Successfully added unregistered ${task.type} schedule method ${method.getName()} as task: $name");
        }
      } else if (_logger.getIsTraceEnabled()) {
        _logger.trace("Couldn't add unregistered method ${method.getName()} of ${task.type} schedule but task reference not available (may be pending): $name");
      }
    }
  }

  @override
  Future<Object?> processAfterInitialization(Object pod, Class podClass, String name) async {
    if (_qualifiedAnnotatedClassNames.add(podClass.getQualifiedName()) || _qualifiedAnnotatedClasses.add(podClass)) {
      if (_logger.getIsTraceEnabled()) {
        _logger.trace("Searching for scheduled methods in ${podClass.getQualifiedName()}");
      }

      await _loadConfiguration();

      List<Method> cronMethods = [];
      List<Method> scheduledMethods = [];
      List<Method> periodicMethods = [];

      for (final method in podClass.getMethods()) {
        if (method.hasDirectAnnotation<Scheduled>()) {
          await _processScheduledAnnotation(pod, podClass, method, name, scheduledMethods);
        } else if (method.hasDirectAnnotation<Cron>()) {
          await _processCronAnnotation(pod, podClass, method, name, cronMethods);
        } else if (method.hasDirectAnnotation<Periodic>()) {
          await _processPeriodicAnnotation(pod, podClass, method, name, periodicMethods);
        }
      }

      _logProcessedMethods(podClass, name, scheduledMethods, cronMethods, periodicMethods);
    }

    return super.processAfterInitialization(pod, podClass, name);
  }

  /// {@template ProcessScheduledAnnotation}
  /// Processes methods annotated with `@Scheduled` and configures their execution triggers.
  /// 
  /// This method handles the `@Scheduled` annotation which supports multiple
  /// scheduling strategies through different properties. It validates the
  /// annotation configuration, resolves the appropriate trigger, and schedules
  /// the method for execution.
  /// 
  /// ## Supported @Scheduled Properties
  /// 
  /// - `cron`: Cron expression for time-based scheduling
  /// - `type`: Pre-defined cron type with expression
  /// - `fixedRate`: Fixed rate execution (start to start)
  /// - `fixedDelay`: Fixed delay execution (end to start)
  /// 
  /// ## Validation Rules
  /// 
  /// - Only one scheduling property can be specified
  /// - Timezone resolution: annotation zone → environment zone → system default
  /// - Trigger must be resolvable from the provided properties
  /// 
  /// Example valid annotations:
  /// ```dart
  /// @Scheduled(cron: '0 0 * * * *')          // Every hour
  /// @Scheduled(fixedRate: 5000)              // Every 5 seconds
  /// @Scheduled(fixedDelay: 10000)            // 10 seconds after completion
  /// @Scheduled(cron: '0 0 9 * * *', zone: 'America/New_York')  // 9 AM New York time
  /// ```
  /// {@endtemplate}
  Future<void> _processScheduledAnnotation(Object pod, Class podClass, Method method, String podName, List<Method> scheduledMethods) async {
    if (_logger.getIsTraceEnabled()) {
      _logger.trace("Method ${method.getName()} of class ${podClass.getQualifiedName()} has [Scheduled] annotation");
    }

    final scheduled = method.getDirectAnnotation<Scheduled>();
    if (scheduled == null) return;

    // Validate scheduling options
    final options = [
      if (scheduled.cron != null) 'cron',
      if (scheduled.type != null) 'type',
      if (scheduled.fixedRate != null) 'fixedRate',
      if (scheduled.fixedDelay != null) 'fixedDelay',
    ];

    if (options.length > 1) {
      throw SchedulerException(
        "Method ${method.getName()} of class ${podClass.getQualifiedName()} has multiple scheduling options: "
        "${options.join(', ')}. Only one of them is allowed.",
      );
    }

    final zone = scheduled.zone ?? _timezone;
    Trigger? trigger;

    if (scheduled.cron != null) {
      trigger = TriggerBuilder(expression: scheduled.cron!, zone: zone).getTrigger();
    } else if (scheduled.type != null) {
      trigger = TriggerBuilder(expression: scheduled.type!.expression, zone: zone).getTrigger();
    } else if (scheduled.fixedRate != null) {
      trigger = TriggerBuilder(fixedRate: scheduled.fixedRate!, zone: zone).getTrigger();
    } else if (scheduled.fixedDelay != null) {
      trigger = TriggerBuilder(fixedDelay: scheduled.fixedDelay!, zone: zone).getTrigger();
    }

    if (trigger != null) {
      await _scheduleMethod(pod, podClass, method, trigger, podName, "scheduled");
      scheduledMethods.add(method);
    } else {
      _logger.warn("Method ${method.getName()} of class ${podClass.getQualifiedName()} has [Scheduled] annotation but no valid trigger was found.");
    }
  }

  /// {@template ProcessCronAnnotation}
  /// Processes methods annotated with `@Cron` for cron expression-based scheduling.
  /// 
  /// This method handles the `@Cron` annotation which provides specialized
  /// cron expression scheduling. It supports both direct cron expressions
  /// and pre-defined cron types for common scheduling patterns.
  /// 
  /// ## Supported @Cron Properties
  /// 
  /// - `expression`: Direct cron expression string
  /// - `type`: Pre-defined cron type with built-in expression
  /// - `zone`: Timezone for cron expression evaluation
  /// 
  /// ## Validation Rules
  /// 
  /// - Either `expression` or `type` must be provided, but not both
  /// - Cron expressions must be valid and parseable
  /// - Timezone resolution follows the same precedence as @Scheduled
  /// 
  /// Example valid annotations:
  /// ```dart
  /// @Cron(expression: '0 0 * * * *')                    // Every hour
  /// @Cron(type: CronType.HOURLY)                        // Using pre-defined type
  /// @Cron(expression: '0 0 9 * * *', zone: 'UTC')      // 9 AM UTC
  /// ```
  /// {@endtemplate}
  Future<void> _processCronAnnotation(Object pod, Class podClass, Method method, String podName, List<Method> cronMethods) async {
    if (_logger.getIsTraceEnabled()) {
      _logger.trace("Method ${method.getName()} of class ${podClass.getQualifiedName()} has [Cron] annotation");
    }

    final cron = method.getDirectAnnotation<Cron>();
    if (cron == null) return;

    if (cron.expression != null && cron.type != null) {
      throw SchedulerException("Method ${method.getName()} of class ${podClass.getQualifiedName()} has both [expression] and [type] value. Only one of them is allowed");
    }

    final zone = cron.zone ?? _timezone;
    Trigger? trigger;

    if (cron.expression != null) {
      trigger = TriggerBuilder(expression: cron.expression!, zone: zone).getTrigger();
    } else if (cron.type != null) {
      trigger = TriggerBuilder(expression: cron.type!.expression, zone: zone).getTrigger();
    }

    if (trigger != null) {
      await _scheduleMethod(pod, podClass, method, trigger, podName, "cron");
      cronMethods.add(method);
    } else {
      _logger.warn("Method ${method.getName()} of class ${podClass.getQualifiedName()} has [Cron] annotation but no valid trigger was found.");
    }
  }

  /// {@template ProcessPeriodicAnnotation}
  /// Processes methods annotated with `@Periodic` for simple interval-based scheduling.
  /// 
  /// This method handles the `@Periodic` annotation which provides a
  /// simplified interface for fixed-rate scheduling with a single duration
  /// parameter. It's ideal for simple recurring tasks without complex
  /// cron expression requirements.
  /// 
  /// ## @Periodic Characteristics
  /// 
  /// - **Simple Configuration**: Single `period` parameter
  /// - **Fixed Rate**: Executions occur at fixed intervals
  /// - **TimeZone Aware**: Supports optional timezone specification
  /// - **No Initial Delay**: First execution occurs after initial period
  /// 
  /// Example valid annotations:
  /// ```dart
  /// @Periodic(Duration(seconds: 30))                    // Every 30 seconds
  /// @Periodic(Duration(minutes: 5))                     // Every 5 minutes  
  /// @Periodic(Duration(hours: 1), zone: 'Europe/London') // Every hour in London time
  /// ```
  /// 
  /// ## Comparison with @Scheduled(fixedRate)
  /// 
  /// While similar to `@Scheduled(fixedRate)`, `@Periodic` provides:
  /// - Cleaner syntax for simple interval scheduling
  /// - Dedicated semantic meaning for periodic tasks
  /// - Consistent naming with other framework periodic constructs
  /// {@endtemplate}
  Future<void> _processPeriodicAnnotation(Object pod, Class podClass, Method method, String podName, List<Method> periodicMethods) async {
    if (_logger.getIsTraceEnabled()) {
      _logger.trace("Method ${method.getName()} of class ${podClass.getQualifiedName()} has [Periodic] annotation");
    }

    final periodic = method.getDirectAnnotation<Periodic>();
    if (periodic == null) return;

    final trigger = TriggerBuilder(period: periodic.period, zone: periodic.zone ?? _timezone);
    await _scheduleMethod(pod, podClass, method, trigger.getTrigger(), podName, "periodic");
    periodicMethods.add(method);
  }

  /// {@template ScheduleMethod}
  /// Schedules a method for execution with the given trigger and configuration.
  /// 
  /// This method is the central point for registering any scheduled method
  /// regardless of the annotation type. It handles task creation, naming,
  /// and registration with the appropriate scheduling infrastructure.
  /// 
  /// ## Task Creation Process
  /// 
  /// 1. **Runnable Creation**: Wrap method in `RunnableScheduledMethod`
  /// 2. **Name Generation**: Generate descriptive task name
  /// 3. **Task Holder Creation**: Create `RunnableTaskHolder` with configuration
  /// 4. **Registration**: Register with scheduler or defer if unavailable
  /// 
  /// ## Name Generation Strategy
  /// 
  /// Task names are generated using the following precedence:
  /// 1. Custom `SchedulingTaskNameGenerator` if available
  /// 2. Default `DefaultSchedulingTaskNameGenerator` with pod context
  /// 
  /// Example generated names:
  /// ```dart
  /// // With DefaultSchedulingTaskNameGenerator
  /// "scheduled-userservice-cleanupinactiveusers"
  /// "cron-reportservice-generatedailyreport"  
  /// "periodic-cacheservice-refreshcache"
  /// ```
  /// 
  /// ## Deferred Registration
  /// 
  /// If the task scheduler is not yet available, tasks are stored in
  /// `_unregisteredTaskHolders` and processed during final initialization.
  /// This handles cases where annotation scanning occurs before scheduler
  /// initialization is complete.
  /// {@endtemplate}
  Future<void> _scheduleMethod(Object pod, Class cls, Method method, Trigger trigger, String podName, String type) async {
    final runnable = RunnableScheduledMethod(pod, method);
    final nameGenerator = _schedulingTaskNameGenerator ?? DefaultSchedulingTaskNameGenerator(podName, type, _namePrefix);
    final name = nameGenerator.generate(cls, method);
    final task = RunnableTaskHolder(runnable, (name: name, trigger: trigger));
    
    if (_taskScheduler == null) {
      _unregisteredTaskHolders.add(_LocalTask(pod: pod, cls: cls, method: method, trigger: trigger, podName: podName, type: type, task: task));

      if (_logger.getIsTraceEnabled()) {
        _logger.trace("Adding $type schedule method ${method.getName()} as an unregistered task: $name");
      }
    } else {
      final scheduledTask = await _schedulingTaskRegistrar.scheduleTask(task);

      if (scheduledTask != null) {
        _scheduledTasks.add(pod, scheduledTask);

        if (_logger.getIsTraceEnabled()) {
          _logger.trace("Successfully added $type schedule method ${method.getName()} as task: $name");
        }
      } else if (_logger.getIsTraceEnabled()) {
        _logger.trace("Couldnt't add method ${method.getName()} of $type schedule but task reference not available (may be pending): $name");
      }
    }
  }

  /// {@template LogProcessedMethods}
  /// Logs a summary of processed scheduling methods for a given class.
  /// 
  /// This method provides trace-level logging that summarizes the annotation
  /// processing results for a specific class. It helps with debugging and
  /// monitoring by showing exactly which scheduling annotations were found
  /// and processed for each component.
  /// 
  /// ## Logging Output
  /// 
  /// The method generates separate log entries for each annotation type:
  /// - `@Scheduled` methods count and details
  /// - `@Cron` methods count and details  
  /// - `@Periodic` methods count and details
  /// 
  /// ## Conditional Logging
  /// 
  /// Logging only occurs when:
  /// - Trace logging is enabled for this logger
  /// - At least one method of a given type was processed
  /// - The class actually contained scheduling annotations
  /// 
  /// Example log output:
  /// ```
  /// TRACE: Processed 2 @Scheduled methods in userService for package:example/test.dart.UserService
  /// TRACE: Processed 1 @Cron methods in reportService for package:example/test.dart.ReportService
  /// TRACE: Processed 1 @Periodic methods in cacheService for package:example/test.dart.CacheService
  /// ```
  /// 
  /// ## Performance Considerations
  /// 
  /// - Method counting is efficient (O(1) for list length)
  /// - String building is deferred until trace level is confirmed
  /// - No reflection or expensive operations in logging path
  /// {@endtemplate}
  void _logProcessedMethods(Class podClass, String name, List<Method> scheduledMethods, List<Method> cronMethods, List<Method> periodicMethods) {
    if (_logger.getIsTraceEnabled()) {
      if (scheduledMethods.isNotEmpty) {
        _logger.trace("Processed ${scheduledMethods.length} @Scheduled methods in $name for ${podClass.getQualifiedName()}");
      }
      if (cronMethods.isNotEmpty) {
        _logger.trace("Processed ${cronMethods.length} @Cron methods in $name for ${podClass.getQualifiedName()}");
      }
      if (periodicMethods.isNotEmpty) {
        _logger.trace("Processed ${periodicMethods.length} @Periodic methods in $name for ${podClass.getQualifiedName()}");
      }
    }
  }
  
  @override
  Future<void> processAfterDestruction(Object pod, Class podClass, String name) async {}
  
  @override
  Future<void> processBeforeDestruction(Object pod, Class podClass, String name) async {
    return Future.value([await _cancelScheduledTasks(pod)]);
  }

  /// {@template CancelScheduledTasks}
  /// Cancels all scheduled tasks associated with a specific pod instance.
  /// 
  /// This method is called during pod destruction to ensure proper cleanup
  /// of scheduled tasks. It removes the task from tracking and requests
  /// cancellation with interruption to prevent lingering executions.
  /// 
  /// ## Cancellation Behavior
  /// 
  /// - **Immediate Removal**: Task is removed from `_scheduledTasks` map
  /// - **Forced Cancellation**: `cancel(true)` requests immediate interruption
  /// - **Async Handling**: Returns Future for proper async cancellation
  /// - **Error Resilience**: Continues even if individual task cancellation fails
  /// 
  /// ## Lifecycle Integration
  /// 
  /// This method is called from:
  /// - `processBeforeDestruction()` during pod lifecycle
  /// - `onDestroy()` during processor shutdown
  /// - Error recovery paths when pods fail initialization
  /// 
  /// Example cancellation scenario:
  /// ```dart
  /// // When UserService pod is destroyed:
  /// await _cancelScheduledTasks(userServiceInstance);
  /// // All tasks scheduled on UserService methods are now canceled
  /// ```
  /// 
  /// ## Error Handling
  /// 
  /// - Task cancellation exceptions are caught and logged by the task itself
  /// - Map removal happens before cancellation attempt
  /// - Processor continues with other destruction tasks even if cancellation fails
  /// {@endtemplate}
  Future<void> _cancelScheduledTasks(Object pod) async {
    final task = _scheduledTasks.remove(pod);

    if (task != null) {
      if (_logger.getIsTraceEnabled()) {
        _logger.trace("Cancelling scheduled task of $pod - ${task.getName()}");
      }

      await task.cancel(true);
    }
  }

  @override
  Future<bool> requiresDestruction(Object pod, Class podClass, String name) async {
    return _scheduledTasks.containsKey(pod);
  }
  
  @override
  Future<void> onDestroy() async {
    if (_logger.getIsTraceEnabled()) {
      _logger.trace("Destroying scheduled tasks in $runtimeType");
    }

    await _schedulingTaskRegistrar.onDestroy();
    await _taskScheduler?.shutdown(false);
  }
  
  @override
  List<ScheduledTask> getScheduledTasks() {
    final tasks = <ScheduledTask>{};
    tasks.addAll(_schedulingTaskRegistrar.getScheduledTasks());
    tasks.addAll(_scheduledTasks.values);

    return List<ScheduledTask>.unmodifiable(tasks);
  }
  
  @override
  bool hasScheduledTasks() => getScheduledTasks().isNotEmpty;
}

/// {@template Task}
/// Internal data structure representing a task waiting to be scheduled.
/// 
/// This class holds all the necessary information to schedule a method
/// for execution when the task scheduler becomes available. It serves
/// as a temporary container for tasks discovered during annotation
/// scanning that cannot be immediately registered.
/// 
/// ## Usage Context
/// 
/// Instances of `_Task` are created when:
/// - A scheduling annotation is found during pod processing
/// - The task scheduler is not yet available for registration
/// - The method needs to be deferred for later scheduling
/// 
/// ## Data Composition
/// 
/// Each `_Task` contains:
/// - **Pod Reference**: The object instance containing the scheduled method
/// - **Class Metadata**: Reflection information about the containing class
/// - **Method Metadata**: Reflection information about the scheduled method
/// - **Trigger Configuration**: The resolved trigger for task execution
/// - **Pod Name**: The name of the pod in the application context
/// - **Annotation Type**: Which scheduling annotation was used (@Scheduled, @Cron, @Periodic)
/// - **Task Holder**: The fully configured task ready for scheduling
/// 
/// Example usage in deferred registration:
/// ```dart
/// final task = _Task(
///   pod: userService,
///   cls: userServiceClass,
///   method: cleanupMethod,
///   trigger: cronTrigger,
///   podName: 'userService',
///   type: 'scheduled',
///   task: runnableTaskHolder
/// );
/// _unregisteredTaskHolders.add(task);
/// ```
/// 
/// ## Lifecycle
/// 
/// 1. **Creation**: During annotation processing when scheduler unavailable
/// 2. **Storage**: Added to `_unregisteredTaskHolders` set
/// 3. **Processing**: Retrieved and scheduled during final initialization
/// 4. **Cleanup**: Removed from set after successful registration
/// 
/// ## Thread Safety
/// 
/// - Instances are immutable after creation
/// - All fields are final and properly initialized
/// - Safe for storage in concurrent collections
/// {@endtemplate}
final class _LocalTask {
  /// The pod instance that contains the scheduled method.
  final Object pod;

  /// The class metadata for the pod's type.
  final Class cls;

  /// The method metadata for the scheduled method.
  final Method method;

  /// The trigger that determines when the method should execute.
  final Trigger trigger;

  /// The name of the pod in the application context.
  final String podName;

  /// The type of scheduling annotation (e.g., 'scheduled', 'cron', 'periodic').
  final String type;

  /// The task holder containing the runnable and scheduling configuration.
  final RunnableTaskHolder task;

  /// {@macro Task}
  /// 
  /// Creates a new task instance with all required scheduling information.
  /// 
  /// @param pod The object instance that contains the scheduled method
  /// @param cls The class metadata for type information and reflection
  /// @param method The method metadata for the scheduled method
  /// @param trigger The resolved trigger for task execution timing
  /// @param podName The application context name for the pod
  /// @param type The annotation type for logging and categorization
  /// @param task The configured task holder ready for scheduling
  _LocalTask({
    required this.pod,
    required this.cls,
    required this.method,
    required this.trigger,
    required this.podName,
    required this.type,
    required this.task
  });

  /// Returns a string representation of this task for debugging purposes.
  /// 
  /// Provides a concise summary including the pod name, method name,
  /// annotation type, and trigger information.
  /// 
  /// @return A string representation of the task configuration
  /// 
  /// Example output:
  /// ```dart
  /// '_Task{pod: userService, method: cleanupInactiveUsers, type: scheduled, trigger: CronTrigger{0 0 * * * *}}'
  /// ```
  @override
  String toString() {
    return '_Task{'
        'pod: $pod, '
        'method: ${method.getName()}, '
        'type: $type, '
        'trigger: $trigger'
        '}';
  }
}