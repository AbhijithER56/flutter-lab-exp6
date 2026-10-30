import 'package:flutter/material.dart';

import 'database_helper.dart';
import 'main.dart';
import 'student_list_screen.dart';
import 'student_model.dart';

/// Screen 1 – registration form that INSERTs a student into SQLite.
class AddStudentScreen extends StatefulWidget {
  /// True when this screen was opened from the Student Records screen,
  /// so "View Students" returns there instead of pushing a new copy.
  final bool openedFromList;

  const AddStudentScreen({super.key, this.openedFromList = false});

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _registerNumberController =
      TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  bool _isSaving = false;

  /// Live validation is switched on only after the first failed submit,
  /// and off again after a successful save so the cleared form has no errors.
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  static final RegExp _nameRegExp = RegExp(r"^[A-Za-z][A-Za-z .']*$");
  static final RegExp _registerNumberRegExp = RegExp(r'^[A-Za-z0-9/-]+$');
  static final RegExp _departmentRegExp = RegExp(r'^[A-Za-z][A-Za-z .&()-]*$');
  static final RegExp _emailRegExp =
      RegExp(r'^[\w.+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}$');

  @override
  void dispose() {
    _nameController.dispose();
    _registerNumberController.dispose();
    _departmentController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty) return 'Please enter the student name.';
    if (text.length < 3) return 'Name must have at least 3 characters.';
    if (!_nameRegExp.hasMatch(text)) {
      return 'Name can contain only letters, spaces and dots.';
    }
    return null;
  }

  String? _validateRegisterNumber(String? value) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty) return 'Please enter the registration number.';
    if (!_registerNumberRegExp.hasMatch(text)) {
      return 'Use letters, digits, "/" or "-" only (no spaces).';
    }
    return null;
  }

  String? _validateDepartment(String? value) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty) return 'Please enter the department.';
    if (!_departmentRegExp.hasMatch(text)) {
      return 'Department can contain only letters and spaces.';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty) return 'Please enter the email address.';
    if (!_emailRegExp.hasMatch(text)) {
      return 'Enter a valid email address (e.g. name@example.com).';
    }
    return null;
  }

  Future<void> _saveStudent() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      return;
    }

    setState(() => _isSaving = true);

    final Student student = Student(
      name: _nameController.text.trim(),
      registerNumber: _registerNumberController.text.trim().toUpperCase(),
      department: _departmentController.text.trim(),
      email: _emailController.text.trim().toLowerCase(),
    );

    try {
      final int id = await DatabaseHelper.instance.insertStudent(student);
      if (!mounted) return;

      _nameController.clear();
      _registerNumberController.clear();
      _departmentController.clear();
      _emailController.clear();
      _formKey.currentState!.reset();
      setState(() => _autovalidateMode = AutovalidateMode.disabled);

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: StudentRecordApp.accentTeal,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${student.name} saved successfully (ID: $id).',
                  ),
                ),
              ],
            ),
          ),
        );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Failed to save student: $error'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _viewStudents() {
    if (widget.openedFromList) {
      Navigator.pop(context);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StudentListScreen()),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization capitalization = TextCapitalization.none,
    TextInputAction action = TextInputAction.next,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: capitalization,
        textInputAction: action,
        validator: validator,
        onFieldSubmitted:
            action == TextInputAction.done ? (_) => _saveStudent() : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: StudentRecordApp.primaryBlue),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const GradientAppBarBackground(),
        leading: widget.openedFromList ? const BackButton() : null,
        title: const Text('Add Student'),
        actions: [
          IconButton(
            tooltip: 'View Students',
            icon: const Icon(Icons.list_alt_rounded),
            onPressed: _viewStudents,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _HeaderBanner(),
                  const SizedBox(height: 20),
                  Card(
                    elevation: 3,
                    shadowColor: Colors.blue.withValues(alpha: 0.2),
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: _autovalidateMode,
                        child: Column(
                          children: [
                            _buildField(
                              controller: _nameController,
                              label: 'Student Name',
                              hint: 'Yokesh',
                              icon: Icons.person_outline,
                              validator: _validateName,
                              capitalization: TextCapitalization.words,
                            ),
                            _buildField(
                              controller: _registerNumberController,
                              label: 'Registration Number',
                              hint: 'e.g. RA2211003010123',
                              icon: Icons.badge_outlined,
                              validator: _validateRegisterNumber,
                              capitalization: TextCapitalization.characters,
                            ),
                            _buildField(
                              controller: _departmentController,
                              label: 'Department',
                              hint: 'e.g. Computer Science',
                              icon: Icons.apartment_outlined,
                              validator: _validateDepartment,
                              capitalization: TextCapitalization.words,
                            ),
                            _buildField(
                              controller: _emailController,
                              label: 'Email Address',
                              hint: 'e.g. Yokesh@gmail.com',
                              icon: Icons.email_outlined,
                              validator: _validateEmail,
                              keyboardType: TextInputType.emailAddress,
                              action: TextInputAction.done,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveStudent,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(_isSaving ? 'Saving...' : 'Save Student'),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _viewStudents,
                    icon: const Icon(Icons.people_alt_outlined),
                    label: const Text('View Students'),
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

class _HeaderBanner extends StatelessWidget {
  const _HeaderBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [StudentRecordApp.primaryBlue, StudentRecordApp.accentTeal],
        ),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white24,
            child: Icon(Icons.school_rounded, color: Colors.white, size: 32),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Student Registration',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Records are stored in the SQLite database '
                  '"student_database.db".',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
