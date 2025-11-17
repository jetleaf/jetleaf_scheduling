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
import 'package:meta/meta_meta.dart';
import 'package:jetleaf_core/annotation.dart';

import 'scheduling_configuration.dart';

/// {@template EnableScheduling}
/// Enables scheduled task execution for the application.
/// 
/// When this annotation is present on a configuration class, it activates
/// the scheduling infrastructure, allowing methods annotated with `@Scheduled`
/// and `@Cron` to be automatically detected and executed according to their
/// configured triggers.
/// 
/// This annotation imports the `SchedulingConfiguration` which sets up the
/// necessary pods for task scheduling, including the task scheduler and
/// annotation processors.
/// 
/// ## Usage
/// 
/// Apply this annotation to your main application configuration class to
/// enable scheduling capabilities throughout your application:
/// 
/// ```dart
/// @EnableScheduling
/// @Configuration
/// class AppConfig {
///   // Application configuration pods...
/// }
/// 
/// // Or on your main application class:
/// @EnableScheduling
/// class MyApplication {
///   void run() {
///     final context = AnnotationConfigApplicationContext();
///     context.register(MyApplication);
///     context.refresh();
///   }
/// }
/// ```
/// 
/// ## How It Works
/// 
/// 1. **Infrastructure Setup**: Registers `SchedulingConfiguration` which
///    provides the necessary scheduling infrastructure pods
/// 2. **Annotation Processing**: Enables detection of `@Scheduled` and `@Cron`
///    annotations on methods during component scanning
/// 3. **Task Registration**: Automatically registers detected scheduled methods
///    with the task scheduler
/// 4. **Lifecycle Integration**: Ensures scheduled tasks are properly started
///    and stopped with the application context lifecycle
/// 
/// ## Required Dependencies
/// 
/// To use scheduling, ensure your application has:
/// - A `TaskScheduler` pod available in the context (auto-configured or custom)
/// - The scheduling annotation processor on the classpath
/// - Proper thread pool configuration for your task workload
/// 
/// ## Customization
/// 
/// You can customize scheduling behavior by providing your own configuration:
/// 
/// ```dart
/// @EnableScheduling
/// @Configuration
/// class CustomSchedulingConfig {
///   @Pod
///   TaskScheduler taskScheduler() {
///     return ThreadPoolTaskScheduler()
///       ..setPoolSize(10)
///       ..setThreadNamePrefix('scheduled-task-')
///       ..setWaitForTasksToCompleteOnShutdown(true);
///   }
/// }
/// ```
/// 
/// ## Integration with Other Features
/// 
/// Scheduling works well with other application features:
/// 
/// ```dart
/// @EnableScheduling
/// @EnableCaching
/// @Configuration
/// class FullFeaturedConfig {
///   // Combines scheduling with async execution and caching
/// }
/// 
/// @Service
/// class DataProcessingService {
///   @Scheduled(fixedRate: 30000)
///   Future<void> processData() async {
///     // This method runs asynchronously every 30 seconds
///   }
/// }
/// ```
/// 
/// ## Error Handling
/// 
/// Scheduled methods should handle their own exceptions. Uncaught exceptions
/// will be logged but won't stop the scheduler. For critical tasks, consider
/// implementing retry logic or circuit breakers.
/// 
/// ```dart
/// @Service
/// class RobustScheduledService {
///   @Scheduled(cron: '0 * * * * *')
///   void scheduledTaskWithErrorHandling() {
///     try {
///       // Task logic that might throw exceptions
///     } catch (error, stackTrace) {
///       // Log error and continue - scheduler will run again next minute
///       logger.error('Scheduled task failed', error, stackTrace);
///     }
///   }
/// }
/// ```
/// 
/// ## Testing Considerations
/// 
/// When testing applications with scheduled tasks, you might want to disable
/// scheduling in test profiles:
/// 
/// ```dart
/// @Configuration
/// @Profile('test')
/// class TestConfig {
///   // No @EnableScheduling - tasks won't run during tests
/// }
/// 
/// // Or conditionally enable based on test type
/// @EnableScheduling
/// @Conditional(ProductionCondition)
/// class ProductionConfig {
///   // Scheduling only enabled in production
/// }
/// ```
/// 
/// ## Performance Implications
/// 
/// - Each scheduled method creates a separate scheduled task
/// - Consider the thread pool size based on your concurrent task requirements
/// - Use appropriate trigger types (cron vs fixed rate) based on your needs
/// - Monitor task execution times to identify performance bottlenecks
/// 
/// ## Common Patterns
/// 
/// ```dart
/// // Multiple scheduling strategies in one application
/// @EnableScheduling
/// @Configuration
/// class MultiSchedulerApp {
///   @Pod
///   @Primary
///   TaskScheduler defaultScheduler() => ThreadPoolTaskScheduler();
///   
///   @Pod
///   TaskScheduler backgroundScheduler() {
///     return ThreadPoolTaskScheduler()
///       ..setPoolSize(5)
///       ..setThreadNamePrefix('background-');
///   }
/// }
/// 
/// @Service
/// class MultiScheduledService {
///   // Uses default scheduler
///   @Scheduled(fixedRate: 5000)
///   void frequentTask() {
///     // Runs every 5 seconds
///   }
///   
///   // Uses specific scheduler
///   @Scheduled(cron: '0 0 2 * * *', scheduler: 'backgroundScheduler')
///   void nightlyTask() {
///     // Runs daily at 2 AM on background scheduler
///   }
/// }
/// ```
/// {@endtemplate}
@Target({TargetKind.classType})
@Import([ClassType<SchedulingConfiguration>()])
class EnableScheduling extends ReflectableAnnotation {
  /// {@macro EnableScheduling}
  /// 
  /// Creates an instance of [EnableScheduling] annotation.
  /// 
  /// This annotation activates the scheduling infrastructure when applied
  /// to a configuration class. It requires no parameters as it relies on
  /// auto-configuration and component scanning to set up scheduling.
  /// 
  /// Example:
  /// ```dart
  /// @EnableScheduling
  /// class MyApplication {
  ///   // Application class with scheduling enabled
  /// }
  /// ```
  const EnableScheduling();

  @override
  String toString() => 'EnableScheduler()';

  @override
  Type get annotationType => EnableScheduling;
}

/// {@template _Zoned}
/// Base class for scheduling annotations that support timezone specification.
/// 
/// This abstract class provides the foundation for timezone-aware scheduling
/// annotations in the JetLeaf framework. It encapsulates the timezone
/// configuration that determines how scheduling expressions are interpreted.
/// 
/// ## Timezone Support
/// 
/// Derived annotations can specify a timezone that affects how their
/// scheduling expressions are evaluated:
/// 
/// - **Cron Expressions**: Evaluated in the context of the specified timezone
/// - **Fixed Intervals**: Period calculations respect the timezone for
///   daylight saving time transitions
/// - **Execution Times**: All execution timestamps are recorded in the
///   specified timezone
/// 
/// ## Timezone Format
/// 
/// Timezones should be specified using IANA Time Zone Database identifiers:
/// 
/// - 'UTC': Coordinated Universal Time
/// - 'America/New_York': Eastern Time (US)
/// - 'Europe/London': British Time
/// - 'Asia/Tokyo': Japan Standard Time
/// - 'Australia/Sydney': Australian Eastern Time
/// 
/// ## Inheritance
/// 
/// This class is designed to be extended by specific scheduling annotations
/// that require timezone support. Derived classes should:
/// 
/// - Call the super constructor with the zone parameter
/// - Implement the `annotationType` getter
/// - Provide appropriate documentation for their specific scheduling behavior
/// 
/// Example:
/// ```dart
/// @Target({TargetKind.method})
/// class CustomScheduled extends _Zoned {
///   final String customProperty;
///   
///   const CustomScheduled(this.customProperty, {super.zone});
///   
///   @override
///   Type get annotationType => CustomScheduled;
/// }
/// ```
/// 
/// ## Default Behavior
/// 
/// When no timezone is specified (`zone` is `null`), the system default
/// timezone is used. This is appropriate for many applications but may
/// cause issues with daylight saving time transitions for long-running
/// applications.
/// 
/// ## Best Practices for Timezone Usage
/// 
/// - Specify timezones explicitly for business-critical scheduling
/// - Use 'UTC' for system-level tasks that should run at absolute times
/// - Consider daylight saving time implications for your use case
/// - Test timezone behavior thoroughly in different environments
/// - Document the timezone requirements for your scheduled methods
/// {@endtemplate}
abstract class _Zoned extends ReflectableAnnotation {
  /// The timezone in which the scheduling expression should be evaluated.
  /// 
  /// This optional field specifies the timezone context for the scheduling
  /// annotation. When provided, all time calculations (cron evaluation,
  /// period measurement, execution timing) are performed in this timezone.
  /// 
  /// If not specified (`null`), the system default timezone is used.
  final String? zone;

  /// {@macro _Zoned}
  /// 
  /// Creates a timezone-aware scheduling annotation.
  /// 
  /// @param zone Optional timezone identifier for scheduling calculations.
  ///        Uses IANA timezone format. If `null`, uses system default timezone.
  const _Zoned({this.zone});
}

/// {@template scheduled}
/// Schedules the annotated method for periodic execution.
///
/// This annotation is applied to methods intended to run on a schedule, whether
/// at fixed intervals or at specific times defined by a cron expression.
///
/// ### Fields:
///
/// - [cron]: *(Optional)* A string-based cron expression defining the schedule
///   (e.g., `"0 0 * * * *"`). This expression will only be used if no [Cron]
///   annotation is present on the method.
/// - [fixedRate]: *(Optional)* Runs the method repeatedly with a fixed duration
///   between the *start* of each invocation.
/// - [fixedDelay]: *(Optional)* Runs the method repeatedly with a fixed duration
///   after the *completion* of the previous invocation.
/// - [zone]: *(Optional)* A timezone which will be used to run the schedule.
///
/// **Note:** At least one of [cron], [fixedRate], or [fixedDelay] must be set.
///
/// ### Example:
/// ```dart
/// @Scheduled(fixedRate: Duration(seconds: 10))
/// void heartbeat() {
///   print('Ping every 10 seconds');
/// }
/// ```
///
/// {@endtemplate}
@Target({TargetKind.method})
class Scheduled extends _Zoned with EqualsAndHashCode, ToString {
  /// A cron string expression representing the timing for execution.
  ///
  /// ### Example:
  /// ```dart
  /// @Scheduled(cron: '0 0 * * * *')
  /// void dailyTask() {
  ///   print('Daily task executed');
  /// }
  /// ```
  ///
  /// Supports standard 6-field cron expressions:
  /// ```
  /// ┌───────────── second (0–59)
  /// │ ┌───────────── minute (0–59)
  /// │ │ ┌───────────── hour (0–23)
  /// │ │ │ ┌───────────── day of month (1–31)
  /// │ │ │ │ ┌───────────── month (1–12)
  /// │ │ │ │ │ ┌───────────── day of week (0–6)
  /// │ │ │ │ │ │
  /// * * * * * *
  /// ```
  final String? cron;

  /// A cron type expression representing the timing for execution.
  ///
  /// ### Example:
  /// ```dart
  /// @Scheduled(type: CronType.EVERY_HOUR)
  /// void dailyTask() {
  ///   print('Daily task executed');
  /// }
  /// ```
  final CronType? type;

  /// Executes the method at a constant rate, measured from the start of each call.
  ///
  /// ### Example:
  /// ```dart
  /// @Scheduled(fixedRate: Duration(seconds: 10))
  /// void heartbeat() {
  ///   print('Ping every 10 seconds');
  /// }
  /// ```
  final Duration? fixedRate;

  /// Executes the method after a fixed delay from the previous call's completion.
  ///
  /// ### Example:
  /// ```dart
  /// @Scheduled(fixedDelay: Duration(seconds: 10))
  /// void heartbeat() {
  ///   print('Ping every 10 seconds');
  /// }
  /// ```
  final Duration? fixedDelay;

  /// {@macro scheduled}
  const Scheduled({this.cron, this.type, this.fixedRate, this.fixedDelay, super.zone});

  @override
  List<Object?> equalizedProperties() => [cron, type, fixedRate, fixedDelay, zone];

  @override
  ToStringOptions toStringOptions() => ToStringOptions(
    includeClassName: true,
    customParameterNames: ['cron', 'type', 'fixedRate', 'fixedDelay', 'zone'],
  );

  @override
  Type get annotationType => Scheduled;
}

/// {@template cron}
/// Defines a cron expression for scheduling the annotated method's execution.
///
/// Unlike a raw string, this annotation can also be used in conjunction with
/// [CronExpression] to validate the syntax of the provided expression at
/// compile-time or runtime, depending on implementation.
///
/// ### Field:
///
/// - [expression]: *(Optional)* A cron expression that follows a 6-field UNIX format string,
///   typically used to specify the schedule of job execution. Examples:
///   - `"0 0 * * * *"` - every hour
///   - `"*/15 * * * * *"` - every 15 seconds
///   - `"0 0 12 * * MON"` - at noon every Monday
/// - [zone]: *(Optional)* A timezone which will be used to run the schedule.
/// - [type]: *(Optional)* A [CronType] which contains common values for cron expression.
///
/// ### Constructor:
///
/// Accepts a cron string or a [CronExpression] to provide better validation.
///
/// ### Example:
/// ```dart
/// @Cron('0 0 * * * *') // Executes every hour
/// void cleanTempFiles() {
///   // cleanup logic
/// }
/// ```
///
/// {@endtemplate}
@Target({TargetKind.method})
class Cron extends _Zoned with EqualsAndHashCode, ToString {
  /// A validated cron expression string using the 6-field format.
  ///
  /// ### Example:
  /// ```dart
  /// @Cron('0 0 * * * *') // Executes every hour
  /// void cleanTempFiles() {
  ///   // cleanup logic
  /// }
  /// ```
  ///
  /// Supports standard 6-field cron expressions:
  /// ```
  /// ┌───────────── second (0–59)
  /// │ ┌───────────── minute (0–59)
  /// │ │ ┌───────────── hour (0–23)
  /// │ │ │ ┌───────────── day of month (1–31)
  /// │ │ │ │ ┌───────────── month (1–12)
  /// │ │ │ │ │ ┌───────────── day of week (0–6)
  /// │ │ │ │ │ │
  /// * * * * * *
  /// ```
  final String? expression;

  /// A DSL for common cron expressions.
  ///
  /// ### Example:
  /// ```dart
  /// @Cron(CronType.EVERY_HOUR)
  /// void cleanTempFiles() {
  ///   // cleanup logic
  /// }
  /// ```
  ///
  /// {@macro typedCron}
  final CronType? type;

  /// {@macro cron}
  const Cron({this.expression, this.type, super.zone});

  @override
  Type get annotationType => Cron;

  @override
  List<Object?> equalizedProperties() => [annotationType, expression, type, zone];

  @override
  ToStringOptions toStringOptions() => ToStringOptions(
    includeClassName: true,
    customParameterNames: ['annotationType', 'expression', 'type', 'zone'],
  );
}

/// {@template cron_type}
/// Common cron expression presets for scheduling recurring tasks.
///
/// Each type defines a standard cron expression in the format:
/// ```
/// /**
/// * ┌───────────── second (0–59)
/// * │ ┌───────────── minute (0–59)
/// * │ │ ┌───────────── hour (0–23)
/// * │ │ │ ┌───────────── day of month (1–31)
/// * │ │ │ │ ┌───────────── month (1–12)
/// * │ │ │ │ │ ┌───────────── day of week (0–6) (Sunday=0)
/// * │ │ │ │ │ │
/// * * * * * * *
/// */
/// ```
/// 
/// {@endtemplate}
enum CronType {
  /// Every second.
  EVERY_SECOND('* * * * * *'),

  /// Every 5 seconds.
  EVERY_5_SECONDS('*/5 * * * * *'),

  /// Every 10 seconds.
  EVERY_10_SECONDS('*/10 * * * * *'),

  /// Every 30 seconds.
  EVERY_30_SECONDS('*/30 * * * * *'),

  /// Every minute.
  EVERY_MINUTE('0 * * * * *'),

  /// Every 5 minutes.
  EVERY_5_MINUTES('0 */5 * * * *'),

  /// Every 10 minutes.
  EVERY_10_MINUTES('0 */10 * * * *'),

  /// Every 30 minutes.
  EVERY_30_MINUTES('0 */30 * * * *'),

  /// Every hour on the hour.
  EVERY_HOUR('0 0 * * * *'),

  /// Every 3 hours.
  EVERY_3_HOURS('0 0 */3 * * *'),

  /// Every 6 hours.
  EVERY_6_HOURS('0 0 */6 * * *'),

  /// Every 12 hours (noon and midnight).
  EVERY_12_HOURS('0 0 */12 * * *'),

  /// Once daily at midnight.
  DAILY_AT_MIDNIGHT('0 0 0 * * *'),

  /// Once daily at noon.
  DAILY_AT_NOON('0 0 12 * * *'),

  /// Once daily at 6 AM.
  DAILY_AT_6AM('0 0 6 * * *'),

  /// Once daily at 6 PM.
  DAILY_AT_6PM('0 0 18 * * *'),

  /// Every weekday (Mon–Fri) at 9 AM.
  WEEKDAYS_AT_9AM('0 0 9 * * 1-5'),

  /// Every Saturday at midnight.
  WEEKLY_ON_SATURDAY_MIDNIGHT('0 0 0 * * 6'),

  /// Every Sunday at midnight.
  WEEKLY_ON_SUNDAY_MIDNIGHT('0 0 0 * * 0'),

  /// Every Monday at 9 AM.
  WEEKLY_ON_MONDAY_9AM('0 0 9 * * 1'),

  /// First day of every month at midnight.
  MONTHLY_ON_FIRST_MIDNIGHT('0 0 0 1 * *'),

  /// First day of every month at 9 AM.
  MONTHLY_ON_FIRST_9AM('0 0 9 1 * *'),

  /// Last day of every month at midnight.
  MONTHLY_ON_LAST_MIDNIGHT('0 0 0 L * *'),

  /// Every January 1st at midnight (New Year’s).
  YEARLY_ON_JAN1_MIDNIGHT('0 0 0 1 1 *'),

  /// Every July 1st at midnight (mid-year).
  YEARLY_ON_JULY1_MIDNIGHT('0 0 0 1 7 *');

  /// The cron expression string.
  final String expression;

  /// {@macro cron_type}
  const CronType(this.expression);
}

/// {@template Periodic}
/// Annotation that marks a method to be executed periodically at a fixed rate.
/// 
/// This annotation schedules a method to run repeatedly with a fixed time period
/// between the start of each execution. The period is measured from the start
/// of one execution to the start of the next, regardless of how long the
/// method takes to complete.
/// 
/// ## Usage Examples
/// 
/// ```dart
/// @Service
/// class MonitoringService {
///   // Run every 30 seconds in system default timezone
///   @Periodic(Duration(seconds: 30))
///   void healthCheck() {
///     // Check system health every 30 seconds
///   }
/// 
///   // Run every 5 minutes in UTC timezone
///   @Periodic(Duration(minutes: 5), zone: 'UTC')
///   void metricsCollection() {
///     // Collect and report metrics every 5 minutes
///   }
/// 
///   // Run every hour in New York timezone
///   @Periodic(Duration(hours: 1), zone: 'America/New_York')
///   void businessHourTask() {
///     // Execute during New York business hours
///   }
/// }
/// ```
/// 
/// ## Timezone Considerations
/// 
/// When a timezone is specified, the period is calculated relative to
/// that timezone. This is particularly important for longer periods
/// that may span daylight saving time transitions:
/// 
/// ```dart
/// // This task will run daily at the same local time in New York,
/// // adjusting automatically for daylight saving time
/// @Periodic(Duration(days: 1), zone: 'America/New_York')
/// void dailyReport() {
///   // Generate daily report at same local time each day
/// }
/// ```
/// 
/// ## Comparison with Other Scheduling Annotations
/// 
/// - **vs @Scheduled(fixedRate)**: Similar behavior, but @Periodic is
///   dedicated to fixed-rate scheduling with simpler configuration
/// - **vs @Scheduled(fixedDelay)**: Fixed delay waits for completion
///   before scheduling next execution, while fixed rate runs at
///   fixed intervals regardless of completion
/// - **vs @Cron**: Cron provides calendar-based scheduling, while
///   @Periodic provides simple interval-based scheduling
/// 
/// ## Error Handling
/// 
/// Exceptions thrown by periodic methods are caught and logged by the
/// scheduler, but do not stop subsequent executions. The method will
/// continue to be called according to the fixed rate schedule:
/// 
/// ```dart
/// @Periodic(Duration(minutes: 1))
/// void sometimesFailingTask() {
///   if (Random().nextBool()) {
///     throw Exception('Random failure');
///   }
///   // This method will continue running every minute despite occasional failures
/// }
/// ```
/// 
/// ## Best Practices
/// 
/// - Use for tasks that should run at consistent intervals regardless of
///   execution time
/// - Consider method execution time relative to period to avoid overlapping
/// - Use appropriate timezone for business-hour sensitive tasks
/// - Implement proper error handling within the method
/// - Consider using @Async for long-running periodic tasks
/// - Monitor execution times to ensure they don't exceed the period
/// 
/// ## Performance Considerations
/// 
/// - Each periodic method creates a separate scheduled task
/// - Consider thread pool size when many periodic tasks run concurrently
/// - Monitor for overlapping executions that may consume excessive resources
/// - Use appropriate period durations based on task criticality and resources
/// 
/// ## Testing
/// 
/// ```dart
/// test('periodic task execution', () async {
///   final scheduler = TestTaskScheduler();
///   final service = MonitoringService();
///   
///   // Test that method is scheduled with correct period
///   expect(scheduler.getPeriod('healthCheck'), Duration(seconds: 30));
/// });
/// ```
/// {@endtemplate}
@Target({TargetKind.method})
class Periodic extends _Zoned {
  /// The fixed time period between the start of each execution.
  /// 
  /// This duration defines the interval between successive executions
  /// of the annotated method. The scheduler will attempt to invoke the
  /// method at this fixed rate, measured from the start of one execution
  /// to the start of the next.
  /// 
  /// The period must be a positive duration. Very short periods (under
  /// 100 milliseconds) may not be supported by all scheduler implementations.
  final Duration period;

  /// {@macro Periodic}
  /// 
  /// Creates a periodic scheduling annotation with the specified period.
  /// 
  /// @param period The fixed time period between executions. Must be positive.
  /// @param zone Optional timezone identifier for period calculation.
  ///        Uses IANA timezone format (e.g., 'UTC', 'America/New_York').
  ///        If not specified, uses the system default timezone.
  /// 
  /// Example:
  /// ```dart
  /// // Basic usage with duration only
  /// @Periodic(Duration(minutes: 5))
  /// void everyFiveMinutes() { }
  /// 
  /// // With timezone specification
  /// @Periodic(Duration(hours: 1), zone: 'Europe/London')
  /// void hourlyInLondon() { }
  /// ```
  const Periodic(this.period, {super.zone});

  /// Returns the runtime type of this annotation.
  /// 
  /// @return The [Periodic] type
  @override
  Type get annotationType => Periodic;
}