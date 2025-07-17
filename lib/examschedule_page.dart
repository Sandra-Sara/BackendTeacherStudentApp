import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExamSchedulePage extends StatefulWidget {
  const ExamSchedulePage({super.key});

  @override
  State<ExamSchedulePage> createState() => _ExamSchedulePageState();
}

class _ExamSchedulePageState extends State<ExamSchedulePage> {
  List<Map<String, dynamic>> examSchedule = [];
  final TextEditingController dateController = TextEditingController();
  final TextEditingController subjectController = TextEditingController();
  bool _isLoading = false;
  bool _isSubmitting = false;
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  RealtimeChannel? _scheduleSubscription;

  @override
  void initState() {
    super.initState();
    _checkUser();
    _loadSchedule();
  }

  Future<void> _checkUser() async {
    final user = Supabase.instance.client.auth.currentUser;
    print('ExamSchedulePage: Checking user, user=${user?.id ?? 'null'}');
    if (user == null) {
      _showSnackBar('Please log in to view exam schedule', Colors.redAccent);
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Future<void> _loadSchedule() async {
    print('ExamSchedulePage: Starting _loadSchedule');
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await Supabase.instance.client
          .from('exam_schedule')
          .select()
          .order('date', ascending: true);

      setState(() {
        examSchedule = List<Map<String, dynamic>>.from(response);
      });
      print('ExamSchedulePage: Loaded ${examSchedule.length} exam entries: $examSchedule');

      // Unsubscribe from previous subscription to avoid duplicates
      if (_scheduleSubscription != null) {
        await _scheduleSubscription!.unsubscribe();
      }
      _scheduleSubscription = Supabase.instance.client
          .channel('exam_schedule_channel')
          .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'exam_schedule',
        callback: (payload) {
          print('ExamSchedulePage: Real-time update received: $payload');
          if (mounted) {
            _loadSchedule();
          }
        },
      )
          .subscribe((status, [error]) {
        print('ExamSchedulePage: Subscription status: $status, error: $error');
        if (error != null) {
          _showSnackBar('Subscription error: $error', Colors.redAccent);
        }
      });
    } catch (e) {
      String errorMessage = 'Error loading exam schedule: $e';
      if (e is PostgrestException) {
        errorMessage = 'Error loading exam schedule: ${e.message} (code: ${e.code}, details: ${e.details})';
      }
      _showSnackBar(errorMessage, Colors.redAccent);
      print('ExamSchedulePage: $errorMessage');
    } finally {
      setState(() {
        _isLoading = false;
      });
      print('ExamSchedulePage: _loadSchedule completed, _isLoading=$_isLoading');
    }
  }

  Future<void> _addExam(String date, String subject) async {
    print('ExamSchedulePage: Starting _addExam: $date, $subject');
    if (_isSubmitting) {
      print('ExamSchedulePage: Add exam blocked - already submitting');
      return;
    }
    setState(() {
      _isLoading = true;
      _isSubmitting = true;
    });

    try {
      // Validate date format (DD/MM/YYYY)
      final datePattern = RegExp(r'^\d{2}/\d{2}/\d{4}$');
      if (!datePattern.hasMatch(date)) {
        _showSnackBar('Invalid date format. Use DD/MM/YYYY', Colors.redAccent);
        print('ExamSchedulePage: Invalid date format: $date');
        return;
      }

      // Check for existing exam
      final existingExam = await Supabase.instance.client
          .from('exam_schedule')
          .select()
          .eq('subject', subject.toLowerCase());

      print('ExamSchedulePage: Existing exam check: $existingExam');
      if (existingExam.isNotEmpty) {
        _showSnackBar('Subject already exists in the schedule', Colors.redAccent);
        print('ExamSchedulePage: Subject $subject already exists');
        return;
      }

      final insertPayload = {
        'date': date, // Store as DD/MM/YYYY (adjust if database expects YYYY-MM-DD)
        'subject': subject.toLowerCase(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      print('ExamSchedulePage: Inserting work with payload: $insertPayload');
      final response = await Supabase.instance.client
          .from('exam_schedule')
          .insert(insertPayload)
          .select()
          .single();

      print('ExamSchedulePage: Insert response: $response');
      _showSnackBar('Work added successfully', Colors.green);
      print('ExamSchedulePage: Work added successfully: $date, $subject');

      // Clear input fields
      dateController.clear();
      subjectController.clear();

      // Explicitly reload schedule to ensure UI updates
      await _loadSchedule();
    } catch (e) {
      String errorMessage = 'Error adding work: $e';
      if (e is PostgrestException) {
        errorMessage = 'Error adding work: ${e.message} (code: ${e.code}, details: ${e.details})';
      }
      _showSnackBar(errorMessage, Colors.redAccent);
      print('ExamSchedulePage: $errorMessage');
    } finally {
      setState(() {
        _isLoading = false;
        _isSubmitting = false;
      });
      print('ExamSchedulePage: _addExam completed, _isLoading=$_isLoading, _isSubmitting=$_isSubmitting');
    }
  }

  Future<void> _updateExam(int id, String date, String subject) async {
    print('ExamSchedulePage: Starting _updateExam for id=$id');
    if (_isSubmitting) {
      print('ExamSchedulePage: Update exam blocked - already submitting');
      return;
    }
    setState(() {
      _isLoading = true;
      _isSubmitting = true;
    });

    try {
      // Validate date format (DD/MM/YYYY)
      final datePattern = RegExp(r'^\d{2}/\d{2}/\d{4}$');
      if (!datePattern.hasMatch(date)) {
        _showSnackBar('Invalid date format. Use DD/MM/YYYY', Colors.redAccent);
        print('ExamSchedulePage: Invalid date format: $date');
        return;
      }

      await Supabase.instance.client
          .from('exam_schedule')
          .update({
        'date': date, // Store as DD/MM/YYYY (adjust if database expects YYYY-MM-DD)
        'subject': subject.toLowerCase(),
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', id);
      _showSnackBar('work updated successfully', Colors.green);
      print('ExamSchedulePage: work updated successfully for id=$id');

      // Explicitly reload schedule to ensure UI updates
      await _loadSchedule();
    } catch (e) {
      String errorMessage = 'Error updating work: $e';
      if (e is PostgrestException) {
        errorMessage = 'Error updating work: ${e.message} (code: ${e.code}, details: ${e.details})';
      }
      _showSnackBar(errorMessage, Colors.redAccent);
      print('ExamSchedulePage: $errorMessage');
    } finally {
      setState(() {
        _isLoading = false;
        _isSubmitting = false;
      });
      print('ExamSchedulePage: _updateExam completed, _isLoading=$_isLoading, _isSubmitting=$_isSubmitting');
    }
  }

  Future<void> _deleteExam(int id) async {
    print('ExamSchedulePage: Starting _deleteExam for id=$id');
    if (_isSubmitting) {
      print('ExamSchedulePage: Delete work blocked - already submitting');
      return;
    }
    setState(() {
      _isLoading = true;
      _isSubmitting = true;
    });

    try {
      await Supabase.instance.client.from('exam_schedule').delete().eq('id', id);
      _showSnackBar('Work deleted successfully', Colors.green);
      print('ExamSchedulePage: work deleted successfully for id=$id');

      // Explicitly reload schedule to ensure UI updates
      await _loadSchedule();
    } catch (e) {
      String errorMessage = 'Error deleting work: $e';
      if (e is PostgrestException) {
        errorMessage = 'Error deleting work: ${e.message} (code: ${e.code}, details: ${e.details})';
      }
      _showSnackBar(errorMessage, Colors.redAccent);
      print('ExamSchedulePage: $errorMessage');
    } finally {
      setState(() {
        _isLoading = false;
        _isSubmitting = false;
      });
      print('ExamSchedulePage: _deleteExam completed, _isLoading=$_isLoading, _isSubmitting=$_isSubmitting');
    }
  }

  void _showInputDialog({Map<String, dynamic>? exam}) {
    print('ExamSchedulePage: Opening input dialog for exam=${exam != null ? exam['subject'] : 'new'}');
    dateController.text = exam?['date'] ?? '';
    subjectController.text = exam?['subject'] ?? '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            exam == null ? 'Add work' : 'Edit work',
            style: const TextStyle(color: Colors.black87),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: dateController,
                  decoration: InputDecoration(
                    labelText: 'Date (DD/MM/YYYY)',
                    filled: true,
                    fillColor: Colors.white24,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    labelStyle: const TextStyle(color: Colors.black87),
                    hintStyle: const TextStyle(color: Colors.black54),
                  ),
                  style: const TextStyle(color: Colors.black87),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: subjectController,
                  decoration: InputDecoration(
                    labelText: 'Subject',
                    filled: true,
                    fillColor: Colors.white24,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    labelStyle: const TextStyle(color: Colors.black87),
                    hintStyle: const TextStyle(color: Colors.black54),
                  ),
                  style: const TextStyle(color: Colors.black87),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                print('ExamSchedulePage: Dialog cancelled');
                Navigator.pop(context);
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.redAccent)),
            ),
            TextButton(
              onPressed: _isLoading || _isSubmitting
                  ? null
                  : () async {
                print('ExamSchedulePage: Add/Update work button clicked');
                final date = dateController.text.trim();
                final subject = subjectController.text.trim();

                if (date.isEmpty) {
                  _showSnackBar('Please enter a date', Colors.redAccent);
                  print('ExamSchedulePage: Validation failed - Empty date');
                  return;
                }
                if (subject.isEmpty) {
                  _showSnackBar('Please enter a subject', Colors.redAccent);
                  print('ExamSchedulePage: Validation failed - Empty subject');
                  return;
                }

                try {
                  if (exam == null) {
                    await _addExam(date, subject);
                  } else {
                    await _updateExam(exam['id'], date, subject);
                  }
                  if (mounted) {
                    print('ExamSchedulePage: Closing dialog after add/update');
                    Navigator.pop(context);
                  }
                } catch (e) {
                  _showSnackBar('Error processing work: $e', Colors.redAccent);
                  print('ExamSchedulePage: Error processing work: $e');
                }
              },
              child: _isLoading || _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.blue)
                  : Text(exam == null ? 'Add' : 'Update', style: const TextStyle(color: Colors.blue)),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message, Color backgroundColor) {
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    dateController.dispose();
    subjectController.dispose();
    _scheduleSubscription?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('ExamSchedulePage: Building UI with ${examSchedule.length} exams');
    print('ExamSchedulePage: Add Work button state: _isLoading=$_isLoading, _isSubmitting=$_isSubmitting');
    return Scaffold(
      key: _scaffoldMessengerKey,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Work Schedule',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue.withOpacity(0.9),
        elevation: 4,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue, Colors.deepPurple],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Image.asset(
                      'assets/dulogo.png',
                      height: 150,
                      width: 300,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.image_not_supported,
                        size: 100,
                        color: Colors.white70,
                      ),
                    ).animate().fadeIn(duration: 800.ms).scaleXY(
                      begin: 0.8,
                      end: 1.0,
                      curve: Curves.easeOut,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'University Of Dhaka',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          blurRadius: 4.0,
                          color: Colors.black26,
                          offset: Offset(2.0, 2.0),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 600.ms),
                  const SizedBox(height: 20),
                  const Text(
                    'work Schedule',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                      shadows: [
                        Shadow(
                          blurRadius: 4.0,
                          color: Colors.black26,
                          offset: Offset(2.0, 2.0),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 650.ms),
                  const SizedBox(height: 30),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                height: 50,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Colors.blue, Colors.deepPurple],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _isLoading || _isSubmitting
                                      ? null
                                      : () {
                                    print('ExamSchedulePage: Add work button clicked');
                                    _showInputDialog();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Add Work',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ).animate().fadeIn(duration: 800.ms).scaleXY(
                                begin: 0.9,
                                end: 1.0,
                                curve: Curves.bounceOut,
                              ),
                              const SizedBox(height: 16),
                              if (_isLoading || _isSubmitting)
                                const Center(child: CircularProgressIndicator(color: Colors.white))
                              else if (examSchedule.isEmpty)
                                const Text(
                                  'No work available',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white70,
                                  ),
                                ).animate().fadeIn(duration: 600.ms)
                              else
                                Column(
                                  children: examSchedule.map((exam) {
                                    return ExamScheduleRow(
                                      id: exam['id'],
                                      date: exam['date'],
                                      subject: exam['subject'],
                                      onEdit: () => _showInputDialog(exam: exam),
                                      onDelete: () => _deleteExam(exam['id']),
                                    );
                                  }).toList(),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(duration: 800.ms).scaleXY(
                    begin: 0.9,
                    end: 1.0,
                    curve: Curves.bounceOut,
                  ),
                  const SizedBox(height: 30),
                  Center(
                    child: ElevatedButton(
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
                  ).animate().fadeIn(duration: 800.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ExamScheduleRow extends StatelessWidget {
  final int id;
  final String date;
  final String subject;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ExamScheduleRow({
    super.key,
    required this.id,
    required this.date,
    required this.subject,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    print('ExamSchedulePage: Rendering exam row: $id, $date, $subject');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            date,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16.0),
          Expanded(
            child: Text(
              subject,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue),
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}