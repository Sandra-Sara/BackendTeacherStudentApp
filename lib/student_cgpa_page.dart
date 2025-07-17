
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class StudentCGPAPage extends StatefulWidget {
const StudentCGPAPage({super.key});

@override
State<StudentCGPAPage> createState() => _StudentCGPAPageState();
}

class _StudentCGPAPageState extends State<StudentCGPAPage> {
List<Map<String, dynamic>> grades = [];
final TextEditingController studentNameController = TextEditingController();
final TextEditingController rollNoController = TextEditingController();
final TextEditingController subjectController = TextEditingController();
final TextEditingController gradeController = TextEditingController();
final TextEditingController creditController = TextEditingController();
String? currentStudentName;
String? currentRollNo;
bool _isLoading = false;
bool _isSubmitting = false; // Prevent double submissions
final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
RealtimeChannel? _gradesSubscription;

@override
void initState() {
super.initState();
_checkUser();
}

Future<void> _checkUser() async {
final user = Supabase.instance.client.auth.currentUser;
if (user == null) {
_showSnackBar('Please log in to view grades', Colors.redAccent);
Navigator.pushReplacementNamed(context, '/login');
}
}

Future<void> _loadGrades(String studentName, String rollNo) async {
print("######################################");
setState(() {
_isLoading = true;
});
try {
print('StudentCGPAPage: Loading grades for $studentName ($rollNo)');
final user = Supabase.instance.client.auth.currentUser;
if (user == null) throw Exception('User not authenticated');

final response = await Supabase.instance.client
    .from('grades')
    .select()
    .eq('user_id', user.id)
    .eq('student_name', studentName)
    .eq('roll_no', rollNo);

setState(() {
grades = List<Map<String, dynamic>>.from(response);
currentStudentName = studentName;
currentRollNo = rollNo;
});

print('StudentCGPAPage: Loaded ${grades.length} grades for $studentName ($rollNo): $grades');

// Subscribe to real-time changes
_gradesSubscription?.unsubscribe();
_gradesSubscription = Supabase.instance.client
    .channel('grades_channel_${user.id}_${studentName}_${rollNo}')
    .onPostgresChanges(
event: PostgresChangeEvent.all,
schema: 'public',
table: 'grades',
filter: PostgresChangeFilter(
type: PostgresChangeFilterType.eq,
column: 'user_id',
value: user.id,
),
callback: (payload) {
print('StudentCGPAPage: Real-time update received: $payload');
if (payload.eventType == 'INSERT' || payload.eventType == 'UPDATE' || payload.eventType == 'DELETE') {
_loadGrades(studentName, rollNo);
}
},
)
    .subscribe();
} catch (e) {
String errorMessage = 'Error loading grades: $e';
if (e is PostgrestException) {
errorMessage = 'Error loading grades: ${e.message} (code: ${e.code}, details: ${e.details})';
}
_showSnackBar(errorMessage, Colors.redAccent);
print('StudentCGPAPage: $errorMessage');
} finally {
setState(() {
_isLoading = false;
});
}
}

Future<void> _addGrade(String studentRefId, String subject, String grade, double credit) async {
if (currentStudentName == null || currentRollNo == null) {
_showSnackBar('Cannot add grade: Missing student information', Colors.redAccent);
print('StudentCGPAPage: Cannot add grade - missing student_name or roll_no');
return;
}

if (_isSubmitting) return;
setState(() {
_isLoading = true;
_isSubmitting = true;
});

try {
print('StudentCGPAPage: Adding grade for $currentStudentName ($currentRollNo): $subject, $grade, $credit');
final user = Supabase.instance.client.auth.currentUser;
if (user == null) throw Exception('User not authenticated');

final existingGrade = await Supabase.instance.client
    .from('grades')
    .select()
    .eq('user_id', user.id)
    .eq('student_name', currentStudentName!)
    .eq('roll_no', currentRollNo!)
    .eq('subject', subject.toLowerCase())
    .maybeSingle();

if (existingGrade != null) {
_showSnackBar('Subject already exists for this student', Colors.redAccent);
print('StudentCGPAPage: Subject $subject already exists for $currentStudentName ($currentRollNo)');
return;
}

await Supabase.instance.client.from('grades').insert({
'student_ref_id': studentRefId, // Non-unique ID
'user_id': user.id,
'student_name': currentStudentName,
'roll_no': currentRollNo,
'subject': subject.toLowerCase(),
'grade': grade.toUpperCase(),
'credit': credit,
'created_at': DateTime.now().toIso8601String(),
'updated_at': DateTime.now().toIso8601String(),
});

await _loadGrades(currentStudentName!, currentRollNo!);
_showSnackBar('Grade added successfully for $currentStudentName ($currentRollNo)', Colors.green);
print('StudentCGPAPage: Grade added successfully for $currentStudentName ($currentRollNo)');
} catch (e) {
String errorMessage = 'Error adding grade: $e';
if (e is PostgrestException) {
errorMessage = 'Error adding grade: ${e.message} (code: ${e.code}, details: ${e.details})';
}
_showSnackBar(errorMessage, Colors.redAccent);
print('StudentCGPAPage: $errorMessage');
} finally {
setState(() {
_isLoading = false;
_isSubmitting = false;
});
}
}

Future<void> _updateGrade(int gradeId, String studentRefId, String subject, String grade, double credit) async {
if (_isSubmitting) return;
setState(() {
_isLoading = true;
_isSubmitting = true;
});

try {
print('StudentCGPAPage: Updating grade for $currentStudentName ($currentRollNo), subject: $subject');
await Supabase.instance.client
    .from('grades')
    .update({
'student_ref_id': studentRefId,
'subject': subject.toLowerCase(),
'grade': grade.toUpperCase(),
'credit': credit,
'updated_at': DateTime.now().toIso8601String(),
})
    .eq('grade_id', gradeId);
await _loadGrades(currentStudentName!, currentRollNo!);

_showSnackBar('Grade updated successfully', Colors.green);
print('StudentCGPAPage: Grade updated successfully for $currentStudentName ($currentRollNo)');
} catch (e) {
String errorMessage = 'Error updating grade: $e';
if (e is PostgrestException) {
errorMessage = 'Error updating grade: ${e.message} (code: ${e.code}, details: ${e.details})';
}
_showSnackBar(errorMessage, Colors.redAccent);
print('StudentCGPAPage: $errorMessage');
} finally {
setState(() {
_isLoading = false;
_isSubmitting = false;
});
}
}

Future<void> _deleteGrade(int gradeId) async {
if (_isSubmitting) return;
setState(() {
_isLoading = true;
_isSubmitting = true;
});

try {
print('StudentCGPAPage: Deleting grade with grade_id: $gradeId');
await Supabase.instance.client.from('grades').delete().eq('grade_id', gradeId);

await _loadGrades(currentStudentName!, currentRollNo!);
_showSnackBar('Grade deleted successfully', Colors.green);
print('StudentCGPAPage: Grade deleted successfully for $currentStudentName ($currentRollNo)');
} catch (e) {
String errorMessage = 'Error deleting grade: $e';
if (e is PostgrestException) {
errorMessage = 'Error deleting grade: ${e.message} (code: ${e.code}, details: ${e.details})';
}
_showSnackBar(errorMessage, Colors.redAccent);
print('StudentCGPAPage: $errorMessage');
} finally {
setState(() {
_isLoading = false;
_isSubmitting = false;
});
}
}

Future<void> _clearGrades(String studentName, String rollNo) async {
if (_isSubmitting) return;
setState(() {
_isLoading = true;
_isSubmitting = true;
});
try {
print('StudentCGPAPage: Clearing grades for $studentName ($rollNo)');
final user = Supabase.instance.client.auth.currentUser;
if (user == null) throw Exception('User not authenticated');

await Supabase.instance.client
    .from('grades')
    .delete()
    .eq('id', user.id)
    .eq('student_name', studentName)
    .eq('roll_no', rollNo);

setState(() {
grades = [];
currentStudentName = studentName;
currentRollNo = rollNo;
});
_showSnackBar('All grades cleared for $studentName ($rollNo)', Colors.green);
print('StudentCGPAPage: Grades cleared for $studentName ($rollNo)');
} catch (e) {
String errorMessage = 'Error clearing grades: $e';
if (e is PostgrestException) {
errorMessage = 'Error clearing grades: ${e.message} (code: ${e.code}, details: ${e.details})';
}
_showSnackBar(errorMessage, Colors.redAccent);
print('StudentCGPAPage: $errorMessage');
} finally {
setState(() {
_isLoading = false;
_isSubmitting = false;
});
}
}

double calculateCGPA() {
if (grades.isEmpty) return 0.0;
double totalPoints = 0.0;
double totalCredits = 0.0;
for (var g in grades) {
double gradePoint = _gradeToPoint(g['grade']);
if (gradePoint == 0.0) continue;
double credit = g['credit']?.toDouble() ?? 0.0;
if (credit <= 0) continue;
totalPoints += gradePoint * credit;
totalCredits += credit;
}
return totalCredits > 0 ? totalPoints / totalCredits : 0.0;
}

double _gradeToPoint(String grade) {
switch (grade.toUpperCase()) {
case 'A+':
return 4.0;
case 'A':
return 3.75;
case 'A-':
return 3.5;
case 'B+':
return 3.25;
case 'B':
return 3.0;
case 'C':
return 2.5;
case 'D':
return 2.0;
case 'F':
return 0.0;
default:
return 0.0;
}
}

bool _isValidGrade(String grade) {
final validGrades = ['A+', 'A', 'A-', 'B+', 'B', 'C', 'D', 'F'];
return validGrades.contains(grade.toUpperCase());
}

void _showSnackBar(String message, Color backgroundColor) {
_scaffoldMessengerKey.currentState?.showSnackBar(
SnackBar(
content: Text(message),
backgroundColor: backgroundColor,
),
);
}

void _showInputDialog({Map<String, dynamic>? grade}) {
if (currentStudentName == null || currentRollNo == null) {
_showSnackBar('Please enter and load a student first', Colors.redAccent);
print('StudentCGPAPage: Please enter and load a student first');
return;
}

subjectController.text = grade?['subject'] ?? '';
gradeController.text = grade?['grade'] ?? '';
creditController.text = grade?['credit']?.toString() ?? '';

showDialog(
context: context,
builder: (context) {
return AlertDialog(
backgroundColor: Colors.white.withOpacity(0.9),
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
title: Text(
grade == null
? 'Enter Grade for $currentStudentName ($currentRollNo)'
    : 'Edit Grade for $currentStudentName ($currentRollNo)',
style: const TextStyle(color: Colors.black87),
),
content: SingleChildScrollView(
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
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
const SizedBox(height: 16),
TextField(
controller: gradeController,
decoration: InputDecoration(
labelText: 'Grade (e.g., A+, A, B+, etc.)',
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
controller: creditController,
decoration: InputDecoration(
labelText: 'Credits (e.g., 3.0)',
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
keyboardType: const TextInputType.numberWithOptions(decimal: true),
),
],
),
),
actions: [
TextButton(
onPressed: () => Navigator.pop(context),
child: const Text('Cancel', style: TextStyle(color: Colors.redAccent)),
),
TextButton(
onPressed: _isLoading || _isSubmitting
? null
    : () async {
if (_isSubmitting) return;
setState(() {
_isSubmitting = true;
});
final subject = subjectController.text.trim();
final gradeText = gradeController.text.trim();
final creditText = creditController.text.trim();
double? credit = double.tryParse(creditText);

if (subject.isEmpty) {
_showSnackBar('Please enter a subject', Colors.redAccent);
print('StudentCGPAPage: Validation failed - Empty subject');
setState(() {
_isSubmitting = false;
});
return;
}
if (gradeText.isEmpty) {
_showSnackBar('Please enter a grade', Colors.redAccent);
print('StudentCGPAPage: Validation failed - Empty grade');
setState(() {
_isSubmitting = false;
});
return;
}
if (!_isValidGrade(gradeText)) {
_showSnackBar('Invalid grade. Use A+, A, A-, B+, B, C, D, or F', Colors.redAccent);
print('StudentCGPAPage: Validation failed - Invalid grade: $gradeText');
setState(() {
_isSubmitting = false;
});
return;
}
if (credit == null || credit <= 0) {
_showSnackBar('Credits must be a positive number', Colors.redAccent);
print('StudentCGPAPage: Validation failed - Invalid credits: $creditText');
setState(() {
_isSubmitting = false;
});
return;
}

// Use roll_no as student_ref_id for simplicity, or generate a custom ID
final studentRefId = currentRollNo ?? const Uuid().v4();

if (grade == null) {
await _addGrade(studentRefId, subject, gradeText, credit);
} else {
await _updateGrade(grade['grade_id'], studentRefId, subject, gradeText, credit);
}
if (mounted) Navigator.pop(context);
},
child: _isLoading || _isSubmitting
? const CircularProgressIndicator(color: Colors.blue)
    : Text(grade == null ? 'Add' : 'Update', style: const TextStyle(color: Colors.blue)),
),
],
);
},
);
}

@override
void dispose() {
studentNameController.dispose();
rollNoController.dispose();
subjectController.dispose();
gradeController.dispose();
creditController.dispose();
_gradesSubscription?.unsubscribe();
super.dispose();
}

@override
Widget build(BuildContext context) {
print('StudentCGPAPage: Building UI with ${grades.length} grades for ${currentStudentName ?? "no student"} (${currentRollNo ?? "no roll"})');
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
).animate().fadeIn(duration: 800.ms).scaleXY(begin: 0.9, end: 1.0),
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
currentStudentName != null && currentRollNo != null
? 'CGPA for $currentStudentName ($currentRollNo)'
    : 'Student CGPA',
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
TextField(
controller: studentNameController,
decoration: InputDecoration(
labelText: 'Student Name',
filled: true,
fillColor: Colors.white24,
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: BorderSide.none,
),
labelStyle: const TextStyle(color: Colors.white70),
hintStyle: const TextStyle(color: Colors.white54),
),
style: const TextStyle(color: Colors.white),
).animate().fadeIn(duration: 600.ms).slideX(begin: -0.5, end: 0),
const SizedBox(height: 16),
TextField(
controller: rollNoController,
decoration: InputDecoration(
labelText: 'Roll Number',
filled: true,
fillColor: Colors.white24,
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: BorderSide.none,
),
labelStyle: const TextStyle(color: Colors.white70),
hintStyle: const TextStyle(color: Colors.white54),
),
style: const TextStyle(color: Colors.white),
).animate().fadeIn(duration: 600.ms).slideX(begin: -0.5, end: 0),
const SizedBox(height: 16),
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
final studentName = studentNameController.text.trim();
final rollNo = rollNoController.text.trim();
if (studentName.isEmpty || rollNo.isEmpty) {
_showSnackBar('Please enter both student name and roll number', Colors.redAccent);
print('StudentCGPAPage: Validation failed - Empty name or roll number');
return;
}
_loadGrades(studentName, rollNo);
},
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
'Load Grades',
style: TextStyle(
color: Colors.white,
fontSize: 18,
fontWeight: FontWeight.bold,
),
),
),
).animate().fadeIn(duration: 800.ms).scaleXY(begin: 0.9, end: 1.0),
const SizedBox(height: 30),
Card(
key: ValueKey(grades.length), // Force rebuild when grades change
elevation: 4,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(12),
),
color: Colors.white.withOpacity(0.1),
child: Padding(
padding: const EdgeInsets.all(16.0),
child: Column(
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
onPressed: _isLoading || _isSubmitting ? null : _showInputDialog,
style: ElevatedButton.styleFrom(
backgroundColor: Colors.transparent,
shadowColor: Colors.transparent,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(12),
),
),
child: const Text(
'Add Grade',
style: TextStyle(
color: Colors.white,
fontSize: 18,
fontWeight: FontWeight.bold,
),
),
),
).animate().fadeIn(duration: 800.ms).scaleXY(begin: 0.9, end: 1.0),
const SizedBox(height: 16),
Container(
width: double.infinity,
height: 50,
decoration: BoxDecoration(
gradient: const LinearGradient(
colors: [Colors.redAccent, Colors.red],
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
onPressed: _isLoading || _isSubmitting || currentStudentName == null || currentRollNo == null
? null
    : () => _clearGrades(currentStudentName!, currentRollNo!),
style: ElevatedButton.styleFrom(
backgroundColor: Colors.transparent,
shadowColor: Colors.transparent,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(12),
),
),
child: const Text(
'Clear All Grades',
style: TextStyle(
color: Colors.white,
fontSize: 18,
fontWeight: FontWeight.bold,
),
),
),
).animate().fadeIn(duration: 800.ms).scaleXY(begin: 0.9, end: 1.0),
const SizedBox(height: 20),
if (_isLoading || _isSubmitting)
const Center(child: CircularProgressIndicator(color: Colors.white))
else if (grades.isEmpty)
const Text(
'No grades available',
style: TextStyle(
fontSize: 16,
color: Colors.white70,
),
).animate().fadeIn(duration: 600.ms)
else
ListView.builder(
key: ValueKey(grades.length),
shrinkWrap: true,
physics: const NeverScrollableScrollPhysics(),
itemCount: grades.length,
itemBuilder: (context, index) {
final g = grades[index];
print('StudentCGPAPage: Rendering grade $index: ${g['subject']} - ${g['grade']} - ${g['credit']}');
return ListTile(
title: Text(
g['subject'],
style: const TextStyle(color: Colors.white),
),
subtitle: Text(
'Grade: ${g['grade']} | Credits: ${g['credit']} | Student ID: ${g['student_ref_id']}',
style: const TextStyle(color: Colors.white70),
),
trailing: Row(
mainAxisSize: MainAxisSize.min,
children: [
IconButton(
icon: const Icon(Icons.edit, color: Colors.blue),
onPressed: () => _showInputDialog(grade: g),
),
IconButton(
icon: const Icon(Icons.delete, color: Colors.redAccent),
onPressed: () => _deleteGrade(g['grade_id']),
),
],
),
);
},
),
const SizedBox(height: 20),
Text(
'CGPA: ${calculateCGPA().toStringAsFixed(2)}',
style: const TextStyle(
fontSize: 20,
fontWeight: FontWeight.bold,
color: Colors.white,
),
),
],
),
),
).animate().fadeIn(duration: 600.ms).slideY(begin: 0.5, end: 0),
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
boxShadow: [
BoxShadow(
color: Colors.black.withOpacity(0.2),
blurRadius: 8,
offset: const Offset(0, 4),
),
],
),
child: ElevatedButton(
onPressed: () => Navigator.pop(context),
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
).animate().fadeIn(duration: 800.ms).scaleXY(begin: 0.9, end: 1.0),
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
