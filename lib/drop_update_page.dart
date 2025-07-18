import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'package:path/path.dart' as path;

class DropUpdatePage extends StatefulWidget {
  const DropUpdatePage({super.key});

  @override
  State<DropUpdatePage> createState() => _DropUpdatePageState();
}

class _DropUpdatePageState extends State<DropUpdatePage> {
  final TextEditingController _announcementController = TextEditingController();
  List<Map<String, dynamic>> announcements = [];
  PlatformFile? _selectedFile;
  bool _isLoading = false;
  String _errorMessage = '';
  Color _errorMessageColor = Colors.red;
  bool _isTeacher = false;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
    _loadAnnouncements();
  }

  Future<void> _checkUserRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        _errorMessage = 'Please log in to access this page';
        _errorMessageColor = Colors.red;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage), backgroundColor: _errorMessageColor),
      );
      return;
    }
    try {
      final response = await Supabase.instance.client
          .from('profile')
          .select('role')
          .eq('id', user.id)
          .single();
      setState(() {
        _isTeacher = response['role'] == 'teacher';
      });
      print('DropUpdatePage: User role: ${response['role']}');
    } catch (e) {
      print('DropUpdatePage: Error checking role: $e');
      setState(() {
        _errorMessage = 'Error checking user role: $e';
        _errorMessageColor = Colors.red;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage), backgroundColor: _errorMessageColor),
      );
    }
  }

  Future<void> _loadAnnouncements() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await Supabase.instance.client
          .from('announcements')
          .select('id, text, file_name, file_path, created_at')
          .order('created_at', ascending: false);

      setState(() {
        announcements = List<Map<String, dynamic>>.from(response).map((a) {
          return {
            'id': a['id'] ?? '',
            'text': (a['text'] ?? '').toString(),
            'fileName': (a['file_name'] ?? '').toString(),
            'filePath': (a['file_path'] ?? '').toString(),
            'date': a['created_at'] != null
                ? DateFormat('dd/MM/yyyy').format(DateTime.parse(a['created_at']))
                : '',
          };
        }).toList();
        if (announcements.isEmpty) {
          _errorMessage = 'No announcements found';
          _errorMessageColor = Colors.yellow;
        } else {
          _errorMessage = '';
          _errorMessageColor = Colors.green;
        }
      });
      print('DropUpdatePage: Loaded ${announcements.length} announcements');
    } catch (e) {
      String errorMessage = 'Error loading announcements: $e';
      if (e is PostgrestException) {
        errorMessage = 'Error loading announcements: ${e.message} (code: ${e.code})';
      }
      setState(() {
        _errorMessage = errorMessage;
        _errorMessageColor = Colors.red;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage), backgroundColor: _errorMessageColor),
      );
      print('DropUpdatePage: $errorMessage');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveAnnouncement() async {
    if (_announcementController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Announcement text is required';
        _errorMessageColor = Colors.red;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage), backgroundColor: _errorMessageColor),
      );
      print('DropUpdatePage: Validation failed - No text provided');
      return;
    }

    if (!_isTeacher) {
      setState(() {
        _errorMessage = 'Only teachers can add announcements';
        _errorMessageColor = Colors.red;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage), backgroundColor: _errorMessageColor),
      );
      print('DropUpdatePage: User is not a teacher');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? filePath;
      String? fileName;

      if (_selectedFile != null) {
        if (_selectedFile!.bytes == null) {
          throw Exception('File data is unavailable');
        }
        fileName = _selectedFile!.name;
        final uniqueFileName =
            '${Supabase.instance.client.auth.currentUser!.id}_${DateTime.now().millisecondsSinceEpoch}_$fileName';
        await Supabase.instance.client.storage
            .from('announcements')
            .uploadBinary(uniqueFileName, _selectedFile!.bytes!);
        filePath = uniqueFileName;
        print('DropUpdatePage: File uploaded to $filePath');
      }

      final response = await Supabase.instance.client.from('announcements').insert({
        'user_id': Supabase.instance.client.auth.currentUser!.id,
        'text': _announcementController.text.trim(),
        'file_name': fileName ?? '',
        'file_path': filePath ?? '',
      }).select('id, text, file_name, file_path, created_at').single();

      setState(() {
        announcements.insert(0, {
          'id': response['id'] ?? '',
          'text': (response['text'] ?? '').toString(),
          'fileName': (response['file_name'] ?? '').toString(),
          'filePath': (response['file_path'] ?? '').toString(),
          'date': response['created_at'] != null
              ? DateFormat('dd/MM/yyyy').format(DateTime.parse(response['created_at']))
              : '',
        });
        _announcementController.clear();
        _selectedFile = null;
        _errorMessage = 'Announcement saved successfully!';
        _errorMessageColor = Colors.green;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage), backgroundColor: _errorMessageColor),
      );
      print('DropUpdatePage: Announcement saved: ${response['id']}');
    } catch (e) {
      String errorMessage = 'Error saving announcement: $e';
      if (e is PostgrestException) {
        errorMessage = 'Error saving announcement: ${e.message} (code: ${e.code})';
      }
      setState(() {
        _errorMessage = errorMessage;
        _errorMessageColor = Colors.red;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage), backgroundColor: _errorMessageColor),
      );
      print('DropUpdatePage: $errorMessage');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearAnnouncements() async {
    if (!_isTeacher) {
      setState(() {
        _errorMessage = 'Only teachers can clear announcements';
        _errorMessageColor = Colors.red;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage), backgroundColor: _errorMessageColor),
      );
      print('DropUpdatePage: User is not a teacher');
      return;
    }

    setState(() {
      _isLoading = true;
    });
    try {
      for (var announcement in announcements) {
        if (announcement['filePath'].isNotEmpty) {
          try {
            await Supabase.instance.client.storage
                .from('annoucements')
                .remove([announcement['filePath']]);
            print('DropUpdatePage: Deleted file ${announcement['filePath']}');
          } catch (e) {
            print('DropUpdatePage: Error deleting file ${announcement['filePath']}: $e');
          }
        }
      }

      await Supabase.instance.client.from('announcements').delete().neq('id', '');
      setState(() {
        announcements = [];
        _selectedFile = null;
        _announcementController.clear();
        _errorMessage = 'All announcements cleared';
        _errorMessageColor = Colors.green;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage), backgroundColor: _errorMessageColor),
      );
      print('DropUpdatePage: All announcements cleared');
    } catch (e) {
      String errorMessage = 'Error clearing announcements: $e';
      if (e is PostgrestException) {
        errorMessage = 'Error clearing announcements: ${e.message} (code: ${e.code})';
      }
      setState(() {
        _errorMessage = errorMessage;
        _errorMessageColor = Colors.red;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage), backgroundColor: _errorMessageColor),
      );
      print('DropUpdatePage: $errorMessage');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
          _errorMessage = 'File selected: ${_selectedFile!.name}';
          _errorMessageColor = Colors.green;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage), backgroundColor: _errorMessageColor),
        );
        print('DropUpdatePage: File selected: ${_selectedFile!.name}');
      } else {
        setState(() {
          _errorMessage = 'No file selected';
          _errorMessageColor = Colors.white;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage), backgroundColor: _errorMessageColor),
        );
        print('DropUpdatePage: No file selected');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking file: $e';
        _errorMessageColor = Colors.red;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage), backgroundColor: _errorMessageColor),
      );
      print('DropUpdatePage: Error picking file: $e');
    }
  }

  Future<void> _openFile(String filePath) async {
    if (filePath.isEmpty) {
      setState(() {
        _errorMessage = 'No file path provided';
        _errorMessageColor = Colors.red;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage), backgroundColor: _errorMessageColor),
      );
      return;
    }
    try {
      print('DropUpdatePage: Attempting to open file with path: $filePath');
      final url = await Supabase.instance.client.storage
          .from('annoucements')
          .createSignedUrl(filePath, 60);
      print('DropUpdatePage: Generated Signed URL: $url');
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        print('DropUpdatePage: Could not launch $url');
        setState(() {
          _errorMessage = 'Could not open file';
          _errorMessageColor = Colors.red;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage), backgroundColor: _errorMessageColor),
        );
      }
    } catch (e) {
      print('DropUpdatePage: Error opening file: $e, FilePath: $filePath');
      setState(() {
        _errorMessage = 'Error opening file: $e';
        _errorMessageColor = Colors.red;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage), backgroundColor: _errorMessageColor),
      );
    }
  }

  @override
  void dispose() {
    _announcementController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue, Colors.blue],
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
                          offset: Offset(2.0, 2.0),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 600.ms),
                  const SizedBox(height: 20),
                  const Text(
                    'Drop Update',
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
                  const SizedBox(height: 20),
                  if (_errorMessage.isNotEmpty)
                    Text(
                      _errorMessage,
                      style: TextStyle(color: _errorMessageColor, fontSize: 16),
                    ).animate().fadeIn(duration: 500.ms),
                  const SizedBox(height: 10),
                  if (_isTeacher)
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: Colors.white.withOpacity(0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'New Announcement',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _announcementController,
                              maxLines: 5,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white24,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                hintText: 'Enter announcement here...',
                                hintStyle: const TextStyle(color: Colors.white54),
                              ),
                              style: const TextStyle(color: Colors.white),
                            ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.5),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedFile != null
                                        ? 'Selected: ${_selectedFile!.name}'
                                        : 'No file selected',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Colors.blue, Colors.blue],
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
                                    onPressed: _isLoading ? null : _pickFile,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const CircularProgressIndicator(color: Colors.white)
                                        : const Text(
                                      'Pick File',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ).animate().fadeIn(duration: 600.ms).slideX(begin: 0.5),
                            const SizedBox(height: 20),
                            Center(
                              child: Container(
                                width: double.infinity,
                                height: 50,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Colors.blue, Colors.lightBlue],
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
                                  onPressed: _isLoading ? null : _saveAnnouncement,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const CircularProgressIndicator(color: Colors.white)
                                      : const Text(
                                    'Save Update',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ).animate().fadeIn(duration: 800.ms).scaleXY(begin: 0.9),
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.5),
                  const SizedBox(height: 20),
                  const Text(
                    'Announcements',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Colors.white))
                      : announcements.isEmpty
                      ? const Text(
                    'No announcements available',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ).animate().fadeIn(duration: 600.ms)
                      : ClipRRect(
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
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: announcements.length,
                          itemBuilder: (context, index) {
                            final announcement = announcements[index];
                            return ListTile(
                              leading: announcement['fileName'].isNotEmpty
                                  ? const Icon(
                                Icons.insert_drive_file,
                                color: Colors.white70,
                              )
                                  : null,
                              title: Text(
                                announcement['text'].isNotEmpty
                                    ? announcement['text']
                                    : '(No text)',
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    announcement['date'],
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (announcement['fileName'].isNotEmpty)
                                    GestureDetector(
                                      onTap: () => _openFile(announcement['filePath']),
                                      child: Text(
                                        'File: ${announcement['fileName']}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              trailing: _isTeacher
                                  ? IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteAnnouncement(
                                    announcement['id'], announcement['filePath']),
                              )
                                  : null,
                            );
                          },
                        ),
                      ),
                    ),
                  ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.5),
                  const SizedBox(height: 20),
                  if (_isTeacher)
                    Center(
                      child: Container(
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
                          onPressed: _isLoading ? null : _clearAnnouncements,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                            'Clear All Announcements',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ).animate().fadeIn(duration: 800.ms).scaleXY(begin: 0.9),
                    ),
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
                    ).animate().fadeIn(duration: 800.ms).scaleXY(begin: 0.9),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteAnnouncement(String id, String filePath) async {
    if (!_isTeacher) {
      setState(() {
        _errorMessage = 'Only teachers can delete announcements';
        _errorMessageColor = Colors.red;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage), backgroundColor: _errorMessageColor),
      );
      print('DropUpdatePage: User is not a teacher');
      return;
    }

    setState(() {
      _isLoading = true;
    });
    try {
      if (filePath.isNotEmpty) {
        await Supabase.instance.client.storage.from('annoucements').remove([filePath]);
        print('DropUpdatePage: Deleted file $filePath');
      }

      await Supabase.instance.client.from('announcements').delete().eq('id', id);
      setState(() {
        announcements.removeWhere((a) => a['id'] == id);
        _errorMessage = 'Announcement deleted successfully';
        _errorMessageColor = Colors.green;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage), backgroundColor: _errorMessageColor),
      );
      print('DropUpdatePage: Announcement deleted: $id');
    } catch (e) {
      String errorMessage = 'Error deleting announcement: $e';
      if (e is PostgrestException) {
        errorMessage = 'Error deleting announcement: ${e.message} (code: ${e.code})';
      }
      setState(() {
        _errorMessage = errorMessage;
        _errorMessageColor = Colors.red;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage), backgroundColor: _errorMessageColor),
      );
      print('DropUpdatePage: $errorMessage');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

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
  bool _isLoading = false;
  final TextEditingController _titleController = TextEditingController();

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
    if (user == null) {
      setState(() {
        _errorMessage = 'Please log in to view announcements';
        _errorMessageColor = Colors.red;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage), backgroundColor: _errorMessageColor),
      );
      return;
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage), backgroundColor: _errorMessageColor),
      );
    }
  }

  Future<List<Map<String, String>>> _loadNotifications() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        _errorMessage = 'Please log in to view announcements';
        _errorMessageColor = Colors.red;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage), backgroundColor: _errorMessageColor),
      );
      print('NotificationPage: User not authenticated');
      return [];
    }
    try {
      print('NotificationPage: Loading announcements for user ID: ${user.id}');
      final response = await Supabase.instance.client
          .from('announcements')
          .select('created_at, text, file_name, file_path')
          .order('created_at', ascending: false);
      final notifications = (response as List<dynamic>).map((notification) => {
        'date': DateFormat('dd/MM/yyyy').format(DateTime.parse(notification['created_at'])),
        'title': (notification['text'] ?? 'Untitled').toString(),
        'file_name': (notification['file_name'] ?? '').toString(),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage), backgroundColor: _errorMessageColor),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage), backgroundColor: _errorMessageColor),
      );
      print('NotificationPage: User not authenticated');
      return;
    }
    if (!_isTeacher) {
      setState(() {
        _errorMessage = 'Only teachers can add announcements';
        _errorMessageColor = Colors.red;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage), backgroundColor: _errorMessageColor),
      );
      print('NotificationPage: User is not a teacher');
      return;
    }
    if (_titleController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Announcement text is required';
        _errorMessageColor = Colors.red;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage), backgroundColor: _errorMessageColor),
      );
      print('NotificationPage: Announcement text is empty');
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      String? filePath;
      String? fileName;
      if (file != null) {
        fileName = path.basename(file.name);
        final uploadFileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}${path.extension(fileName)}';
        print('NotificationPage: Uploading file: $uploadFileName');
        final fileBytes = file.bytes!;
        await Supabase.instance.client.storage.from('annoucements').uploadBinary(uploadFileName, fileBytes);
        filePath = uploadFileName;
        print('NotificationPage: File uploaded, path: $filePath');
      }

      await Supabase.instance.client.from('announcements').insert({
        'user_id': user.id,
        'text': _titleController.text.trim(),
        'file_name': fileName ?? '',
        'file_path': filePath ?? '',
      });
      setState(() {
        _errorMessage = 'Announcement added successfully';
        _errorMessageColor = Colors.green;
        _notificationsFuture = _loadNotifications();
        _titleController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage), backgroundColor: _errorMessageColor),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage), backgroundColor: _errorMessageColor),
      );
      print('NotificationPage: $errorMessage');
    } finally {
      setState(() {
        _isLoading = false;
      });
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
              decoration: const InputDecoration(
                labelText: 'Announcement',
                hintText: 'Enter announcement here...',
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                if (_titleController.text.trim().isEmpty) {
                  setState(() {
                    _errorMessage = 'Announcement text is required';
                    _errorMessageColor = Colors.red;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_errorMessage), backgroundColor: _errorMessageColor),
                  );
                  return;
                }
                Navigator.pop(context);
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['pdf', 'doc', 'docx'],
                  withData: true,
                );
                if (result != null && result.files.isNotEmpty) {
                  await _addAnnouncement(file: result.files.single);
                } else {
                  await _addAnnouncement();
                }
              },
              child: const Text('Upload File (PDF/DOC)'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_titleController.text.trim().isEmpty) {
                  setState(() {
                    _errorMessage = 'Announcement text is required';
                    _errorMessageColor = Colors.red;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_errorMessage), backgroundColor: _errorMessageColor),
                  );
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

  Future<void> _openFile(String filePath) async {
    if (filePath.isEmpty) {
      setState(() {
        _errorMessage = 'No file path provided';
        _errorMessageColor = Colors.red;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage), backgroundColor: _errorMessageColor),
      );
      return;
    }
    try {
      print('NotificationPage: Attempting to open file with path: $filePath');
      final url = await Supabase.instance.client.storage
          .from('annoucements')
          .createSignedUrl(filePath, 60);
      print('NotificationPage: Generated Signed URL: $url');
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        print('NotificationPage: Could not launch $url');
        setState(() {
          _errorMessage = 'Could not open file';
          _errorMessageColor = Colors.red;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage), backgroundColor: _errorMessageColor),
        );
      }
    } catch (e) {
      print('NotificationPage: Error opening file: $e, FilePath: $filePath');
      setState(() {
        _errorMessage = 'Error opening file: $e';
        _errorMessageColor = Colors.red;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage), backgroundColor: _errorMessageColor),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
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
                  const SizedBox(height: 20),
                  if (_errorMessage.isNotEmpty)
                    Text(
                      _errorMessage,
                      style: TextStyle(color: _errorMessageColor, fontSize: 16),
                    ).animate().fadeIn(duration: 500.ms),
                  const SizedBox(height: 10),
                  if (_isTeacher)
                    Center(
                      child: Container(
                        width: 200,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.green, Colors.greenAccent],
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
                          onPressed: _isLoading ? null : _showAddAnnouncementDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                            'Add Announcement',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ).animate().fadeIn(duration: 800.ms),
                    ),
                  const SizedBox(height: 20),
                  FutureBuilder<List<Map<String, String>>>(
                    future: _notificationsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ).animate().fadeIn(duration: 500.ms);
                      }
                      if (snapshot.hasError) {
                        return Text(
                          _errorMessage.isNotEmpty ? _errorMessage : 'Failed to load announcements',
                          style: TextStyle(color: _errorMessageColor),
                        ).animate().fadeIn(duration: 500.ms);
                      }
                      final notifications = snapshot.data ?? [];
                      if (notifications.isEmpty) {
                        return Text(
                          _errorMessage.isNotEmpty ? _errorMessage : 'No announcements available',
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
                                    fileName: notification['file_name']!,
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
                    ).animate().fadeIn(duration: 800.ms),
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

class NotificationRow extends StatelessWidget {
  final String date;
  final String title;
  final String fileName;
  final String filePath;

  const NotificationRow({
    super.key,
    required this.date,
    required this.title,
    required this.fileName,
    required this.filePath,
  });

  Future<void> _openFile(BuildContext context) async {
    if (filePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No file path provided'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    try {
      print('NotificationRow: Attempting to open file with path: $filePath');
      final url = await Supabase.instance.client.storage
          .from('annoucements')
          .createSignedUrl(filePath, 60);
      print('NotificationRow: Generated Signed URL: $url');
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        print('NotificationRow: Could not launch $url');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open file'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('NotificationRow: Error opening file: $e, FilePath: $filePath');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening file: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
          if (fileName.isNotEmpty) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => _openFile(context),
              child: Text(
                'View File: $fileName',
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
