// lib/views/feedback/feedback_routes_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '/models/route_model.dart';
import 'community_feedback_screen.dart';
import '/widgets/loading_widget.dart';
import '/widgets/error_widget.dart';

class FeedbackRoutesScreen extends StatefulWidget {
  const FeedbackRoutesScreen({super.key});

  @override
  State<FeedbackRoutesScreen> createState() => _FeedbackRoutesScreenState();
}

class _FeedbackRoutesScreenState extends State<FeedbackRoutesScreen> {
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

  // 🔁 Helper to refresh routes after returning from feedback screen
  Future<void> _reloadRoutes() async {
    final routes = await _fetchRoutes();
    if (!mounted) return;

    setState(() {
      // wrap in Future.value so it still matches FutureBuilder's expected type
      _routesFuture = Future.value(routes);
    });
  }

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF9C27B0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Feedback'),
        backgroundColor: purple,
      ),
      body: FutureBuilder<List<RouteModel>>(
        future: _routesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingWidget();
          }
          if (snapshot.hasError) {
            return AppErrorWidget(onRetry: _reloadRoutes);
          }
          final routes = snapshot.data ?? [];
          if (routes.isEmpty) {
            return const Center(child: Text('No routes found yet.'));
          }

          return RefreshIndicator(
            onRefresh: _reloadRoutes,
            child: ListView.separated(
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
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CommunityFeedbackScreen(route: r),
                      ),
                    );
                    await _reloadRoutes();
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
