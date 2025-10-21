import 'package:jetleaf_lang/lang.dart';

/// {@template SchedulingTaskNameGenerator}
/// Interface for generating unique and meaningful names for scheduled tasks.
/// 
/// This interface defines the contract for components that generate
/// descriptive names for scheduled tasks based on the class and method
/// that contain the scheduling logic. Generated names are used for:
/// 
/// - **Task Identification**: Unique identifiers for task management
/// - **Logging and Monitoring**: Meaningful names in logs and metrics
/// - **Debugging**: Clear correlation between tasks and their source code
/// - **Management Interfaces**: Human-readable names in admin tools
/// 
/// ## Implementation Requirements
/// 
/// Implementations should generate names that are:
/// - **Unique**: Different tasks should have different names
/// - **Descriptive**: Names should indicate the task's purpose and origin
/// - **Consistent**: Same class/method should always generate same name
/// - **Stable**: Names should not change across application restarts
/// - **Readable**: Names should be human-readable and meaningful
/// 
/// ## Default Implementation Strategy
/// 
/// A typical implementation might generate names using patterns like:
/// - `className#methodName` (e.g., `UserService#cleanupInactiveUsers`)
/// - `packageName.className.methodName` (e.g., `package:example/test.dart.UserService.cleanupInactiveUsers`)
/// - `className.methodName-timestamp` (for unique instances)
/// 
/// ## Usage Examples
/// 
/// ### Basic Implementation
/// ```dart
/// final class SimpleTaskNameGenerator implements SchedulingTaskNameGenerator {
///   @override
///   String generate(Class type, Method method) {
///     return '${type.getSimpleName()}#${method.getName()}';
///   }
/// }
/// ```
/// 
/// ### Qualified Name Implementation
/// ```dart
/// final class QualifiedTaskNameGenerator implements SchedulingTaskNameGenerator {
///   @override
///   String generate(Class type, Method method) {
///     final package = type.getPackage()?.getName() ?? 'default';
///     final className = type.getSimpleName();
///     final methodName = method.getName();
///     return '$package.$className.$methodName';
///   }
/// }
/// ```
/// 
/// ### Custom Naming Strategy
/// ```dart
/// final class CustomTaskNameGenerator implements SchedulingTaskNameGenerator {
///   final Map<Class, String> _classAliases = {};
/// 
///   void setClassAlias(Class type, String alias) {
///     _classAliases[type] = alias;
///   }
/// 
///   @override
///   String generate(Class type, Method method) {
///     final className = _classAliases[type] ?? type.getSimpleName();
///     final methodName = _getFriendlyMethodName(method);
///     return '$className.$methodName';
///   }
/// 
///   String _getFriendlyMethodName(Method method) {
///     // Convert camelCase to space-separated words
///     final name = method.getName();
///     return name.replaceAllMapped(
///       RegExp(r'([A-Z])'), 
///       (match) => ' ${match.group(1)!.toLowerCase()}'
///     ).trim();
///   }
/// }
/// ```
/// 
/// ### Integration with Task Scheduler
/// ```dart
/// final class NamedTaskScheduler {
///   final TaskScheduler _delegate;
///   final SchedulingTaskNameGenerator _nameGenerator;
/// 
///   NamedTaskScheduler(this._delegate, this._nameGenerator);
/// 
///   Future<void> scheduleMethod(
///     Object instance, 
///     Method method, 
///     Trigger trigger
///   ) async {
///     final taskName = _nameGenerator.generate(
///       instance.runtimeType as Class, 
///       method
///     );
///     
///     final task = () => method.invoke(instance);
///     final scheduledTask = SimpleScheduledTask(task, trigger, taskName);
///     
///     await _delegate.schedule(scheduledTask);
///     
///     if (_logger.getIsInfoEnabled()) {
///       _logger.info('Scheduled task: $taskName with trigger: $trigger');
///     }
///   }
/// }
/// ```
/// 
/// ### Usage with Scheduling Annotations
/// ```dart
/// @Service
/// class UserMaintenanceService {
///   final NamedTaskScheduler _scheduler;
/// 
///   UserMaintenanceService(this._scheduler);
/// 
///   @Scheduled(fixedRate: 3600000) // Every hour
///   void cleanupInactiveUsers() {
///     // Task will be named using the generator
///     // e.g., "UserMaintenanceService.cleanupInactiveUsers"
///   }
/// 
///   @Scheduled(cron: '0 0 2 * * *') // Daily at 2 AM
///   void sendDailyReports() {
///     // Task will be named: "UserMaintenanceService.sendDailyReports"
///   }
/// }
/// ```
/// 
/// ## Advanced Implementation Patterns
/// 
/// ### Environment-Aware Naming
/// ```dart
/// final class EnvironmentAwareNameGenerator implements SchedulingTaskNameGenerator {
///   final SchedulingTaskNameGenerator _delegate;
///   final String _environment;
/// 
///   EnvironmentAwareNameGenerator(this._delegate, this._environment);
/// 
///   @override
///   String generate(Class type, Method method) {
///     final baseName = _delegate.generate(type, method);
///     return '$_environment.$baseName';
///   }
/// }
/// 
/// // Usage: Generates names like "production.UserService.cleanup"
/// final generator = EnvironmentAwareNameGenerator(
///   SimpleTaskNameGenerator(), 
///   'production'
/// );
/// ```
/// 
/// ### Instance-Scoped Naming
/// ```dart
/// final class InstanceScopedNameGenerator implements SchedulingTaskNameGenerator {
///   final SchedulingTaskNameGenerator _delegate;
///   final Map<Object, int> _instanceCounters = {};
/// 
///   @override
///   String generate(Class type, Method method) {
///     final instance = _getCurrentInstance(); // Implementation specific
///     final counter = _instanceCounters[instance] = 
///         (_instanceCounters[instance] ?? 0) + 1;
///     
///     final baseName = _delegate.generate(type, method);
///     return '$baseName-instance$counter';
///   }
/// }
/// ```
/// 
/// ### Configurable Name Generator
/// ```dart
/// final class ConfigurableTaskNameGenerator implements SchedulingTaskNameGenerator {
///   final String _pattern;
/// 
///   ConfigurableTaskNameGenerator({String pattern = '{class}#{method}'})
///       : _pattern = pattern;
/// 
///   @override
///   String generate(Class type, Method method) {
///     return _pattern
///         .replaceAll('{class}', type.getSimpleName())
///         .replaceAll('{method}', method.getName())
///         .replaceAll('{package}', type.getPackage()?.getName() ?? '')
///         .replaceAll('{qualifiedClass}', type.getQualifiedName());
///   }
/// }
/// 
/// // Usage with different patterns:
/// final simpleGenerator = ConfigurableTaskNameGenerator(pattern: '{class}.{method}');
/// final qualifiedGenerator = ConfigurableTaskNameGenerator(
///   pattern: '{package}.{class}.{method}'
/// );
/// ```
/// 
/// ## Testing Strategies
/// 
/// ### Unit Testing Name Generation
/// ```dart
/// test('should generate expected task names', () {
///   final generator = SimpleTaskNameGenerator();
///   final mockClass = MockClass();
///   final mockMethod = MockMethod();
/// 
///   when(mockClass.getSimpleName()).thenReturn('UserService');
///   when(mockMethod.getName()).thenReturn('cleanup');
/// 
///   final taskName = generator.generate(mockClass, mockMethod);
/// 
///   expect(taskName, equals('UserService#cleanup'));
/// });
/// ```
/// 
/// ### Testing Name Uniqueness
/// ```dart
/// test('should generate unique names for different methods', () {
///   final generator = QualifiedTaskNameGenerator();
///   final mockClass = MockClass();
///   final mockMethod1 = MockMethod();
///   final mockMethod2 = MockMethod();
/// 
///   when(mockClass.getSimpleName()).thenReturn('Service');
///   when(mockClass.getPackage()).thenReturn(MockPackage()..name = 'package:example/test.dart');
///   when(mockMethod1.getName()).thenReturn('method1');
///   when(mockMethod2.getName()).thenReturn('method2');
/// 
///   final name1 = generator.generate(mockClass, mockMethod1);
///   final name2 = generator.generate(mockClass, mockMethod2);
/// 
///   expect(name1, isNot(equals(name2)));
///   expect(name1, equals('package:example/test.dart.Service.method1'));
///   expect(name2, equals('package:example/test.dart.Service.method2'));
/// });
/// ```
/// 
/// ## Performance Considerations
/// 
/// - **Reflection Cost**: Minimize reflective operations in name generation
/// - **Caching**: Consider caching generated names for same class/method pairs
/// - **String Operations**: Use efficient string concatenation methods
/// - **Memory Usage**: Avoid retaining unnecessary references to class/method objects
/// 
/// ## Error Handling
/// 
/// Implementations should handle:
/// - **Null values** for class or method parameters
/// - **Invalid class/method** states during reflection
/// - **Name collisions** in distributed environments
/// - **Encoding issues** with special characters in names
/// 
/// ## Best Practices
/// 
/// - Use names that are meaningful in logs and monitoring systems
/// - Ensure names are valid identifiers for your task management system
/// - Consider name length limitations of downstream systems
/// - Document your naming convention for team consistency
/// - Test name generation with your specific class/method patterns
/// {@endtemplate}
abstract interface class SchedulingTaskNameGenerator {
  /// {@template SchedulingTaskNameGenerator.generate}
  /// Generates a unique and descriptive name for a scheduled task.
  /// 
  /// This method creates a name that identifies a scheduled task based on
  /// the class containing the scheduled method and the method itself. The
  /// generated name should be consistent across application restarts and
  /// suitable for use in logging, monitoring, and management interfaces.
  /// 
  /// @param type The class that contains the scheduled method. This provides
  ///        context about where the task is defined in the codebase.
  /// @param method The method that is scheduled for execution. This identifies
  ///        the specific function that will be run by the task.
  /// @return A unique, descriptive name for the scheduled task. The name
  ///         should be consistent when called with the same class and method.
  /// 
  /// Example:
  /// ```dart
  /// final generator = SimpleTaskNameGenerator();
  /// final taskName = generator.generate(userServiceClass, cleanupMethod);
  /// print(taskName); // Output: "UserService#cleanupInactiveUsers"
  /// 
  /// // The generated name can be used for task management:
  /// final task = SimpleScheduledTask(cleanupTask, trigger, taskName);
  /// await taskScheduler.schedule(task);
  /// 
  /// // Later, in monitoring:
  /// print('Monitoring task: $taskName'); // "Monitoring task: UserService#cleanupInactiveUsers"
  /// ```
  /// 
  /// Implementation Notes:
  /// - The method should not return `null` or empty strings
  /// - Names should be deterministic for the same input
  /// - Consider name collisions when multiple instances exist
  /// - Ensure names are valid for your logging and monitoring systems
  /// {@endtemplate}
  String generate(Class type, Method method);
}