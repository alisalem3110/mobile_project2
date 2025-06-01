

class Task {
  final int id;
  final String title;
  final bool isDone;
  final String priority;
  final DateTime? dueDate;







  Task({
    required this.id,
    required this.title,
    required this.isDone,
    required this.priority,
    this.dueDate,




  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: int.tryParse(json['id'].toString()) ?? 0,
      title: json['title'] ?? '',
      isDone: json['is_done'] == '1' || json['is_done'] == 1 || json['is_done'] == true,
      priority: json['priority'] ?? 'Medium',
      dueDate: (json['due_date'] != null && (json['due_date'] as String).isNotEmpty)
          ? DateTime.tryParse(json['due_date'])
          : null,


    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id.toString(),
      'title': title,
      'is_done': isDone ? '1' : '0',
      'priority': priority,
      'due_date': dueDate?.toIso8601String() ?? '',


    };
  }

  Task copyWith({
    int? id,
    String? title,
    bool? isDone,
    String? priority,
    DateTime? dueDate,


  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,

    );
  }
}