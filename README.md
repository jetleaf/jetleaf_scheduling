# ⏱️ JetLeaf Scheduling — Task Scheduling & Timed Execution

[![pub package](https://img.shields.io/badge/version-1.0.0-blue)](https://pub.dev/packages/jetleaf_scheduling)
[![License](https://img.shields.io/badge/license-JetLeaf-green)](#license)
[![Dart SDK](https://img.shields.io/badge/sdk-%3E%3D3.9.0-blue)](https://dart.dev)

Task scheduling framework for background jobs, periodic tasks, and delayed execution in JetLeaf applications.

## 📋 Overview

`jetleaf_scheduling` provides comprehensive scheduling capabilities:

- **Periodic Tasks** — Run tasks at fixed intervals
- **Delayed Execution** — Schedule tasks for later execution
- **Cron Expressions** — Complex scheduling with cron syntax
- **Task Pools** — Manage concurrent task execution
- **Error Handling** — Robust failure management
- **Pod Integration** — Declarative scheduled pods
- **Async Support** — Full async/await support

## 🚀 Quick Start

### Installation

```yaml
dependencies:
  jetleaf_scheduling:
    path: ./jetleaf_scheduling
```

### Basic Scheduled Tasks

```dart
import 'package:jetleaf_scheduling/scheduling.dart';

@Service()
class ReportService {
  @Scheduled(fixedDelay: 60000)  // Run every 60 seconds
  void generateDailyReport() {
    print('Generating daily report...');
  }

  @Scheduled(fixedRate: 300000)  // Run every 5 minutes
  Future<void> syncData() async {
    print('Syncing data...');
    await performSync();
  }
}

void main() async {
  final context = AnnotationConfigApplicationContext(['package:myapp']);
  // Scheduled tasks run automatically
}
```

## 📚 Key Features

### 1. Fixed Delay Scheduling

**Run after delay between executions**:

```dart
@Service()
class TaskService {
  @Scheduled(fixedDelay: 5000)  // 5 second delay after completion
  void periodicTask() {
    print('Task executed at ${DateTime.now()}');
  }

  @Scheduled(fixedDelay: 10000, initialDelay: 2000)
  void delayedPeriodicTask() {
    // Wait 2 seconds before first execution, then 10s between executions
    print('Delayed task running...');
  }
}
```

### 2. Fixed Rate Scheduling

**Run at fixed intervals regardless of execution time**:

```dart
@Service()
class MetricsService {
  @Scheduled(fixedRate: 60000)  // Every 60 seconds
  Future<void> collectMetrics() async {
    print('Collecting metrics...');
    await _collectSystemMetrics();
    await _collectApplicationMetrics();
  }
}
```

### 3. Cron Scheduling

**Complex scheduling with cron expressions**:

```dart
@Service()
class ScheduledJobs {
  // Every day at 2:00 AM
  @Scheduled(cron: '0 2 * * *')
  Future<void> dailyMaintenance() {
    print('Running daily maintenance...');
  }

  // Every Monday at 8:00 AM
  @Scheduled(cron: '0 8 * * MON')
  Future<void> weeklyReport() {
    print('Generating weekly report...');
  }

  // Every 15 minutes
  @Scheduled(cron: '*/15 * * * *')
  void frequentCheck() {
    print('Frequent check running...');
  }

  // First day of month at midnight
  @Scheduled(cron: '0 0 1 * *')
  Future<void> monthlyCleanup() {
    print('Monthly cleanup started...');
  }
}
```

### 4. Async Scheduled Tasks

**Support for async operations**:

```dart
@Service()
class DataService {
  final DatabaseConnection _db;
  final ApiClient _api;

  @Autowired
  DataService(this._db, this._api);

  @Scheduled(fixedRate: 300000)
  Future<void> syncExternalData() async {
    try {
      // Fetch from external API
      final data = await _api.fetchData();
      
      // Store in database
      await _db.transaction((tx) async {
        for (final item in data) {
          await tx.insert('items', item);
        }
      });
      
      print('Data sync completed');
    } catch (e) {
      print('Data sync failed: $e');
    }
  }
}
```

### 5. Manual Task Scheduling

**Schedule tasks programmatically**:

```dart
@Service()
class TaskScheduler {
  final ScheduledTaskRegistry _registry;

  @Autowired
  TaskScheduler(this._registry);

  void scheduleCustomTask() {
    // Schedule task to run after 5 seconds
    _registry.scheduleOnce(
      Duration(seconds: 5),
      () => print('One-time task executed'),
    );

    // Schedule recurring task
    _registry.scheduleAtFixedRate(
      Duration(seconds: 30),
      () => print('Recurring task'),
    );

    // Schedule with cron
    _registry.scheduleWithCron(
      '0 * * * *',  // Every hour
      () => print('Hourly task'),
    );
  }
}
```

### 6. Task Error Handling

**Handle task failures gracefully**:

```dart
@Service()
class RobustTaskService {
  @Scheduled(fixedRate: 60000)
  Future<void> safetask() async {
    try {
      await performRiskyOperation();
    } catch (e) {
      // Log error but don't crash scheduler
      print('Task failed: $e');
      // Optionally notify monitoring systems
      await notifyError(e);
    }
  }

  Future<void> performRiskyOperation() async {
    // Operation that might fail
  }

  Future<void> notifyError(Object error) async {
    // Send alert to monitoring system
  }
}
```

## 📖 Cron Expression Format

```
┌───────────── second (0-59)
│ ┌───────────── minute (0-59)
│ │ ┌───────────── hour (0-23)
│ │ │ ┌───────────── day of month (1-31)
│ │ │ │ ┌───────────── month (1-12 or JAN-DEC)
│ │ │ │ │ ┌───────────── day of week (0-6 or SUN-SAT)
│ │ │ │ │ │
* * * * * *
```

**Common cron patterns**:

| Pattern | Meaning |
|---------|---------|
| `0 0 * * *` | Every day at midnight |
| `0 12 * * *` | Every day at noon |
| `0 0 * * MON` | Every Monday at midnight |
| `0 0 1 * *` | First day of every month |
| `*/15 * * * *` | Every 15 minutes |
| `0 */6 * * *` | Every 6 hours |
| `30 2 * * *` | Daily at 2:30 AM |

## 🎯 Common Patterns

### Pattern 1: Periodic Data Synchronization

```dart
@Service()
class SyncService {
  final ExternalApiClient _api;
  final Repository _repo;

  @Scheduled(fixedRate: 300000)  // Every 5 minutes
  Future<void> syncData() async {
    try {
      final remoteData = await _api.getData();
      await _repo.updateAll(remoteData);
      print('✓ Data synced successfully');
    } catch (e) {
      print('✗ Sync failed: $e');
    }
  }
}
```

### Pattern 2: Scheduled Reports

```dart
@Service()
class ReportingService {
  final ReportGenerator _generator;
  final EmailService _email;

  @Scheduled(cron: '0 6 * * *')  // 6 AM daily
  Future<void> sendDailyReport() async {
    final report = await _generator.generateDailyReport();
    await _email.send(
      to: 'admin@example.com',
      subject: 'Daily Report',
      body: report,
    );
  }

  @Scheduled(cron: '0 9 * * MON')  // 9 AM every Monday
  Future<void> sendWeeklyReport() async {
    final report = await _generator.generateWeeklyReport();
    await _email.send(
      to: 'team@example.com',
      subject: 'Weekly Report',
      body: report,
    );
  }
}
```

### Pattern 3: Cleanup & Maintenance

```dart
@Service()
class MaintenanceService {
  final Database _db;
  final CacheService _cache;

  @Scheduled(cron: '0 3 * * *')  // 3 AM daily
  Future<void> cleanupOldData() async {
    // Delete records older than 30 days
    await _db.delete(
      'logs',
      where: 'createdAt < DATE_SUB(NOW(), INTERVAL 30 DAY)',
    );
    print('✓ Old data cleaned up');
  }

  @Scheduled(fixedRate: 3600000)  // Every hour
  Future<void> rebuildCache() async {
    await _cache.clear();
    await _cache.preload();
    print('✓ Cache rebuilt');
  }
}
```

### Pattern 4: Health Checks

```dart
@Service()
class HealthCheckService {
  @Scheduled(fixedRate: 60000)  // Every minute
  Future<void> checkServiceHealth() async {
    final health = HealthStatus.healthy;

    // Check database
    try {
      await _db.ping();
    } catch (e) {
      health = HealthStatus.degraded;
      print('⚠️ Database unreachable');
    }

    // Check external service
    try {
      await _externalApi.ping();
    } catch (e) {
      health = HealthStatus.degraded;
      print('⚠️ External service unreachable');
    }

    if (health != HealthStatus.healthy) {
      await notifyOps(health);
    }
  }
}
```

## ⚠️ Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Task not executing | Scheduling not enabled | Ensure `@EnableScheduling` or framework initializes scheduler |
| Cron not working | Invalid expression | Verify cron format |
| Task runs forever | No completion logic | Add timeout or break condition |
| Resource leak | Tasks not cleaned up | Properly close scheduler on shutdown |

## 📋 Best Practices

### ✅ DO

- Keep scheduled tasks lightweight
- Handle exceptions in tasks
- Use appropriate scheduling intervals
- Log task execution
- Monitor long-running tasks
- Clean up resources properly
- Test task logic independently

### ❌ DON'T

- Block the scheduler with long operations
- Schedule too many frequent tasks
- Ignore task failures
- Share mutable state between tasks
- Schedule CPU-intensive work frequently
- Forget error handling
- Create resource leaks in tasks

## 📦 Dependencies

- **`jetleaf_lang`** — Language utilities
- **`jetleaf_logging`** — Structured logging
- **`jetleaf_pod`** — Pod lifecycle
- **`jetleaf_core`** — Core framework

## 📄 License

This package is part of the JetLeaf Framework. See LICENSE in the root directory.

## 🔗 Related Packages

- **`jetleaf_core`** — Framework integration
- **`jetleaf_logging`** — Task logging

## 📞 Support

For issues, questions, or contributions, visit:
- [GitHub Issues](https://github.com/jetleaf/jetleaf_scheduling/issues)
- [Documentation](https://jetleaf.hapnium.com/docs/scheduling)
- [Community Forum](https://forum.jetleaf.hapnium.com)

---

**Created with ❤️ by [Hapnium](https://hapnium.com)**
