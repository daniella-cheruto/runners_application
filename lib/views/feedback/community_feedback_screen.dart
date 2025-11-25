// lib/views/feedback/community_feedback_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '/models/route_model.dart';
import '/models/route_feedback_model.dart';
import '/controllers/route_feedback_controller.dart';
import '/widgets/custom_button.dart';
import '/widgets/custom_textfield.dart';

class CommunityFeedbackScreen extends StatefulWidget {
  final RouteModel route;

  const CommunityFeedbackScreen({super.key, required this.route});

  @override
  State<CommunityFeedbackScreen> createState() =>
      _CommunityFeedbackScreenState();
}

class _CommunityFeedbackScreenState extends State<CommunityFeedbackScreen> {
  final _ctrl = RouteFeedbackController();
  late Future<List<RouteFeedback>> _feedbackFuture;

  final _commentController = TextEditingController();
  int _selectedRating = 5;
  bool _submitting = false;
  String? _status;

  // Local rating state so header can update without leaving screen
  late double _currentAverageRating;

  @override
  void initState() {
    super.initState();
    _feedbackFuture = _ctrl.fetchForRoute(widget.route.routeId);
    _currentAverageRating = widget.route.averageRating;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final newAvg = await _ctrl.averageForRoute(widget.route.routeId);
    if (!mounted) return;

    setState(() {
      _currentAverageRating = newAvg;
      _feedbackFuture = _ctrl.fetchForRoute(widget.route.routeId);
      _status = null;
    });
  }

  Future<void> _submit() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) {
      setState(() => _status = 'Please enter a comment.');
      return;
    }

    setState(() {
      _submitting = true;
      _status = null;
    });

    final err = await _ctrl.addFeedback(
      routeId: widget.route.routeId,
      rating: _selectedRating,
      comment: text,
    );

    if (!mounted) return;

    if (err != null) {
      setState(() {
        _submitting = false;
        _status = err;
      });
      return;
    }

    // After successful submit, refresh rating + comments
    final newAvg = await _ctrl.averageForRoute(widget.route.routeId);
    if (!mounted) return;

    _commentController.clear();
    setState(() {
      _submitting = false;
      _selectedRating = 5;
      _status = 'Thank you for your feedback!';
      _currentAverageRating = newAvg;
      _feedbackFuture = _ctrl.fetchForRoute(widget.route.routeId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final purple = const Color(0xFF9C27B0);
    final r = widget.route;

    return Scaffold(
      appBar: AppBar(
        title: Text('Feedback: ${r.name}'),
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
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ROUTE HEADER CARD
                Card(
                  elevation: 4,
                  shadowColor: Colors.black12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              '${(r.distanceM / 1000).toStringAsFixed(2)} km',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  size: 16,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _currentAverageRating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'average rating',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (r.description.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            r.description,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // COMMUNITY COMMENTS
                const Text(
                  'Community Comments',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),

                FutureBuilder<List<RouteFeedback>>(
                  future: _feedbackFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Failed to load feedback: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    }

                    final feedbackList = snapshot.data ?? [];
                    if (feedbackList.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No comments yet. Be the first to share your experience!',
                          style: TextStyle(fontSize: 14, color: Colors.black54),
                        ),
                      );
                    }

                    final currentUserId =
                        Supabase.instance.client.auth.currentUser?.id;

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: feedbackList.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, index) {
                        final f = feedbackList[index];
                        final name = f.userName?.trim().isNotEmpty == true
                            ? f.userName!
                            : 'Runner';

                        final canDelete =
                            currentUserId != null && f.userId == currentUserId;

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
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: purple.withValues(
                                        alpha: 0.12,
                                      ),
                                      child: Text(
                                        name.substring(0, 1).toUpperCase(),
                                        style: TextStyle(
                                          color: purple,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.star,
                                              size: 14,
                                              color: Colors.amber,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              '${f.rating}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    Text(
                                      _formatDateTime(f.createdAt),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    if (canDelete) ...[
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                          color: Colors.redAccent,
                                        ),
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text(
                                                'Delete comment?',
                                              ),
                                              content: const Text(
                                                'Are you sure you want to delete this comment?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.of(
                                                    ctx,
                                                  ).pop(false),
                                                  child: const Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () => Navigator.of(
                                                    ctx,
                                                  ).pop(true),
                                                  child: const Text(
                                                    'Delete',
                                                    style: TextStyle(
                                                      color: Colors.redAccent,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (confirm != true) return;

                                          final err = await _ctrl
                                              .deleteFeedback(
                                                f.id,
                                                widget.route.routeId,
                                              );

                                          if (!mounted) return;

                                          if (err != null) {
                                            setState(() => _status = err);
                                          } else {
                                            final newAvg = await _ctrl
                                                .averageForRoute(
                                                  widget.route.routeId,
                                                );
                                            if (!mounted) return;

                                            setState(() {
                                              _status = 'Comment deleted.';
                                              _currentAverageRating = newAvg;
                                              _feedbackFuture = _ctrl
                                                  .fetchForRoute(
                                                    widget.route.routeId,
                                                  );
                                            });
                                          }
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  f.comment,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 24),

                // ADD FEEDBACK SECTION
                const Text(
                  'Add Your Feedback',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    const Text('Rating:', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: _selectedRating,
                      items: [1, 2, 3, 4, 5]
                          .map(
                            (v) =>
                                DropdownMenuItem(value: v, child: Text('$v ★')),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _selectedRating = v);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 🔹 Use CustomTextField instead of TextField
                CustomTextField(
                  controller: _commentController,
                  hint: 'Share details about safety, lighting, traffic, etc.',
                  maxLines: 4,
                ),
                const SizedBox(height: 12),

                if (_status != null) ...[
                  Text(
                    _status!,
                    style: TextStyle(
                      color: _status!.startsWith('Failed')
                          ? Colors.red
                          : purple,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],

                // 🔹 Use CustomButton instead of ElevatedButton
                CustomButton(
                  label: _submitting ? 'Submitting...' : 'Submit Feedback',
                  loading: _submitting,
                  color: purple,
                  onPressed: _submitting ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Show local time (EAT on your device) instead of raw UTC
  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal(); // converts from UTC to phone’s timezone
    final d =
        '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    final t =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '$d $t';
  }
}
