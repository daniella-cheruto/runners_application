// lib/views/incident/route_incidents_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '/models/route_model.dart';
import '/models/incident_report_model.dart';
import '/controllers/incident_report_controller.dart';
import '/views/incident/fullscreen_image_screen.dart';

class RouteIncidentsScreen extends StatefulWidget {
  final RouteModel route;

  const RouteIncidentsScreen({super.key, required this.route});

  @override
  State<RouteIncidentsScreen> createState() => _RouteIncidentsScreenState();
}

class _RouteIncidentsScreenState extends State<RouteIncidentsScreen> {
  final _ctrl = IncidentReportController();
  late Future<List<IncidentReport>> _future;

  @override
  void initState() {
    super.initState();
    _future = _ctrl.fetchForRoute(widget.route.routeId);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _ctrl.fetchForRoute(widget.route.routeId);
    });
  }

  // 🔹 Open Google Maps safely (no async context error)
  Future<void> _openInMaps(double lat, double lng) async {
    final url = "https://www.google.com/maps/search/?api=1&query=$lat,$lng";
    final uri = Uri.parse(url);

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open Google Maps")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF9C27B0);

    return Scaffold(
      appBar: AppBar(
        title: Text('Incidents – ${widget.route.name}'),
        backgroundColor: purple,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF7F3FF), Color(0xFFFDFBFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<IncidentReport>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return ListView(
                  children: [
                    const SizedBox(height: 80),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Failed to load incidents: ${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                );
              }

              final incidents = snapshot.data ?? [];
              if (incidents.isEmpty) {
                return ListView(
                  children: const [
                    SizedBox(height: 80),
                    Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'No incidents have been reported yet for this route.\n'
                          'Be the first to share a safety update.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: Colors.black54),
                        ),
                      ),
                    ),
                  ],
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                itemCount: incidents.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final i = incidents[index];

                  final reporterName = (i.userName?.trim().isNotEmpty ?? false)
                      ? i.userName!
                      : 'Runner';

                  final dateTimeLabel = _formatDateTime(i.createdAt);

                  // Severity chip color
                  Color chipColor;
                  switch (i.severity.toLowerCase()) {
                    case 'high':
                      chipColor = Colors.red.shade100;
                      break;
                    case 'medium':
                      chipColor = Colors.orange.shade100;
                      break;
                    default:
                      chipColor = Colors.green.shade100;
                  }

                  final photos = i.photoUrls ?? <String>[];

                  return Card(
                    elevation: 2,
                    shadowColor: Colors.black12,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 🟣 Top Row: avatar, name, date, severity chip
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: purple.withValues(alpha: 0.12),
                                child: Text(
                                  reporterName.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(
                                    color: purple,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      reporterName,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      dateTimeLabel,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: chipColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${i.severity} • ${i.incidentType}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // 📝 Description
                          if (i.description != null &&
                              i.description!.trim().isNotEmpty)
                            Text(
                              i.description!,
                              style: const TextStyle(fontSize: 14),
                            ),

                          // 🖼️ Photos (multi)
                          if (photos.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final url in photos)
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => FullscreenImageScreen(
                                            imageUrl: url,
                                          ),
                                        ),
                                      );
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(
                                        url,
                                        width: 70,
                                        height: 70,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],

                          // 📍 Location
                          if (i.latitude != null && i.longitude != null) ...[
                            const SizedBox(height: 10),

                            Row(
                              children: [
                                Text(
                                  'Location: ${i.latitude!.toStringAsFixed(5)}, ${i.longitude!.toStringAsFixed(5)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(width: 12),

                                TextButton(
                                  onPressed: () =>
                                      _openInMaps(i.latitude!, i.longitude!),
                                  child: const Text(
                                    "View on map",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: purple,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final d =
        '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    final t =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '$d $t';
  }
}
