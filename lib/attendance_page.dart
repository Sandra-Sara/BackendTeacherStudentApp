import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CourseAttendance {
final String courseId;
final String courseName;
final int? attendancePercentage;

CourseAttendance({
required this.courseId,
required this.courseName,
this.attendancePercentage,
});
}

class StudentAttendanceOverviewPage extends StatefulWidget {
const StudentAttendanceOverviewPage({super.key});

@override
State<StudentAttendanceOverviewPage> createState() =>
_StudentAttendanceOverviewPageState();
}

class _StudentAttendanceOverviewPageState
extends State<StudentAttendanceOverviewPage> {
final _supabase = Supabase.instance.client;
List<CourseAttendance>? _courseAttendanceList;
bool _isLoading = true;
String? _errorMessage;
Color _errorMessageColor = Colors.red;

@override
void initState() {
super.initState();
_fetchStudentAttendance();
}

Future<void> _fetchStudentAttendance() async {
setState(() {
_isLoading = true;
_errorMessage = null;
_errorMessageColor = Colors.red;
});

try {
// Fetch all courses
final coursesResponse = await _supabase.from('courses').select('id, course_name');
print('StudentAttendanceOverviewPage: Courses fetched: ${coursesResponse.length}');

List<CourseAttendance> attendanceList = [];

for (var courseData in coursesResponse) {
final courseId = courseData['id'] as String;
final courseName = courseData['course_name'] as String;

// Fetch all attendance records for this course
final attendanceResponse = await _supabase
    .from('attendance')
    .select('attendance')
    .eq('course_id', courseId);

int? currentAttendancePercentage;
if (attendanceResponse != null && attendanceResponse.isNotEmpty) {
// Calculate average attendance for the course
final total = attendanceResponse.fold<int>(
0,
(sum, row) => sum + (row['attendance'] as int? ?? 0),
);
currentAttendancePercentage = (total / attendanceResponse.length).round();
}

attendanceList.add(CourseAttendance(
courseId: courseId,
courseName: courseName,
attendancePercentage: currentAttendancePercentage,
));
}

setState(() {
_courseAttendanceList = attendanceList;
if (_courseAttendanceList!.isEmpty && coursesResponse.isNotEmpty) {
_errorMessage = "No attendance records found for any course yet.";
_errorMessageColor = Colors.yellow;
} else if (coursesResponse.isEmpty) {
_errorMessage = "No courses available at the moment.";
_errorMessageColor = Colors.yellow;
}
print('StudentAttendanceOverviewPage: Loaded ${_courseAttendanceList?.length ?? 0} courses with attendance');
});
} catch (e, stackTrace) {
print('StudentAttendanceOverviewPage: Error fetching attendance: $e\nStackTrace: $stackTrace');
setState(() {
_errorMessage = 'Failed to load attendance: $e';
if (e is PostgrestException) {
_errorMessage = 'Failed to load attendance: ${e.message}';
}
_errorMessageColor = Colors.red;
});
} finally {
setState(() {
_isLoading = false;
});
}
}

@override
Widget build(BuildContext context) {
print('StudentAttendanceOverviewPage: Building UI with ${_courseAttendanceList?.length ?? 0} courses');
return Scaffold(
appBar: AppBar(
automaticallyImplyLeading: false,
title: const Text('Attendance'),
backgroundColor: Colors.blue,
),
body: Padding(
padding: const EdgeInsets.all(16.0),
child: SingleChildScrollView(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Image.asset(
'assets/dulogo.png',
height: 150,
width: 300,
errorBuilder: (context, error, stackTrace) => const Icon(
Icons.error,
size: 100,
color: Colors.grey,
),
),
const SizedBox(height: 20),
const Text(
'University Of Dhaka',
style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
),
const SizedBox(height: 20),
const Text(
'Attendance',
style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.grey),
),
const SizedBox(height: 30),
if (_errorMessage != null)
Text(
_errorMessage!,
style: TextStyle(color: _errorMessageColor, fontSize: 16),
),
const SizedBox(height: 10),
_isLoading
? const Center(child: CircularProgressIndicator(color: Colors.blue))
    : _courseAttendanceList == null || _courseAttendanceList!.isEmpty
? const Text(
'No courses or attendance data available',
style: TextStyle(fontSize: 16, color: Colors.grey),
)
    : Card(
elevation: 4,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(12),
),
child: Padding(
padding: const EdgeInsets.all(16.0),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: _courseAttendanceList!.map((data) {
return AttendanceRow(
subject: data.courseName,
courseId: data.courseId,
percentage: data.attendancePercentage?.toString(),
);
}).toList(),
),
),
),
const SizedBox(height: 30),
Center(
child: ElevatedButton(
onPressed: () {
if (_errorMessage != null) {
_fetchStudentAttendance();
} else {
Navigator.pop(context);
}
},
style: ElevatedButton.styleFrom(
backgroundColor: Colors.blue,
minimumSize: const Size(200, 50),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(12),
),
elevation: 5,
),
child: Text(
_errorMessage != null ? 'Retry' : 'Back',
style: const TextStyle(
color: Colors.white,
fontSize: 18,
fontWeight: FontWeight.bold,
),
),
),
),
],
),
),
),
);
}
}

class AttendanceRow extends StatelessWidget {
final String subject;
final String courseId;
final String? percentage;

const AttendanceRow({
super.key,
required this.subject,
required this.courseId,
this.percentage,
});

@override
Widget build(BuildContext context) {
final double percentageValue = double.tryParse(percentage?.replaceAll('%', '') ?? '0') ?? 0.0;
Color percentageColor = Colors.grey;
if (percentage != null) {
if (percentageValue >= 80) {
percentageColor = Colors.green;
} else if (percentageValue >= 50) {
percentageColor = Colors.orange;
} else {
percentageColor = Colors.red;
}
}

return Padding(
padding: const EdgeInsets.symmetric(vertical: 8.0),
child: Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Text(
subject,
style: const TextStyle(
fontSize: 16,
fontWeight: FontWeight.bold,
color: Colors.blue,
),
),
Row(
children: [
if (percentage != null)
Text(
'$percentage%',
style: TextStyle(
fontSize: 16,
fontWeight: FontWeight.bold,
color: percentageColor,
),
),
const SizedBox(width: 10),
ElevatedButton(
onPressed: () {
Navigator.push(
context,
MaterialPageRoute(
builder: (context) => ClassAttendancePage(courseId: courseId),
),
);
},
style: ElevatedButton.styleFrom(
backgroundColor: Colors.blue,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(8),
),
elevation: 2,
),
child: const Text(
'View',
style: TextStyle(
color: Colors.white,
fontSize: 14,
fontWeight: FontWeight.bold,
),
),
),
],
),
],
),
);
}
}

class ClassAttendancePage extends StatefulWidget {
final String courseId;

const ClassAttendancePage({super.key, required this.courseId});

@override
State<ClassAttendancePage> createState() => _ClassAttendancePageState();
}

class _ClassAttendancePageState extends State<ClassAttendancePage> {
final _supabase = Supabase.instance.client;
List<Map<String, dynamic>>? _classAttendanceList;
bool _isLoading = true;
String? _errorMessage;
String? _courseName;

@override
void initState() {
super.initState();
_fetchClassAttendance();
}

Future<void> _fetchClassAttendance() async {
setState(() {
_isLoading = true;
_errorMessage = null;
});

try {
// Fetch course name
final courseResponse = await _supabase
    .from('courses')
    .select('course_name')
    .eq('id', widget.courseId)
    .single();
_courseName = courseResponse['course_name'] as String? ?? 'Unknown Course';

// Fetch attendance for all students in the course
final attendanceResponse = await _supabase
    .from('attendance')
    .select('student_name, attendance')
    .eq('course_id', widget.courseId);

List<Map<String, dynamic>> attendanceList = [];

for (var attendance in attendanceResponse) {
final name = attendance['student_name'] as String? ?? 'Unknown Student';
final attendancePercentage = attendance['attendance'] as int?;
attendanceList.add({
'name': name,
'roll': '', // No roll available in your schema
'percentage': attendancePercentage?.toString(),
});
}

setState(() {
_classAttendanceList = attendanceList;
if (_classAttendanceList!.isEmpty) {
_errorMessage = 'No attendance records found for this course.';
}
print('ClassAttendancePage: Loaded ${_classAttendanceList?.length ?? 0} attendance records for course: ${widget.courseId}');
});
} catch (e, stackTrace) {
print('ClassAttendancePage: Error fetching class attendance: $e\nStackTrace: $stackTrace');
setState(() {
_errorMessage = 'Failed to load attendance: $e';
if (e is PostgrestException) {
_errorMessage = 'Failed to load attendance: ${e.message}';
}
});
} finally {
setState(() {
_isLoading = false;
});
}
}

@override
Widget build(BuildContext context) {
print('ClassAttendancePage: Building UI with ${_classAttendanceList?.length ?? 0} records');
return Scaffold(
appBar: AppBar(
automaticallyImplyLeading: false,
title: Text('Class Attendance - $_courseName'),
backgroundColor: Colors.blue,
),
body: Padding(
padding: const EdgeInsets.all(16.0),
child: SingleChildScrollView(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Image.asset(
'assets/dulogo.png',
height: 150,
width: 300,
errorBuilder: (context, error, stackTrace) => const Icon(
Icons.error,
size: 100,
color: Colors.grey,
),
),
const SizedBox(height: 20),
const Text(
'University Of Dhaka',
style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
),
const SizedBox(height: 20),
Text(
'Class Attendance - $_courseName',
style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.grey),
),
const SizedBox(height: 30),
if (_errorMessage != null)
Text(
_errorMessage!,
style: const TextStyle(color: Colors.red, fontSize: 16),
),
const SizedBox(height: 10),
_isLoading
? const Center(child: CircularProgressIndicator(color: Colors.blue))
    : _classAttendanceList == null || _classAttendanceList!.isEmpty
? const Text(
'No attendance data available',
style: TextStyle(fontSize: 16, color: Colors.grey),
)
    : Card(
elevation: 4,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(12),
),
child: Padding(
padding: const EdgeInsets.all(16.0),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: _classAttendanceList!.map((student) {
return ClassAttendanceRow(
name: student['name']!,
roll: student['roll']!,
percentage: student['percentage'],
);
}).toList(),
),
),
),
const SizedBox(height: 30),
Center(
child: ElevatedButton(
onPressed: () {
if (_errorMessage != null) {
_fetchClassAttendance();
} else {
Navigator.pop(context);
}
},
style: ElevatedButton.styleFrom(
backgroundColor: Colors.blue,
minimumSize: const Size(200, 50),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(12),
),
elevation: 5,
),
child: Text(
_errorMessage != null ? 'Retry' : 'Back',
style: const TextStyle(
color: Colors.white,
fontSize: 18,
fontWeight: FontWeight.bold,
),
),
),
),
],
),
),
),
);
}
}

class ClassAttendanceRow extends StatelessWidget {
final String name;
final String roll;
final String? percentage;

const ClassAttendanceRow({
super.key,
required this.name,
required this.roll,
this.percentage,
});

@override
Widget build(BuildContext context) {
final double percentageValue = double.tryParse(percentage?.replaceAll('%', '') ?? '0') ?? 0.0;
Color percentageColor = Colors.grey;
if (percentage != null) {
if (percentageValue >= 80) {
percentageColor = Colors.green;
} else if (percentageValue >= 50) {
percentageColor = Colors.orange;
} else {
percentageColor = Colors.red;
}
}

return Padding(
padding: const EdgeInsets.symmetric(vertical: 8.0),
child: Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Expanded(
flex: 2,
child: Text(
name,
style: const TextStyle(
fontSize: 16,
fontWeight: FontWeight.bold,
color: Colors.blue,
),
overflow: TextOverflow.ellipsis,
),
),
Expanded(
flex: 1,
child: Text(
roll,
style: const TextStyle(fontSize: 16, color: Colors.black87),
textAlign: TextAlign.center,
),
),
Expanded(
flex: 1,
child: Text(
percentage ?? 'N/A',
style: TextStyle(
fontSize: 16,
color: percentageColor,
fontWeight: FontWeight.bold,
),
textAlign: TextAlign.right,
),
),
],
),
);
}
}
