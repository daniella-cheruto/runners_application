import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '/controllers/routes_controller.dart';
import '/widgets/custom_button.dart';
import '/widgets/custom_textfield.dart';
import '/widgets/map_widget.dart';

class AddRouteScreen extends StatefulWidget {
  const AddRouteScreen({super.key});
  @override
  State<AddRouteScreen> createState() => _AddRouteScreenState();
}

class _AddRouteScreenState extends State<AddRouteScreen> {
  final _form = GlobalKey<FormState>();
  final _cName = TextEditingController();
  final _cDesc = TextEditingController();
  final _cDist = TextEditingController();
  final _controller = RoutesController();
  bool _saving = false;

  double startLat = -1.2921, startLng = 36.8219;
  double endLat = -1.2935, endLng = 36.8250;
  bool _selectingStart = true;

  @override
  void initState() {
    super.initState();
    _recomputeDistance();
  }

  @override
  void dispose() {
    _cName.dispose();
    _cDesc.dispose();
    _cDist.dispose();
    super.dispose();
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  void _recomputeDistance() {
    final d = Geolocator.distanceBetween(
      startLat,
      startLng,
      endLat,
      endLng,
    ).round();
    _cDist.text = d.toString();
    setState(() {});
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;

    final dist = int.tryParse(_cDist.text.trim()) ?? 0;
    if (dist <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Distance is invalid')));
      return;
    }

    setState(() => _saving = true);
    final ok = await _controller.addRoute(
      name: _cName.text.trim(),
      description: _cDesc.text.trim(),
      distanceM: dist,
      startLat: startLat,
      startLng: startLng,
      endLat: endLat,
      endLng: endLng,
    );
    setState(() => _saving = false);

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Route added')));
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to add route')));
    }
  }

  // 🔹 Draggable markers for Start & End
  Set<Marker> _markers() => {
    Marker(
      markerId: const MarkerId('start'),
      position: LatLng(startLat, startLng),
      infoWindow: const InfoWindow(title: 'Start'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      draggable: true,
      onDragEnd: (pos) {
        setState(() {
          startLat = pos.latitude;
          startLng = pos.longitude;
          _recomputeDistance();
        });
      },
    ),
    Marker(
      markerId: const MarkerId('end'),
      position: LatLng(endLat, endLng),
      infoWindow: const InfoWindow(title: 'End'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      draggable: true,
      onDragEnd: (pos) {
        setState(() {
          endLat = pos.latitude;
          endLng = pos.longitude;
          _recomputeDistance();
        });
      },
    ),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Route'),
        backgroundColor: Colors.purple,
        elevation: 0,
      ),

      // 🌄 Main body scrolls, button stays fixed below
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF3E9FF), Color(0xFFEDE7F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Card(
                  elevation: 8,
                  shadowColor: Colors.black26,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE1BEE7),
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(10),
                                child: const Icon(
                                  Icons.add_location_alt,
                                  color: Colors.purple,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Create a New Route',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.purple.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // 🧭 TextFields
                          CustomTextField(
                            controller: _cName,
                            hint: 'Route name (e.g., Karura Forest Loop)',
                            prefixIcon: const Icon(Icons.map_outlined),
                            validator: _required,
                          ),
                          const SizedBox(height: 14),

                          CustomTextField(
                            controller: _cDesc,
                            hint: 'Short note about the route',
                            maxLines: 2,
                            prefixIcon: const Icon(Icons.notes_outlined),
                          ),
                          const SizedBox(height: 14),

                          CustomTextField(
                            controller: _cDist,
                            hint: 'Distance (meters)',
                            readOnly: true,
                            prefixIcon: const Icon(Icons.straighten_outlined),
                          ),
                          const SizedBox(height: 18),

                          // 🏁 Start/End coordinates
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Chip(
                                avatar: const Icon(
                                  Icons.flag_outlined,
                                  size: 18,
                                  color: Colors.purple,
                                ),
                                label: Text(
                                  'Start: ${startLat.toStringAsFixed(4)}, ${startLng.toStringAsFixed(4)}',
                                ),
                                backgroundColor: const Color(0xFFF5E9FF),
                              ),
                              Chip(
                                avatar: const Icon(
                                  Icons.outlined_flag,
                                  size: 18,
                                  color: Colors.purple,
                                ),
                                label: Text(
                                  'End: ${endLat.toStringAsFixed(4)}, ${endLng.toStringAsFixed(4)}',
                                ),
                                backgroundColor: const Color(0xFFF5E9FF),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // 🟣 Selector pills
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.purple),
                              borderRadius: BorderRadius.circular(30),
                              color: Colors.white,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _SelectorPill(
                                  label: 'Set Start',
                                  selected: _selectingStart,
                                  onTap: () =>
                                      setState(() => _selectingStart = true),
                                ),
                                _SelectorPill(
                                  label: 'Set End',
                                  selected: !_selectingStart,
                                  onTap: () =>
                                      setState(() => _selectingStart = false),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 🗺️ Map (tap + drag)
                          SizedBox(
                            height: 260,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: MapWidget(
                                initialPosition: const CameraPosition(
                                  target: LatLng(-1.2921, 36.8219),
                                  zoom: 14,
                                ),
                                markers: _markers(),
                                fitToMarkers: false,
                                onTap: (pos) {
                                  setState(() {
                                    if (_selectingStart) {
                                      startLat = pos.latitude;
                                      startLng = pos.longitude;
                                    } else {
                                      endLat = pos.latitude;
                                      endLng = pos.longitude;
                                    }
                                    _recomputeDistance();
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          Text(
                            'Tip: tap the map or drag the markers to set Start/End. Distance updates automatically.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),

      // ✅ Fixed "Save Route" button (always visible)
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: CustomButton(
          label: _saving ? 'Saving...' : 'Save Route',
          onPressed: _saving ? null : _save,
          color: Colors.purple,
          loading: _saving,
        ),
      ),
    );
  }
}

// Small toggle pill
class _SelectorPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SelectorPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.purple : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.purple,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
