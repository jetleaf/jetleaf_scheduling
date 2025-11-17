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

import 'exceptions.dart';

/// {@template runnableScheduledMethod}
/// Adapter that converts a method reflection into a [Runnable] for scheduling.
///
/// This class bridges the gap between method reflection and task scheduling
/// by wrapping a reflected method and its target object into a runnable task
/// that can be executed by the scheduler. It handles parameter validation
/// and error logging for scheduled method executions.
///
/// **Example:**
/// ```dart
/// class ScheduledTasks {
///   void dailyCleanup() {
///     // Cleanup logic here
///   }
///   
///   void generateReport() {
///     // Report generation logic
///   }
/// }
/// 
/// final tasks = ScheduledTasks();
/// final method = Reflector.getMethod(ScheduledTasks, 'dailyCleanup');
/// 
/// // Create runnable for scheduling
/// final runnable = RunnableScheduledMethod(tasks, method);
/// 
/// // Schedule the method execution
/// await scheduler.schedule(
///   runnable,
///   CronTrigger('0 0 2 * * *'), // Daily at 2 AM
/// );
/// ```
/// {@endtemplate}
final class RunnableScheduledMethod implements Runnable {
  /// The target object on which the method will be invoked.
  final Object _target;

  /// The reflected method to be executed.
  final Method _method;

  /// Logger instance for execution tracking and error reporting.
  final Log _logger = LogFactory.getLog(RunnableScheduledMethod);

  /// {@macro runnableScheduledMethod}
  RunnableScheduledMethod(this._target, this._method);

  @override
  FutureOr<void> run() async {
    if (_method.getParameters().isNotEmpty) {
      throw SchedulerException(
        "Scheduled method '${_method.getName()}' declared in '${_method.getDeclaringClass().getQualifiedName()}' "
        "has parameters, but scheduled methods must be parameterless. "
        "Inject any required dependencies via the constructor or fields instead."
      );
    }

    try {
      return _method.invoke(_target);
    } catch (e) {
      if (_logger.getIsErrorEnabled()) {
        _logger.error("Failed to run scheduled method ${_method.getName()}", error: e);
      }

      rethrow;
    }
  }
}