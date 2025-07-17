import 'package:final_app/student_assignment_page.dart';
import 'package:final_app/student_attendance_page.dart';
import 'package:final_app/student_cgpa_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'class_routine_page.dart';
import 'drop_update_page.dart';
import 'login.dart';
import 'dashboard_page.dart';
import 'teacher_dashboard_page.dart';
import 'profile_page.dart';
import 'teacher_profile_page.dart';
import 'signup.dart';
import 'about_us_page.dart';

// Placeholder pages
class AttendancePage extends StatelessWidget {
  const AttendancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue.withOpacity(0.9),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue, Colors.deepPurple],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: const Center(child: Text('Attendance Page', style: TextStyle(color: Colors.white))),
      ),
    );
  }
}

class ExamSchedulePage extends StatelessWidget {
  const ExamSchedulePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Schedule', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue.withOpacity(0.9),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue, Colors.deepPurple],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: const Center(child: Text('Exam Schedule Page', style: TextStyle(color: Colors.white))),
      ),
    );
  }
}

class LeavePage extends StatelessWidget {
  const LeavePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue.withOpacity(0.9),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue, Colors.deepPurple],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: const Center(child: Text('Leave Page', style: TextStyle(color: Colors.white))),
      ),
    );
  }
}

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue.withOpacity(0.9),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue, Colors.deepPurple],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: const Center(child: Text('Notification Page', style: TextStyle(color: Colors.white))),
      ),
    );
  }
}

class ClassworkPage extends StatelessWidget {
  const ClassworkPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Classwork', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue.withOpacity(0.9),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue, Colors.deepPurple],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: const Center(child: Text('Classwork Page', style: TextStyle(color: Colors.white))),
      ),
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://lmvjvduylszuwhdijaqp.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxtdmp2ZHV5bHN6dXdoZGlqYXFwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIxMjg2MjcsImV4cCI6MjA2NzcwNDYyN30.i03CNOcPsUS4USyhnfEf4StS-7kYimghobJ-nyTQ-sY',
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
        '/attendance': (context) => const AttendancePage(),
        '/exam_schedule': (context) => const ExamSchedulePage(),
        '/leave': (context) => const LeavePage(),
        '/notification': (context) => const NotificationPage(),
        '/classwork': (context) => const ClassworkPage(),
        '/drop_update': (context) => const DropUpdatePage(),
        '/student_attendance': (context) => const StudentAttendancePage(),
        '/student_cgpa': (context) => const StudentCGPAPage(),
        '/student_assignment': (context) => const StudentAssignmentPage(),
        '/class_routine': (context) => const ClassRoutinePage(),

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
          print('AuthCheck: Waiting for auth state');
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          print('AuthCheck: Error in auth state: ${snapshot.error}');
          return Scaffold(
            body: Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          );
        }
        if (snapshot.hasData && snapshot.data!.session != null) {
          print('AuthCheck: Session found for user ID: ${snapshot.data!.session!.user.id}');
          return FutureBuilder<Map<String, dynamic>?>(
            future: Supabase.instance.client
                .from('profile')
                .select()
                .eq('id', snapshot.data!.session!.user.id)
                .maybeSingle(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                print('AuthCheck: Waiting for profile data');
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (userSnapshot.hasError) {
                print('AuthCheck: Error fetching profile data: ${userSnapshot.error}');
                return Scaffold(
                  body: Center(
                    child: Text(
                      'Error fetching user data: ${userSnapshot.error}',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                );
              }
              if (userSnapshot.hasData && userSnapshot.data != null) {
                try {
                  final role = userSnapshot.data!['role'] as String?;
                  print('AuthCheck: User role fetched: $role');
                  if (role == 'student') {
                    print('AuthCheck: Navigating to student_dashboard');
                    return const DashboardPage();
                  } else if (role == 'teacher') {
                    print('AuthCheck: Navigating to teacher_dashboard');
                    return const TeacherDashboardPage();
                  } else {
                    print('AuthCheck: Invalid role: $role');
                    return const LoginPage();
                  }
                } catch (e) {
                  print('AuthCheck: Error reading role: $e');
                  return const LoginPage();
                }
              }
              print('AuthCheck: No profile data found, redirecting to login');
              return const LoginPage();
            },
          );
        }
        print('AuthCheck: No session found, redirecting to login');
        return const LoginPage();
      },
    );
  }
}