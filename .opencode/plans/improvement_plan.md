# Runners Application - Improvement Plan

**Last Updated:** April 2026
**Status:** Planned (Not Implemented)

---

## Table of Contents

1. [GPS Improvements for Forests](#1-gps-improvements-for-forests)
2. [Clean Architecture Refactor](#2-clean-architecture-refactor)
3. [Areas of Improvement](#3-areas-of-improvement)
4. [New Features](#4-new-features)
5. [Implementation Order](#5-implementation-order)

---

## 1. GPS Improvements for Forests

### Problem
When running in areas with poor GPS signal (e.g., Kimakia Falls forest), the app doesn't track distance, pace, or location accurately.

### Causes
- Dense tree cover degrades GPS signal
- `LocationAccuracy.best` isn't optimized for degraded conditions
- No cold-start filtering (first GPS fixes are unreliable)
- No handling for intermittent GPS lock

### Solution: Phase A - Tune Geolocator Settings

**File to modify:** `lib/controllers/run_controller.dart`

```dart
void _startPositionStream() {
  _posSub?.cancel();

  final locationSettings = LocationSettings(
    accuracy: LocationAccuracy.bestForNavigation, // Changed from 'best'
    distanceFilter: 10, // Capture movement every 10 meters
  );

  _posSub = Geolocator.getPositionStream(
    locationSettings: locationSettings,
  ).listen((pos) {
    // Add cold-start filtering
    if (_positionCount < 3) {
      _positionCount++;
      return; // Discard first 3 fixes (GPS warm-up)
    }

    // Improve accuracy filter for forests
    if (pos.accuracy > 50) {
      debugPrint('Skipping low-quality GPS fix: ${pos.accuracy}m accuracy');
      return;
    }

    // Add speed sanity check
    if (_lastPosition != null) {
      final speed = pos.speed; // m/s
      if (speed > 15) { // ~54 km/h, faster than running
        debugPrint('Skipping GPS jump: ${speed}m/s');
        return;
      }
    }

    // Existing distance calculation logic...
  });
}
```

**Changes Summary:**

| Setting | Before | After |
|---------|--------|-------|
| Accuracy | `best` | `bestForNavigation` |
| Distance filter | `1m` | `10m` |
| Accuracy threshold | `>25m` reject | `>50m` reject |
| Cold-start filter | None | Discard first 3 fixes |

---

### Solution: Phase B - Add Offline GPS Caching

**Add packages:**
```yaml
dependencies:
  sqflite: ^2.3.0
  path: ^1.8.0
```

**Create:** `lib/data/local/position_cache.dart`

```dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class PositionCache {
  static Database? _db;

  Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    return openDatabase(
      join(await getDatabasesPath(), 'run_cache.db'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pending_positions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            lat REAL,
            lng REAL,
            timestamp TEXT,
            accuracy REAL,
            synced INTEGER DEFAULT 0
          )
        ''');
      },
    );
  }

  Future<void> cachePosition(double lat, double lng, DateTime timestamp, double accuracy) async {
    final database = await db;
    await database.insert('pending_positions', {
      'lat': lat,
      'lng': lng,
      'timestamp': timestamp.toIso8601String(),
      'accuracy': accuracy,
      'synced': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getPending() async {
    final database = await db;
    return database.query('pending_positions', where: 'synced = ?', whereArgs: [0]);
  }

  Future<void> markSynced(int id) async {
    final database = await db;
    await database.update('pending_positions', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }
}
```

**Update:** `lib/controllers/run_controller.dart`

Add `PositionCache` to `stop()` method:

```dart
Future<void> stop({required int routeId}) async {
  // ... existing logic ...

  // Sync cached positions
  await _syncPendingPositions(runId);
}

Future<void> _syncPendingPositions(int runId) async {
  final pending = await _positionCache.getPending();
  if (pending.isEmpty) return;

  final payload = pending.map((p) => {
    'run_id': runId,
    'lat': p['lat'],
    'lng': p['lng'],
    'recorded_at': p['timestamp'],
  }).toList();

  try {
    await _supabase.from('run_points').insert(payload);

    for (final p in pending) {
      await _positionCache.markSynced(p['id']);
    }
  } catch (e) {
    debugPrint('Failed to sync positions: $e');
    // Positions remain in local DB for next sync attempt
  }
}
```

---

### Solution: Phase C - Watchdog for GPS Silence

Add to `lib/controllers/run_controller.dart`:

```dart
int _positionCount = 0;
DateTime? _lastPositionTime;
Timer? _watchdogTimer;

void _startWatchdog() {
  _watchdogTimer?.cancel();
  _watchdogTimer = Timer.periodic(const Duration(seconds: 30), (_) {
    if (!_running) return;

    final silentFor = _lastPositionTime != null
        ? DateTime.now().difference(_lastPositionTime!).inSeconds
        : 0;

    if (silentFor > 60) {
      debugPrint('GPS silent for $silentFor seconds - forcing fresh position');
      _forceFreshPosition();
    }
  });
}

Future<void> _forceFreshPosition() async {
  try {
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.bestForNavigation,
    ).timeout(const Duration(seconds: 10));

    if (pos.accuracy <= 50) {
      _handlePosition(pos);
    }
  } catch (e) {
    debugPrint('Failed to get fresh position: $e');
  }
}
```

Call `_startWatchdog()` in `start()` and `resume()` methods.

---

## 2. Clean Architecture Refactor

### Current State
- Controllers directly call Supabase (no abstraction)
- Inconsistent patterns (some extend `ChangeNotifier`, some don't)
- No repository layer
- No dependency injection

### Target State
```
lib/
├── core/
│   ├── constants/
│   ├── theme/
│   └── utils/
├── data/
│   ├── datasources/
│   │   └── supabase_client.dart
│   └── repositories/
│       ├── auth_repository.dart (interface)
│       ├── supabase_auth_repository.dart
│       ├── route_repository.dart
│       ├── supabase_route_repository.dart
│       ├── run_repository.dart
│       └── supabase_run_repository.dart
├── domain/
│   ├── entities/
│   └── usecases/
├── presentation/
│   ├── controllers/
│   ├── providers/
│   ├── screens/
│   └── widgets/
└── main.dart
```

### Phase 1: Create Repository Layer

**Step 1.1 - Create Supabase Client Wrapper**

Create: `lib/data/datasources/supabase_client.dart`

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseDataSource {
  static final SupabaseClient _client = Supabase.instance.client;

  SupabaseClient get client => _client;

  // Typed query helpers
  Future<List<Map<String, dynamic>>> select(String table, {
    String? columns,
    Map<String, dynamic>? filters,
    int? limit,
    String? orderBy,
    bool ascending = true,
  }) async {
    var query = _client.from(table).select(columns ?? '*');

    if (filters != null) {
      filters.forEach((key, value) {
        query = query.eq(key, value);
      });
    }

    if (orderBy != null) {
      query = query.order(orderBy, ascending: ascending);
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    final response = await query;
    return List<Map<String, dynamic>>.from(response);
  }
}

final supabaseDataSource = SupabaseDataSource();
```

**Step 1.2 - Create Repository Interfaces**

Create: `lib/data/repositories/auth_repository.dart`

```dart
abstract class AuthRepository {
  Future<dynamic> login(String email, String password);
  Future<dynamic> register(String email, String password, String fullName);
  Future<dynamic> forgotPassword(String email);
  Future<dynamic> updatePassword(String newPassword);
  Future<void> logout();
  User? getCurrentUser();
  Session? getCurrentSession();
}
```

Create: `lib/data/repositories/route_repository.dart`

```dart
import '../../models/route_model.dart';

abstract class RouteRepository {
  Future<List<RouteModel>> fetchRoutes({
    double? maxDistance,
    double? minRating,
    int? minPopularity,
  });
  Future<List<RouteModel>> searchRoutes(String term);
  Future<bool> addRoute({
    required String name,
    required String description,
    required int distanceM,
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  });
}
```

**Step 1.3 - Create Repository Implementations**

Create: `lib/data/repositories/supabase_auth_repository.dart`

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _client = Supabase.instance.client;

  @override
  Future<dynamic> login(String email, String password) async {
    // Move logic from AuthController here
  }

  @override
  Future<dynamic> register(String email, String password, String fullName) async {
    // Move logic from AuthController here
  }

  // ... other methods
}
```

**Step 1.4 - Update Controllers to Use Repositories**

```dart
// Before
class AuthController {
  final SupabaseClient _client = Supabase.instance.client;
  // Direct Supabase calls
}

// After
class AuthController {
  final AuthRepository _repository;

  AuthController({AuthRepository? repository})
      : _repository = repository ?? SupabaseAuthRepository();
}
```

---

### Phase 2: Add Dependency Injection

**Add to pubspec.yaml:**
```yaml
dependencies:
  get_it: ^7.6.0
```

**Create:** `lib/core/di/injection.dart`

```dart
import 'package:get_it/get_it.dart';
import '../data/datasources/supabase_client.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/supabase_auth_repository.dart';
import '../data/repositories/route_repository.dart';
import '../data/repositories/supabase_route_repository.dart';

final getIt = GetIt.instance;

void setupDependencies() {
  // Data Sources
  getIt.registerLazySingleton<SupabaseDataSource>(() => supabaseDataSource);

  // Repositories
  getIt.registerLazySingleton<AuthRepository>(() => SupabaseAuthRepository());
  getIt.registerLazySingleton<RouteRepository>(() => SupabaseRouteRepository());

  // Controllers (if still using)
  // getIt.registerFactory<AuthController>(() => AuthController());
}
```

**Update:** `lib/main.dart`

```dart
import 'core/di/injection.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Supabase.initialize(...);

  setupDependencies(); // Add this

  runApp(const MyApp());
}
```

---

### Phase 3: Add Riverpod State Management

**Add to pubspec.yaml:**
```yaml
dependencies:
  flutter_riverpod: ^2.4.0

dev_dependencies:
  riverpod_generator: ^2.3.0
  build_runner: ^2.4.0
```

**Convert RunController to Riverpod:**

```dart
// lib/presentation/providers/run_provider.dart
import 'package:riverpod/riverpod.dart';

final runProvider = StateNotifierProvider<RunNotifier, RunState>((ref) {
  return RunNotifier();
});

class RunState {
  final bool running;
  final double distanceMeters;
  final Duration elapsed;
  final List<Position> positions;
  // ... other state
}

class RunNotifier extends StateNotifier<RunState> {
  RunNotifier() : super(RunState());

  Future<void> start() async {
    // Start logic
  }

  void pause() {
    // Pause logic
  }
}
```

---

### Phase 4: Extract Utilities

**Create:** `lib/core/utils/formatters.dart`

```dart
class DurationFormatter {
  static String format(Duration duration) {
    final m = duration.inMinutes;
    final s = duration.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  static String formatPace(double distanceMeters, Duration elapsed) {
    if (distanceMeters < 100 || elapsed.inSeconds < 30) return '--';
    final km = distanceMeters / 1000.0;
    final paceSecPerKm = elapsed.inSeconds / km;
    final paceMin = paceSecPerKm ~/ 60;
    final paceSec = (paceSecPerKm % 60).round();
    return '$paceMin:${paceSec.toString().padLeft(2, '0')} /km';
  }
}

class DistanceFormatter {
  static String formatKm(double meters) {
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  static String formatMeters(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    }
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }
}
```

---

## 3. Areas of Improvement

### High Priority

| Issue | Solution |
|-------|----------|
| No offline GPS support | Add SQLite caching (Phase B above) |
| No loading states | Create `LoadingWidget` component |
| No error boundaries | Wrap async operations with error handling |
| No pull-to-refresh | Add `RefreshIndicator` to list screens |

### Medium Priority

| Issue | Solution |
|-------|----------|
| Inconsistent navigation | Standardize on named routes |
| No image compression | Compress photos before upload |
| No rate limiting | Debounce search requests (300ms) |
| No pagination | Add `.limit()` and `.range()` to list queries |
| Duplicate profile fetching | Consolidate `home_controller` + `profile_controller` into single source of truth |
| No input length validation | Add max length on feedback comments and incident descriptions |
| No tests | Add unit tests for controllers alongside repository refactor |

### Low Priority

| Issue | Solution |
|-------|----------|
| Hardcoded colors | Create theme file with `AppColors` |
| No dark mode | Add `ThemeMode` switching |
| No onboarding | Create onboarding screens |
| No push notifications | Add Firebase Cloud Messaging |

---

## 4. New Features

| Feature | Priority | Description |
|---------|----------|-------------|
| Offline mode toggle | High | Save runs locally, sync when online |
| Run challenges | Medium | Weekly/monthly distance goals |
| Social features | Low | Follow runners, share routes |
| Route suggestions | Low | Recommend routes based on history |
| Export data | Medium | Download runs as CSV/GPX |
| Wear OS support | Low | Better GPS with companion device |

---

## 5. Implementation Order

### Recommended Sequence

```
1. [GPS Improvements]
   │
   ├── Phase A: Tune Geolocator Settings
   │      File: lib/controllers/run_controller.dart
   │      Effort: Low
   │
   ├── Phase B: Add SQLite Caching
   │      New Files: lib/data/local/position_cache.dart
   │      Effort: Medium
   │
   └── Phase C: Add Watchdog
          File: lib/controllers/run_controller.dart
          Effort: Low

2. [Architecture Refactor]
   │
   ├── Create Supabase Client Wrapper
   │      File: lib/data/datasources/supabase_client.dart
   │
   ├── Create Repository Interfaces
   │      Files: lib/data/repositories/*.dart
   │
   ├── Create Repository Implementations
   │      Files: lib/data/repositories/supabase_*.dart
   │
   ├── Update Controllers to Use Repositories
   │      Files: lib/controllers/*.dart
   │
   ├── Setup Dependency Injection (GetIt)
   │      File: lib/core/di/injection.dart
   │
   └── Add Riverpod (optional)
          Files: lib/presentation/providers/*.dart

3. [UI Improvements]
   │
   ├── Add LoadingWidget
   │      File: lib/widgets/loading_widget.dart
   │
   ├── Add ErrorWidget
   │      File: lib/widgets/error_widget.dart
   │
   ├── Add Pull-to-Refresh
   │      Screens: All list screens
   │
   └── Add Pagination
          Controllers: Routes, Runs, Incidents

4. [Extras]
   │
   ├── Create Theme File
   │      File: lib/core/theme/app_theme.dart
   │
   ├── Add Formatters
   │      File: lib/core/utils/formatters.dart
   │
   └── Add Validators
          File: lib/core/utils/validators.dart
```

---

## Quick Wins (Do First)

These can be done in under an hour each:

1. **Change GPS accuracy** - 1 line change in `run_controller.dart`
2. **Add pull-to-refresh** - 5 lines per list screen
3. **Add loading indicators** - Create reusable widget
4. **Debounce search** - Add timer cancel/restart
5. **Move all config to `.env`** - Keep environment-specific values out of source code

---

## Notes

- RLS policies are managed via Supabase Dashboard
- Current architecture works fine for small teams
- Refactor incrementally to reduce risk
- Test GPS changes in real forest environment
- `distanceFilter: 5` may be better than `10` for slow trail pace — test in the field
- Add tests alongside the repository layer (interfaces make unit testing straightforward)
- Consider consolidating duplicate controller logic when doing the architecture refactor

---

*Document created based on code review - April 2026*
