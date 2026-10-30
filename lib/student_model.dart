/// Data model for one row of the `students` table.
class Student {
  final int? id;
  final String name;
  final String registerNumber;
  final String department;
  final String email;

  const Student({
    this.id,
    required this.name,
    required this.registerNumber,
    required this.department,
    required this.email,
  });

  /// Converts the object into a map whose keys match the table columns.
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'register_number': registerNumber,
      'department': department,
      'email': email,
    };
  }

  /// Builds a Student from a row returned by a SELECT query.
  factory Student.fromMap(Map<String, Object?> map) {
    return Student(
      id: map['id'] as int?,
      name: map['name'] as String,
      registerNumber: map['register_number'] as String,
      department: map['department'] as String,
      email: map['email'] as String,
    );
  }

  @override
  String toString() =>
      'Student(id: $id, name: $name, registerNumber: $registerNumber, '
      'department: $department, email: $email)';
}
