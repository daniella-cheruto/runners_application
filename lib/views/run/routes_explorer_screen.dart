import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '/controllers/routes_controller.dart';
import '/models/route_model.dart';
import '/views/run/add_route_screen.dart';
import '/views/home/route_detail_screen.dart';
import '/widgets/map_widget.dart';
import '/views/run/widgets/explorer_search_bar.dart';
import '/views/run/widgets/explorer_filters.dart';
import '/views/run/widgets/routes_list.dart';

class RoutesExplorerScreen extends StatefulWidget {
  const RoutesExplorerScreen({super.key});

  @override
  State<RoutesExplorerScreen> createState() => _RoutesExplorerScreenState();
}

class _RoutesExplorerScreenState extends State<RoutesExplorerScreen> {
  final RoutesController _controller = RoutesController();
  final TextEditingController _searchController = TextEditingController();

  GoogleMapController? _mapController;
  Timer? _debounce;

  late Future<List<RouteModel>> _routesFuture;

  // Filters
  bool _distance = false; // Distance <= 5km
  bool _safety = false; // Rating >= 4
  bool _preferences = false; // Popularity >= 70

  // UI
  bool _showFab = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _routesFuture = Future.value(<RouteModel>[]);
    _load(_controller.fetchRoutes());

    _searchController.addListener(() {
      if (mounted) setState(() {}); // updates clear icon in search
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ---------- Helpers ----------

  LatLng _center(RouteModel r) => LatLng(
    (r.startLatitude + r.endLatitude) / 2,
    (r.startLongitude + r.endLongitude) / 2,
  );

  void _zoom(RouteModel r) {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_center(r), 15));
  }

  void _fitTo(List<RouteModel> routes) {
    if (_mapController == null || routes.isEmpty) return;

    double? minLat, maxLat, minLng, maxLng;
    for (final r in routes) {
      final c = _center(r);
      minLat ??= c.latitude;
      maxLat ??= c.latitude;
      minLng ??= c.longitude;
      maxLng ??= c.longitude;

      if (c.latitude < minLat) minLat = c.latitude;
      if (c.latitude > maxLat) maxLat = c.latitude;
      if (c.longitude < minLng) minLng = c.longitude;
      if (c.longitude > maxLng) maxLng = c.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
    });
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _load(Future<List<RouteModel>> fut) async {
    setState(() => _isLoading = true);
    try {
      final data = await fut;
      if (!mounted) return;
      debugPrint('Loaded ${data.length} routes');
      setState(() {
        _routesFuture = Future.value(data);
      });
    } catch (e, st) {
      if (!mounted) return;
      debugPrint('Error loading routes: $e');
      debugPrint('$st');
      _showError("Couldn’t load routes. Please try again.");
      setState(() {
        _routesFuture = Future.value(<RouteModel>[]);
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _reloadAll() => _load(_controller.fetchRoutes());

  void _applyFilters() {
    final t = _searchController.text.trim();

    final fut = t.isNotEmpty
        ? _controller.searchRoutes(t)
        : _controller.fetchRoutes(
            maxDistance: _distance ? 5000 : null,
            minRating: _safety ? 4.0 : null,
            minPopularity: _preferences ? 70 : null,
          );

    _load(fut);
  }

  void _reset() {
    setState(() {
      _distance = _safety = _preferences = false;
      _searchController.clear();
    });
    _load(_controller.fetchRoutes());
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Explore Routes"),
        backgroundColor: Colors.purple,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          FutureBuilder<List<RouteModel>>(
            future: _routesFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !_isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snap.hasError) {
                return Center(child: Text("Error: ${snap.error}"));
              }

              final routes = snap.data ?? [];

              if (routes.isEmpty) {
                return const Center(child: Text("No routes found"));
              }

              _fitTo(routes);

              final markers = routes
                  .map(
                    (r) => Marker(
                      markerId: MarkerId(r.routeId.toString()),
                      position: _center(r),
                      infoWindow: InfoWindow(
                        title: r.name,
                        snippet:
                            "${(r.distanceM / 1000).toStringAsFixed(1)} km • ⭐ ${r.averageRating}",
                      ),
                      onTap: () => _zoom(r),
                    ),
                  )
                  .toSet();

              return Stack(
                children: [
                  MapWidget(
                    initialPosition: const CameraPosition(
                      target: LatLng(-1.2921, 36.8219), // Nairobi-ish
                      zoom: 12,
                    ),
                    markers: markers,
                    fitToMarkers: false,
                    onMapCreated: (c) => _mapController = c,
                  ),
                  NotificationListener<DraggableScrollableNotification>(
                    onNotification: (n) {
                      final show = n.extent < 0.6;
                      if (show != _showFab) {
                        setState(() => _showFab = show);
                      }
                      return false;
                    },
                    child: DraggableScrollableSheet(
                      initialChildSize: 0.3,
                      minChildSize: 0.15,
                      maxChildSize: 0.85,
                      builder: (context, scrollController) {
                        return Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                            boxShadow: [
                              BoxShadow(blurRadius: 8, color: Colors.black26),
                            ],
                          ),
                          child: RefreshIndicator(
                            onRefresh: _reloadAll,
                            child: ListView(
                              controller: scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(12),
                              children: [
                                // Search
                                ExplorerSearchBar(
                                  controller: _searchController,
                                  onChanged: (text) {
                                    final t = text.trim();
                                    _debounce?.cancel();
                                    _debounce = Timer(
                                      const Duration(milliseconds: 400),
                                      () {
                                        if (!mounted) return;
                                        _load(
                                          t.isEmpty
                                              ? _controller.fetchRoutes(
                                                  maxDistance: _distance
                                                      ? 5000
                                                      : null,
                                                  minRating: _safety
                                                      ? 4.0
                                                      : null,
                                                  minPopularity: _preferences
                                                      ? 70
                                                      : null,
                                                )
                                              : _controller.searchRoutes(t),
                                        );
                                      },
                                    );
                                  },
                                  onSubmitted: (text) {
                                    final t = text.trim();
                                    _load(
                                      t.isEmpty
                                          ? _controller.fetchRoutes(
                                              maxDistance: _distance
                                                  ? 5000
                                                  : null,
                                              minRating: _safety ? 4.0 : null,
                                              minPopularity: _preferences
                                                  ? 70
                                                  : null,
                                            )
                                          : _controller.searchRoutes(t),
                                    );
                                  },
                                  onClear: _reset,
                                ),
                                const SizedBox(height: 12),

                                // Filters
                                ExplorerFilters(
                                  distance: _distance,
                                  safety: _safety,
                                  preferences: _preferences,
                                  onDistanceChanged: (v) =>
                                      setState(() => _distance = v),
                                  onSafetyChanged: (v) =>
                                      setState(() => _safety = v),
                                  onPreferencesChanged: (v) =>
                                      setState(() => _preferences = v),
                                  onApply: _applyFilters,
                                ),
                                const SizedBox(height: 16),

                                // Routes list
                                RoutesList(
                                  routes: routes,
                                  onTap: (r) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            RouteDetailScreen(route: r),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),

          // Fullscreen loading overlay
          AnimatedOpacity(
            opacity: _isLoading ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: IgnorePointer(
              ignoring: !_isLoading,
              child: Container(
                color: Colors.black26,
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        scale: _showFab ? 1 : 0,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: _showFab ? 1 : 0,
          child: FloatingActionButton.extended(
            foregroundColor: Colors.white,
            backgroundColor: Colors.purple,
            icon: const Icon(Icons.add),
            label: const Text('Add Route'),
            onPressed: () async {
              final navigator = Navigator.of(context);
              final created = await navigator.push(
                MaterialPageRoute(builder: (_) => const AddRouteScreen()),
              );
              if (!mounted) return;
              if (created == true) {
                await _load(_controller.fetchRoutes());
              }
            },
          ),
        ),
      ),
    );
  }
}
