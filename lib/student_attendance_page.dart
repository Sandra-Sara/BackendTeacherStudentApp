import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentAttendancePage extends StatefulWidget {
  const StudentAttendancePage({super.key});

  @override
  State<StudentAttendancePage> createState() => _StudentAttendancePageState();
}

class _StudentAttendancePageState extends State<StudentAttendancePage> {
  List<Map<String, dynamic>> students = [];
  List<Map<String, dynamic>> courses = [];
  String? selectedCourseId;
  String selectedCourseName = 'Select a course';
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  bool _isLoading = false;
  RealtimeChannel? _attendanceSubscription;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _showSnackBar('Please log in', Colors.redAccent);
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    try {
      final profile = await Supabase.instance.client
          .from('profile')
          .select('role')
          .eq('id', user.id)
          .single();
      if (profile['role'] != 'teacher') {
        _showSnackBar('Only teachers can access this page', Colors.redAccent);
        Navigator.pop(context);
        return;
      }
      await _loadCourses();
    } catch (e) {
      _showSnackBar('Error checking user role: $e', Colors.redAccent);
      print('StudentAttendancePage: Error checking user role: $e');
    }
  }

  Future<void> _loadCourses() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final response = await Supabase.instance.client
          .from('courses')
          .select()
          .eq('teacher_id', user.id);
      setState(() {
        courses = List<Map<String, dynamic>>.from(response);
        if (courses.isNotEmpty && selectedCourseId == null) {
          selectedCourseId = courses[0]['id'];
          selectedCourseName = courses[0]['course_name'];
          _loadStudents(selectedCourseId!);
        } else if (courses.isEmpty) {
          selectedCourseId = null;
          selectedCourseName = 'No courses available';
          students = [];
        }
      });
      print('StudentAttendancePage: Loaded ${courses.length} courses');
    } catch (e) {
      _showSnackBar('Error loading courses: $e', Colors.redAccent);
      print('StudentAttendancePage: Error loading courses: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStudents(String courseId) async {
    setState(() {
      _isLoading = true;
    });
    try {
      print('StudentAttendancePage: Loading students for course ID: $courseId');
      final response = await Supabase.instance.client
          .from('attendance')
          .select()
          .eq('course_id', courseId);
      setState(() {
        students = List<Map<String, dynamic>>.from(response);
      });
      print('StudentAttendancePage: Loaded ${students.length} students for course ID: $courseId');

      _attendanceSubscription?.unsubscribe();
      _attendanceSubscription = Supabase.instance.client
          .channel('attendance_channel_${courseId}')
          .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'attendance',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'course_id',
          value: courseId,
        ),
        callback: (payload) {
          print('StudentAttendancePage: Real-time update received: $payload');
          if (payload.eventType == 'INSERT' || payload.eventType == 'UPDATE') {
            _loadStudents(courseId);
          }
        },
      )
          .subscribe();
    } catch (e) {
      _showSnackBar('Error loading students: $e', Colors.redAccent);
      print('StudentAttendancePage: Error loading students: $e');
      setState(() {
        students = [];
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addCourse(String courseName) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _showSnackBar('Please log in to add a course', Colors.redAccent);
      return;
    }

    try {
      print('StudentAttendancePage: Adding course: $courseName');
      final courseId = '${user.id}_${courseName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}';
      await Supabase.instance.client.from('courses').insert({
        'id': courseId,
        'course_name': courseName,
        'teacher_id': user.id,
        'created_at': DateTime.now().toIso8601String(),
      });
      setState(() {
        courses.add({
          'id': courseId,
          'course_name': courseName,
          'teacher_id': user.id,
        });
        selectedCourseId = courseId;
        selectedCourseName = courseName;
        students = [];
      });
      _showSnackBar('Course added successfully', Colors.green);
      print('StudentAttendancePage: Course added: $courseName');
    } catch (e) {
      _showSnackBar('Error adding course: $e', Colors.redAccent);
      print('StudentAttendancePage: Error adding course: $e');
    }
  }

  Future<void> _updateAttendance(int index, bool increase) async {
    if (selectedCourseId == null) return;
    final student = students[index];
    final newAttendance = increase
        ? (student['attendance'] + 5).clamp(0, 100)
        : (student['attendance'] - 5).clamp(0, 100);

    try {
      print('StudentAttendancePage: Updating attendance for ${student['student_name']}: ${student['attendance']}% to $newAttendance%');
      await Supabase.instance.client
          .from('attendance')
          .update({
        'attendance': newAttendance,
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', student['id']);
      setState(() {
        students[index] = {...student, 'attendance': newAttendance};
      });
      _showSnackBar('Attendance updated for ${student['student_name']}', Colors.green);
      print('StudentAttendancePage: Attendance updated successfully');
    } catch (e) {
      _showSnackBar('Error updating attendance: $e', Colors.redAccent);
      print('StudentAttendancePage: Error updating attendance: $e');
    }
  }

  Future<void> _addStudent(String name, int attendance) async {
    if (selectedCourseId == null) {
      _showSnackBar('Please select or add a course first', Colors.redAccent);
      print('StudentAttendancePage: No course selected for adding student');
      return;
    }

    try {
      print('StudentAttendancePage: Attempting to add student: $name, Attendance: $attendance% for course: $selectedCourseId');
      // Validate course_id exists
      final courseExists = await Supabase.instance.client
          .from('courses')
          .select('id')
          .eq('id', selectedCourseId!)
          .eq('teacher_id', Supabase.instance.client.auth.currentUser!.id)
          .maybeSingle();
      if (courseExists == null) {
        throw Exception('Course ID $selectedCourseId does not exist or you do not have permission');
      }

      final response = await Supabase.instance.client.from('attendance').insert({
        'course_id': selectedCourseId,
        'student_name': name,
        'attendance': attendance,
      }).select().single();
      print('StudentAttendancePage: Student inserted successfully: $response');
      await _loadStudents(selectedCourseId!);
      _showSnackBar('Student added successfully', Colors.green);
    } catch (e) {
      String errorMessage = 'Error adding student: $e';
      if (e.toString().contains('permission denied')) {
        errorMessage = 'Permission denied: Ensure you are authorized to add students for this course';
      } else if (e.toString().contains('foreign key violation')) {
        errorMessage = 'Invalid course ID: Please select a valid course';
      }
      _showSnackBar(errorMessage, Colors.redAccent);
      print('StudentAttendancePage: Error adding student: $e');
    }
  }

  Future<void> _saveData() async {
    if (selectedCourseId == null) {
      _showSnackBar('Please select or add a course first', Colors.redAccent);
      print('StudentAttendancePage: No course selected for saving data');
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });
      print('StudentAttendancePage: Saving all student data for course: $selectedCourseId');
      // Validate course_id exists
      final courseExists = await Supabase.instance.client
          .from('courses')
          .select('id')
          .eq('id', selectedCourseId!)
          .eq('teacher_id', Supabase.instance.client.auth.currentUser!.id)
          .maybeSingle();
      if (courseExists == null) {
        throw Exception('Course ID $selectedCourseId does not exist or you do not have permission');
      }

      // Delete existing records for the course
      await Supabase.instance.client
          .from('attendance')
          .delete()
          .eq('course_id', selectedCourseId!);
      // Insert all students as new records
      for (var student in students) {
        await Supabase.instance.client.from('attendance').insert({
          'course_id': selectedCourseId,
          'student_name': student['student_name'],
          'attendance': student['attendance'],
        });
      }
      await _loadStudents(selectedCourseId!);
      _showSnackBar('Data saved successfully', Colors.green);
      print('StudentAttendancePage: Data saved successfully');
    } catch (e) {
      String errorMessage = 'Error saving data: $e';
      if (e.toString().contains('permission denied')) {
        errorMessage = 'Permission denied: Ensure you are authorized to save data for this course';
      } else if (e.toString().contains('foreign key violation')) {
        errorMessage = 'Invalid course ID: Please select a valid course';
      }
      _showSnackBar(errorMessage, Colors.redAccent);
      print('StudentAttendancePage: Error saving data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showAddStudentDialog() {
    final nameController = TextEditingController();
    final attendanceController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.9),
        title: const Text(
          'Add New Student',
          style: TextStyle(color: Colors.blue),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Student Name',
                labelStyle: TextStyle(color: Colors.blue),
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: attendanceController,
              decoration: const InputDecoration(
                labelText: 'Attendance (%)',
                labelStyle: TextStyle(color: Colors.blue),
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(color: Colors.black87),
              keyboardType: TextInputType.number,
            ),
          ],
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
              final newName = nameController.text.trim();
              final attendanceText = attendanceController.text.trim();
              if (newName.isEmpty) {
                _showSnackBar('Please enter a valid student name', Colors.redAccent);
                print('AddStudentDialog: Validation failed - Empty name');
                return;
              }
              if (int.tryParse(attendanceText) == null) {
                _showSnackBar('Please enter a valid attendance percentage', Colors.redAccent);
                print('AddStudentDialog: Validation failed - Invalid attendance');
                return;
              }
              final attendance = int.parse(attendanceText).clamp(0, 100);
              await _addStudent(newName, attendance);
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

  void _showAddCourseDialog() {
    final courseNameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.9),
        title: const Text(
          'Add New Course',
          style: TextStyle(color: Colors.blue),
        ),
        content: TextField(
          controller: courseNameController,
          decoration: const InputDecoration(
            labelText: 'Course ID (e.g., CSE 2201)',
            labelStyle: TextStyle(color: Colors.blue),
            border: OutlineInputBorder(),
          ),
          style: const TextStyle(color: Colors.black87),
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
              final newCourseName = courseNameController.text.trim();
              if (newCourseName.isEmpty) {
                _showSnackBar('Please enter a valid course ID', Colors.redAccent);
                print('AddCourseDialog: Validation failed - Empty course ID');
                return;
              }
              await _addCourse(newCourseName);
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

  Color getAttendanceColor(int percentage) {
    if (percentage >= 75) return Colors.green;
    if (percentage >= 50) return Colors.orange;
    return Colors.red;
  }

  @override
  void dispose() {
    _attendanceSubscription?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('StudentAttendancePage: Building UI with ${students.length} students for course: $selectedCourseName');
    return Scaffold(
      key: _scaffoldMessengerKey,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Class Attendance - $selectedCourseName',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue.withOpacity(0.9),
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.white),
            onPressed: _showAddCourseDialog,
            tooltip: 'Add Course',
          ),
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              print('StudentAttendancePage: Navigating back');
              Navigator.pop(context);
            },
            tooltip: 'Back',
          ),
        ],
      ),
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
                  Text(
                    'Class Attendance - $selectedCourseName',
                    style: const TextStyle(
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
                  const SizedBox(height: 20),
                  DropdownButton<String>(
                    value: selectedCourseId,
                    hint: const Text(
                      'Select a course',
                      style: TextStyle(color: Colors.white70),
                    ),
                    dropdownColor: Colors.blue.withOpacity(0.9),
                    items: courses.map((course) {
                      return DropdownMenuItem<String>(
                        value: course['id'],
                        child: Text(
                          course['course_name'],
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedCourseId = value;
                          selectedCourseName = courses
                              .firstWhere((course) => course['id'] == value)['course_name'];
                          _loadStudents(value);
                        });
                      }
                    },
                  ).animate().fadeIn(duration: 600.ms),
                  const SizedBox(height: 20),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator(color: Colors.white))
                  else if (selectedCourseId == null)
                    const Text(
                      'Please select or add a course',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ).animate().fadeIn(duration: 600.ms)
                  else
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ListView.builder(
                          key: ValueKey(students.length),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: students.length,
                          itemBuilder: (context, index) {
                            final student = students[index];
                            final name = student['student_name'] as String;
                            final attendance = student['attendance'] as int;
                            print('StudentAttendancePage: Rendering student: ${index + 1} - $name - $attendance%');
                            return ListTile(
                              leading: Text('${index + 1}',
                                  style: const TextStyle(fontSize: 18, color: Colors.black87)),
                              title: Text(
                                name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$attendance%',
                                    style: TextStyle(
                                        fontSize: 16, color: getAttendanceColor(attendance)),
                                  ),
                                  const SizedBox(width: 10),
                                  IconButton(
                                    icon: const Icon(Icons.remove, color: Colors.black54, size: 20),
                                    onPressed: () => _updateAttendance(index, false),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add, color: Colors.black54, size: 20),
                                    onPressed: () => _updateAttendance(index, true),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.5, end: 0),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
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
                          onPressed: _saveData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Save',
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
                      const SizedBox(width: 20),
                      Container(
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
                            print('StudentAttendancePage: Navigating back');
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
                      ).animate().fadeIn(duration: 800.ms).scaleXY(
                        begin: 0.9,
                        end: 1.0,
                        curve: Curves.bounceOut,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddStudentDialog,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Add Student',
      ).animate().fadeIn(duration: 800.ms),
    );
  }
}