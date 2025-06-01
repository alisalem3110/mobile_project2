import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/task.dart';

class ApiService {
  static const String baseUrl = "http://mobileapplication.atwebpages.com/todo_api";

  static Future<List<Task>> fetchTasks() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/get_tasks.php'));
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((json) => Task.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch tasks: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch tasks: $e');
    }
  }

  static Future<bool> addTask(Task task) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/add_task.php'),
        body: {
          'title': task.title,
          'is_done': task.isDone ? '1' : '0',
          'priority': task.priority,
          'due_date': task.dueDate?.toIso8601String() ?? '',
        },
      );
      final jsonData = jsonDecode(response.body);
      return jsonData['success'] == true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> updateTask(Task task) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/update_task.php'),
        body: {
          'id': task.id.toString(),
          'title': task.title,
          'is_done': task.isDone ? '1' : '0',
          'priority': task.priority,
          'due_date': task.dueDate?.toIso8601String() ?? '',
        },
      );
      final jsonData = jsonDecode(response.body);
      return jsonData['success'] == true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteTask(int id) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/delete_task.php'),
        body: {'id': id.toString()},
      );
      final jsonData = jsonDecode(response.body);
      return jsonData['success'] == true;
    } catch (e) {
      return false;
    }
  }

  // Deletes all tasks by calling deleteTask for each task
  static Future<bool> deleteAllTasks(List<Task> tasks) async {
    try {
      for (var task in tasks) {
        final success = await deleteTask(task.id);
        if (!success) return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }
}