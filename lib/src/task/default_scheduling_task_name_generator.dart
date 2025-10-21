import 'package:jetleaf_lang/lang.dart';

import 'scheduling_task_name_generator.dart';

/// {@template DefaultSchedulingTaskNameGenerator}
/// Default implementation of [SchedulingTaskNameGenerator] that creates
/// structured, hierarchical task names with environment-aware prefixes.
/// 
/// This generator produces task names that include contextual information
/// about the task's origin, making it easy to identify and manage scheduled
/// tasks in complex applications. The naming strategy supports both
/// environment-specific prefixes and detailed component information.
/// 
/// ## Name Generation Strategy
/// 
/// The generator uses the following priority for name construction:
/// 
/// 1. **Name prefix**: If `jetleaf.scheduling.name-prefix` is set
///    in the environment, uses: `{prefix}-{methodName}`
/// 2. **Default Pattern**: If no environment property is set, uses:
///    `{annotation}-{podName}-{className}-{methodName}`
/// 
/// ## Name Components
/// 
/// - **Annotation**: The scheduling annotation type (e.g., 'scheduled', 'cron')
/// - **Pod Name**: The name of the pod containing the scheduled method
/// - **Class Name**: The simple name of the class (extracted from qualified name)
/// - **Method Name**: The name of the scheduled method
/// - **Environment Prefix**: Optional prefix from application properties
/// 
/// ## Usage Examples
/// 
/// ### With Name prefix
/// ```dart
/// // application.properties:
/// // jetleaf.scheduling.name-prefix=myapp
/// 
/// final generator = DefaultSchedulingTaskNameGenerator(
///   'userService', 
///   'scheduled', 
///   environment
/// );
/// 
/// final taskName = generator.generate(userServiceClass, cleanupMethod);
/// print(taskName); // Output: "myapp-cleanup"
/// ```
/// 
/// ### Without Name prefix
/// ```dart
/// final generator = DefaultSchedulingTaskNameGenerator(
///   'emailService', 
///   'cron'
/// );
/// 
/// final taskName = generator.generate(emailServiceClass, sendNewsletterMethod);
/// print(taskName); 
/// // Output: "cron-emailservice-emailservice-sendnewsletter"
/// // (assuming class qualified name is 'package:example/text.dart.EmailService')
/// ```
/// 
/// ### Integration with Scheduling Processor
/// ```dart
/// final class NamedSchedulingProcessor extends SchedulingAnnotationPodProcessor {
///   final SchedulingTaskNameGenerator _nameGenerator;
/// 
///   NamedSchedulingProcessor(
///     TaskScheduler taskScheduler, 
///     this._nameGenerator
///   ) : super(taskScheduler);
/// 
///   @override
///   Future<Object?> processAfterInitialization(Object pod, Class podClass, String name) async {
///     // Process scheduling annotations...
///     for (final method in podClass.getMethods()) {
///       if (method.hasDirectAnnotation<Scheduled>()) {
///         final taskName = _nameGenerator.generate(podClass, method);
///         // Use the generated name for task scheduling
///         await _scheduleMethod(pod, method, taskName);
///       }
///     }
///     return super.processAfterInitialization(pod, podClass, name);
///   }
/// }
/// ```
/// 
/// ## Configuration Options
/// 
/// ### Name prefix
/// Set the `jetleaf.scheduling.name-prefix` property to customize all task names:
/// 
/// ```properties
/// # application.properties
/// jetleaf.scheduling.name-prefix=my-application
/// ```
/// 
/// ### Programmatic Configuration
/// ```dart
/// @Configuration
/// class SchedulingConfig {
///   @Pod
///   SchedulingTaskNameGenerator taskNameGenerator(Environment environment) {
///     return DefaultSchedulingTaskNameGenerator(
///       'main',           // Default pod name
///       'scheduled',      // Default annotation type
///       environment       // Environment for property lookup
///     );
///   }
/// }
/// ```
/// 
/// ## Name Examples
/// 
/// | Scenario | Generated Name |
/// |----------|----------------|
/// | With prefix 'prod' | `prod-cleanupusers` |
/// | @Scheduled in UserService | `scheduled-userservice-userservice-cleanup` |
/// | @Cron in ReportService | `cron-reportservice-reportservice-generate` |
/// | @Periodic in CacheService | `periodic-cacheservice-cacheservice-refresh` |
/// 
/// ## Benefits
/// 
/// - **Environment Awareness**: Different names per environment (dev, staging, prod)
/// - **Clear Identification**: Easy to trace tasks back to their source code
/// - **Namespace Separation**: Prevents name collisions in multi-tenant systems
/// - **Monitoring Friendly**: Structured names work well with logging and metrics systems
/// - **Configuration Driven**: Environment properties allow runtime customization
/// 
/// ## Customization
/// 
/// Extend or wrap this generator for custom naming strategies:
/// 
/// ```dart
/// final class CustomNameGenerator implements SchedulingTaskNameGenerator {
///   final DefaultSchedulingTaskNameGenerator _delegate;
///   final String _instanceId;
/// 
///   CustomNameGenerator(this._delegate, this._instanceId);
/// 
///   @override
///   String generate(Class type, Method method) {
///     final baseName = _delegate.generate(type, method);
///     return '$_instanceId-$baseName';
///   }
/// }
/// ```
/// 
/// ## Testing
/// 
/// ```dart
/// test('should use environment prefix when available', () {
///   final environment = MockEnvironment();
///   when(environment.getProperty('jetleaf.scheduling.name-prefix'))
///       .thenReturn('testapp');
/// 
///   final generator = DefaultSchedulingTaskNameGenerator(
///     'service', 
///     'scheduled', 
///     environment
///   );
///   final mockClass = MockClass();
///   final mockMethod = MockMethod();
/// 
///   when(mockClass.getQualifiedName()).thenReturn('package:example/text.dart.Service');
///   when(mockMethod.getName()).thenReturn('task');
/// 
///   final name = generator.generate(mockClass, mockMethod);
/// 
///   expect(name, equals('testapp-task'));
/// });
/// 
/// test('should use default pattern without environment prefix', () {
///   final generator = DefaultSchedulingTaskNameGenerator('myservice', 'cron');
///   final mockClass = MockClass();
///   final mockMethod = MockMethod();
/// 
///   when(mockClass.getQualifiedName()).thenReturn('package:example/text.dart.MyService');
///   when(mockMethod.getName()).thenReturn('job');
/// 
///   final name = generator.generate(mockClass, mockMethod);
/// 
///   expect(name, equals('cron-myservice-myservice-job'));
/// });
/// ```
/// 
/// ## Performance Considerations
/// 
/// - Environment property lookup is cached internally by the Environment
/// - String operations are efficient for typical class and method names
/// - No external dependencies beyond the initial configuration
/// - Suitable for use during application startup and pod initialization
/// {@endtemplate}
final class DefaultSchedulingTaskNameGenerator implements SchedulingTaskNameGenerator {
  /// Optional environment for property-based name prefix configuration.
  final String? _namePrefix;

  /// The name of the pod containing the scheduled method.
  final String _podName;

  /// The type of scheduling annotation (e.g., 'scheduled', 'cron', 'periodic').
  final String _annotation;

  /// {@macro DefaultSchedulingTaskNameGenerator}
  /// 
  /// Creates a default task name generator with the specified configuration.
  /// 
  /// @param podName The name of the pod that contains the scheduled method.
  ///        This is typically the pod name from the application context.
  /// @param annotation The type of scheduling annotation being processed.
  ///        Common values: 'scheduled', 'cron', 'periodic'.
  /// @param environment Optional environment for property-based configuration.
  ///        If provided, checks for `jetleaf.scheduling.name-prefix` property.
  /// 
  /// Example:
  /// ```dart
  /// // Basic generator without environment
  /// final basicGenerator = DefaultSchedulingTaskNameGenerator(
  ///   'userService', 
  ///   'scheduled'
  /// );
  /// 
  /// // Generator with environment for property lookup
  /// final envGenerator = DefaultSchedulingTaskNameGenerator(
  ///   'reportService', 
  ///   'cron', 
  ///   environment
  /// );
  /// ```
  DefaultSchedulingTaskNameGenerator(this._podName, this._annotation, [this._namePrefix]);

  /// {@macro SchedulingTaskNameGenerator.generate}
  /// 
  /// Generates a task name using either environment property prefix or
  /// the default hierarchical naming pattern.
  /// 
  /// The generation follows this logic:
  /// 1. If `jetleaf.scheduling.name-prefix` environment property is set,
  ///    returns: `{prefix}-{methodName}` (lowercase)
  /// 2. Otherwise, returns: `{annotation}-{podName}-{className}-{methodName}` (lowercase)
  /// 
  /// @param type The class that contains the scheduled method
  /// @param method The method that is scheduled for execution
  /// @return A lowercase string representing the generated task name
  /// 
  /// Example outputs:
  /// ```dart
  /// // With environment property 'jetleaf.scheduling.name-prefix=myapp'
  /// generate(ServiceClass, cleanupMethod) → 'myapp-cleanup'
  /// 
  /// // Without environment property
  /// generate(ServiceClass, cleanupMethod) → 'scheduled-service-service-cleanup'
  /// ```
  @override
  String generate(Class type, Method method) {
    if (_namePrefix != null) {
      return "$_namePrefix-${method.getName()}".toLowerCase();
    }

    // Extract simple class name from qualified name
    final qualifiedName = type.getQualifiedName();
    final prefix = qualifiedName.split(".").last;

    // Build default hierarchical name
    return "$_annotation-$_podName-$prefix-${method.getName()}".toLowerCase();
  }

  @override
  String toString() {
    return 'DefaultSchedulingTaskNameGenerator{'
        'annotation: $_annotation, '
        'podName: $_podName, '
        'hasEnvironment: ${_namePrefix != null}'
        '}';
  }
}