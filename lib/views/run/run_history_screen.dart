import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '/models/run_model.dart';
import '/models/route_model.dart';
import '/views/run/run_summary_screen.dart';

class RunHistoryScreen extends StatelessWidget {
  const RunHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;

    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to see your runs.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Run History'),
        backgroundColor: Colors.purple,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: client
            .from('runs')
            .select(
              'id, route_id, distance_m, duration_s, started_at, ended_at, routes(name, distance_m)',
            )
            .eq('user_id', userId)
            .order('started_at', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final rows = snapshot.data ?? [];
          if (rows.isEmpty) {
            return const Center(child: Text('No runs yet.'));
          }

          return ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final row = rows[index] as Map<String, dynamic>;
              final distanceM = (row['distance_m'] as num).toDouble();
              final distanceKm = distanceM / 1000.0;
              final duration = Duration(seconds: row['duration_s'] as int);
              final started = DateTime.parse(row['started_at'] as String);
              final routeInfo = row['routes'] as Map<String, dynamic>?;
              final routeName = routeInfo?['name'] as String? ?? 'Route';

              return ListTile(
                title: Text(routeName),
                subtitle: Text(
                  '${_formatDate(started)}  •  '
                  '${distanceKm.toStringAsFixed(2)} km  •  '
                  '${_formatDuration(duration)}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final runId = row['id'] as int;

                  // 1) Fetch GPS points
                  final pointsResp = await client
                      .from('run_points')
                      .select('lat,lng')
                      .eq('run_id', runId)
                      .order('seq', ascending: true);

                  final path = (pointsResp as List<dynamic>)
                      .map(
                        (p) => LatLng(
                          (p['lat'] as num).toDouble(),
                          (p['lng'] as num).toDouble(),
                        ),
                      )
                      .toList();

                  // 2) Build RunModel
                  final run = RunModel(
                    id: runId,
                    userId: userId,
                    routeId: row['route_id'] as int,
                    distanceM: distanceM,
                    durationS: duration.inSeconds,
                    startedAt: started,
                    endedAt: DateTime.parse(row['ended_at'] as String),
                  );

                  // 3) Lightweight RouteModel
                  RouteModel? routeModel;
                  if (routeInfo != null) {
                    routeModel = RouteModel(
                      routeId: row['route_id'] as int,
                      name: routeInfo['name'] as String,
                      description: '',
                      startLatitude: 0,
                      startLongitude: 0,
                      endLatitude: 0,
                      endLongitude: 0,
                      distanceM:
                          routeInfo['distance_m'] as int? ?? distanceM.toInt(),
                      averageRating: 0,
                      popularity: 0,
                      userId: null,
                    );
                  }

                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RunSummaryScreen(
                          route: routeModel,
                          run: run,
                          path: path.isEmpty ? null : path,
                        ),
                      ),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  /// NEW: Formats duration as HH:MM:SS if run lasted over 1 hour
  static String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');

    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);

    if (hours > 0) {
      return '${two(hours)}:${two(minutes)}:${two(seconds)}';
    } else {
      return '${two(minutes)}:${two(seconds)}';
    }
  }

  static String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }
}
