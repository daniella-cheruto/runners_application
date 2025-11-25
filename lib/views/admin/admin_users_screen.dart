// lib/views/admin/admin_users_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '/controllers/admin_users_controller.dart';
import '/models/user_model.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final AdminUsersController _ctrl = AdminUsersController();

  bool _loading = true;
  String _error = '';
  List<UserModel> _users = [];

  String _searchText = '';
  String _roleFilter = 'All'; // All, Admins, Runners

  String? _inlineMessage;
  Color? _inlineColor;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  void _showInlineMessage(String msg, Color color) {
    setState(() {
      _inlineMessage = msg;
      _inlineColor = color;
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _inlineMessage = null;
        });
      }
    });
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final list = await _ctrl.fetchAllUsers();
      _users = list;
    } catch (e) {
      _error = 'Failed to load users.';
      _users = [];
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    await _loadUsers();
  }

  Future<void> _toggleAdmin(UserModel user) async {
    // 🔒 Do not allow role changes for inactive accounts
    if (!user.isActive) {
      _showInlineMessage(
        'Reactivate this account before changing their role.',
        Colors.red,
      );
      return;
    }

    final newStatus = !user.isAdmin;

    final err = await _ctrl.setAdminStatus(userId: user.id, isAdmin: newStatus);

    if (!mounted) return;

    if (err != null) {
      _showInlineMessage(err, Colors.red);
      return;
    }

    setState(() {
      _users = _users
          .map((u) => u.id == user.id ? u.copyWith(isAdmin: newStatus) : u)
          .toList();
    });

    final label = newStatus ? 'granted admin' : 'removed admin';
    final displayName = user.fullName.isNotEmpty ? user.fullName : user.email;

    _showInlineMessage(
      'Successfully $label role for $displayName.',
      Colors.green,
    );
  }

  Future<void> _toggleActive(UserModel user) async {
    final currentUser = Supabase.instance.client.auth.currentUser;

    // 🔒 Prevent admin from deactivating their own account
    if (user.id == currentUser?.id) {
      _showInlineMessage('You cannot deactivate your own account.', Colors.red);
      return;
    }

    final newStatus = !user.isActive;

    final err = await _ctrl.setActiveStatus(
      userId: user.id,
      isActive: newStatus,
    );

    if (!mounted) return;

    if (err != null) {
      _showInlineMessage(err, Colors.red);
      return;
    }

    setState(() {
      _users = _users
          .map((u) => u.id == user.id ? u.copyWith(isActive: newStatus) : u)
          .toList();
    });

    final label = newStatus ? 'activated' : 'deactivated';
    final displayName = user.fullName.isNotEmpty ? user.fullName : user.email;

    _showInlineMessage('Successfully $label $displayName.', Colors.green);
  }

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF9C27B0);

    final currentUser = Supabase.instance.client.auth.currentUser;
    final currentUserId = currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
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
              : _buildContent(currentUserId),
        ),
      ),
    );
  }

  Widget _buildContent(String? currentUserId) {
    // Filter + search
    List<UserModel> visible = _users.where((u) {
      final search = _searchText.trim().toLowerCase();
      final inSearch =
          search.isEmpty ||
          u.fullName.toLowerCase().contains(search) ||
          u.email.toLowerCase().contains(search);

      final inRole = _roleFilter == 'All'
          ? true
          : _roleFilter == 'Admins'
          ? u.isAdmin
          : !u.isAdmin; // Runners

      return inSearch && inRole;
    }).toList();

    if (visible.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 8),
          if (_inlineMessage != null)
            _InlineMessageBar(
              message: _inlineMessage!,
              color: _inlineColor ?? Colors.green,
            ),
          const SizedBox(height: 40),
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'No users found for the selected filters.',
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

        if (_inlineMessage != null)
          _InlineMessageBar(
            message: _inlineMessage!,
            color: _inlineColor ?? Colors.green,
          ),

        // Search + Role filter
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search by name or email...',
                    prefixIcon: Icon(Icons.search),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchText = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _buildRoleDropdown()),
            ],
          ),
        ),
        const SizedBox(height: 4),

        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: visible.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final user = visible[index];
              final isCurrent = user.id == currentUserId;

              // Disable Make admin button for:
              // - current user (self)
              // - inactive accounts
              final isAdminButtonDisabled = isCurrent || !user.isActive;

              return Card(
                elevation: 2,
                shadowColor: Colors.black12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // First row: avatar + name + badges
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            child: Text(
                              user.fullName.isNotEmpty
                                  ? user.fullName[0].toUpperCase()
                                  : (user.email.isNotEmpty
                                        ? user.email[0].toUpperCase()
                                        : '?'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.fullName.isNotEmpty
                                      ? user.fullName
                                      : 'Runner',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                if (user.email.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    user.email,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    _buildBadge(
                                      user.isAdmin ? 'Admin' : 'Runner',
                                      user.isAdmin
                                          ? Colors.deepPurple
                                          : Colors.green,
                                    ),
                                    const SizedBox(width: 8),
                                    _buildBadge(
                                      user.isActive ? 'Active' : 'Inactive',
                                      user.isActive
                                          ? Colors.blue
                                          : Colors.redAccent,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Second row: Make admin button + Active toggle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: isAdminButtonDisabled
                                ? null
                                : () => _toggleAdmin(user),
                            child: Text(
                              user.isAdmin ? 'Remove admin' : 'Make admin',
                              style: TextStyle(
                                fontSize: 13,
                                color: isAdminButtonDisabled
                                    ? Colors.grey
                                    : Colors.deepPurple,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              const Text(
                                'Account',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Switch(
                                value: user.isActive,
                                onChanged: (user.id == currentUserId)
                                    ? null // 🔒 cannot deactivate own account
                                    : (_) => _toggleActive(user),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                activeColor: Colors.deepPurple,
                              ),
                            ],
                          ),
                        ],
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
  }

  Widget _buildRoleDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Role',
          style: TextStyle(
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
              value: _roleFilter,
              items: const [
                DropdownMenuItem(value: 'All', child: Text('All')),
                DropdownMenuItem(value: 'Admins', child: Text('Admins')),
                DropdownMenuItem(value: 'Runners', child: Text('Runners')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _roleFilter = value;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _InlineMessageBar extends StatelessWidget {
  final String message;
  final Color color;

  const _InlineMessageBar({required this.message, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
