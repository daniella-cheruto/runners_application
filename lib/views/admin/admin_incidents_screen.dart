// lib/views/admin/admin_incidents_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '/models/incident_report_model.dart';
import '/controllers/incident_report_controller.dart';
import '/views/incident/fullscreen_image_screen.dart';

class AdminIncidentsScreen extends StatefulWidget {
  const AdminIncidentsScreen({super.key});

  @override
  State<AdminIncidentsScreen> createState() => _AdminIncidentsScreenState();
}

class _AdminIncidentsScreenState extends State<AdminIncidentsScreen> {
  final _ctrl = IncidentReportController();

  bool _loading = true;
  String _error = '';
  List<IncidentReport> _allIncidents = [];
  List<IncidentReport> _filteredIncidents = [];

  // Filters
  String _selectedSeverity = 'All';
  String _selectedType = 'All';

  List<String> _availableTypes = ['All'];

  @override
  void initState() {
    super.initState();
    _loadIncidents();
  }

  Future<void> _loadIncidents() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final incidents = await _ctrl.fetchAllIncidents();

      _allIncidents = incidents;

      // Build list of types for the dropdown
      final typesSet = <String>{};
      for (final inc in incidents) {
        if (inc.incidentType.trim().isNotEmpty) {
          typesSet.add(inc.incidentType.trim());
        }
      }
      _availableTypes = ['All', ...typesSet];

      _applyFilters();
    } catch (e) {
      _error = 'Failed to load incidents: $e';
      _filteredIncidents = [];
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredIncidents = _allIncidents.where((inc) {
        final sevOk =
            _selectedSeverity == 'All' ||
            inc.severity.toLowerCase() == _selectedSeverity.toLowerCase();

        final typeOk =
            _selectedType == 'All' ||
            inc.incidentType.toLowerCase() == _selectedType.toLowerCase();

        return sevOk && typeOk;
      }).toList();
    });
  }

  Future<void> _refresh() async {
    await _loadIncidents();
  }

  Future<void> _deleteIncident(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete incident?'),
        content: const Text(
          'This will permanently delete the incident report.',
        ),
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

    final err = await _ctrl.adminDeleteIncident(id);
    if (!mounted) return;

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      // remove from local lists so UI updates immediately
      _allIncidents.removeWhere((i) => i.incidentId == id);
      _filteredIncidents.removeWhere((i) => i.incidentId == id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incident deleted successfully.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
      setState(() {});
    }
  }

  Future<void> _openInMaps(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open Google Maps'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Color _chipColor(String severity) {
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
        title: const Text('All Incidents'),
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
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error.isNotEmpty
              ? ListView(
                  children: [
                    const SizedBox(height: 80),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(_error, textAlign: TextAlign.center),
                    ),
                  ],
                )
              : _buildContent(purple),
        ),
      ),
    );
  }

  Widget _buildContent(Color purple) {
    if (_filteredIncidents.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'No incidents found for the selected filters.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        const SizedBox(height: 8),

        // Filters row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  label: 'Severity',
                  value: _selectedSeverity,
                  items: const ['All', 'High', 'Medium', 'Low'],
                  onChanged: (value) {
                    if (value == null) return;
                    _selectedSeverity = value;
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdown(
                  label: 'Type',
                  value: _selectedType,
                  items: _availableTypes,
                  onChanged: (value) {
                    if (value == null) return;
                    _selectedType = value;
                    _applyFilters();
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),

        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: _filteredIncidents.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final inc = _filteredIncidents[index];

              final reporter = (inc.userName?.trim().isNotEmpty ?? false)
                  ? inc.userName!
                  : 'Runner';
              final routeLabel = 'Route ${inc.routeId}';
              final date = _formatDateTime(inc.createdAt);
              final photos = inc.photoUrls ?? <String>[];

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
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  routeLabel,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$reporter • $date',
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
                              color: _chipColor(inc.severity),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${inc.severity} • ${inc.incidentType}',
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
                            onPressed: () => _deleteIncident(inc.incidentId),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (inc.description != null &&
                          inc.description!.trim().isNotEmpty)
                        Text(
                          inc.description!,
                          style: const TextStyle(fontSize: 14),
                        ),
                      if (photos.isNotEmpty) ...[
                        const SizedBox(height: 8),
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
                                      builder: (_) =>
                                          FullscreenImageScreen(imageUrl: url),
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
                      if (inc.latitude != null && inc.longitude != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              'Location: '
                              '${inc.latitude!.toStringAsFixed(5)}, '
                              '${inc.longitude!.toStringAsFixed(5)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(width: 12),
                            TextButton(
                              onPressed: () =>
                                  _openInMaps(inc.latitude!, inc.longitude!),
                              child: Text(
                                'View on map',
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
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              items: items
                  .map(
                    (v) => DropdownMenuItem<String>(value: v, child: Text(v)),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
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
