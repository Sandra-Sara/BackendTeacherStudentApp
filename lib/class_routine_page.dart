import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClassRoutinePage extends StatefulWidget {
  const ClassRoutinePage({super.key});

  @override
  State<ClassRoutinePage> createState() => _ClassRoutinePageState();
}

class _ClassRoutinePageState extends State<ClassRoutinePage> {
  List<Map<String, dynamic>> routines = [];
  final TextEditingController searchController = TextEditingController();
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  bool _isLoading = false;
  RealtimeChannel? _routineSubscription;

  @override
  void initState() {
    super.initState();
    _checkUserAndLoadRoutines();
  }

  Future<void> _checkUserAndLoadRoutines() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _showSnackBar('Please log in to view routines', Colors.redAccent);
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    await _loadRoutines();
  }

  Future<void> _loadRoutines() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final response = await Supabase.instance.client
          .from('routines')
          .select()
          .eq('user_id', user.id);
      setState(() {
        routines = List<Map<String, dynamic>>.from(response);
        if (routines.isEmpty) {
          _showSnackBar('No routines found. Add a new routine.', Colors.orange);
        }
      });
      print('ClassRoutinePage: Loaded ${routines.length} routines');

      // Subscribe to real-time changes
      _routineSubscription?.unsubscribe();
      _routineSubscription = Supabase.instance.client
          .channel('routines_channel_${user.id}')
          .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'routines',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: user.id,
        ),
        callback: (payload) {
          print('ClassRoutinePage: Real-time update received: $payload');
          if (payload.eventType == 'INSERT' || payload.eventType == 'UPDATE' || payload.eventType == 'DELETE') {
            _loadRoutines();
          }
        },
      )
          .subscribe();
    } catch (e) {
      String errorMessage = 'Error loading routines: $e';
      if (e is PostgrestException) {
        errorMessage = 'Error loading routines: ${e.message} (code: ${e.code}, details: ${e.details})';
      }
      _showSnackBar(errorMessage, Colors.redAccent);
      print('ClassRoutinePage: $errorMessage');
      setState(() {
        routines = [];
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addRoutine(String subject, String day, String time, String date) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _showSnackBar('Please log in to add a routine', Colors.redAccent);
      return;
    }

    try {
      print('ClassRoutinePage: Adding routine: $subject, $day, $time, $date');
      await Supabase.instance.client.from('routines').insert({
        'user_id': user.id,
        'subject': subject,
        'day': day,
        'time': time,
        'date': date,
      });
      await _loadRoutines();
      _showSnackBar('Routine added successfully', Colors.green);
      print('ClassRoutinePage: Routine added successfully');
    } catch (e) {
      String errorMessage = 'Error adding routine: $e';
      if (e is PostgrestException) {
        errorMessage = 'Error adding routine: ${e.message} (code: ${e.code}, details: ${e.details})';
      }
      _showSnackBar(errorMessage, Colors.redAccent);
      print('ClassRoutinePage: $errorMessage');
    }
  }

  void _showAddRoutineDialog() {
    final subjectController = TextEditingController();
    final dayController = TextEditingController();
    final timeController = TextEditingController();
    final dateController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.9),
        title: const Text(
          'Add New Routine',
          style: TextStyle(color: Colors.blue),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: subjectController,
                decoration: const InputDecoration(
                  labelText: 'Subject (e.g., CSE 2201)',
                  labelStyle: TextStyle(color: Colors.blue),
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(color: Colors.black87),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: dayController,
                decoration: const InputDecoration(
                  labelText: 'Day (e.g., Monday)',
                  labelStyle: TextStyle(color: Colors.blue),
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(color: Colors.black87),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: timeController,
                decoration: const InputDecoration(
                  labelText: 'Time (e.g., 9:00 AM - 11:00 AM)',
                  labelStyle: TextStyle(color: Colors.blue),
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(color: Colors.black87),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: dateController,
                decoration: const InputDecoration(
                  labelText: 'Date (YYYY-MM-DD)',
                  labelStyle: TextStyle(color: Colors.blue),
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(color: Colors.black87),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final subject = subjectController.text.trim();
              final day = dayController.text.trim();
              final time = timeController.text.trim();
              final date = dateController.text.trim();

              if (subject.isEmpty || day.isEmpty || time.isEmpty || date.isEmpty) {
                _showSnackBar('Please fill in all fields', Colors.redAccent);
                print('AddRoutineDialog: Validation failed - Empty fields');
                return;
              }
              if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
                _showSnackBar('Please enter a valid date (YYYY-MM-DD)', Colors.redAccent);
                print('AddRoutineDialog: Validation failed - Invalid date format');
                return;
              }
              await _addRoutine(subject, day, time, date);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            child: const Text(
              'Add',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color backgroundColor) {
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
      ),
    );
  }

  List<Map<String, dynamic>> get filteredRoutines {
    String query = searchController.text.trim().toLowerCase();
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(query)) {
      return routines.where((routine) => routine['date'] == query).toList();
    } else {
      return routines.where((routine) => routine['subject'].toLowerCase().contains(query)).toList();
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    _routineSubscription?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldMessengerKey,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue, Colors.deepPurple],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    'assets/dulogo.png',
                    height: 150,
                    width: 300,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, size: 100, color: Colors.white70),
                  ).animate().fadeIn(duration: 800.ms),
                  const SizedBox(height: 20),
                  const Text(
                    'University Of Dhaka',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Class Routine',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.white70),
                  ),
                  const SizedBox(height: 30),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: searchController,
                            decoration: const InputDecoration(
                              labelText: 'Search by Subject or Date (YYYY-MM-DD)',
                              border: OutlineInputBorder(),
                              labelStyle: TextStyle(color: Colors.black87),
                            ),
                            style: const TextStyle(color: Colors.black87),
                            onChanged: (value) => setState(() {}),
                          ),
                          const SizedBox(height: 20),
                          if (_isLoading)
                            const Center(child: CircularProgressIndicator(color: Colors.blue))
                          else if (routines.isEmpty && searchController.text.isEmpty)
                            const Text(
                              'No routines available. Add a new routine.',
                              style: TextStyle(fontSize: 16, color: Colors.red),
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(searchController.text.trim())
                                      ? 'Subjects on ${searchController.text}:'
                                      : 'Schedule for ${searchController.text}:',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 5),
                                if (filteredRoutines.isEmpty)
                                  const Text(
                                    'No class found',
                                    style: TextStyle(fontSize: 16, color: Colors.red),
                                  )
                                else
                                  ...filteredRoutines.map((routine) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Text(
                                      RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(searchController.text.trim())
                                          ? '${routine['subject']} at ${routine['time']}'
                                          : '${routine['subject']} on ${routine['day']} (${routine['date']}) at ${routine['time']}',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  )),
                              ],
                            ),
                          const SizedBox(height: 20),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredRoutines.length,
                            itemBuilder: (context, index) {
                              final routine = filteredRoutines[index];
                              return ListTile(
                                title: Text('${routine['subject']} (${routine['time']})'),
                                subtitle: Text('${routine['day']} - ${routine['date']}'),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.5, end: 0),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: _showAddRoutineDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          minimumSize: const Size(200, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 5,
                        ),
                        child: const Text(
                          'Add Routine',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          minimumSize: const Size(200, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 5,
                        ),
                        child: const Text(
                          'Back',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}