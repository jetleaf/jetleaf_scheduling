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

/// {@template jetleaf_scheduling_library}
/// JetLeaf Scheduling Library - Comprehensive task scheduling and execution framework.
///
/// This library provides a robust scheduling infrastructure for JetLeaf applications,
/// enabling time-based task execution, cron expressions, periodic triggers, and
/// concurrent task management. It integrates seamlessly with JetLeaf's core
/// dependency injection and aspect-oriented programming capabilities.
///
/// The scheduling library supports various scheduling patterns:
/// - **Fixed Rate**: Execute at fixed intervals regardless of previous execution completion
/// - **Fixed Delay**: Execute with fixed delay between completion and next start
/// - **Cron Expressions**: Complex scheduling using Unix-style cron patterns
/// - **Periodic**: Simple recurring execution with configurable initial delay
///
/// ## Example: Scheduled Task Configuration
///
/// ```dart
/// @Pod
/// class ScheduledTasks {
///   @Scheduled(fixedRate: 5000) // Every 5 seconds
///   void performHealthCheck() {
///     // Health check logic
///     _healthService.checkSystemHealth();
///   }
///
///   @Scheduled(cron: '0 0 2 * * *') // Daily at 2 AM
///   void generateDailyReport() {
///     // Report generation logic
///     _reportService.generateDailyReport();
///   }
///
///   @Scheduled(fixedDelay: 10000, initialDelay: 5000) // 10s delay after 5s initial
///   void processQueue() {
///     // Queue processing logic
///     _queueService.processPendingItems();
///   }
/// }
/// ```
///
/// ## Example: Custom Task Scheduler
///
/// ```dart
/// @Pod
/// class CustomSchedulingConfigurer implements SchedulingConfigurer {
///   @override
///   void configureTasks(ScheduledTaskRegistrar registrar) {
///     registrar.addFixedRateTask(
///       ScheduledTask(
///         name: 'CustomTask',
///         runnable: _customTask,
///         initialDelay: Duration(seconds: 10),
///         interval: Duration(minutes: 5)
///       )
///     );
///   }
///
///   Future<void> _customTask() async {
///     // Custom task implementation
///     await _customService.executeBusinessLogic();
///   }
/// }
/// ```
/// {@endtemplate}
library;

// Core scheduling infrastructure and configuration
export 'src/scheduling_configuration.dart';
export 'src/scheduling_configurer.dart';
export 'src/runnable_scheduled_method.dart';
export 'src/scheduling_annotation_pod_procesor.dart';

// Task execution and management components
export 'src/task/concurrent_task_scheduler.dart';
export 'src/task/default_scheduling_task_name_generator.dart';
export 'src/task/default_task_execution_context.dart';
export 'src/task/scheduled_task.dart';
export 'src/task/scheduled_task_holder.dart';
export 'src/task/scheduling_task_name_generator.dart';
export 'src/task/simple_scheduled_task.dart';
export 'src/task/task_execution_context.dart';
export 'src/task/task_scheduler.dart';

// Trigger implementations for various scheduling patterns
export 'src/trigger/cron_trigger.dart';
export 'src/trigger/fixed_delay_trigger.dart';
export 'src/trigger/fixed_rate_trigger.dart';
export 'src/trigger/periodic_trigger.dart';
export 'src/trigger/trigger.dart';
export 'src/trigger/trigger_builder.dart';

// Annotations and exception types
export 'src/annotations.dart';
export 'src/exceptions.dart';