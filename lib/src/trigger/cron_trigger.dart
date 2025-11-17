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

import '../exceptions.dart';
import '../task/task_execution_context.dart';
import 'trigger.dart';

/// {@template cronTrigger}
/// Trigger implementation for cron expression-based scheduling.
///
/// Supports standard 6-field cron expressions for precise scheduling
/// of tasks based on calendar-based time specifications:
/// ```
/// ┌───────────── second (0–59)
/// │ ┌───────────── minute (0–59)
/// │ │ ┌───────────── hour (0–23)
/// │ │ │ ┌───────────── day of month (1–31)
/// │ │ │ │ ┌───────────── month (1–12)
/// │ │ │ │ │ ┌───────────── day of week (0–6) (Sunday=0 or 7)
/// │ │ │ │ │ │
/// * * * * * *
/// ```
///
/// **Example:**
/// ```dart
/// // Every hour at the start of the hour in system timezone
/// final trigger = CronTrigger('0 0 * * * *');
/// 
/// // Every day at midnight in specific timezone
/// final trigger = CronTrigger('0 0 0 * * *', ZoneId.of('Europe/Paris'));
/// 
/// // Every Monday at 9 AM in New York time
/// final trigger = CronTrigger('0 0 9 * * 1', ZoneId.of('America/New_York'));
/// 
/// // Every 15 minutes during business hours (9 AM - 5 PM) on weekdays in London
/// final trigger = CronTrigger('0 */15 9-17 * * 1-5', ZoneId.of('Europe/London'));
/// 
/// // First day of every month at 6:30 AM in Tokyo time
/// final trigger = CronTrigger('0 30 6 1 * *', ZoneId.of('Asia/Tokyo'));
/// 
/// // Use in scheduler for complex scheduling needs with timezone awareness
/// final backupTask = await scheduler.schedule(
///   () => performBackup(),
///   CronTrigger('0 0 2 * * *', ZoneId.of('America/Los_Angeles')), // Daily at 2 AM PST
/// );
/// 
/// final reportTask = await scheduler.schedule(
///   () => generateReports(),
///   CronTrigger('0 0 9 * * 1', ZoneId.of('Europe/London')), // Every Monday at 9 AM GMT/BST
/// );
///
/// // Global operation synchronized to UTC
/// final globalSync = await scheduler.schedule(
///   () => synchronizeGlobalData(),
///   CronTrigger('0 0 */6 * * *', ZoneId.UTC), // Every 6 hours UTC
/// );
/// ```
/// {@endtemplate}
class CronTrigger with EqualsAndHashCode implements Trigger {
  /// The underlying cron expression parser and calculator.
  final CronExpression _expression;

  /// The timezone in which this trigger operates.
  ///
  /// All cron scheduling calculations are performed in this timezone.
  final ZoneId zone;

  /// {@macro cronTrigger}
  CronTrigger(String expression, this.zone) : _expression = CronExpression(expression);

  /// Creates a trigger from a pre-parsed [CronExpression].
  ///
  /// This constructor is useful when you want to reuse the same
  /// cron expression across multiple triggers or pre-validate expressions.
  ///
  /// **Example:**
  /// ```dart
  /// final cronExpr = CronExpression('0 0 9 * * 1');
  /// // Validate once, use multiple times with different timezones
  /// final londonTrigger = CronTrigger.fromExpression(cronExpr, ZoneId.of('Europe/London'));
  /// final nyTrigger = CronTrigger.fromExpression(cronExpr, ZoneId.of('America/New_York'));
  /// ```
  CronTrigger.fromExpression(CronExpression expression, this.zone) : _expression = expression;

  @override
  List<Object?> equalizedProperties() => [_expression, zone];

  @override
  ZonedDateTime? nextExecutionTime(TaskExecutionContext context) {
    // Get current time in the trigger's timezone
    final nowInZone = ZonedDateTime.now(zone);
    
    // Get last execution time, convert to trigger's timezone if available
    final lastExecution = context.getLastActualExecutionTime();
    final referenceTime = lastExecution?.withZoneSameInstant(zone) ?? nowInZone;
    
    return _expression.nextExecution(referenceTime, zone);
  }

  @override
  ZoneId getZone() => zone;

  /// Returns the cron expression string used by this trigger.
  ///
  /// This provides access to the original cron expression for
  /// logging, debugging, or serialization purposes.
  ///
  /// **Example:**
  /// ```dart
  /// final trigger = CronTrigger('0 0 9 * * 1', ZoneId.of('Europe/Paris'));
  /// print(trigger.getExpression()); // '0 0 9 * * 1'
  /// print(trigger.getZone().id); // 'Europe/Paris'
  /// ```
  String getExpression() => _expression.expression;

  @override
  String toString() => 'CronTrigger(expression: ${getExpression()}, zone: ${zone.id})';
}

/// {@template cronExpression}
/// A strongly typed and runtime-validated representation of a cron expression.
///
/// This class serves as a safer alternative to using raw strings for cron scheduling.
/// It validates that any cron expression passed to it conforms to the standard 6-field
/// UNIX format. Invalid expressions will throw a [InvalidCronExpressionException] 
/// immediately upon construction.
///
/// ### Supported Format:
/// ```
/// ┌───────────── second (0–59)
/// │ ┌───────────── minute (0–59)
/// │ │ ┌───────────── hour (0–23)
/// │ │ │ ┌───────────── day of month (1–31)
/// │ │ │ │ ┌───────────── month (1–12)
/// │ │ │ │ │ ┌───────────── day of week (0–6) (Sunday=0 or 7)
/// │ │ │ │ │ │
/// * * * * * *
/// ```
///
/// ### Supported Syntax:
/// - `*` - any value
/// - `,` - value list separator  
/// - `-` - range of values
/// - `/` - step values
/// - `?` - no specific value (only for day of month/day of week)
///
/// ### Example:
/// ```dart
/// final cron = CronExpression('0 0 * * * *'); // Valid - every hour
/// final bad = CronExpression('* * *'); // Throws InvalidCronExpressionException
/// 
/// // Complex examples:
/// final every5Minutes = CronExpression('0 */5 * * * *');
/// final businessHours = CronExpression('0 0 9-17 * * 1-5');
/// final firstOfMonth = CronExpression('0 0 0 1 * *');
/// ```
/// {@endtemplate}
final class CronExpression with EqualsAndHashCode {
  /// The cron expression value
  final String expression;

  late final List<CronField> _fields;

  /// {@macro cronExpression}
  CronExpression(this.expression) {
    _validateExpression(expression);
    _fields = _parseExpression(expression);
  }

  /// Validates the cron expression format and syntax
  void _validateExpression(String expression) {
    if (expression.isEmpty) {
      throw InvalidCronExpressionException('Cron expression cannot be empty', expression);
    }

    final parts = expression.trim().split(RegExp(r'\s+'));
    
    if (parts.length != 6) {
      throw InvalidCronExpressionException(
        'Cron expression must have exactly 6 fields (second, minute, hour, day of month, month, day of week). Found ${parts.length} fields.',
        expression
      );
    }

    // Validate each field
    _validateField(parts[0], 0, 59, 'second', expression);
    _validateField(parts[1], 0, 59, 'minute', expression);
    _validateField(parts[2], 0, 23, 'hour', expression);
    _validateField(parts[3], 1, 31, 'day of month', expression);
    _validateField(parts[4], 1, 12, 'month', expression);
    _validateField(parts[5], 0, 7, 'day of week', expression); // 0-7 (0 and 7 both = Sunday)
  }

  /// Validates a single cron field
  void _validateField(String field, int min, int max, String fieldName, String originalExpression) {
    if (field == '?' && (fieldName == 'day of month' || fieldName == 'day of week')) {
      return; // '?' is allowed for day fields
    }

    if (field == '*') {
      return; // Wildcard is always valid
    }

    // Handle step values (e.g., */5, 1-30/5)
    final stepParts = field.split('/');
    if (stepParts.length > 2) {
      throw InvalidCronExpressionException(
        'Invalid step syntax in $fieldName field: "$field"',
        originalExpression
      );
    }

    final basePart = stepParts[0];
    
    // Handle ranges and lists
    final rangeParts = basePart.split(',');
    for (final rangePart in rangeParts) {
      final dashParts = rangePart.split('-');
      
      if (dashParts.length == 1) {
        // Single value
        final value = int.tryParse(dashParts[0]);
        if (value == null || value < min || value > max) {
          throw InvalidCronExpressionException(
            'Invalid value in $fieldName field: "$rangePart". Must be between $min and $max.',
            originalExpression
          );
        }
      } else if (dashParts.length == 2) {
        // Range
        final start = int.tryParse(dashParts[0]);
        final end = int.tryParse(dashParts[1]);
        
        if (start == null || end == null || start < min || end > max || start > end) {
          throw InvalidCronExpressionException(
            'Invalid range in $fieldName field: "$rangePart". Must be between $min and $max with start <= end.',
            originalExpression
          );
        }
      } else {
        throw InvalidCronExpressionException(
          'Invalid syntax in $fieldName field: "$rangePart"',
          originalExpression
        );
      }
    }

    // Validate step value if present
    if (stepParts.length == 2) {
      final step = int.tryParse(stepParts[1]);
      if (step == null || step < 1) {
        throw InvalidCronExpressionException(
          'Invalid step value in $fieldName field: "${stepParts[1]}". Must be a positive integer.',
          originalExpression
        );
      }
    }
  }

  /// Parses the cron expression into field objects
  List<CronField> _parseExpression(String expression) {
    final parts = expression.trim().split(RegExp(r'\s+'));
    
    return [
      CronField(parts[0], 0, 59),   // second
      CronField(parts[1], 0, 59),   // minute  
      CronField(parts[2], 0, 23),   // hour
      CronField(parts[3], 1, 31),   // day of month
      CronField(parts[4], 1, 12),   // month
      CronField(parts[5], 0, 7),    // day of week (0-7)
    ];
  }

  /// Calculates the next execution time after the given reference time in the specified timezone
  ///
  /// This method implements the cron scheduling algorithm to find the next
  /// valid execution time that matches the cron expression in the given timezone.
  ///
  /// **Example:**
  /// ```dart
  /// final cron = CronExpression('0 0 * * * *'); // Every hour
  /// final now = ZonedDateTime.now(ZoneId.of('Europe/Paris'));
  /// final next = cron.nextExecution(now, ZoneId.of('Europe/Paris'));
  /// print('Next execution: $next'); // Next hour at :00:00 in Paris time
  /// ```
  ZonedDateTime? nextExecution(ZonedDateTime after, ZoneId zone) {
    // Start looking from the next second in the same timezone
    var candidate = after.plusSeconds(1);

    // Limit iterations to prevent infinite loops
    const maxIterations = 100000;
    var iterations = 0;

    while (iterations < maxIterations) {
      iterations++;

      // Check if candidate matches all cron fields
      if (_matches(candidate)) {
        return candidate;
      }

      // Move to next second in the same timezone
      candidate = candidate.plusSeconds(1);

      // If we've moved into the next year and still no match, give up
      if (candidate.year > after.year + 5) {
        throw SchedulerException('Unable to find next execution time within 5 years for expression: $expression');
      }
    }

    throw SchedulerException('Exceeded maximum iterations while calculating next execution time for expression: $expression');
  }

  /// Checks if the given ZonedDateTime matches the cron expression
  bool _matches(ZonedDateTime time) {
    final values = [
      time.second,
      time.minute, 
      time.hour,
      time.day,
      time.month,
      time.dayOfWeek % 7, // Convert 1-7 (Mon-Sun) to 0-6 (Sun-Sat)
    ];

    for (int i = 0; i < _fields.length; i++) {
      if (!_fields[i].matches(values[i])) {
        return false;
      }
    }

    return true;
  }

  /// Returns whether this cron expression represents a valid schedule
  static bool isValid(String expression) {
    try {
      CronExpression(expression);
      return true;
    } on InvalidCronExpressionException {
      return false;
    }
  }

  @override
  String toString() => 'CronExpression($expression)';

  @override
  List<Object?> equalizedProperties() => [expression];
}

/// Represents a single field in a cron expression
final class CronField {
  final String _expression;
  final int _min;
  final int _max;
  late final Set<int> _allowedValues;

  CronField(this._expression, this._min, this._max) {
    _allowedValues = _parseField(_expression, _min, _max);
  }

  /// Parses a cron field expression into a set of allowed values
  Set<int> _parseField(String expression, int min, int max) {
    if (expression == '*') {
      return Set<int>.from(List.generate(max - min + 1, (i) => min + i));
    }

    if (expression == '?') {
      // '?' means no specific value - used for day conflicts
      return Set<int>.from(List.generate(max - min + 1, (i) => min + i));
    }

    final values = <int>{};
    final parts = expression.split(',');

    for (final part in parts) {
      if (part.contains('/')) {
        // Step values (e.g., */5, 1-30/5)
        final stepParts = part.split('/');
        final range = stepParts[0];
        final step = int.parse(stepParts[1]);

        Set<int> rangeValues;
        if (range == '*') {
          rangeValues = Set<int>.from(List.generate(max - min + 1, (i) => min + i));
        } else {
          rangeValues = _parseRange(range, min, max);
        }

        // Apply step
        final sorted = rangeValues.toList()..sort();
        for (int i = 0; i < sorted.length; i += step) {
          values.add(sorted[i]);
        }
      } else {
        // Simple range or value
        values.addAll(_parseRange(part, min, max));
      }
    }

    return values;
  }

  /// Parses a range expression (e.g., "1-5", "10")
  Set<int> _parseRange(String range, int min, int max) {
    if (range.contains('-')) {
      final parts = range.split('-');
      final start = int.parse(parts[0]);
      final end = int.parse(parts[1]);
      
      // Handle Sunday as both 0 and 7
      if (min == 0 && max == 7) {
        final values = <int>{};
        for (int i = start; i <= end; i++) {
          values.add(i == 7 ? 0 : i);
        }
        return values;
      }
      
      return Set<int>.from(List.generate(end - start + 1, (i) => start + i));
    } else {
      final value = int.parse(range);
      // Handle Sunday as both 0 and 7
      if (min == 0 && max == 7 && value == 7) {
        return {0};
      }
      return {value};
    }
  }

  /// Checks if the given value matches this cron field
  bool matches(int value) {
    // Handle Sunday as both 0 and 7 for day of week
    if (_min == 0 && _max == 7) {
      return _allowedValues.contains(value) || (value == 0 && _allowedValues.contains(7));
    }
    return _allowedValues.contains(value);
  }

  @override
  String toString() => _expression;
}