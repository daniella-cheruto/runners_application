// lib/views/home/route_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '/models/route_model.dart';
import '/models/route_photo_model.dart';
import '/models/route_feedback_model.dart';
import '/models/incident_report_model.dart';

import '/controllers/route_photos_controller.dart';
import '/controllers/route_feedback_controller.dart';
import '/controllers/incident_report_controller.dart';

import '../feedback/community_feedback_screen.dart';
import '/views/incident/route_incidents_screen.dart';

import 'widgets/route_header.dart';
import 'widgets/route_photos_section.dart';
import 'widgets/start_run_button.dart';

class RouteDetailScreen extends StatefulWidget {
  final RouteModel route;
  const RouteDetailScreen({super.key, required this.route});

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen> {
  final _photosCtrl = RoutePhotosController();
  final _feedbackCtrl = RouteFeedbackController();
  final _incidentCtrl = IncidentReportController();

  late Future<List<RoutePhoto>> _photosFuture;
  late Future<List<RouteFeedback>> _feedbackFuture;

  bool _uploading = false;

  String? _statusMessage;
  Color _statusColor = Colors.green;

  // dynamic average rating from feedback
  double? _avgRating; // null = no feedback yet

  @override
  void initState() {
    super.initState();
    final routeId = widget.route.routeId;
    _photosFuture = _photosCtrl.list(routeId);
    _feedbackFuture = _feedbackCtrl.fetchForRoute(routeId);
    _loadAverageRating(); // also load average rating from feedback
  }

  // Load avg rating from route_feedback
  Future<void> _loadAverageRating() async {
    try {
      final avg = await _feedbackCtrl.averageForRoute(widget.route.routeId);
      if (!mounted) return;
      setState(() {
        _avgRating = avg; // can be null if no feedback rows
      });
    } catch (_) {
      if (!mounted) return;
      // If it fails, we just keep _avgRating as null and fall back to route.averageRating
    }
  }

  void _showStatus(String msg, Color color) {
    setState(() {
      _statusMessage = msg;
      _statusColor = color;
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _statusMessage = null);
      }
    });
  }

  Future<void> _refreshAll() async {
    final routeId = widget.route.routeId;
    setState(() {
      _photosFuture = _photosCtrl.list(routeId);
      _feedbackFuture = _feedbackCtrl.fetchForRoute(routeId);
      _statusMessage = null;
    });

    // refresh average rating too
    await _loadAverageRating();
  }

  Future<void> _addPhoto() async {
    if (_uploading) return;

    setState(() {
      _uploading = true;
      _statusMessage = null;
    });

    try {
      final ok = await _photosCtrl.pickAndUpload(routeId: widget.route.routeId);
      if (!mounted) return;

      if (ok) {
        setState(() {
          _photosFuture = _photosCtrl.list(widget.route.routeId);
        });
        _showStatus('Photo uploaded successfully!', Colors.green);
      } else {
        _showStatus('Upload cancelled or failed.', Colors.red);
      }
    } catch (e) {
      if (!mounted) return;
      _showStatus('Unexpected error: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  Future<void> _confirmDelete(RoutePhoto photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete photo?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final msg = await _photosCtrl.deletePhoto(photo);
    if (!mounted) return;

    if (msg == null) {
      setState(() {
        _photosFuture = _photosCtrl.list(widget.route.routeId);
      });
      _showStatus('Photo deleted.', Colors.green);
    } else {
      _showStatus(msg, Colors.red);
    }
  }

  void _openPhotoViewer(String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image, color: Colors.white),
                ),
              ),
            ),
            const Positioned(
              top: 16,
              right: 16,
              child: CloseButton(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  void _openAllFeedback() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => CommunityFeedbackScreen(route: widget.route),
          ),
        )
        .then((_) {
          // when returning, refresh feedback + average rating
          setState(() {
            _feedbackFuture = _feedbackCtrl.fetchForRoute(widget.route.routeId);
          });
          _loadAverageRating();
        });
  }

  @override
  Widget build(BuildContext context) {
    final purple = const Color(0xFF9C27B0);
    final r = widget.route;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(title: Text(r.name), backgroundColor: purple),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1) Header (now using dynamic avg if available)
            RouteHeader(
              route: r,
              overrideAverageRating:
                  _avgRating, // this comes from feedback table
            ),

            const SizedBox(height: 24),

            // 2) Photos section
            RoutePhotosSection(
              photosFuture: _photosFuture,
              photosCtrl: _photosCtrl,
              uploading: _uploading,
              currentUserId: currentUserId,
              onAddPhoto: _addPhoto,
              onViewPhoto: _openPhotoViewer,
              onDeletePhoto: _confirmDelete,
            ),

            if (_statusMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _statusMessage!,
                style: TextStyle(
                  color: _statusColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],

            // 3) Safety incidents (only shows if there is at least 1)
            FutureBuilder<List<IncidentReport>>(
              future: _incidentCtrl.fetchForRoute(widget.route.routeId),
              builder: (context, snapshot) {
                // hide while loading
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox.shrink();
                }

                // hide completely if error or empty
                if (snapshot.hasError ||
                    !snapshot.hasData ||
                    (snapshot.data?.isEmpty ?? true)) {
                  return const SizedBox.shrink();
                }

                final incidents = snapshot.data!;
                final latest = incidents.first;

                // severity chip color
                Color chipBg;
                Color chipText;
                switch (latest.severity.toLowerCase()) {
                  case 'high':
                    chipBg = Colors.red.shade50;
                    chipText = Colors.red.shade700;
                    break;
                  case 'medium':
                    chipBg = Colors.orange.shade50;
                    chipText = Colors.orange.shade700;
                    break;
                  default:
                    chipBg = Colors.green.shade50;
                    chipText = Colors.green.shade700;
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Safety Incidents',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    RouteIncidentsScreen(route: widget.route),
                              ),
                            );
                          },
                          child: const Text('View all'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                RouteIncidentsScreen(route: widget.route),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // left icon
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: purple.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.purple,
                              ),
                            ),
                            const SizedBox(width: 12),

                            // main content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          '${latest.incidentType} • ${latest.severity}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: chipBg,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          latest.severity,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: chipText,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  if ((latest.description ?? '')
                                      .trim()
                                      .isNotEmpty)
                                    Text(
                                      latest.description!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatDateTime(latest.createdAt),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const Icon(
                              Icons.chevron_right,
                              color: Colors.black38,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 28),

            // 4) Latest community comments (REAL data)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Latest Community Comments',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                TextButton(
                  onPressed: _openAllFeedback,
                  child: const Text('View all'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            FutureBuilder<List<RouteFeedback>>(
              future: _feedbackFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Failed to load comments.',
                      style: TextStyle(color: Colors.red),
                    ),
                  );
                }

                final list = snapshot.data ?? [];
                if (list.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'No comments yet. Check what others say after they start using this route.',
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  );
                }

                // show at most 2 comments here
                final latestComments = list.length <= 2
                    ? list
                    : list.take(2).toList();

                return Column(
                  children: latestComments.map((f) {
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: purple.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${f.rating} ★',
                                    style: TextStyle(
                                      color: purple,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatDateTime(f.createdAt),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              f.comment,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 32),

            // 5) Start Run button
            StartRunButton(route: r, color: purple),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final d =
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    final t =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '$d $t';
  }
}
