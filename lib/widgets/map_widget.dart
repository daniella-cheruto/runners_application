import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapWidget extends StatefulWidget {
  const MapWidget({
    super.key,
    required this.initialPosition,
    this.markers = const <Marker>{},
    this.polylines = const <Polyline>{},
    this.onTap,
    this.myLocationEnabled = false, //  default off (safer)
    this.myLocationButtonEnabled = false, //  default off
    this.fitToMarkers = false,
    this.padding = 60,
    this.onMapCreated,
  });

  /// Fallback camera position (used when markers are empty, or as the first frame).
  final CameraPosition initialPosition;

  /// Markers to render on the map (e.g., Start/End).
  final Set<Marker> markers;

  /// Optional polylines (e.g., live GPS path).
  final Set<Polyline> polylines;

  /// Optional tap handler (useful for picking coordinates).
  final void Function(LatLng)? onTap;

  /// Show the user's location.
  final bool myLocationEnabled;

  /// Show the default my-location button.
  final bool myLocationButtonEnabled;

  /// If true, auto-zooms to include all markers after create/updates.
  final bool fitToMarkers;

  /// Padding (in px) when fitting markers.
  final double padding;

  /// Callback with the created map controller.
  final void Function(GoogleMapController controller)? onMapCreated;

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  GoogleMapController? _controller;

  @override
  void didUpdateWidget(covariant MapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If markers changed and fitting is enabled, refit.
    if (widget.fitToMarkers && widget.markers != oldWidget.markers) {
      _fitToMarkers();
    }
  }

  void _fitToMarkers() {
    final controller = _controller;
    if (controller == null) return;

    if (widget.markers.isEmpty) {
      // No markers to fit: just ensure we’re at the initial position.
      controller.animateCamera(
        CameraUpdate.newCameraPosition(widget.initialPosition),
      );
      return;
    }

    double? minLat, maxLat, minLng, maxLng;
    for (final m in widget.markers) {
      final p = m.position;
      minLat = (minLat == null)
          ? p.latitude
          : (p.latitude < minLat ? p.latitude : minLat);
      maxLat = (maxLat == null)
          ? p.latitude
          : (p.latitude > maxLat ? p.latitude : maxLat);
      minLng = (minLng == null)
          ? p.longitude
          : (p.longitude < minLng ? p.longitude : minLng);
      maxLng = (maxLng == null)
          ? p.longitude
          : (p.longitude > maxLng ? p.longitude : maxLng);
    }

    if (minLat == null || maxLat == null || minLng == null || maxLng == null) {
      return;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, widget.padding),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: widget.initialPosition,
      myLocationEnabled: widget.myLocationEnabled,
      myLocationButtonEnabled: widget.myLocationButtonEnabled,
      markers: widget.markers,
      polylines: widget.polylines,
      onTap: widget.onTap,
      onMapCreated: (c) {
        _controller = c;
        widget.onMapCreated?.call(c);
        if (widget.fitToMarkers) {
          _fitToMarkers();
        }
      },
      // Gestures are enabled by default, so you can pan/zoom freely.
      // add flags here.
    );
  }
}
