import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:runners_application/views/profile/profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'views/home/home_screen.dart';
import 'views/auth/login_screen.dart';
import 'views/auth/register_screen.dart';
import 'views/auth/forgot_password_screen.dart';
import 'views/run/routes_explorer_screen.dart'; 
import 'views/home/route_detail_screen.dart';

void main() async {
   // Make sure Flutter is ready
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env
  await dotenv.load(fileName: ".env");
  
  
  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://vdehpugshsdjkuxrlnjx.supabase.co',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Runners App',
      debugShowCheckedModeBanner: false,
      initialRoute: '/', //start with wrapper
      routes: {
        '/': (context) => const AuthWrapper(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/home': (context) => const HomeScreen(),
        '/routes-explorer': (context) => const RoutesExplorerScreen(), 
        '/route-details': (context) => const RouteDetailsScreen(),
        '/profile':(context) => const ProfileScreen()
      },
    );
  }
}
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    if (session != null) {
      // User is logged in
      return const HomeScreen();
    } else {
      // User is NOT logged in
      return const LoginScreen();
    }
  }
}
