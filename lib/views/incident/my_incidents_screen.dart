// lib/views/incident/my_incidents_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '/controllers/incident_report_controller.dart';
import '/views/incident/fullscreen_image_screen.dart';

class MyIncidentsScreen extends StatefulWidget {
  final int routeId; // now required
  final String routeName; // now required

  const MyIncidentsScreen({
    super.key,
    required this.routeId,
    required this.routeName,
  });

  @override
  State<MyIncidentsScreen> createState() => _MyIncidentsScreenState();
}

class _MyIncidentsScreenState extends State<MyIncidentsScreen> {
  final SupabaseClient _client = Supabase.instance.client;
  final IncidentReportController _ctrl = IncidentReportController();

  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadIncidents();
  }

  Future<List<Map<String, dynamic>>> _loadIncidents() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('You must be logged in to view your incident reports.');
    }

    final data = await _client
        .from('incident_report')
        .select(
          'incident_id, incident_type, severity, description, created_at, '
          'latitude, longitude, photo_urls, routes(name)',
        )
        .eq('user_id', userId)
        .eq('route_id', widget.routeId) // 🔒 only this route
        .order('created_at', ascending: false);

    return (data as List).map((e) => e as Map<String, dynamic>).toList();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadIncidents();
    });
  }

  Future<void> _deleteIncident(int incidentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete incident'),
          content: const Text(
            'Are you sure you want to delete this incident report?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final err = await _ctrl.deleteIncident(incidentId);
    if (!mounted) return;

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Incident deleted.')));
      _refresh();
    }
  }

  Future<void> _openInMaps(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps')),
      );
    }
  }

  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'high':
        return Colors.red.shade100;
      case 'medium':
        return Colors.orange.shade100;
      default:
        return Colors.green.shade100;
    }
  }

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF9C27B0);

    return Scaffold(
      appBar: AppBar(
        title: Text('My Reports – ${widget.routeName}'),
        backgroundColor: purple,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Error loading incidents:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
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
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'You have not submitted any incident reports for this route yet.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: incidents.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final inc = incidents[index];
                final routeName =
                    (inc['routes'] as Map<String, dynamic>?)?['name'] ??
                    widget.routeName;

                final severity = (inc['severity'] ?? '') as String;
                final incidentType = (inc['incident_type'] ?? '') as String;
                final desc = (inc['description'] ?? '') as String;
                final createdAtIso = inc['created_at'] as String;

                final photosRaw = inc['photo_urls'];
                final List<String> photoUrls =
                    (photosRaw as List<dynamic>?)
                        ?.map((e) => e.toString())
                        .toList() ??
                    [];

                final lat = (inc['latitude'] as num?)?.toDouble();
                final lng = (inc['longitude'] as num?)?.toDouble();

                final dt = DateTime.parse(createdAtIso).toLocal();
                final dateStr =
                    '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
                    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

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
                        // top row: route + date + severity chip + delete
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    routeName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    dateStr,
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
                                color: _severityColor(severity),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${severity.isEmpty ? '' : severity}'
                                '${incidentType.isEmpty ? '' : ' • $incidentType'}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: Colors.red,
                              ),
                              tooltip: 'Delete report',
                              onPressed: () =>
                                  _deleteIncident(inc['incident_id'] as int),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        if (desc.trim().isNotEmpty)
                          Text(desc, style: const TextStyle(fontSize: 13.5)),

                        // photos
                        if (photoUrls.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final url in photoUrls)
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

                        // location + Google Maps link (only if coords exist)
                        if (lat != null && lng != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 16,
                                color: Colors.purple,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Location: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => _openInMaps(lat, lng),
                              icon: const Icon(Icons.map_outlined, size: 18),
                              label: const Text('View on map'),
                            ),
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
    );
  }
}
