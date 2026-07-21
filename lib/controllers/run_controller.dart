import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RunController extends ChangeNotifier {
  // ---- state ----
  bool _running = false;
  bool _hasStartedOnce = false;

  bool get running => _running;
  bool get hasStartedOnce => _hasStartedOnce;
  bool get isPaused => _hasStartedOnce && !_running;

  final List<Position> _positions = [];
  List<Position> get positions => List.unmodifiable(_positions);

  double _distanceMeters = 0.0;
  double get distanceMeters => _distanceMeters;

  /// Total active time (only when actually running, not paused)
  Duration _elapsed = Duration.zero;
  Duration get elapsed => _elapsed;

  /// Sum of all previous active segments (before the current resume)
  Duration _accumulatedActive = Duration.zero;

  /// When we last resumed/start running; null when paused/stopped
  DateTime? _lastResumeAt;

  String? _statusMessage;
  String? get statusMessage => _statusMessage;

  int _statusColorValue = 0xFF4CAF50; // green-ish
  int get statusColorValue => _statusColorValue;

  Timer? _timer;
  StreamSubscription<Position>? _posSub;
  Position? _lastPosition;
  DateTime? _startedAt;
  DateTime? _endedAt;
  int _positionCount = 0;
  DateTime? _lastPositionTime;
  Timer? _watchdogTimer;

  final _supabase = Supabase.instance.client;

  // ---- lifecycle ----

  @override
  void dispose() {
    _timer?.cancel();
    _posSub?.cancel();
    _watchdogTimer?.cancel();
    super.dispose();
  }

  // ---- helpers ----

  Future<String?> _ensureLocationReady() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return 'Please enable location services to track your run.';
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    if (perm == LocationPermission.denied) {
      return 'Location permission denied.';
    }
    if (perm == LocationPermission.deniedForever) {
      return 'Location permission permanently denied. Enable it in Settings.';
    }

    return null;
  }

  void _setStatus(String msg, int colorValue) {
    _statusMessage = msg;
    _statusColorValue = colorValue;
    notifyListeners();
  }

  /// Timer now just refreshes elapsed based on real wall-clock time
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_running) return;

      if (_lastResumeAt != null) {
        final now = DateTime.now();
        _elapsed = _accumulatedActive + now.difference(_lastResumeAt!);
      } else {
        _elapsed = _accumulatedActive;
      }
      notifyListeners();
    });
  }

  void _startPositionStream() {
    _posSub?.cancel();
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen((pos) {
      if (!_running) return;

      // Discard first 3 fixes — GPS needs time to lock on accurately
      if (_positionCount < 3) {
        _positionCount++;
        return;
      }

      // Skip poor accuracy points (relaxed for forest environments)
      if (pos.accuracy > 50) return;

      // Skip GPS jumps — no runner moves faster than 54 km/h
      if (_lastPosition != null && pos.speed > 15) return;

      if (_lastPosition != null) {
        final delta = Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          pos.latitude,
          pos.longitude,
        );

        if (delta >= 3) {
          _distanceMeters += delta;
          _positions.add(pos);
          notifyListeners();
        }
      } else {
        _positions.add(pos);
      }

      _lastPosition = pos;
      _lastPositionTime = DateTime.now();
    });
  }

  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_running) return;

      final silentFor = _lastPositionTime != null
          ? DateTime.now().difference(_lastPositionTime!).inSeconds
          : 0;

      if (silentFor > 60) {
        debugPrint('GPS silent for ${silentFor}s — forcing fresh position');
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
        _lastPositionTime = DateTime.now();
      }
    } catch (e) {
      debugPrint('Failed to get fresh position: $e');
    }
  }

  Future<void> _stopPositionStream() async {
    if (_posSub != null) {
      await _posSub!.cancel();
      _posSub = null;
    }
    _lastPosition = null;
  }

  /// When pausing/stopping, fold the current segment into accumulated time.
  void _finaliseElapsedNow() {
    final now = DateTime.now();
    if (_lastResumeAt != null) {
      _accumulatedActive += now.difference(_lastResumeAt!);
      _lastResumeAt = null;
    }
    _elapsed = _accumulatedActive;
  }

  // ---- public API ----

  /// Start a NEW run.
  Future<String?> start() async {
    // If already started before, let UI call resume() instead.
    if (_running) return null;
    if (_hasStartedOnce) {
      // Safety: don't silently reset if they've already run.
      return 'Run already started. Use Resume or Stop.';
    }

    final err = await _ensureLocationReady();
    if (err != null) {
      _setStatus(err, 0xFFF44336); // red
      return err;
    }

    final now = DateTime.now();

    _running = true;
    _hasStartedOnce = true;

    _distanceMeters = 0;
    _elapsed = Duration.zero;
    _accumulatedActive = Duration.zero;
    _lastResumeAt = now;
    _positions.clear();
    _lastPosition = null;
    _startedAt = now;
    _positionCount = 0;

    _setStatus('Tracking started. Enjoy your run 🏃‍♀️', 0xFF4CAF50);

    _startTimer();
    _startPositionStream();
    _startWatchdog();

    return null;
  }

  /// Resume after a pause (keeps distance/time).
  Future<String?> resume() async {
    if (_running || !_hasStartedOnce) return null;

    final err = await _ensureLocationReady();
    if (err != null) {
      _setStatus(err, 0xFFF44336);
      return err;
    }

    _running = true;
    _lastResumeAt = DateTime.now();
    _setStatus('Run resumed. Keep going 🏃‍♀️', 0xFF4CAF50);

    _startTimer();
    _startPositionStream();
    _startWatchdog();

    return null;
  }

  /// Pause run: stop tracking but keep stats for resume.
  Future<void> pause() async {
    if (!_running || !_hasStartedOnce) return;

    _running = false;

    // lock in elapsed up to this moment
    _finaliseElapsedNow();

    _timer?.cancel();
    _timer = null;
    _watchdogTimer?.cancel();
    _watchdogTimer = null;

    await _stopPositionStream();

    _setStatus('Run paused. Tap resume to continue.', 0xFFFF9800);
    notifyListeners();
  }

  /// Stop run: finalise tracking locally, then attempt to save to Supabase.
  /// Returns true if the save succeeded, false otherwise (e.g. logged out,
  /// no network). On failure, call [retrySave] to try again without
  /// re-finalising tracking or losing the recorded distance/time/points.
  Future<bool> stop({required int routeId}) async {
    if (!_hasStartedOnce) return false;

    // finalise elapsed one last time
    _finaliseElapsedNow();

    _running = false;

    _timer?.cancel();
    _timer = null;
    _watchdogTimer?.cancel();
    _watchdogTimer = null;

    await _stopPositionStream();

    _endedAt = DateTime.now();
    final km = _distanceMeters / 1000.0;

    _setStatus(
      'Run stopped. Distance: ${km.toStringAsFixed(2)} km in $formattedTime.',
      0xFF9C27B0,
    );

    return retrySave(routeId);
  }

  /// Attempt (or retry) saving the finalised run to Supabase. Safe to call
  /// again after a failure — reuses the original end time rather than the
  /// moment the retry happened, so `ended_at` stays accurate.
  Future<bool> retrySave(int routeId) async {
    final endedAt = _endedAt ?? DateTime.now();
    final startedAt = _startedAt ?? endedAt;
    final km = _distanceMeters / 1000.0;

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        _setStatus(
          "Not saved — you're logged out. Log in and retry.",
          0xFFF44336,
        );
        return false;
      }

      // 1) Insert into runs and get new run_id
      final runRow = await _supabase
          .from('runs')
          .insert({
            'user_id': user.id,
            'route_id': routeId,
            'distance_m': _distanceMeters,
            'duration_s': _elapsed.inSeconds,
            'started_at': startedAt.toUtc().toIso8601String(),
            'ended_at': endedAt.toUtc().toIso8601String(),
          })
          .select('id')
          .single();

      final runId = runRow['id'] as int;

      // 2) Insert GPS points (if any)
      if (_positions.isNotEmpty) {
        final pointsPayload = <Map<String, dynamic>>[];

        for (var i = 0; i < _positions.length; i++) {
          final p = _positions[i];
          final ts = p.timestamp;

          pointsPayload.add({
            'run_id': runId,
            'seq': i,
            'lat': p.latitude,
            'lng': p.longitude,
            'recorded_at': ts.toUtc().toIso8601String(),
          });
        }

        await _supabase.from('run_points').insert(pointsPayload);
      }

      _setStatus(
        'Run saved, Distance: ${km.toStringAsFixed(2)} km in $formattedTime.',
        0xFF4CAF50,
      );
      return true;
    } catch (e) {
      // Don't leak raw exception details to the user; log for debugging.
      debugPrint('retrySave error: $e');
      _setStatus(
        "Not saved — couldn't reach the server. Check your connection and retry.",
        0xFFF44336,
      );
      return false;
    }
  }

  // ---- formatting helpers ----

  String get formattedTime {
    final m = _elapsed.inMinutes;
    final s = _elapsed.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Human-readable pace: mm:ss /km
  /// Only shown when distance & time are meaningful.
  String get formattedPace {
    // Require at least 100m and 30s to avoid junk values
    if (_distanceMeters < 100 || _elapsed.inSeconds < 30) return '--';

    final km = _distanceMeters / 1000.0;
    if (km <= 0) return '--';

    final paceSecPerKm = _elapsed.inSeconds / km;
    final paceMin = paceSecPerKm ~/ 60;
    final paceSec = (paceSecPerKm % 60).round();

    return '$paceMin:${paceSec.toString().padLeft(2, '0')} /km';
  }
}
