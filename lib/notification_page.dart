
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class NotificationPage extends StatefulWidget {
const NotificationPage({super.key});

@override
State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
Future<List<Map<String, String>>>? _notificationsFuture;
String _errorMessage = '';
Color _errorMessageColor = Colors.red;
bool _isTeacher = false;
final TextEditingController _titleController = TextEditingController();
final TextEditingController _messageController = TextEditingController();

@override
void initState() {
super.initState();
_init();
}

Future<void> _init() async {
await _checkUserRole();
setState(() {
_notificationsFuture = _loadNotifications();
});
}

Future<void> _checkUserRole() async {
final user = Supabase.instance.client.auth.currentUser;
if (user == null) return;
try {
final response = await Supabase.instance.client
    .from('profile')
    .select('role')
    .eq('id', user.id)
    .single();
setState(() {
_isTeacher = response['role'] == 'teacher';
});
print('NotificationPage: User role: ${response['role']}');
} catch (e) {
print('NotificationPage: Error checking role: $e');
setState(() {
_errorMessage = 'Error checking user role: $e';
_errorMessageColor = Colors.red;
});
}
}

Future<List<Map<String, String>>> _loadNotifications() async {
final user = Supabase.instance.client.auth.currentUser;
if (user == null) {
setState(() {
_errorMessage = 'Please log in to view announcements';
_errorMessageColor = Colors.red;
});
print('NotificationPage: User not authenticated');
return [];
}
try {
print('NotificationPage: Loading announcements for user ID: ${user.id}');
final response = await Supabase.instance.client
    .from('announcements')
    .select()
    .order('created_at', ascending: false);
final notifications = (response as List<dynamic>).map((notification) => {
'date': DateFormat('dd/MM/yyyy').format(DateTime.parse(notification['created_at'])),
'title': (notification['title'] ?? 'Untitled').toString(),
'message': (notification['message'] ?? '').toString(),
'file_path': (notification['file_path'] ?? '').toString(),
}).toList();
print('NotificationPage: Loaded ${notifications.length} announcements');
setState(() {
if (notifications.isEmpty) {
_errorMessage = 'No announcements found';
_errorMessageColor = Colors.yellow;
} else {
_errorMessage = 'Announcements loaded successfully';
_errorMessageColor = Colors.green;
}
});
return notifications;
} catch (e) {
String errorMessage = 'Error loading announcements: $e';
if (e is PostgrestException) {
errorMessage = 'Error loading announcements: ${e.message} (code: ${e.code})';
}
setState(() {
_errorMessage = errorMessage;
_errorMessageColor = Colors.red;
});
print('NotificationPage: $errorMessage');
return [];
}
}

Future<void> _addAnnouncement({PlatformFile? file}) async {
final user = Supabase.instance.client.auth.currentUser;
if (user == null) {
setState(() {
_errorMessage = 'Please log in to add announcements';
_errorMessageColor = Colors.red;
});
print('NotificationPage: User not authenticated');
return;
}
if (!_isTeacher) {
setState(() {
_errorMessage = 'Only teachers can add announcements';
_errorMessageColor = Colors.red;
});
print('NotificationPage: User is not a teacher');
return;
}
try {
String? filePath;
if (file != null) {
final fileName = path.basename(file.name);
final uploadFileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}${path.extension(fileName)}';
print('NotificationPage: Uploading file: $uploadFileName');
final fileBytes = file.bytes!;
await Supabase.instance.client.storage.from('announcements').uploadBinary(uploadFileName, fileBytes);
filePath = uploadFileName;
print('NotificationPage: File uploaded, path: $filePath');
}

await Supabase.instance.client.from('announcements').insert({
'user_id': user.id,
'title': _titleController.text.trim(),
'message': file == null ? _messageController.text.trim() : null,
'file_path': filePath,
});
setState(() {
_errorMessage = 'Announcement added successfully';
_errorMessageColor = Colors.green;
_notificationsFuture = _loadNotifications();
_titleController.clear();
_messageController.clear();
});
print('NotificationPage: Announcement added');
} catch (e) {
String errorMessage = 'Error adding announcement: $e';
if (e is PostgrestException) {
errorMessage = 'Error adding announcement: ${e.message} (code: ${e.code})';
}
setState(() {
_errorMessage = errorMessage;
_errorMessageColor = Colors.red;
});
print('NotificationPage: $errorMessage');
}
}

void _showAddAnnouncementDialog() {
showDialog(
context: context,
builder: (context) => AlertDialog(
title: const Text('Add Announcement'),
content: Column(
mainAxisSize: MainAxisSize.min,
children: [
TextField(
controller: _titleController,
decoration: const InputDecoration(labelText: 'Title'),
),
TextField(
controller: _messageController,
decoration: const InputDecoration(labelText: 'Message (optional for files)'),
),
const SizedBox(height: 10),
ElevatedButton(
onPressed: () async {
Navigator.pop(context);
final result = await FilePicker.platform.pickFiles(
type: FileType.custom,
allowedExtensions: ['pdf', 'doc', 'docx'],
);
if (result != null && _titleController.text.trim().isNotEmpty) {
final file = result.files.single;
await _addAnnouncement(file: file);
} else {
setState(() {
_errorMessage = 'Title is required and a file must be selected';
_errorMessageColor = Colors.red;
});
}
},
child: const Text('Upload File (PDF/DOC)'),
),
ElevatedButton(
onPressed: () {
if (_titleController.text.trim().isEmpty || _messageController.text.trim().isEmpty) {
setState(() {
_errorMessage = 'Title and message are required for text announcements';
_errorMessageColor = Colors.red;
});
return;
}
Navigator.pop(context);
_addAnnouncement();
},
child: const Text('Add Text Announcement'),
),
],
),
actions: [
TextButton(
onPressed: () => Navigator.pop(context),
child: const Text('Cancel'),
),
],
),
);
}

@override
void dispose() {
_titleController.dispose();
_messageController.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
automaticallyImplyLeading: false,
title: const Text(
'Notifications',
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
'Notifications',
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
if (_isTeacher)
Center(
child: ElevatedButton(
onPressed: _showAddAnnouncementDialog,
style: ElevatedButton.styleFrom(
backgroundColor: Colors.green,
minimumSize: const Size(200, 50),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(12),
),
elevation: 5,
),
child: const Text(
'Add Announcement',
style: TextStyle(
color: Colors.white,
fontSize: 18,
fontWeight: FontWeight.bold,
),
),
),
).animate().fadeIn(duration: 800.ms),
const SizedBox(height: 20),
FutureBuilder<List<Map<String, String>>>(
future: _notificationsFuture,
builder: (context, snapshot) {
if (snapshot.connectionState == ConnectionState.waiting) {
return const Center(
child: CircularProgressIndicator(),
).animate().fadeIn(duration: 500.ms);
}
if (snapshot.hasError) {
return Text(
_errorMessage.isNotEmpty
? _errorMessage
    : 'Failed to load announcements',
style: TextStyle(color: _errorMessageColor),
).animate().fadeIn(duration: 500.ms);
}
final notifications = snapshot.data ?? [];
if (notifications.isEmpty) {
return Text(
_errorMessage.isNotEmpty
? _errorMessage
    : 'No announcements available',
style: TextStyle(color: _errorMessageColor),
).animate().fadeIn(duration: 500.ms);
}
return ClipRRect(
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
children: notifications.map((notification) {
return NotificationRow(
date: notification['date']!,
title: notification['title']!,
message: notification['message']!,
filePath: notification['file_path']!,
);
}).toList(),
),
),
),
),
).animate().fadeIn(duration: 800.ms).scaleXY(
begin: 0.9,
end: 1.0,
curve: Curves.bounceOut,
);
},
),
const SizedBox(height: 30),
if (_errorMessage.isNotEmpty)
Text(
_errorMessage,
style: TextStyle(color: _errorMessageColor),
).animate().fadeIn(duration: 500.ms),
const SizedBox(height: 20),
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

class NotificationRow extends StatelessWidget {
final String date;
final String title;
final String message;
final String filePath;

const NotificationRow({
super.key,
required this.date,
required this.title,
required this.message,
required this.filePath,
});

Future<void> _openFile(String filePath) async {
if (filePath.isNotEmpty) {
final url = Supabase.instance.client.storage.from('announcements').getPublicUrl(filePath);
print('NotificationRow: Opening URL: $url');
final uri = Uri.parse(url);
if (await canLaunchUrl(uri)) {
await launchUrl(uri, mode: LaunchMode.externalApplication);
} else {
print('NotificationRow: Could not launch $url');
}
}
}

@override
Widget build(BuildContext context) {
return Padding(
padding: const EdgeInsets.symmetric(vertical: 12.0),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
date,
style: const TextStyle(
fontSize: 14,
fontWeight: FontWeight.bold,
color: Colors.white70,
),
),
const SizedBox(height: 4),
Text(
title,
style: const TextStyle(
fontSize: 16,
fontWeight: FontWeight.bold,
color: Colors.white,
),
),
const SizedBox(height: 4),
if (message.isNotEmpty)
Text(
message,
style: const TextStyle(
fontSize: 14,
color: Colors.white70,
),
),
if (filePath.isNotEmpty) ...[
const SizedBox(height: 4),
GestureDetector(
onTap: () => _openFile(filePath),
child: Text(
'View File: ${path.basename(filePath)}',
style: const TextStyle(
fontSize: 14,
color: Colors.blue,
decoration: TextDecoration.underline,
),
),
),
],
const Divider(
height: 20,
thickness: 1,
color: Colors.white30,
),
],
),
);
}
}
