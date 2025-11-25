// lib/views/admin/admin_feedback_screen.dart
import 'package:flutter/material.dart';

import '/controllers/admin_feedback_controller.dart';
import '/models/route_feedback_model.dart'; // RouteFeedback

class AdminFeedbackScreen extends StatefulWidget {
  const AdminFeedbackScreen({super.key});

  @override
  State<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends State<AdminFeedbackScreen> {
  final _ctrl = AdminFeedbackController();

  bool _loading = true;
  String _error = '';
  List<RouteFeedback> _allFeedback = [];
  List<RouteFeedback> _filteredFeedback = [];

  // filters
  String _selectedRating = 'All';
  String _selectedRoute = 'All';

  List<String> _availableRoutes = ['All'];

  @override
  void initState() {
    super.initState();
    _loadFeedback();
  }

  Future<void> _loadFeedback() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final list = await _ctrl.fetchAllFeedback();
      _allFeedback = list;

      // collect unique route names
      final routeSet = <String>{};
      for (final fb in list) {
        final rName = fb.routeName?.trim() ?? '';
        if (rName.isNotEmpty) {
          routeSet.add(rName);
        }
      }

      final routeList = routeSet.toList()..sort();
      _availableRoutes = ['All', ...routeList];

      _applyFilters();
    } catch (e) {
      _error = 'Failed to load feedback: $e';
      _filteredFeedback = [];
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
      _filteredFeedback = _allFeedback.where((fb) {
        final ratingOk =
            _selectedRating == 'All' || fb.rating.toString() == _selectedRating;

        final routeOk =
            _selectedRoute == 'All' ||
            (fb.routeName ?? '').toLowerCase() == _selectedRoute.toLowerCase();

        return ratingOk && routeOk;
      }).toList();
    });
  }

  Future<void> _refresh() async {
    await _loadFeedback();
  }

  // 🔹 now takes the whole RouteFeedback object
  Future<void> _deleteFeedback(RouteFeedback fb) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete feedback?'),
        content: const Text(
          'This will permanently delete this feedback entry.',
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

    // ✅ pass both required named params
    final err = await _ctrl.adminDeleteFeedback(
      feedbackId: fb.id,
      routeId: fb.routeId,
    );

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
      _allFeedback.removeWhere((f) => f.id == fb.id);
      _filteredFeedback.removeWhere((f) => f.id == fb.id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Feedback deleted successfully.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF9C27B0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Feedback'),
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
              : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_filteredFeedback.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'No feedback found for the selected filters.',
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

        // filters
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  label: 'Rating',
                  value: _selectedRating,
                  items: const ['All', '1', '2', '3', '4', '5'],
                  onChanged: (value) {
                    if (value == null) return;
                    _selectedRating = value;
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdown(
                  label: 'Route',
                  value: _selectedRoute,
                  items: _availableRoutes,
                  onChanged: (value) {
                    if (value == null) return;
                    _selectedRoute = value;
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
            itemCount: _filteredFeedback.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final fb = _filteredFeedback[index];

              final routeName = (fb.routeName ?? '').trim().isNotEmpty
                  ? fb.routeName!
                  : 'Route ${fb.routeId}';

              final userName = (fb.userName ?? '').trim().isNotEmpty
                  ? fb.userName!
                  : 'Runner';

              final date = _formatDateTime(fb.createdAt);

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
                      // top row: route + rating + delete
                      Row(
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
                                  '$userName • $date',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                size: 16,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                fb.rating.toString(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: Colors.red,
                            ),
                            // ✅ pass full object now
                            onPressed: () => _deleteFeedback(fb),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (fb.comment.trim().isNotEmpty)
                        Text(fb.comment, style: const TextStyle(fontSize: 14)),
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
