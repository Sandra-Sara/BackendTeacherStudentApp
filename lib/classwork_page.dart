import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';

class ClassworkPage extends StatefulWidget {
  const ClassworkPage({super.key});

  @override
  State<ClassworkPage> createState() => _ClassworkPageState();
}

class _ClassworkPageState extends State<ClassworkPage> {
  String? _selectedCourse;
  final TextEditingController _submissionController = TextEditingController();
  final List<String> _courses = ['CSE 2201', 'CSE 2202', 'CSE 2203', 'CSE 2204', 'CSE 2205'];
  List<String> _submissions = [];
  bool _isUploading = false; // ফাইল আপলোডের জন্য লোডিং স্টেট

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _submissions = prefs.getStringList('classwork_submissions') ?? [];
    });
  }

  Future<void> _saveSubmissions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('classwork_submissions', _submissions);
  }

  void _submitClasswork() {
    if (_selectedCourse != null && _submissionController.text.isNotEmpty) {
      setState(() {
        _submissions.add('$_selectedCourse: ${_submissionController.text}');
        _saveSubmissions();
        _submissionController.clear();
        _selectedCourse = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Classwork submitted successfully!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a course and enter submission details')),
      );
    }
  }

  Future<void> _uploadFile() async {
    setState(() {
      _isUploading = true;
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any, // যেকোনো ফাইল (PDF, DOC, IMG ইত্যাদি)
      );

      if (result != null) {
        final file = result.files.first;
        final supabase = Supabase.instance.client;
        final userId = supabase.auth.currentUser?.id;

        if (userId != null) {
          final filePath = 'classwork/$userId/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
          await supabase.storage
              .from('classwork-files') // আপনার বাকেট নাম
              .uploadBinary(
            filePath,
            file.bytes!,
            fileOptions: FileOptions(contentType: file.extension == 'pdf' ? 'application/pdf' : 'application/octet-stream'),
          );

          final fileUrl = supabase.storage.from('classwork-files').getPublicUrl(filePath);
          setState(() {
            _submissions.add('$_selectedCourse: File uploaded - $fileUrl');
            _saveSubmissions();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('File uploaded successfully! URL: $fileUrl')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not logged in.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No file selected.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading file: $e')),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  void dispose() {
    _submissionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Classwork Submission'),
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
              ),
              const SizedBox(height: 20),
              const Text(
                'University Of Dhaka',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              const Text(
                'Classwork Submission',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.grey),
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
                      const Text(
                        'Select Course:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButton<String>(
                        value: _selectedCourse,
                        hint: const Text('Choose a course'),
                        isExpanded: true,
                        items: _courses.map((String course) {
                          return DropdownMenuItem<String>(
                            value: course,
                            child: Text(course),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedCourse = newValue;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Submission Details:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _submissionController,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Enter classwork details or answers...',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Previous Submissions',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _submissions.length,
                itemBuilder: (context, index) {
                  return Card(
                    child: ListTile(
                      title: Text(_submissions[index]),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _submitClasswork,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    minimumSize: const Size(200, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
                  ),
                  child: const Text(
                    'Submit',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _uploadFile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    minimumSize: const Size(200, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
                  ),
                  child: _isUploading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    'Upload File',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}