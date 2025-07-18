import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:ui';

class ClassworkPage extends StatefulWidget {
  const ClassworkPage({super.key});

  @override
  State<ClassworkPage> createState() => _ClassworkPageState();
}

class _ClassworkPageState extends State<ClassworkPage> {
  String? _selectedCourseId;
  final TextEditingController _submissionController = TextEditingController();
  final TextEditingController _courseNameController = TextEditingController();
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _submissions = [];
  PlatformFile? _selectedFile;
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _isAddingCourse = false;
  String? _courseLoadError;
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  RealtimeChannel? _submissionSubscription;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    print('ClassworkPage: Checking user role at ${DateTime.now().toIso8601String()}');
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _showSnackBar('Please log in', Colors.redAccent);
      print('ClassworkPage: User not authenticated');
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    print('ClassworkPage: Authenticated user ID: ${user.id}, email: ${user.email}');
    try {
      final profile = await Supabase.instance.client
          .from('student_teacher')
          .select('role')
          .eq('id', user.id)
          .single();
      print('ClassworkPage: User role: ${profile['role']}');
      if (profile['role'] != 'student') {
        _showSnackBar('Only students can access this page', Colors.redAccent);
        print('ClassworkPage: Access denied - user is not a student');
        Navigator.pop(context);
        return;
      }
      await _loadCourses();
      await _loadSubmissions();
    } catch (e) {
      String errorMessage = 'Error checking user role: $e';
      if (e is PostgrestException) {
        errorMessage = 'Error checking user role: ${e.message} (code: ${e.code}, details: ${e.details})';
      }
      _showSnackBar(errorMessage, Colors.redAccent);
      print('ClassworkPage: $errorMessage');
    }
  }

  Future<void> _loadCourses() async {
    print('ClassworkPage: Starting _loadCourses at ${DateTime.now().toIso8601String()}');
    setState(() {
      _isLoading = true;
      _courseLoadError = null;
    });
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      print('ClassworkPage: Querying submissioncourse for user: ${user.id}');
      final response = await Supabase.instance.client
          .from('submissioncourse')
          .select()
          .withConverter((data) => List<Map<String, dynamic>>.from(data));
      setState(() {
        _courses = response;
        if (_courses.isNotEmpty) {
          _selectedCourseId = _courses[0]['id'];
          print('ClassworkPage: Selected default course ID: $_selectedCourseId');
        } else {
          _courseLoadError = 'No courses available. Add a new course below.';
          _selectedCourseId = null;
          print('ClassworkPage: No courses found in submissioncourse table');
        }
      });
      print('ClassworkPage: Loaded ${_courses.length} courses: $_courses');
    } catch (e) {
      String errorMessage = 'Error loading courses: $e';
      if (e is PostgrestException) {
        errorMessage = 'Error loading courses: ${e.message} (code: ${e.code}, details: ${e.details})';
        if (e.code == '42501') {
          errorMessage = 'Permission denied: Check RLS policies for submissioncourse';
        }
      }
      setState(() {
        _courseLoadError = errorMessage;
      });
      _showSnackBar(errorMessage, Colors.redAccent);
      print('ClassworkPage: $errorMessage');
    } finally {
      setState(() {
        _isLoading = false;
      });
      print('ClassworkPage: _loadCourses completed, _isLoading=$_isLoading, _courseLoadError=$_courseLoadError');
    }
  }

  Future<void> _addCourse() async {
    final courseName = _courseNameController.text.trim();
    if (courseName.isEmpty) {
      _showSnackBar('Please enter a course name', Colors.redAccent);
      print('ClassworkPage: Course name is empty');
      return;
    }
    if (_isAddingCourse) {
      print('ClassworkPage: Course addition blocked - already adding');
      return;
    }

    setState(() {
      _isAddingCourse = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');
      print('ClassworkPage: Adding course: $courseName for user: ${user.id}');
      final response = await Supabase.instance.client
          .from('submissioncourse')
          .insert({'course_name': courseName})
          .select()
          .single();
      print('ClassworkPage: Course added: $response');
      setState(() {
        _courseNameController.clear();
        _courseLoadError = null;
      });
      await _loadCourses();
      setState(() {
        _selectedCourseId = response['id'];
      });
      _showSnackBar('Course "$courseName" added successfully!', Colors.green);
      print('ClassworkPage: Selected new course ID: $_selectedCourseId');
    } catch (e) {
      String errorMessage = 'Error adding course: $e';
      if (e is PostgrestException) {
        errorMessage = 'Error adding course: ${e.message} (code: ${e.code}, details: ${e.details})';
        if (e.code == '42501') {
          errorMessage = 'Permission denied: Check RLS policies for submissioncourse';
        }
      }
      _showSnackBar(errorMessage, Colors.redAccent);
      print('ClassworkPage: $errorMessage');
    } finally {
      setState(() {
        _isAddingCourse = false;
      });
      print('ClassworkPage: _addCourse completed, _isAddingCourse=$_isAddingCourse');
    }
  }

  Future<void> _loadSubmissions() async {
    print('ClassworkPage: Starting _loadSubmissions at ${DateTime.now().toIso8601String()}');
    setState(() {
      _isLoading = true;
    });
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final response = await Supabase.instance.client
          .from('classwork_submissions')
          .select()
          .eq('user_id', user.id);
      setState(() {
        _submissions = List<Map<String, dynamic>>.from(response);
      });
      print('ClassworkPage: Loaded ${_submissions.length} submissions: $_submissions');

      // Unsubscribe from previous subscription to avoid duplicates
      if (_submissionSubscription != null) {
        await _submissionSubscription!.unsubscribe();
      }
      _submissionSubscription = Supabase.instance.client
          .channel('classwork_submissions_channel')
          .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'classwork_submissions',
        callback: (payload) {
          print('ClassworkPage: Real-time update received: $payload');
          if (mounted) {
            _loadSubmissions();
          }
        },
      )
          .subscribe((status, [error]) {
        print('ClassworkPage: Subscription status: $status, error: $error');
        if (error != null) {
          _showSnackBar('Subscription error: $error', Colors.redAccent);
        }
      });
    } catch (e) {
      String errorMessage = 'Error loading submissions: $e';
      if (e is PostgrestException) {
        errorMessage = 'Error loading submissions: ${e.message} (code: ${e.code}, details: ${e.details})';
      }
      _showSnackBar(errorMessage, Colors.redAccent);
      print('ClassworkPage: $errorMessage');
    } finally {
      setState(() {
        _isLoading = false;
      });
      print('ClassworkPage: _loadSubmissions completed, _isLoading=$_isLoading');
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
        });
        _showSnackBar('File selected: ${_selectedFile!.name}', Colors.green);
        print('ClassworkPage: File selected: ${_selectedFile!.name}, size: ${_selectedFile!.size} bytes');
      } else {
        _showSnackBar('No file selected', Colors.redAccent);
        print('ClassworkPage: No file selected');
      }
    } catch (e) {
      String errorMessage = 'Error picking file: $e';
      _showSnackBar(errorMessage, Colors.redAccent);
      print('ClassworkPage: $errorMessage');
    }
  }

  Future<void> _submitClasswork() async {
    if (_selectedCourseId == null || _submissionController.text.isEmpty) {
      _showSnackBar('Please select a course and enter submission details', Colors.redAccent);
      print('ClassworkPage: Validation failed - Missing course or submission text');
      return;
    }
    if (_isSubmitting) {
      print('ClassworkPage: Submission blocked - already submitting');
      return;
    }

    setState(() {
      _isLoading = true;
      _isSubmitting = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');
      print('ClassworkPage: Current user: ${user.id}');

      String? fileUrl;
      if (_selectedFile != null) {
        final filePath = 'submissions/${user.id}/${DateTime.now().millisecondsSinceEpoch}_${_selectedFile!.name}';
        print('ClassworkPage: Uploading file to classwork bucket: $filePath');
        final fileBytes = _selectedFile!.bytes ?? File(_selectedFile!.path!).readAsBytesSync();
        await Supabase.instance.client.storage
            .from('classwork')
            .uploadBinary(filePath, fileBytes);
        fileUrl = Supabase.instance.client.storage.from('classwork').getPublicUrl(filePath);
        print('ClassworkPage: File uploaded to: $fileUrl');
      }

      final insertPayload = {
        'course_id': _selectedCourseId,
        'user_id': user.id,
        'submission_text': _submissionController.text,
        'file_url': fileUrl,
        'created_at': DateTime.now().toIso8601String(),
      };
      print('ClassworkPage: Inserting submission with payload: $insertPayload');
      final response = await Supabase.instance.client
          .from('classwork_submissions')
          .insert(insertPayload)
          .select()
          .single();

      print('ClassworkPage: Insert response: $response');
      await _loadSubmissions();
      setState(() {
        _submissionController.clear();
        _selectedFile = null;
        _selectedCourseId = _courses.isNotEmpty ? _courses[0]['id'] : null;
      });
      _showSnackBar('Classwork submitted successfully!', Colors.green);
      print('ClassworkPage: Classwork submitted successfully');
    } catch (e) {
      String errorMessage = 'Error submitting classwork: $e';
      if (e is PostgrestException) {
        errorMessage = 'Error submitting classwork: ${e.message} (code: ${e.code}, details: ${e.details})';
      } else if (e.toString().contains('permission denied')) {
        errorMessage = 'Permission denied: Ensure you are authorized to submit classwork';
      } else if (e.toString().contains('foreign key violation')) {
        errorMessage = 'Invalid course ID: Please select a valid course';
      }
      _showSnackBar(errorMessage, Colors.redAccent);
      print('ClassworkPage: $errorMessage');
    } finally {
      setState(() {
        _isLoading = false;
        _isSubmitting = false;
      });
      print('ClassworkPage: _submitClasswork completed, _isLoading=$_isLoading, _isSubmitting=$_isSubmitting');
    }
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
    _submissionController.dispose();
    _courseNameController.dispose();
    _submissionSubscription?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('ClassworkPage: Building UI with ${_submissions.length} submissions, ${_courses.length} courses, error: $_courseLoadError');
    return Scaffold(
      key: _scaffoldMessengerKey,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Classwork Submission',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue.withOpacity(0.9),
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              print('ClassworkPage: Navigating back');
              Navigator.pop(context);
            },
            tooltip: 'Back',
          ),
        ],
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
                    'Classwork Submission',
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
                              const Text(
                                'Add New Course:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _courseNameController,
                                      style: const TextStyle(color: Colors.white),
                                      decoration: InputDecoration(
                                        border: const OutlineInputBorder(),
                                        hintText: 'Enter new course name...',
                                        hintStyle: const TextStyle(color: Colors.white70),
                                        filled: true,
                                        fillColor: Colors.white.withOpacity(0.1),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _isAddingCourse ? null : _addCourse,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: _isAddingCourse
                                        ? const CircularProgressIndicator(color: Colors.white)
                                        : const Text(
                                      'Add',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Select Course:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _isLoading
                                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                                  : _courseLoadError != null
                                  ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _courseLoadError!,
                                    style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton(
                                    onPressed: _loadCourses,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      'Retry',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              )
                                  : _courses.isEmpty
                                  ? const Text(
                                'No courses available. Add a new course above.',
                                style: TextStyle(color: Colors.white70, fontSize: 14),
                              )
                                  : DropdownButton<String>(
                                value: _selectedCourseId,
                                hint: const Text(
                                  'Choose a course',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                isExpanded: true,
                                dropdownColor: Colors.blue.withOpacity(0.8),
                                items: _courses.map((course) {
                                  return DropdownMenuItem<String>(
                                    value: course['id'],
                                    child: Text(
                                      course['course_name'] ?? 'Unnamed Course',
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  if (newValue != null) {
                                    setState(() {
                                      _selectedCourseId = newValue;
                                    });
                                    print('ClassworkPage: Selected course ID: $_selectedCourseId');
                                  }
                                },
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Submission Details:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _submissionController,
                                maxLines: 5,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  border: const OutlineInputBorder(),
                                  hintText: 'Enter classwork details or answers...',
                                  hintStyle: const TextStyle(color: Colors.white70),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.1),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Attach File:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _selectedFile != null
                                          ? _selectedFile!.name
                                          : 'No file selected',
                                      style: const TextStyle(color: Colors.white70),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: _pickFile,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      'Pick File',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
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
                  const SizedBox(height: 20),
                  const Text(
                    'Previous Submissions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ).animate().fadeIn(duration: 600.ms),
                  const SizedBox(height: 10),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Colors.white))
                      : _submissions.isEmpty
                      ? const Text(
                    'No submissions yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ).animate().fadeIn(duration: 600.ms)
                      : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _submissions.length,
                    itemBuilder: (context, index) {
                      final submission = _submissions[index];
                      final courseName = _courses.firstWhere(
                            (course) => course['id'] == submission['course_id'],
                        orElse: () => {'course_name': 'Unknown Course'},
                      )['course_name'];
                      return Card(
                        color: Colors.white.withOpacity(0.1),
                        child: ListTile(
                          title: Text(
                            '$courseName: ${submission['submission_text']}',
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: submission['file_url'] != null
                              ? GestureDetector(
                            onTap: () async {
                              try {
                                final fileName = submission['file_url'].split('/').last;
                                final filePath = 'submissions/${submission['user_id']}/$fileName';
                                final data = await Supabase.instance.client.storage
                                    .from('classwork')
                                    .download(filePath);
                                _showSnackBar('File downloaded', Colors.green);
                                print('ClassworkPage: File downloaded: $filePath');
                              } catch (e) {
                                String errorMessage = 'Error downloading file: $e';
                                _showSnackBar(errorMessage, Colors.redAccent);
                                print('ClassworkPage: $errorMessage');
                              }
                            },
                            child: Text(
                              'File: ${submission['file_url'].split('/').last}',
                              style: const TextStyle(
                                color: Colors.yellowAccent,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          )
                              : null,
                        ),
                      );
                    },
                  ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.5, end: 0),
                  const SizedBox(height: 30),
                  Center(
                    child: Container(
                      width: 200,
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
                        onPressed: (_isLoading || _isSubmitting || _selectedCourseId == null) ? null : _submitClasswork,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading || _isSubmitting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                          'Submit',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(duration: 800.ms).scaleXY(
                    begin: 0.9,
                    end: 1.0,
                    curve: Curves.bounceOut,
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Container(
                      width: 200,
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
                        onPressed: () {
                          print('ClassworkPage: Navigating back');
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
                    ),
                  ).animate().fadeIn(duration: 800.ms).scaleXY(
                    begin: 0.9,
                    end: 1.0,
                    curve: Curves.bounceOut,
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
