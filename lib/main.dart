import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login.dart';
import 'dashboard_page.dart';
import 'teacher_dashboard_page.dart';
import 'profile_page.dart';
import 'signup.dart';
import 'about_us_page.dart';
import 'teacher_profile_page.dart';

Future<void> main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://lmvjvduylszuwhdijaqp.supabase.co', // Your Supabase URL
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxtdmp2ZHV5bHN6dXdoZGlqYXFwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIxMjg2MjcsImV4cCI6MjA2NzcwNDYyN30.i03CNOcPsUS4USyhnfEf4StS-7kYimghobJ-nyTQ-sY', // Your Supabase anon key
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthCheck(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/student_dashboard': (context) => const DashboardPage(),
        '/teacher_dashboard': (context) => const TeacherDashboardPage(),
        '/student_profile': (context) => const ProfilePage(),
        '/teacher_profile': (context) => const TeacherProfilePage(),
        '/about_us': (context) => const AboutUsPage(),
      },
    );
  }
}

class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }
        final session = snapshot.data?.session;
        if (session != null && session.user != null) {
          return FutureBuilder(
            future: Supabase.instance.client
                .from('profiles')
                .select('role')
                .eq('user_id', session.user.id)
                .maybeSingle(),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (profileSnapshot.hasError) {
                return Scaffold(
                  body: Center(child: Text('Error fetching user data: ${profileSnapshot.error}')),
                );
              }
              if (profileSnapshot.hasData && profileSnapshot.data != null) {
                try {
                  final role = profileSnapshot.data!['role'] as String?;
                  if (role == 'student') {
                    return const ProfilePage(); // Navigate to ProfilePage for students
                  } else if (role == 'teacher') {
                    return const TeacherProfilePage(); // Navigate to TeacherProfilePage for teachers
                  }
                } catch (e) {
                  print('Error reading role: $e');
                }
              }
              return const LoginPage();
            },
          );
        }
        return const LoginPage();
      },
    );
  }
}