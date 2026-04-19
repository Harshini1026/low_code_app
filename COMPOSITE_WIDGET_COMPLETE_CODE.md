# Composite Widget System - Complete Code Reference

## Quick Copy-Paste Code

### 1. Task Model - Complete Code
**File:** `lib/models/task_model.dart`

```dart
/// Data model for tasks in composite widgets (like todo widget)
class Task {
  final String id;
  String title;
  bool isCompleted;

  Task({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });

  factory Task.fromMap(Map<String, dynamic> map) => Task(
    id: map['id'],
    title: map['title'],
    isCompleted: map['isCompleted'] ?? false,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'isCompleted': isCompleted,
  };

  Task copyWith({
    String? id,
    String? title,
    bool? isCompleted,
  }) => Task(
    id: id ?? this.id,
    title: title ?? this.title,
    isCompleted: isCompleted ?? this.isCompleted,
  );
}
```

---

### 2. TodoWidget - Complete Code
**File:** `lib/widgets/todo_widget.dart`

```dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/task_model.dart';
import '../core/theme/app_theme.dart';

/// A fully functional, composite Todo widget that combines:
/// • Checkbox (task completion)
/// • Text (task name)
/// • Delete button (remove task with confirmation)
/// • FloatingActionButton (add task)
/// • Dialog (add task input + delete confirmation)
/// • ListView (display all tasks)
///
/// This widget manages its own state (tasks) and does NOT rely on external
/// state management. It's self-contained and can be used as a single dragged widget.
class TodoWidget extends StatefulWidget {
  final String title;
  final Color primaryColor;
  final String emptyMessage;

  const TodoWidget({
    Key? key,
    this.title = 'My Tasks',
    this.primaryColor = AppTheme.primary,
    this.emptyMessage = 'No tasks yet. Add one!',
  }) : super(key: key);

  @override
  State<TodoWidget> createState() => _TodoWidgetState();
}

class _TodoWidgetState extends State<TodoWidget> {
  // ══════════════════════════════════════════════════════════════════════
  // STATE: Tasks stored locally in this widget
  // ══════════════════════════════════════════════════════════════════════
  late List<Task> tasks;
  final TextEditingController _inputController = TextEditingController();
  final uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    // Initialize with empty task list (can be loaded from widget state)
    tasks = [];
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════
  // ACTIONS: Core functionality
  // ══════════════════════════════════════════════════════════════════════

  /// Shows dialog to add a new task
  void _showAddTaskDialog() {
    _inputController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add New Task'),
        content: TextField(
          controller: _inputController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter task name...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onSubmitted: (_) => _addTask(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.primaryColor,
            ),
            onPressed: _addTask,
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  /// Adds a task to the list
  void _addTask() {
    final taskTitle = _inputController.text.trim();
    if (taskTitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task cannot be empty!')),
      );
      return;
    }

    setState(() {
      tasks.add(Task(
        id: uuid.v4(),
        title: taskTitle,
        isCompleted: false,
      ));
    });

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Task added!'),
        duration: Duration(milliseconds: 1500),
      ),
    );
  }

  /// Toggles task completion status
  void _toggleTask(String taskId) {
    setState(() {
      final taskIndex = tasks.indexWhere((t) => t.id == taskId);
      if (taskIndex != -1) {
        tasks[taskIndex] = tasks[taskIndex].copyWith(
          isCompleted: !tasks[taskIndex].isCompleted,
        );
      }
    });
  }

  /// Shows confirmation dialog before deleting a task
  void _showDeleteConfirmation(String taskId, String taskTitle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Task?'),
        content: Text('Are you sure you want to delete "$taskTitle"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () {
              Navigator.pop(context);
              _deleteTask(taskId);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Deletes a task from the list
  void _deleteTask(String taskId) {
    setState(() {
      tasks.removeWhere((t) => t.id == taskId);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Task deleted!'),
        duration: Duration(milliseconds: 1500),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // BUILD: Complete UI with all functionality
  // ══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: widget.primaryColor,
        elevation: 0,
        title: Text(widget.title),
      ),
      body: tasks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.task_alt,
                    size: 64,
                    color: widget.primaryColor.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.emptyMessage,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: tasks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final task = tasks[index];
                return _buildTaskTile(task);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        backgroundColor: widget.primaryColor,
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Builds a single task tile with checkbox, title, and delete button
  Widget _buildTaskTile(Task task) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Checkbox(
          value: task.isCompleted,
          onChanged: (_) => _toggleTask(task.id),
          activeColor: widget.primaryColor,
        ),
        title: Text(
          task.title,
          style: TextStyle(
            fontSize: 15,
            decoration: task.isCompleted
                ? TextDecoration.lineThrough
                : TextDecoration.none,
            color: task.isCompleted ? Colors.grey[400] : Colors.black87,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => _showDeleteConfirmation(task.id, task.title),
        ),
      ),
    );
  }
}
```

---

### 3. Updates to WidgetModel
**File:** `lib/models/widget_model.dart`

#### Add These Imports (if not present)
```dart
// At the top of the file
```

#### Update Constructor
```dart
class WidgetModel {
  final String id;
  final String type;
  double x, y, width, height;
  Map<String, dynamic> properties;
  String? boundTable;
  String? boundField;
  List<WidgetModel> children;        // NEW: Support child widgets
  Map<String, dynamic> state;        // NEW: Store widget state (tasks, etc)

  WidgetModel({
    required this.id,
    required this.type,
    this.x = 20,
    this.y = 20,
    this.width = 300,
    this.height = 52,
    this.properties = const {},
    this.boundTable,
    this.boundField,
    this.children = const [],        // NEW: Initialize children
    this.state = const {},           // NEW: Initialize state
  });
```

#### Update fromMap()
```dart
  factory WidgetModel.fromMap(Map<String, dynamic> m) => WidgetModel(
    id: m['id'],
    type: m['type'],
    x: (m['x'] as num).toDouble(),
    y: (m['y'] as num).toDouble(),
    width: (m['width'] as num).toDouble(),
    height: (m['height'] as num).toDouble(),
    properties: Map<String, dynamic>.from(m['properties'] ?? {}),
    boundTable: m['boundTable'],
    boundField: m['boundField'],
    children: (m['children'] as List<dynamic>?)
        ?.map((c) => WidgetModel.fromMap(c as Map<String, dynamic>))
        .toList() ?? [],
    state: Map<String, dynamic>.from(m['state'] ?? {}),
  );
```

#### Update toMap()
```dart
  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'properties': properties,
    'boundTable': boundTable,
    'boundField': boundField,
    'children': children.map((c) => c.toMap()).toList(),
    'state': state,
  };
```

#### Add 'todo' to defaultPropsFor()
```dart
  static Map<String, dynamic> defaultPropsFor(String type) =>
      {
        // ... existing widgets ...
        'todo': {
          'title': 'My Tasks',
          'color': '#00C896',
          'emptyMessage': 'No tasks yet. Add one!',
        },
      }[type] ??
      {};
```

#### Add 'todo' to defaultHeightFor()
```dart
  static double defaultHeightFor(String type) =>
      {
        // ... existing widgets ...
        'todo': 300.0,
      }[type] ??
      60.0;
```

---

### 4. Add Case to Canvas Renderer
**File:** `lib/screens/builder/canvas_area.dart`

Add this import at the top:
```dart
import '../widgets/todo_widget.dart';
```

Find the switch statement in WidgetRenderer.build() and add:
```dart
      case 'todo':
        return _buildTodoWidget(props, w, h);
```

Add these methods to the WidgetRenderer class (before the closing brace):
```dart
  /// Builds the fully functional Todo widget
  Widget _buildTodoWidget(Map<String, dynamic> props, double w, double h) {
    return SizedBox(
      width: w,
      height: h,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Header with title ──────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: _c(props, 'color', AppTheme.primary),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.task_alt, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _s(props, 'title', 'My Tasks'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // ── Task list area ────────────────────────────────────────
            Expanded(
              child: _buildTaskListPreview(props),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a preview of the task list
  Widget _buildTaskListPreview(Map<String, dynamic> props) {
    final sampleTasks = [
      'Click "+" button to add a task',
      'Check the box to mark complete',
      'Click trash icon to delete',
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: sampleTasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (_, i) => Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Checkbox(
              value: false,
              onChanged: null,
              activeColor: _c(props, 'color', AppTheme.primary),
            ),
            Expanded(
              child: Text(
                sampleTasks[i],
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
```

---

### 5. Add to Widget Panel
**File:** `lib/screens/builder/widget_panel.dart`

Find this section:
```dart
  'Navigation': [
    // ... nav items ...
  ],
  'Advanced': [
```

Add a new 'Composite' category before 'Advanced':
```dart
  'Navigation': [
    // ... nav items ...
  ],
  'Composite': [
    {
      'type': 'todo',
      'label': 'Todo Widget',
      'icon': '✓',
      'color': 0xFF00C896,
    },
  ],
  'Advanced': [
```

---

## Verification Checklist

- [ ] `task_model.dart` created with Task class
- [ ] `todo_widget.dart` created with full TodoWidget implementation
- [ ] `widget_model.dart` updated with `children` and `state` fields
- [ ] `widget_model.dart` includes 'todo' in defaultPropsFor()
- [ ] `widget_model.dart` includes 'todo': 300.0 in defaultHeightFor()
- [ ] `canvas_area.dart` imports todo_widget.dart
- [ ] `canvas_area.dart` has case 'todo' in switch statement
- [ ] `canvas_area.dart` has _buildTodoWidget() and _buildTaskListPreview() methods
- [ ] `widget_panel.dart` has 'Composite' category with 'todo' widget
- [ ] No compilation errors in the project

## Testing Steps

1. **In Builder:**
   - Open the app
   - Go to Widget Panel → Composite
   - Drag "Todo Widget" onto canvas
   - See preview with sample tasks
   - Edit title in properties panel

2. **In App:**
   - Click "Run" or preview
   - Click "+" button to add task
   - Type task name and confirm
   - Check box to mark complete
   - Click trash to delete (confirm)
   - See strikethrough on completed tasks

## Troubleshooting

### "todo_widget.dart not found"
- Ensure file is in `lib/widgets/` folder
- Check import path: `import '../widgets/todo_widget.dart';`

### "Class _TodoWidgetState not defined"
- Make sure TodoWidget is StatefulWidget, not StatelessWidget
- Check that `createState() => _TodoWidgetState();` exists

### "uuid not found"
- The uuid package should already be in your pubspec.yaml
- If not, run: `flutter pub add uuid`

### Tasks disappear on app restart
- This is normal - state is session-only
- To persist, save to Firestore (future enhancement)

