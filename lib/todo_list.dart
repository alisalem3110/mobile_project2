import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TodoList extends StatelessWidget {
  final String taskName;
  final bool taskCompleted;
  final DateTime? taskDateTime;
  final String priority;
  final ValueChanged<bool?> onChanged;
  final VoidCallback deleteFunction;
  final VoidCallback onUpdate;

  const TodoList({
    super.key,
    required this.taskName,
    required this.taskCompleted,
    this.taskDateTime,
    required this.priority,
    required this.onChanged,
    required this.deleteFunction,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    Color getPriorityColor() {
      switch (priority) {
        case 'High':
          return Colors.red;
        case 'Medium':
          return Colors.orange;
        case 'Low':
          return Colors.green;
        default:
          return Colors.grey;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: 2,
        child: ListTile(
          leading: Checkbox(
            value: taskCompleted,
            onChanged: onChanged,
          ),
          title: Text(
            taskName,
            style: TextStyle(
              decoration:
              taskCompleted ? TextDecoration.lineThrough : TextDecoration.none,
            ),
          ),
          subtitle: Row(
            children: [
              if (taskDateTime != null)
                Text('Due: ${DateFormat.yMMMd().format(taskDateTime!)}'),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: getPriorityColor(),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  priority,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.edit),
            onPressed: onUpdate,
          ),
          onLongPress: deleteFunction,
        ),
      ),
    );
  }
}