import 'package:flutter/material.dart';

import '/controllers/home_controller.dart';
import '/controllers/profile_controller.dart';
import '/models/user_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HomeController _homeController = HomeController();
  final ProfileController _profileController = ProfileController();

  late Future<UserModel?> _userFuture;

  @override
  void initState() {
    super.initState();

    // 👉 Get auth user (for id), then load full profile via ProfileController
    final currentUser = _homeController.getCurrentUserModel();
    if (currentUser != null) {
      _userFuture = _profileController.fetchUserProfile(currentUser.id);
    } else {
      _userFuture = Future.value(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // 🔹 Title now reacts to whether the user is admin or not
        title: FutureBuilder<UserModel?>(
          future: _userFuture,
          builder: (context, snapshot) {
            // default if still loading or no user
            if (snapshot.connectionState == ConnectionState.waiting ||
                !snapshot.hasData) {
              return const Text('Runner Dashboard');
            }

            final user = snapshot.data!;
            return Text(user.isAdmin ? 'Admin Dashboard' : 'Runner Dashboard');
          },
        ),
        backgroundColor: Colors.purple,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _homeController.logout();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 210, 189, 214),
              Color.fromARGB(255, 248, 245, 246),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: FutureBuilder<UserModel?>(
            future: _userFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                // just log; still show dashboard with fallback
                debugPrint('Home profile error: ${snapshot.error}');
              }

              // This user comes from the SAME place as ProfileScreen
              final user =
                  snapshot.data ?? _homeController.getCurrentUserModel();

              // Prefer full name from profile; fallback to "Runner"
              final name = (user != null && user.fullName.isNotEmpty)
                  ? user.fullName
                  : 'Runner';

              final bool isAdmin = user?.isAdmin ?? false;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 60),
                  Text(
                    "Welcome, $name",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildActionCard(
                          context,
                          icon: Icons.map,
                          label: "View Safe Routes",
                          route: '/routes-explorer',
                          color: Colors.teal,
                        ),
                        _buildActionCard(
                          context,
                          icon: Icons.timeline,
                          label: "Run History",
                          route: '/run-history',
                          color: Colors.indigo,
                        ),
                        _buildActionCard(
                          context,
                          icon: Icons.feedback,
                          label: "Community Feedback",
                          route: '/feedback-routes',
                          color: Colors.orange,
                        ),
                        _buildActionCard(
                          context,
                          icon: Icons.person,
                          label: "Profile",
                          route: '/profile',
                          color: Colors.pink,
                        ),
                        _buildActionCard(
                          context,
                          icon: Icons.report_problem,
                          label: "Incident Report",
                          route: '/incident-routes',
                          color: const Color.fromARGB(255, 243, 47, 47),
                        ),

                        // 👑 Admin Panel card – only for admins
                        if (isAdmin)
                          _buildActionCard(
                            context,
                            icon: Icons.admin_panel_settings,
                            label: "Admin Panel",
                            route: '/admin',
                            color: Colors.deepPurple,
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
    required Color color,
  }) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, route),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        color: color.withAlpha((0.9 * 255).round()),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 42, color: Colors.white),
              const SizedBox(height: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
