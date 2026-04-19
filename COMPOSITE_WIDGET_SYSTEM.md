# Composite Widget System - Architecture & Implementation

## Overview

This document explains how **composite widgets** work in your low-code builder. A composite widget is a self-contained, fully functional widget that combines multiple basic widgets and manages its own state.

**Key Principle:** Instead of creating isolated UI-only widgets, composite widgets are **real functional components** that live in your builder.

---

## 1. Architecture: How Composite Widgets Work

### Traditional Approach (❌ What We Avoided)
```
Basic Widgets → UI Only → No Real Functionality
  • Button (just shows)
  • Text (just displays)
  • Checkbox (looks good but doesn't work)
```

### Composite Approach (✅ What We Built)
```
Composite Widget = Basic Widgets + State + Logic + Dialogs
  • Checkbox (toggles task completion)
  • Text (shows task name)
  • Button (deletes task with confirmation)
  • Dialog (add new task)
  • Dialog (confirm delete)
  • ListView (displays all tasks)
```

---

## 2. Data Flow: From Drag to Full Functionality

```
┌─────────────────────────────────────────────────────────────────┐
│ USER DRAGS "TODO WIDGET" FROM PANEL ONTO CANVAS                 │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ widget_panel.dart                                               │
│ Draggable<String>(                                              │
│   data: 'todo',  // Type = 'todo'                               │
│   child: Icon + Label                                           │
│ )                                                               │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ canvas_area.dart                                                │
│ DragTarget<String>(                                             │
│   onAccept: (type) {                                            │
│     provider.addWidget(type, x, y);  // Creates WidgetModel    │
│   }                                                             │
│ )                                                               │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ builder_provider.dart                                           │
│ addWidget(type, x, y) creates WidgetModel:                      │
│   WidgetModel {                                                 │
│     id: unique(),                                               │
│     type: 'todo',                                               │
│     x: x, y: y,                                                 │
│     properties: defaultPropsFor('todo'),                        │
│     state: {},  // Empty initially                              │
│     children: []  // Can contain other widgets                  │
│   }                                                             │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ canvas_area.dart :: WidgetRenderer.build()                      │
│ switch(widgetModel.type) {                                      │
│   case 'todo':                                                  │
│     return _buildTodoWidget(props, w, h);                       │
│ }                                                               │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ canvas_area.dart :: _buildTodoWidget()                          │
│ Returns: SizedBox with Container showing preview                │
│   • Header with title                                           │
│   • Task list preview (read-only in builder)                    │
│   • Sample tasks: "Click + button", "Check box", etc           │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ PREVIEW IN BUILDER SHOWS:                                       │
│ ┌─────────────────────────────┐                                 │
│ │ ✓ My Tasks                  │  ← Title from properties        │
│ ├─────────────────────────────┤                                 │
│ │ ☐ Click "+" button to add   │                                 │
│ │ ☐ Check the box complete    │                                 │
│ │ ☐ Click trash to delete     │                                 │
│ └─────────────────────────────┘                                 │
└─────────────────────────────────────────────────────────────────┘

WHEN USER CLICKS "PLAY" OR RUNS APP:
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ todo_widget.dart :: TodoWidget (StatefulWidget)                 │
│ Creates FULL functional widget:                                 │
│   • Manages tasks state locally                                 │
│   • FloatingActionButton to add task                            │
│   • Dialog for task input                                       │
│   • ListView with checkboxes & delete buttons                   │
│   • Delete confirmation dialog                                  │
│   • All interactions work!                                      │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ USER CAN NOW:                                                   │
│ ✓ Add tasks (type in dialog)                                    │
│ ✓ Mark complete (checkbox with strikethrough)                   │
│ ✓ Delete task (confirmation dialog)                             │
│ ✓ See task count                                                │
│ ✓ All state persists during session                             │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Core Components

### 3.1 WidgetModel (Updated)
**File:** `lib/models/widget_model.dart`

**New Fields for Composite Support:**
```dart
class WidgetModel {
  final String id;
  final String type;
  double x, y, width, height;
  Map<String, dynamic> properties;
  String? boundTable;
  String? boundField;
  List<WidgetModel> children;        // NEW: Child widgets for composite
  Map<String, dynamic> state;        // NEW: Widget-specific state
}
```

**Why These Matter:**
- `children`: Allows nesting widgets (e.g., todo can contain checkboxes, buttons)
- `state`: Stores widget-specific data like tasks list, without needing external state management

**Serialization:**
```dart
// All data persists in database via toMap()/fromMap()
WidgetModel.toMap() includes:
  - children: List of child widget maps
  - state: Task list, checkboxes, etc.
```

---

### 3.2 Task Model (New)
**File:** `lib/models/task_model.dart`

```dart
class Task {
  final String id;        // Unique task ID
  String title;          // Task name
  bool isCompleted;      // Completion status
}
```

**Used By:** TodoWidget to manage task data.

---

### 3.3 TodoWidget (New)
**File:** `lib/widgets/todo_widget.dart`

**Type:** StatefulWidget

**State Management:**
```dart
class _TodoWidgetState extends State<TodoWidget> {
  late List<Task> tasks;  // All tasks stored here
  TextEditingController _inputController;
}
```

**Key Features:**

#### A. Add Task Dialog
```dart
void _showAddTaskDialog() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Add New Task'),
      content: TextField(
        controller: _inputController,
        onSubmitted: (_) => _addTask(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
        ElevatedButton(onPressed: _addTask, child: Text('Add')),
      ],
    ),
  );
}

void _addTask() {
  setState(() {
    tasks.add(Task(
      id: uuid.v4(),
      title: _inputController.text,
      isCompleted: false,
    ));
  });
}
```

#### B. Task Completion Toggle
```dart
void _toggleTask(String taskId) {
  setState(() {
    final task = tasks.firstWhere((t) => t.id == taskId);
    task.isCompleted = !task.isCompleted;
  });
}

// In UI:
Checkbox(
  value: task.isCompleted,
  onChanged: (_) => _toggleTask(task.id),
)
```

#### C. Delete with Confirmation
```dart
void _showDeleteConfirmation(String taskId, String taskTitle) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Task?'),
      content: Text('Are you sure you want to delete "$taskTitle"?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            _deleteTask(taskId);
          },
          child: Text('Delete'),
        ),
      ],
    ),
  );
}

void _deleteTask(String taskId) {
  setState(() {
    tasks.removeWhere((t) => t.id == taskId);
  });
}
```

#### D. Render UI
```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      backgroundColor: widget.primaryColor,
    ),
    body: tasks.isEmpty
        ? _emptyState()
        : ListView.separated(
            itemCount: tasks.length,
            itemBuilder: (_, i) => _buildTaskTile(tasks[i]),
          ),
    floatingActionButton: FloatingActionButton(
      onPressed: _showAddTaskDialog,
      child: const Icon(Icons.add),
    ),
  );
}

Widget _buildTaskTile(Task task) {
  return ListTile(
    leading: Checkbox(
      value: task.isCompleted,
      onChanged: (_) => _toggleTask(task.id),
    ),
    title: Text(
      task.title,
      style: TextStyle(
        decoration: task.isCompleted ? TextDecoration.lineThrough : null,
      ),
    ),
    trailing: IconButton(
      icon: Icon(Icons.delete_outline),
      onPressed: () => _showDeleteConfirmation(task.id, task.title),
    ),
  );
}
```

---

### 3.4 Canvas Renderer (Updated)
**File:** `lib/screens/builder/canvas_area.dart`

**In WidgetRenderer.build():**
```dart
switch(widgetModel.type) {
  case 'todo':
    return _buildTodoWidget(props, w, h);
}
```

**_buildTodoWidget() Function:**
```dart
Widget _buildTodoWidget(Map<String, dynamic> props, double w, double h) {
  return SizedBox(
    width: w,
    height: h,
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Header
          Container(
            color: _c(props, 'color', AppTheme.primary),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.task_alt, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  _s(props, 'title', 'My Tasks'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          // Preview task list
          Expanded(
            child: _buildTaskListPreview(props),
          ),
        ],
      ),
    ),
  );
}
```

**Why Two Representations?**
1. **In Builder (_buildTodoWidget):** Shows preview with sample tasks
   - Read-only (can't actually add/delete in builder)
   - Shows what it will look like
   - Shows task count

2. **In App (TodoWidget):** Full functional widget
   - Real add/delete/toggle
   - State management
   - Dialogs and interactions

---

## 4. How to Build More Composite Widgets

### Example: Building a "Survey" Composite Widget

```dart
// Step 1: Create Data Model
// lib/models/survey_model.dart
class SurveyQuestion {
  String id;
  String question;
  String selectedAnswer;
}

// Step 2: Update WidgetModel
// Add 'survey' to defaultPropsFor
'survey': {
  'title': 'Quick Survey',
  'color': '#00C896',
}

// Add height to defaultHeightFor
'survey': 280.0,

// Step 3: Create Stateful Widget
// lib/widgets/survey_widget.dart
class SurveyWidget extends StatefulWidget {
  final String title;
  final Color primaryColor;
  
  @override
  State<SurveyWidget> createState() => _SurveyWidgetState();
}

class _SurveyWidgetState extends State<SurveyWidget> {
  late List<SurveyQuestion> questions;
  
  void _submitSurvey() {
    // Collect answers and submit
  }
  
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: questions.map((q) => RadioListTile(...)).toList(),
    );
  }
}

// Step 4: Add to WidgetRenderer
// lib/screens/builder/canvas_area.dart
case 'survey':
  return _buildSurveyWidget(props, w, h);

Widget _buildSurveyWidget(Map<String, dynamic> props, double w, double h) {
  // Return preview
}

// Step 5: Add to Widget Panel
// lib/screens/builder/widget_panel.dart
'Composite': [
  {'type': 'survey', 'label': 'Survey', 'icon': '📋', 'color': 0xFF00C896},
  {'type': 'todo', 'label': 'Todo', 'icon': '✓', 'color': 0xFF00C896},
]
```

---

## 5. State Persistence

### Option 1: Session State (Temporary)
Current implementation - tasks reset when app closes:
```dart
late List<Task> tasks;  // In _TodoWidgetState
// Created in initState, destroyed when widget closes
```

### Option 2: Local State (Persistent)
Save to widgetModel.state in WidgetData:
```dart
// In todo_widget.dart
void _addTask() {
  setState(() {
    tasks.add(Task(...));
    // Save to widget model
    widget.onStateChanged?.(tasks); // Callback to parent
  });
}
```

### Option 3: Database Persistence
Save to Firestore:
```dart
void _addTask() {
  final task = Task(...);
  await FirestoreService.addTask(task);
  setState(() => tasks.add(task));
}
```

---

## 6. Files Created/Modified

### New Files
✅ `lib/models/task_model.dart` - Task data model
✅ `lib/widgets/todo_widget.dart` - Full functional Todo widget

### Modified Files
✅ `lib/models/widget_model.dart` - Added children & state fields
✅ `lib/screens/builder/canvas_area.dart` - Added 'todo' case
✅ `lib/screens/builder/widget_panel.dart` - Added 'Composite' category

---

## 7. Key Advantages

| Feature | Before | After |
|---------|--------|-------|
| **Functionality** | UI-only widgets | Full working widgets |
| **State** | No state | Built-in state management |
| **Interactions** | Click handlers | Real add/delete/toggle |
| **Dialogs** | Manual setup | Built-in dialogs |
| **Reusability** | Single-use widgets | Drag multiple instances |
| **Composition** | Flat widgets | Nested/composite support |
| **Data Persistence** | Not possible | Via widget.state |

---

## 8. Testing the Todo Widget

### In Builder (Preview Mode)
1. Open Widget Panel → Composite category
2. Drag "Todo Widget" onto canvas
3. See preview with sample tasks
4. Edit properties (title, color)
5. See changes update immediately

### In App (Full Functionality)
1. Click "Run" or "Preview App"
2. Click "+" button to add task
3. Type task name and press "Add"
4. Check checkbox to mark complete
5. Click trash icon to delete (confirm)
6. Empty state when no tasks

---

## 9. Architecture Summary

```
COMPOSITE WIDGET SYSTEM
│
├─ Data Layer
│  ├─ task_model.dart (Task data)
│  ├─ widget_model.dart (Extended with state & children)
│  └─ survey_model.dart (Future composite widgets)
│
├─ UI Layer
│  ├─ todo_widget.dart (Full stateful widget)
│  ├─ survey_widget.dart (Future)
│  └─ canvas_area.dart (Preview rendering)
│
├─ Interaction Layer
│  ├─ Add task dialog
│  ├─ Delete confirmation
│  ├─ Checkbox toggle
│  └─ FloatingActionButton
│
└─ Integration Layer
   ├─ widget_panel.dart (Draggable composite)
   ├─ builder_provider.dart (Widget creation)
   └─ canvas_area.dart (Preview + rendering)
```

---

## 10. Next Steps

1. **Add more composite widgets** (Survey, Shopping Cart, Chat)
2. **Add state persistence** (Save tasks to Firestore)
3. **Add child widget support** (Let users add custom child widgets to composites)
4. **Add animations** (Slide/fade when adding/deleting tasks)
5. **Add validation** (Empty task names, duplicate prevention)

