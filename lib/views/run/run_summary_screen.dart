import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '/models/run_model.dart';
import '/models/route_model.dart';

class RunSummaryScreen extends StatefulWidget {
  final RouteModel? route;
  final RunModel run;

  /// Optional: the GPS path of the run as LatLng points.
  /// If provided and has at least 2 points, a small map preview is shown.
  final List<LatLng>? path;

  /// Whether the run was actually saved to the backend.
  final bool saved;

  /// Called to retry saving, if [saved] is false. Returns true on success.
  final Future<bool> Function()? onRetrySave;

  const RunSummaryScreen({
    super.key,
    this.route,
    required this.run,
    this.path,
    this.saved = true,
    this.onRetrySave,
  });

  @override
  State<RunSummaryScreen> createState() => _RunSummaryScreenState();
}

class _RunSummaryScreenState extends State<RunSummaryScreen> {
  late bool _saved;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    _saved = widget.saved;
  }

  Future<void> _retry() async {
    if (widget.onRetrySave == null || _retrying) return;

    setState(() => _retrying = true);
    // Minimum delay so the spinner is always visible, even when the
    // failure is near-instant (e.g. no network interface at all).
    final results = await Future.wait([
      widget.onRetrySave!(),
      Future.delayed(const Duration(milliseconds: 500)),
    ]);
    final result = results[0] as bool;
    if (!mounted) return;

    setState(() {
      _saved = result;
      _retrying = false;
    });
  }

  // 🔹 Format duration as HH:MM:SS (or MM:SS if < 1 hour)
  String get _timeText {
    final d = widget.run.duration;

    String twoDigits(int n) => n.toString().padLeft(2, '0');

    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);

    if (hours > 0) {
      // e.g. 01:13:08
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      // e.g. 13:08
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
  }

  String get _paceText {
    // Same UX guard as RunController.formattedPace
    if (widget.run.distanceM < 100 || widget.run.duration.inSeconds < 30) {
      return '--';
    }

    final km = widget.run.distanceM / 1000.0;
    if (km <= 0) return '--';

    final totalSecPerKm = widget.run.duration.inSeconds / km;
    final min = totalSecPerKm ~/ 60;
    final sec = (totalSecPerKm % 60).round();

    return '$min:${sec.toString().padLeft(2, '0')} /km';
  }

  @override
  Widget build(BuildContext context) {
    final purple = const Color(0xFF9C27B0);
    final route = widget.route;
    final run = widget.run;
    final path = widget.path;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Run Summary'),
        backgroundColor: purple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_saved) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 18,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        "This run wasn't saved online.",
                        style: TextStyle(fontSize: 13, color: Colors.red),
                      ),
                    ),
                    if (widget.onRetrySave != null)
                      TextButton(
                        onPressed: _retrying ? null : _retry,
                        child: _retrying
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Retry'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (route != null) ...[
              Text(
                route.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Route completed',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 16),
            ],

            // Mini map preview of the route (if path is provided)
            if (path != null && path.length >= 2) _buildRouteMap(path),

            const SizedBox(height: 16),

            // Summary Card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 24,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _SummaryStat(
                      label: 'Distance',
                      value: '${run.distanceKm.toStringAsFixed(2)} km',
                    ),
                    _SummaryStat(label: 'Time', value: _timeText),
                    _SummaryStat(label: 'Pace', value: _paceText),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Date and duration info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Started: ${_formatDate(run.startedAt)}',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
                Text(
                  'Ended: ${_formatTime(run.endedAt)}',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),

            const SizedBox(height: 40),

            const Text(
              'Great work! 🎉',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Keep up your consistency to improve your pace and endurance.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),

            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: () =>
                  Navigator.popUntil(context, (r) => r.isFirst),
              style: ElevatedButton.styleFrom(
                backgroundColor: purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                'Done',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- helpers ---

  // Build a small GoogleMap snapshot-style card
  Widget _buildRouteMap(List<LatLng> pts) {
    // Compute a simple center from bounds
    double minLat = pts.first.latitude;
    double maxLat = pts.first.latitude;
    double minLng = pts.first.longitude;
    double maxLng = pts.first.longitude;

    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);

    final polyline = Polyline(
      polylineId: const PolylineId('run_path_preview'),
      color: const Color(0xFF9C27B0),
      width: 5,
      points: pts,
    );

    return Container(
      height: 220,
      decoration: BoxDecoration(
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
      child: GoogleMap(
        initialCameraPosition: CameraPosition(target: center, zoom: 14),
        polylines: {polyline},
        markers: {
          Marker(markerId: const MarkerId('start'), position: pts.first),
          Marker(markerId: const MarkerId('end'), position: pts.last),
        },
        zoomControlsEnabled: false,
        myLocationEnabled: false,
        myLocationButtonEnabled: false,
        compassEnabled: false,
        mapToolbarEnabled: false,
        buildingsEnabled: false,
        tiltGesturesEnabled: false,
      ),
    );
  }

  /// Format date in the **device's local timezone** (EAT on your phone)
  static String _formatDate(DateTime d) {
    final local = d.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  /// Format time in the **device's local timezone**
  static String _formatTime(DateTime d) {
    final local = d.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
