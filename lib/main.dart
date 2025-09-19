import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://vdehpugshsdjkuxrlnjx.supabase.co', //  your Project URL
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZkZWhwdWdzaHNkamt1eHJsbmp4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgyMjYyMTksImV4cCI6MjA3MzgwMjIxOX0.0aYWRCR5l-uqciQXJ_DIt5xslXZjxq8VVqfCZuPYlrA', // paste your anon key here
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Supabase Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter + Supabase'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _message = 'Connecting to Supabase...';

  @override
  void initState() {
    super.initState();
    _testConnection();
  }

  // Simple test query to check Supabase connection
  Future<void> _testConnection() async {
    try {
      final response = await Supabase.instance.client
          .from('users') // 👈 make sure this table exists
          .select()
          .limit(1);

      setState(() {
        _message = 'Supabase Connected 🚀\n$response';
      });
    } catch (e) {
      setState(() {
        _message = 'Connection failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(child: Text(_message)),
    );
  }
}
