import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'todo_list.dart';
import 'models/task.dart';
import 'services/api_services.dart';

enum FilterOption {
  none,
  priorityHigh,
  priorityMedium,
  priorityLow,
  dueDateAscending,
  dueDateDescending,
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final ConfettiController _confettiController =
  ConfettiController(duration: const Duration(seconds: 1));


  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _voiceInputText = '';

  DateTime? _selectedDateTime;

  String _selectedPriority = 'Medium';

  List<Task> toDoList = [];
  List<Task> filteredList = [];
  FilterOption _currentFilter = FilterOption.none;
  bool _hasShownConfetti = false;

  final List<String> quotes = [
    "You can do it!",
    "Stay focused and never give up!",
    "Make it happen!",
    "Progress, not perfection.",
    "Keep going, you're doing great!",
  ];

  @override
  void initState() {
    super.initState();
    fetchTasks();
    _speech = stt.SpeechToText();
  }

  Future<void> fetchTasks() async {
    try {
      List<Task> tasks = await ApiService.fetchTasks();
      if (mounted) {
        setState(() {
          toDoList = tasks;
          _applyFilter();
          _hasShownConfetti = false;
        });
      }
    } catch (e) {
      _showSnackbar("Failed to load tasks.\nError: $e");
    }
  }

  void _applyFilter() {
    List<Task> list = List.from(toDoList);

    // Apply search filter if there's a query
    if (_searchQuery.isNotEmpty) {
      list = list.where((task) => task.title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }

    // Then apply the selected filter option
    switch (_currentFilter) {
      case FilterOption.priorityHigh:
        list = list.where((t) => t.priority == 'High').toList();
        break;
      case FilterOption.priorityMedium:
        list = list.where((t) => t.priority == 'Medium').toList();
        break;
      case FilterOption.priorityLow:
        list = list.where((t) => t.priority == 'Low').toList();
        break;
      case FilterOption.dueDateAscending:
        list.sort((a, b) => _compareDates(a.dueDate, b.dueDate));
        break;
      case FilterOption.dueDateDescending:
        list.sort((a, b) => _compareDates(b.dueDate, a.dueDate));
        break;
      case FilterOption.none:
        break;
    }

    filteredList = list;
  }


  int _compareDates(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }

  Future<void> saveNewTask() async {
    final taskText = _controller.text.trim();
    if (taskText.isEmpty) return;

    Task newTask = Task(
      id: 0,
      title: taskText,
      isDone: false,
      priority: _selectedPriority,
      dueDate: _selectedDateTime,
    );

    try {
      bool success = await ApiService.addTask(newTask);
      if (success) {
        _resetForm();
        await fetchTasks();
        if (mounted) Navigator.pop(context);
      } else {
        _showSnackbar("Failed to add task.");
      }
    } catch (_) {
      _showSnackbar("Error adding task.");
    }
  }

  Future<void> deleteTask(Task task) async {
    try {
      bool success = await ApiService.deleteTask(task.id);
      if (success) {
        toDoList.removeWhere((t) => t.id == task.id);
        _applyFilter();
        if (mounted) setState(() {});
      } else {
        _showSnackbar("Failed to delete task.");
      }
    } catch (_) {
      _showSnackbar("Error deleting task.");
    }
  }

  Future<void> checkBoxChanged(Task task) async {
    Task updatedTask = task.copyWith(isDone: !task.isDone);

    try {
      bool success = await ApiService.updateTask(updatedTask);
      if (success) {
        await fetchTasks();
      } else {
        _showSnackbar("Failed to update task.");
      }
    } catch (_) {
      _showSnackbar("Error updating task.");
    }
  }

  void _resetForm() {
    _controller.clear();
    _selectedDateTime = null;
    _selectedPriority = 'Medium';
    _hasShownConfetti = false;
    _voiceInputText = '';
    _isListening = false;
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  int get completedTasks => toDoList.where((t) => t.isDone).length;

  String _filterOptionToString(FilterOption option) {
    return switch (option) {
      FilterOption.none => 'No Filter',
      FilterOption.priorityHigh => 'Priority: High',
      FilterOption.priorityMedium => 'Priority: Medium',
      FilterOption.priorityLow => 'Priority: Low',
      FilterOption.dueDateAscending => 'Due Date ↑',
      FilterOption.dueDateDescending => 'Due Date ↓',
    };
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        onError: (val) {
          setState(() => _isListening = false);
          _showSnackbar('Speech recognition error: ${val.errorMsg}');
        },
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _voiceInputText = val.recognizedWords;
            _controller.text = _voiceInputText;
          }),
        );
      } else {
        _showSnackbar('Speech recognition not available');
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }
  @override
  Widget build(BuildContext context) {
    Widget _buildTaskList() {
      // Group tasks
      final today = DateTime.now();
      final tomorrow = today.add(const Duration(days: 1));
      final nextWeek = today.add(const Duration(days: 7));
      final nextMonth = DateTime(today.year, today.month + 1, today.day);

      // Helper to check if two dates are same day
      bool isSameDay(DateTime? a, DateTime b) {
        if (a == null) return false;
        return a.year == b.year && a.month == b.month && a.day == b.day;
      }

      // Categorize tasks
      List<Task> todayTasks = [];
      List<Task> tomorrowTasks = [];
      List<Task> nextWeekTasks = [];
      List<Task> nextMonthTasks = [];
      List<Task> laterTasks = [];

      for (var task in filteredList) {
        if (task.dueDate == null) {
          laterTasks.add(task);
          continue;
        }
        final due = task.dueDate!;
        if (isSameDay(due, today)) {
          todayTasks.add(task);
        } else if (isSameDay(due, tomorrow)) {
          tomorrowTasks.add(task);
        } else if (due.isAfter(tomorrow) && due.isBefore(nextWeek.add(const Duration(days: 1)))) {
          nextWeekTasks.add(task);
        } else if (due.isAfter(nextWeek) && due.isBefore(nextMonth.add(const Duration(days: 1)))) {
          nextMonthTasks.add(task);
        } else {
          laterTasks.add(task);
        }
      }

      // Helper to build each group section
      Widget buildTaskSection(String title, List<Task> tasks) {
        if (tasks.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return Slidable(
                  key: ValueKey(task.id),
                  endActionPane: ActionPane(
                    motion: const DrawerMotion(),
                    children: [
                      SlidableAction(
                        onPressed: (_) => showUpdateDialog(task),
                        backgroundColor: Colors.blue,
                        icon: Icons.edit,
                        label: 'Edit',
                      ),
                      SlidableAction(
                        onPressed: (_) => deleteTask(task),
                        backgroundColor: Colors.red,
                        icon: Icons.delete,
                        label: 'Delete',
                      ),
                    ],
                  ),
                  child: TodoList(
                    taskName: task.title,
                    taskCompleted: task.isDone,
                    taskDateTime: task.dueDate,
                    priority: task.priority,
                    onChanged: (_) => checkBoxChanged(task),
                    deleteFunction: () => deleteTask(task),
                    onUpdate: () => showUpdateDialog(task),
                  ),
                );
              },
            ),
          ],
        );
      }

      if (filteredList.isEmpty) {
        return const Padding(
          padding: EdgeInsets.only(top: 50),
          child: Center(child: Text('No tasks found.')),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildTaskSection('Today', todayTasks),
          buildTaskSection('Tomorrow', tomorrowTasks),
          buildTaskSection('Next Week', nextWeekTasks),
          buildTaskSection('Next Month', nextMonthTasks),
          buildTaskSection('Later', laterTasks),
        ],
      );
    }


    return Scaffold(
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: fetchTasks,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                const SizedBox(height: 10),
                // <-- Replace this Padding with the updated one below
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      prefixIcon: const SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(
                          Icons.search,
                          color: Colors.deepPurple,
                        ),
                      ),
                      hintText: 'Search tasks...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _applyFilter();
                          });
                        },
                      )
                          : null,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.trim();
                        _applyFilter();
                      });
                    },
                  ),
                ),
                const SizedBox(height: 10),
                _buildMotivationalQuote(),
                const SizedBox(height: 10),
                _buildProgressBar(completedTasks / (toDoList.isEmpty ? 1 : toDoList.length)),
                _buildCompletionText(),
                _buildCompletionBanner(Theme.of(context).brightness == Brightness.dark),
                const SizedBox(height: 12),
                _buildTaskList(),
              ],
            ),
          ),
          _buildConfetti(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: createTaskDialog,
        icon: const Icon(Icons.add),
        label: const Text("Add Task"),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Text('My Tasks (${_filterOptionToString(_currentFilter)})'),
      backgroundColor: Colors.deepPurple,
      actions: [

        PopupMenuButton<FilterOption>(
          tooltip: 'Filter Tasks',
          icon: const Icon(Icons.filter_list),
          onSelected: (option) {
            setState(() {
              _currentFilter = option;
              _applyFilter();
            });
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: FilterOption.none, child: Text('No Filter')),
            const PopupMenuDivider(),
            const PopupMenuItem(value: FilterOption.priorityHigh, child: Text('Priority: High')),
            const PopupMenuItem(value: FilterOption.priorityMedium, child: Text('Priority: Medium')),
            const PopupMenuItem(value: FilterOption.priorityLow, child: Text('Priority: Low')),
            const PopupMenuDivider(),
            const PopupMenuItem(value: FilterOption.dueDateAscending, child: Text('Due Date Ascending')),
            const PopupMenuItem(value: FilterOption.dueDateDescending, child: Text('Due Date Descending')),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.delete_forever),
          tooltip: 'Delete All Tasks',
          onPressed: () => _confirmDeleteAll(),
        ),
      ],
    );
  }

  Widget _buildTaskList() {
    if (filteredList.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 50),
        child: Center(child: Text('No tasks found.')),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredList.length,
      itemBuilder: (context, index) {
        final task = filteredList[index];
        return Slidable(
          key: ValueKey(task.id),
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            children: [
              SlidableAction(
                onPressed: (_) => showUpdateDialog(task),
                backgroundColor: Colors.blue,
                icon: Icons.edit,
                label: 'Edit',
              ),
              SlidableAction(
                onPressed: (_) => deleteTask(task),
                backgroundColor: Colors.red,
                icon: Icons.delete,
                label: 'Delete',
              ),
            ],
          ),
          child: TodoList(
            taskName: task.title,
            taskCompleted: task.isDone,
            taskDateTime: task.dueDate,
            priority: task.priority,
            onChanged: (_) => checkBoxChanged(task),
            deleteFunction: () => deleteTask(task),
            onUpdate: () => showUpdateDialog(task),
          ),
        );
      },
    );
  }

  Widget _buildMotivationalQuote() {
    final quote = quotes.isEmpty ? '' : quotes[toDoList.length % quotes.length];
    return Center(
      child: Text(
        quote,
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w400, color: Colors.grey),
      ),
    );
  }

  Widget _buildProgressBar(double progress) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LinearProgressIndicator(
        value: progress,
        color: Colors.deepPurple,
        backgroundColor: Colors.grey.shade300,
      ),
    );
  }

  Widget _buildCompletionText() {
    return Center(
      child: Text(
        "Completed: $completedTasks / ${toDoList.length}",
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildCompletionBanner(bool isDark) {
    if (completedTasks == toDoList.length && toDoList.isNotEmpty && !_hasShownConfetti) {
      _confettiController.play();
      _hasShownConfetti = true;
    }

    if (completedTasks == toDoList.length && toDoList.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? Colors.green.shade700 : Colors.green.shade300,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(12),
          child: const Center(
            child: Text(
              "🎉 Congratulations! All tasks are done.",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildConfetti() {
    return Align(
      alignment: Alignment.topCenter,
      child: ConfettiWidget(
        confettiController: _confettiController,
        blastDirectionality: BlastDirectionality.explosive,
        shouldLoop: false,
        colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
        emissionFrequency: 0.05,
        numberOfParticles: 20,
      ),
    );
  }

  void createTaskDialog() {
    _showTaskDialog("Add New Task", saveNewTask);
  }

  void showUpdateDialog(Task task) {
    _controller.text = task.title;
    _selectedPriority = task.priority;
    _selectedDateTime = task.dueDate;

    _showTaskDialog("Update Task", () async {
      final updatedTask = task.copyWith(
        title: _controller.text.trim(),
        priority: _selectedPriority,
        dueDate: _selectedDateTime,
      );
      try {
        bool success = await ApiService.updateTask(updatedTask);
        if (success) {
          _resetForm();
          await fetchTasks();
          if (mounted) Navigator.pop(context);
        } else {
          _showSnackbar("Failed to update task.");
        }
      } catch (_) {
        _showSnackbar("Error updating task.");
      }
    });
  }

  void _showTaskDialog(String title, VoidCallback onSave) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        decoration: const InputDecoration(labelText: 'Task Title'),
                        autofocus: true,
                      ),
                    ),
                    IconButton(
                      icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                      onPressed: _listen,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedPriority,
                        decoration: const InputDecoration(labelText: "Priority"),
                        items: const [
                          DropdownMenuItem(value: 'High', child: Text('High')),
                          DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                          DropdownMenuItem(value: 'Low', child: Text('Low')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedPriority = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDateTime ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() => _selectedDateTime = picked);
                        }
                      },
                      child: const Text("Select Due Date"),
                    ),
                  ],
                ),
                if (_selectedDateTime != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      "Due: ${DateFormat.yMMMd().format(_selectedDateTime!)}",
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _resetForm();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: onSave,
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteAll() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete All Tasks'),
          content: const Text('Are you sure you want to delete all tasks?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  bool success = await ApiService.deleteAllTasks(toDoList);
                  if (success) {
                    toDoList.clear();
                    _applyFilter();
                    if (mounted) setState(() {});
                  } else {
                    _showSnackbar("Failed to delete all tasks.");
                  }
                } catch (_) {
                  _showSnackbar("Error deleting all tasks.");
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
