// lib/views/incident/incident_routes_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '/models/route_model.dart';
import 'report_incident_screen.dart';

class IncidentRoutesScreen extends StatefulWidget {
  const IncidentRoutesScreen({super.key});

  @override
  State<IncidentRoutesScreen> createState() => _IncidentRoutesScreenState();
}

class _IncidentRoutesScreenState extends State<IncidentRoutesScreen> {
  late Future<List<RouteModel>> _routesFuture;

  @override
  void initState() {
    super.initState();
    _routesFuture = _fetchRoutes();
  }

  Future<List<RouteModel>> _fetchRoutes() async {
    final data = await Supabase.instance.client
        .from('routes')
        .select()
        .order('name');

    final list = (data as List)
        .map((row) => RouteModel.fromJson(row as Map<String, dynamic>))
        .toList();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF9C27B0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Incident – Choose Route'),
        backgroundColor: purple,
      ),
      body: FutureBuilder<List<RouteModel>>(
        future: _routesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load routes: ${snapshot.error}'),
            );
          }

          final routes = snapshot.data ?? [];
          if (routes.isEmpty) {
            return const Center(
              child: Text('No routes available to report incidents on.'),
            );
          }

          return ListView.separated(
            itemCount: routes.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final r = routes[index];
              final distanceKm = (r.distanceM / 1000).toStringAsFixed(2);

              return ListTile(
                title: Text(
                  r.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '$distanceKm km • rating ${r.averageRating.toStringAsFixed(1)} ★',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // When user taps a route, go to ReportIncidentScreen for that route
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReportIncidentScreen(route: r),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
