import 'package:jetleaf_pod/pod.dart';
import 'package:jetleaf_core/annotation.dart';

import 'scheduling_annotation_pod_procesor.dart';

/// {@template SchedulingConfiguration}
/// Configuration class that sets up the infrastructure for JetLeaf task scheduling.
/// 
/// This configuration class is automatically imported when `@EnableScheduling` is used
/// and provides the necessary pods to support scheduled method execution based on
/// `@Scheduled` and `@Cron` annotations.
/// 
/// ## Responsibilities
/// 
/// - Registers the `SchedulingAnnotationAwareProcesor` as a pod lifecycle processor
/// - Integrates scheduling infrastructure with the pod container lifecycle
/// - Ensures scheduled methods are detected and registered with the task scheduler
/// - Provides proper role metadata for infrastructure components
/// 
/// ## Pod Definitions
/// 
/// This configuration provides the following pods:
/// 
/// - `schedulingAnnotationProcessor`: The main processor that scans for and
///   registers scheduled methods with the task scheduler
/// 
/// ## Integration with Application Lifecycle
/// 
/// The scheduling processor integrates with the pod container lifecycle to ensure
/// scheduled methods are registered at the appropriate time - after all dependencies
/// are resolved but before the application becomes fully operational.
/// 
/// Example:
/// ```dart
/// @EnableScheduling
/// @Configuration
/// class AppConfig {
///   // This will automatically import SchedulingConfiguration
///   // and set up scheduling infrastructure
///   
///   @Pod
///   TaskScheduler taskScheduler() {
///     return ThreadPoolTaskScheduler()
///       ..setPoolSize(5)
///       ..setThreadNamePrefix('scheduled-');
///   }
/// }
/// 
/// @Service
/// class ScheduledService {
///   @Scheduled(fixedRate: 5000)
///   void runEvery5Seconds() {
///     print('Executing every 5 seconds');
///   }
/// }
/// ```
/// 
/// ## Customization Options
/// 
/// While this configuration provides sensible defaults, you can customize
/// scheduling behavior by:
/// 
/// 1. **Providing a custom TaskScheduler**:
/// ```dart
/// @Pod
/// TaskScheduler customTaskScheduler() {
///   return CustomTaskScheduler();
/// }
/// ```
/// 
/// 2. **Extending the configuration**:
/// ```dart
/// @Configuration
/// class CustomSchedulingConfig extends SchedulingConfiguration {
///   @Override
///   @Pod
///   SchedulingAnnotationAwareProcesor schedulingAnnotationProcessor(
///       TaskScheduler taskScheduler) {
///     return CustomSchedulingProcessor(taskScheduler);
///   }
/// }
/// ```
/// 
/// 3. **Adding additional scheduling-related pods**:
/// ```dart
/// @Configuration
/// @Import(SchedulingConfiguration)
/// class ExtendedSchedulingConfig {
///   @Pod
///   ScheduledTaskRegistrar taskRegistrar() {
///     return ScheduledTaskRegistrar();
///   }
/// }
/// ```
/// 
/// ## Infrastructure Role
/// 
/// This configuration and its pods are marked with `DesignRole.INFRASTRUCTURE`
/// to indicate they are framework-level components rather than business logic.
/// This helps with:
/// 
/// - Clear separation of concerns in application architecture
/// - Better understanding of component purposes during debugging
/// - More targeted testing strategies (infrastructure vs business logic tests)
/// - Improved dependency management and visibility control
/// 
/// ## Testing Strategy
/// 
/// When testing applications that use scheduling, you can:
/// 
/// 1. **Disable scheduling in tests**:
/// ```dart
/// @TestConfiguration
/// class TestConfig {
///   // Don't use @EnableScheduling in tests
/// }
/// ```
/// 
/// 2. **Mock the scheduling processor**:
/// ```dart
/// @Test
/// void testWithoutScheduling() {
///   final mockProcessor = MockSchedulingAnnotationPodProcessor();
///   when(mockProcessor.processAfterInitialization(any, any, any))
///       .thenAnswer((invocation) async => invocation.positionalArguments[0]);
///       
///   // Test your business logic without scheduling interference
/// }
/// ```
/// 
/// 3. **Use a test-specific scheduler**:
/// ```dart
/// @TestConfiguration
/// class TestSchedulingConfig {
///   @Pod
///   TaskScheduler testTaskScheduler() {
///     return SyncTaskScheduler(); // Executes tasks synchronously for tests
///   }
/// }
/// ```
/// 
/// ## Error Handling and Resilience
/// 
/// The scheduling infrastructure includes built-in error handling:
/// 
/// - Scheduled method exceptions are caught and logged without stopping the scheduler
/// - Configuration errors during annotation processing throw meaningful exceptions
/// - The processor continues processing other methods if one method fails
/// - Proper lifecycle management ensures resources are cleaned up on shutdown
/// 
/// ## Performance Considerations
/// 
/// - Annotation scanning occurs during application startup, not at runtime
/// - Each scheduled method creates one scheduled task in the task scheduler
/// - The processor uses efficient reflection to detect annotations
/// - Consider using `@Lazy` for expensive-to-initialize scheduled pods
/// - Monitor thread pool usage if you have many concurrent scheduled tasks
/// 
/// {@endtemplate}
@Configuration()
@Role(DesignRole.INFRASTRUCTURE)
final class SchedulingConfiguration {
  /// {@macro SchedulingConfiguration}
  /// 
  /// Creates the main scheduling annotation processor that detects and registers
  /// methods annotated with `@Scheduled` and `@Cron`.
  /// 
  /// This pod is responsible for:
  /// - Scanning all pods for scheduling annotations during initialization
  /// - Validating scheduling configuration (ensuring only one trigger type per method)
  /// - Creating appropriate triggers based on annotation properties
  /// - Registering scheduled methods with the task scheduler
  /// - Providing detailed logging for scheduling activities
  /// 
  /// @param taskScheduler The task scheduler that will execute the scheduled methods.
  ///        This parameter is automatically wired by the container.
  /// @return A configured [SchedulingAnnotationPodProcessor] instance
  /// 
  /// Example of automatic dependency injection:
  /// ```dart
  /// // The taskScheduler parameter is automatically provided by the container
  /// final processor = schedulingAnnotationProcessor(taskScheduler);
  /// ```
  /// 
  /// The processor uses the provided task scheduler to actually schedule method
  /// executions. If no custom task scheduler is defined, a default one will be
  /// auto-configured by the framework.
  @Role(DesignRole.INFRASTRUCTURE)
  @Pod(value: SchedulingAnnotationPodProcessor.SCHEDULING_ANNOTATION_AWARE_PROCESSOR_POD_NAME)
  SchedulingAnnotationPodProcessor schedulingAnnotationProcessor() => SchedulingAnnotationPodProcessor();
}