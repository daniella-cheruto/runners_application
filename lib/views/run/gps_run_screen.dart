import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '/models/route_model.dart';
import '/models/run_model.dart';
import '/widgets/custom_button.dart';
import '/widgets/map_widget.dart';
import '/controllers/run_controller.dart';
import '/views/run/run_summary_screen.dart';

class GpsRunScreen extends StatefulWidget {
  final RouteModel route;
  const GpsRunScreen({super.key, required this.route});

  @override
  State<GpsRunScreen> createState() => _GpsRunScreenState();
}

class _GpsRunScreenState extends State<GpsRunScreen> {
  late final RunController _run;

  @override
  void initState() {
    super.initState();
    _run = RunController()
      ..addListener(() {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  CameraPosition get _initialCamera {
    if (_run.positions.isNotEmpty) {
      final p = _run.positions.last;
      return CameraPosition(target: LatLng(p.latitude, p.longitude), zoom: 15);
    }
    // default (Nairobi-ish)
    return const CameraPosition(target: LatLng(-1.286389, 36.817223), zoom: 13);
  }

  Set<Marker> get _markers {
    if (_run.positions.isEmpty) return {};
    final p = _run.positions.last;
    return {
      Marker(
        markerId: const MarkerId('current'),
        position: LatLng(p.latitude, p.longitude),
      ),
    };
  }

  Set<Polyline> get _polylines {
    if (_run.positions.length < 2) return {};
    return {
      Polyline(
        polylineId: const PolylineId('run_path'),
        width: 5,
        color: const Color(0xFF9C27B0),
        points: _run.positions
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList(),
      ),
    };
  }

  // 🔹 Updated to also pass the GPS path to the summary screen
  Future<void> _handleStop() async {
    final route = widget.route;
    final routeId = route.routeId;
    final navigator = Navigator.of(context);

    var saved = await _run.stop(routeId: routeId);

    if (!saved) {
      if (!mounted) return;

      // The dialog manages its own retry loop internally (via
      // StatefulBuilder) so it only ever closes once — either the save
      // actually succeeds, or the user explicitly chooses to continue
      // without saving. No flicker of separate dialogs opening/closing.
      saved =
          await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) {
              var retrying = false;

              return StatefulBuilder(
                builder: (context, setDialogState) => AlertDialog(
                  title: const Text('Run not saved'),
                  content: retrying
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Retrying…'),
                          ],
                        )
                      : Text(
                          _run.statusMessage ??
                              "Your run couldn't be saved online. You can retry or continue without saving.",
                        ),
                  actions: retrying
                      ? const []
                      : [
                          TextButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(false),
                            child: const Text('Continue without saving'),
                          ),
                          TextButton(
                            onPressed: () async {
                              setDialogState(() => retrying = true);
                              // Minimum delay so the spinner is always
                              // visible, even when the failure is near-
                              // instant (e.g. no network interface at all).
                              final results = await Future.wait([
                                _run.retrySave(routeId),
                                Future.delayed(
                                  const Duration(milliseconds: 500),
                                ),
                              ]);
                              final resaved = results[0] as bool;
                              if (!dialogContext.mounted) return;
                              if (resaved) {
                                Navigator.of(dialogContext).pop(true);
                              } else {
                                setDialogState(() => retrying = false);
                              }
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                ),
              );
            },
          ) ??
          false;
    }

    if (!mounted) return;

    final endedAt = DateTime.now();
    final startedAt = _run.elapsed > Duration.zero
        ? endedAt.subtract(_run.elapsed)
        : endedAt;

    final summary = RunModel(
      id: 0, // real id comes from backend if you later fetch it
      userId: 'local',
      routeId: routeId,
      distanceM: _run.distanceMeters,
      durationS: _run.elapsed.inSeconds,
      startedAt: startedAt,
      endedAt: endedAt,
    );

    // Convert recorded positions to LatLng for the mini-map on the summary
    final path = _run.positions
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    navigator.push(
      MaterialPageRoute(
        builder: (_) => RunSummaryScreen(
          route: route,
          run: summary,
          path: path,
          saved: saved,
          onRetrySave: saved ? null : () => _run.retrySave(routeId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final purple = const Color(0xFF9C27B0);
    final bg = const Color(0xFFF7F3FF);
    final r = widget.route;
    final statusColor = Color(_run.statusColorValue);

    final isRunning = _run.running;
    final hasStarted = _run.hasStartedOnce;
    final isPaused = _run.isPaused;

    return Scaffold(
      appBar: AppBar(title: Text('Run: ${r.name}'), backgroundColor: purple),
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_run.statusMessage != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 10,
                  ),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: statusColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _run.statusMessage!,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              Text(
                r.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${(r.distanceM / 1000).toStringAsFixed(1)} km • Target route',
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      MapWidget(
                        initialPosition: _initialCamera,
                        markers: _markers,
                        polylines: _polylines,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                        fitToMarkers: true,
                        padding: 60,
                      ),
                      Positioned(
                        left: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 3,
                            horizontal: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.gps_fixed,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isRunning
                                    ? 'Tracking live'
                                    : (hasStarted ? 'Paused' : 'Idle'),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 18,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _StatBlock(
                        label: 'Distance',
                        value:
                            '${(_run.distanceMeters / 1000).toStringAsFixed(2)} km',
                      ),
                      _StatBlock(label: 'Time', value: _run.formattedTime),
                      _StatBlock(label: 'Pace', value: _run.formattedPace),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              if (!hasStarted) ...[
                CustomButton(
                  label: 'Start Run',
                  color: purple,
                  onPressed: () async {
                    await _run.start();
                  },
                ),
              ] else if (isRunning) ...[
                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        label: 'Pause',
                        color: const Color(0xFFFFA000),
                        onPressed: () {
                          _run.pause();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomButton(
                        label: 'Stop Run',
                        color: Colors.red,
                        onPressed: _handleStop,
                      ),
                    ),
                  ],
                ),
              ] else if (isPaused) ...[
                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        label: 'Resume Run',
                        color: purple,
                        onPressed: () async {
                          await _run.resume();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomButton(
                        label: 'Stop Run',
                        color: Colors.red,
                        onPressed: _handleStop,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 8),
              const Text(
                'Keep your screen on and location enabled while running.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;
  const _StatBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.black45),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
