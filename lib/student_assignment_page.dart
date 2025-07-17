import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'dart:ui';

class StudentAssignmentPage extends StatefulWidget {
  const StudentAssignmentPage({super.key});

  @override
  State<StudentAssignmentPage> createState() => _StudentAssignmentPageState();
}

class _StudentAssignmentPageState extends State<StudentAssignmentPage> {
  List<Map<String, dynamic>> submissions = [];
  bool _isLoading = false;
  String _errorMessage = '';
  Color _errorMessageColor = Colors.red;
  bool _isTeacher = false;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
    _loadSubmissions();
  }

  Future<void> _checkUserRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        _errorMessage = 'Please log in';
        _errorMessageColor = Colors.red;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_errorMessage), backgroundColor: _errorMessageColor),
      );
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    try {
      final response = await Supabase.instance.client
          .from('student_teacher')
          .select('role')
          .eq('id', user.id)
          .maybeSingle(); // Use maybeSingle to handle no rows
      setState(() {
        _isTeacher = response != null && response['role'] == 'teacher';
      });
      print(
          'StudentAssignmentPage: User role: ${_isTeacher ? 'teacher' : 'student'}');
    } catch (e, stackTrace) {
      setState(() {
        _errorMessage = 'Error checking user role: $e';
        _errorMessageColor = Colors.red;
        _isTeacher = false; // Default to student if role check fails
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_errorMessage), backgroundColor: _errorMessageColor),
      );
      print(
          'StudentAssignmentPage: Error in _checkUserRole: $e\nStackTrace: $stackTrace');
    }
  }

  Future<void> _loadSubmissions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      print(
          'StudentAssignmentPage: Querying classwork_submissions for user: ${user.id}, isTeacher: $_isTeacher');

// Use Supabase client query instead of raw SQL
      var query = Supabase.instance.client
          .from('classwork_submissions')
          .select(
              'id, course_id, user_id, submission_text, file_url, created_at, submissioncourse!left(course_name)')
          .order('created_at', ascending: false);

      final response = await query;

      print('StudentAssignmentPage: Query response: $response');
      setState(() {
        submissions = List<Map<String, dynamic>>.from(response).map((s) {
          final fileUrl = (s['file_url'] ?? '').toString();
          print('StudentAssignmentPage: Processing file_url: $fileUrl');
          return {
            'id': s['id'] ?? '',
            'courseName': s['submissioncourse'] != null
                ? s['submissioncourse']['course_name'] ?? 'Unknown Course'
                : 'Unknown Course',
            'userId': s['user_id'] ?? '',
            'text': (s['submission_text'] ?? '').toString(),
            'fileUrl': fileUrl,
            'fileName': fileUrl.isNotEmpty ? fileUrl.split('/').last : '',
            'date': s['created_at'] != null
                ? DateFormat('dd/MM/yyyy')
                    .format(DateTime.parse(s['created_at']))
                : '',
          };
        }).toList();
        _errorMessage = submissions.isEmpty ? 'No submissions found' : '';
        _errorMessageColor = submissions.isEmpty ? Colors.yellow : Colors.green;
        print(
            'StudentAssignmentPage: Loaded ${submissions.length} submissions');
      });
    } catch (e, stackTrace) {
      setState(() {
        _errorMessage = 'Error loading submissions: $e';
        _errorMessageColor = Colors.red;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_errorMessage), backgroundColor: _errorMessageColor),
      );
      print(
          'StudentAssignmentPage: Error in _loadSubmissions: $e\nStackTrace: $stackTrace');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _openFile(String fileUrl) async {
    if (fileUrl.isEmpty) {
      setState(() {
        _errorMessage = 'No file available';
        _errorMessageColor = Colors.red;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_errorMessage), backgroundColor: _errorMessageColor),
      );
      return;
    }
    try {
      // If the fileUrl starts with 'http' and contains '/public/', just open it directly
      final uri = Uri.parse(fileUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        setState(() {
          _errorMessage = 'Cannot launch URL: $fileUrl';
          _errorMessageColor = Colors.red;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_errorMessage),
              backgroundColor: _errorMessageColor),
        );
      }
    } catch (e, stackTrace) {
      setState(() {
        _errorMessage = 'Error opening file: $e';
        _errorMessageColor = Colors.red;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_errorMessage), backgroundColor: _errorMessageColor),
      );
      print(
          'StudentAssignmentPage: Error in _openFile: $e\nStackTrace: $stackTrace');
    }
  }

  Future<void> _deleteSubmission(String id, String fileUrl) async {
    if (!_isTeacher) {
      setState(() {
        _errorMessage = 'Only teachers can delete submissions';
        _errorMessageColor = Colors.red;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_errorMessage), backgroundColor: _errorMessageColor),
      );
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      if (fileUrl.isNotEmpty) {
        String cleanFilePath = fileUrl;
        if (fileUrl.contains('classwork/')) {
          cleanFilePath = fileUrl.split('classwork/').last;
        } else if (fileUrl.contains('/storage/v1/object/')) {
          cleanFilePath =
              fileUrl.split('/storage/v1/object/').last.split('?').first;
        }
        print('StudentAssignmentPage: Deleting file: $cleanFilePath');
        await Supabase.instance.client.storage
            .from('classwork')
            .remove([cleanFilePath]);
      }
      print('StudentAssignmentPage: Deleting submission ID: $id');
      await Supabase.instance.client
          .from('classwork_submissions')
          .delete()
          .eq('id', id);
      setState(() {
        submissions.removeWhere((s) => s['id'] == id);
        _errorMessage = 'Submission deleted';
        _errorMessageColor = Colors.green;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_errorMessage), backgroundColor: _errorMessageColor),
      );
    } catch (e, stackTrace) {
      setState(() {
        _errorMessage = 'Error deleting submission: $e';
        _errorMessageColor = Colors.red;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_errorMessage), backgroundColor: _errorMessageColor),
      );
      print(
          'StudentAssignmentPage: Error in _deleteSubmission: $e\nStackTrace: $stackTrace');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print(
        'StudentAssignmentPage: Building UI with ${submissions.length} submissions');
    return Scaffold(
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
                        Icons.error,
                        size: 100,
                        color: Colors.white70,
                      ),
                    ).animate().fadeIn(duration: 800.ms),
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
                            offset: Offset(2.0, 2.0)),
                      ],
                    ),
                  ).animate().fadeIn(duration: 600.ms),
                  const SizedBox(height: 20),
                  Text(
                    _isTeacher ? 'Student Submissions' : 'My Submissions',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ).animate().fadeIn(duration: 650.ms),
                  const SizedBox(height: 20),
                  if (_errorMessage.isNotEmpty)
                    Text(
                      _errorMessage,
                      style: TextStyle(color: _errorMessageColor, fontSize: 16),
                    ).animate().fadeIn(duration: 500.ms),
                  const SizedBox(height: 10),
                  const Text(
                    'Submissions',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white))
                      : submissions.isEmpty
                          ? const Text(
                              'No submissions available',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.white70),
                            ).animate().fadeIn(duration: 600.ms)
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: Colors.white.withOpacity(0.2),
                                        width: 1.5),
                                  ),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: submissions.length,
                                    itemBuilder: (context, index) {
                                      final submission = submissions[index];
                                      return ListTile(
                                        leading:
                                            submission['fileName'].isNotEmpty
                                                ? const Icon(
                                                    Icons.insert_drive_file,
                                                    color: Colors.white70)
                                                : null,
                                        title: Text(
                                          '${submission['courseName']}: ${submission['text'].isNotEmpty ? submission['text'] : '(No text)'}',
                                          style: const TextStyle(
                                              color: Colors.white),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              submission['date'],
                                              style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 14),
                                            ),
                                            if (_isTeacher)
                                              Text(
                                                'Submitted by: ${submission['userId']}',
                                                style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 14),
                                              ),
                                            if (submission['fileName']
                                                .isNotEmpty)
                                              GestureDetector(
                                                onTap: () => _openFile(
                                                    submission['fileUrl']),
                                                child: Text(
                                                  'File: ${submission['fileName']}',
                                                  style: const TextStyle(
                                                    color: Colors.blue,
                                                    fontSize: 14,
                                                    decoration: TextDecoration
                                                        .underline,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        trailing: _isTeacher
                                            ? IconButton(
                                                icon: const Icon(Icons.delete,
                                                    color: Colors.red),
                                                onPressed: () =>
                                                    _deleteSubmission(
                                                  submission['id'],
                                                  submission['fileUrl'],
                                                ),
                                              )
                                            : null,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            )
                              .animate()
                              .fadeIn(duration: 600.ms)
                              .slideY(begin: 0.5),
                  const SizedBox(height: 20),
                  Center(
                    child: Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.blue, Colors.deepPurple],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
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
                    ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.5),
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
