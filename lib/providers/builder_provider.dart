import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/project_model.dart';
import '../models/screen_model.dart';
import '../models/widget_model.dart';
import '../services/firestore_service.dart';
import '../services/project_persistence_service.dart';

class BuilderProvider extends ChangeNotifier {
  // ── Service instances ─────────────────────────────────────────────────
  final _fs = FirestoreService();
  final _persistence = ProjectPersistenceService();
  final _uuid = const Uuid();

  // ── Private fields (declare all fields BEFORE getters) ─────────────────
  ProjectModel? _project;
  int _activeScreen = 0;
  WidgetModel? _selectedWidget;
  bool _isLoading = false;
  bool _isSaving = false;
  DateTime? _lastSavedTime;
  final List<ProjectModel> _history = [];
  List<ProjectModel> _allProjects = [];
  String? _currentActiveProjectId;

  // ── Public getters (declare AFTER all fields) ───────────────────────────
  bool get canUndo => _history.isNotEmpty;
  ProjectModel? get project => _project;
  int get activeScreenIndex => _activeScreen;
  AppScreen? get activeScreen => _project?.screens.isNotEmpty == true
      ? _project!.screens[_activeScreen]
      : null;
  String? get currentScreenId => activeScreen?.id;
  WidgetModel? get selectedWidget => _selectedWidget;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  DateTime? get lastSavedTime => _lastSavedTime;
  List<ProjectModel> get allProjects => _allProjects;
  String? get currentActiveProjectId => _currentActiveProjectId;
  List<WidgetModel> get currentWidgets => activeScreen?.widgets ?? [];

  Future<void> loadProject(String id) async {
    try {
      _isLoading = true;
      notifyListeners();

      // ✅ FIX: Get userId from current Firebase user
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

      // ✅ FIX: Try persistence service first (local + Firebase fallback)
      ProjectModel? loaded =
          await _persistence.loadProject(id, userId) ??
          await _fs.getProject(id);

      // ✅ PREVENT EMPTY OVERWRITE: Only set if project loaded successfully
      if (loaded != null) {
        _project = loaded;
        _currentActiveProjectId = loaded.id;
        _activeScreen = 0;
      } else {
        debugPrint('⚠️ Project failed to load: $id');
        _project = null;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading project: $e');
      _isLoading = false;
      _project = null;
      notifyListeners();
    }
  }

  /// Load all projects for current user (from local cache)
  Future<void> loadAllProjects(String userId) async {
    try {
      _allProjects = await _persistence.getCachedUserProjects(userId);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading all projects: $e');
      _allProjects = [];
      notifyListeners();
    }
  }

  void setActiveScreen(int i) {
    _activeScreen = i;
    _selectedWidget = null;
    notifyListeners();
  }

  void setCurrentScreen(String id) {
    if (_project == null) return;
    final index = _project!.screens.indexWhere((s) => s.id == id);
    if (index != -1) {
      _activeScreen = index;
      _selectedWidget = null;
      notifyListeners();
    }
  }

  void addScreen(String name) {
    if (_project == null) return;
    _saveHistory();
    final s = AppScreen(id: _uuid.v4(), name: name);
    _project = _project!.copyWith(screens: [..._project!.screens, s]);
    _activeScreen = _project!.screens.length - 1;
    notifyListeners();
    _autosave();
  }

  void removeScreen(int i) {
    if (_project == null || _project!.screens.length <= 1) return;
    _saveHistory();
    final screens = [..._project!.screens]..removeAt(i);
    _project = _project!.copyWith(screens: screens);
    if (_activeScreen >= screens.length) _activeScreen = screens.length - 1;
    notifyListeners();
    _autosave();
  }

  void renameScreen(int i, String newName) {
    if (_project == null || newName.trim().isEmpty) return;
    _saveHistory();
    final screens = _project!.screens
        .asMap()
        .map(
          (idx, s) => MapEntry(
            idx,
            idx == i
                ? AppScreen(id: s.id, name: newName.trim(), widgets: s.widgets)
                : s,
          ),
        )
        .values
        .toList();
    _project = _project!.copyWith(screens: screens);
    notifyListeners();
    _autosave();
  }

  void addWidget(String type, double x, double y) {
    if (_project == null || activeScreen == null) return;
    _saveHistory();
    final w = WidgetModel(
      id: _uuid.v4(),
      type: type,
      x: x.clamp(0, 320),
      y: y.clamp(0, 680),
      width: 300,
      height: WidgetModel.defaultHeightFor(type),
      // ── FIX 2: Use Map.from() to ensure the properties map is always
      // a mutable copy. Without this, widgets sharing the same default props
      // reference could corrupt each other's state when one is mutated.
      properties: Map<String, dynamic>.from(WidgetModel.defaultPropsFor(type)),
    );
    _updateScreenWidgets([...activeScreen!.widgets, w]);
    _selectedWidget = w;
    notifyListeners();
    _autosave();
  }

  void selectWidget(WidgetModel? w) {
    _selectedWidget = w;
    notifyListeners();
  }

  void moveWidget(String id, double x, double y) {
    _updateWidget(id, (w) {
      w.x = x.clamp(0, 320);
      w.y = y.clamp(0, 680);
    });
    // ── FIX 3: Keep _selectedWidget reference in sync after a move so the
    // Properties panel reflects the correct position immediately.
    if (_selectedWidget?.id == id) {
      _selectedWidget!.x = x.clamp(0, 320);
      _selectedWidget!.y = y.clamp(0, 680);
    }
    notifyListeners();
    _autosave();
  }

  void updateWidgetProperty(String id, String key, dynamic value) {
    _updateWidget(id, (w) => w.properties[key] = value);
    // ── FIX 4: Mirror the change into _selectedWidget so the canvas widget
    // (which reads from provider.selectedWidget) re-renders immediately.
    // Previously only the list copy was updated; the selected reference was stale.
    if (_selectedWidget?.id == id) {
      _selectedWidget!.properties[key] = value;
    }
    notifyListeners();
    _autosave();
  }

  // ── FIX 5: New method — update width/height of a widget and propagate
  // to _selectedWidget so the canvas resizes the widget in real time.
  void updateWidgetSize(String id, double width, double height) {
    _updateWidget(id, (w) {
      w.width = width.clamp(60, 320);
      w.height = height.clamp(20, 600);
    });
    if (_selectedWidget?.id == id) {
      _selectedWidget!.width = width.clamp(60, 320);
      _selectedWidget!.height = height.clamp(20, 600);
    }
    notifyListeners();
    _autosave();
  }

  void removeWidget(String id) {
    if (activeScreen == null) return;
    _saveHistory();
    _updateScreenWidgets(
      activeScreen!.widgets.where((w) => w.id != id).toList(),
    );
    if (_selectedWidget?.id == id) _selectedWidget = null;
    notifyListeners();
    _autosave();
  }

  void duplicateWidget(String id) {
    if (activeScreen == null) return;
    final orig = activeScreen!.widgets.firstWhere((w) => w.id == id);
    final copy = WidgetModel(
      id: _uuid.v4(),
      type: orig.type,
      x: orig.x + 16,
      y: orig.y + 16,
      width: orig.width,
      height: orig.height,
      // ── FIX 6: Deep-copy properties so the duplicate is fully independent.
      properties: Map<String, dynamic>.from(orig.properties),
    );
    _updateScreenWidgets([...activeScreen!.widgets, copy]);
    _selectedWidget = copy;
    notifyListeners();
    _autosave();
  }

  void bindWidgetToData(String id, String table, String field) {
    _updateWidget(id, (w) {
      w.boundTable = table;
      w.boundField = field;
    });
    notifyListeners();
    _autosave();
  }

  // ── NEW: Add a child widget to a Row/Column
  void addChildWidget(String parentId, String childType) {
    _updateWidget(parentId, (parent) {
      if (parent.type == 'row' || parent.type == 'column') {
        final childWidget = WidgetModel(
          id: _uuid.v4(),
          type: childType,
          x: 0,
          y: 0,
          width: 100,
          height: WidgetModel.defaultHeightFor(childType),
          properties: Map<String, dynamic>.from(
            WidgetModel.defaultPropsFor(childType),
          ),
        );
        parent.children = [...parent.children, childWidget];
      } else if (parent.type == 'singlechildscrollview') {
        // ── SingleChildScrollView: Only allow ONE child
        // If a child already exists, replace it (or show warning)
        final childWidget = WidgetModel(
          id: _uuid.v4(),
          type: childType,
          x: 0,
          y: 0,
          width: 100,
          height: WidgetModel.defaultHeightFor(childType),
          properties: Map<String, dynamic>.from(
            WidgetModel.defaultPropsFor(childType),
          ),
        );
        parent.children = [childWidget];
      }
    });
    if (_selectedWidget?.id == parentId) {
      _selectedWidget = activeScreen?.widgets.firstWhere(
        (w) => w.id == parentId,
        orElse: () => _selectedWidget!,
      );
    }
    notifyListeners();
    _autosave();
  }

  // ── NEW: Remove a child widget from Row/Column
  void removeChildWidget(String parentId, String childId) {
    _updateWidget(parentId, (parent) {
      parent.children = parent.children.where((c) => c.id != childId).toList();
    });
    notifyListeners();
    _autosave();
  }

  // ── NEW: Update a child widget's properties
  void updateChildProperty(
    String parentId,
    String childId,
    String key,
    dynamic value,
  ) {
    _updateWidget(parentId, (parent) {
      for (final child in parent.children) {
        if (child.id == childId) {
          child.properties[key] = value;
          break;
        }
      }
    });
    notifyListeners();
    _autosave();
  }

  // ── NEW: Update child widget size
  void updateChildSize(
    String parentId,
    String childId,
    double width,
    double height,
  ) {
    _updateWidget(parentId, (parent) {
      for (final child in parent.children) {
        if (child.id == childId) {
          child.width = width.clamp(40, 320);
          child.height = height.clamp(20, 600);
          break;
        }
      }
    });
    notifyListeners();
    _autosave();
  }

  void updateTheme(ProjectTheme theme) {
    _project = _project?.copyWith(theme: theme);
    notifyListeners();
    _autosave();
  }

  void addTable(String name, List<String> fields) {
    if (_project == null) return;
    final t = DatabaseTable(id: _uuid.v4(), name: name, fields: fields);
    final cfg = _project!.backendConfig;
    _project = _project!.copyWith(
      backendConfig: BackendConfig(
        tables: [...cfg.tables, t],
        emailAuth: cfg.emailAuth,
        googleAuth: cfg.googleAuth,
      ),
    );
    notifyListeners();
    _autosave();
  }

  void undo() {
    if (_history.isNotEmpty) {
      _project = _history.removeLast();
      _selectedWidget = null;
      notifyListeners();
    }
  }

  void _updateWidget(String id, void Function(WidgetModel) fn) {
    if (activeScreen == null) return;
    for (final w in activeScreen!.widgets) {
      if (w.id == id) fn(w);
    }
    _updateScreenWidgets(activeScreen!.widgets);
  }

  void _updateScreenWidgets(List<WidgetModel> widgets) {
    if (_project == null) return;
    final screens = _project!.screens
        .asMap()
        .map(
          (i, s) => MapEntry(
            i,
            i == _activeScreen
                ? AppScreen(id: s.id, name: s.name, widgets: widgets)
                : s,
          ),
        )
        .values
        .toList();
    _project = _project!.copyWith(screens: screens);
  }

  void _saveHistory() {
    if (_project != null) {
      _history.add(_project!);
      if (_history.length > 20) _history.removeAt(0);
    }
  }

  /// Debounced auto-save on every change
  /// Fires after 400ms of inactivity to avoid excessive writes
  void _autosave() {
    // ✅ PREVENT EMPTY OVERWRITE: Only save if project exists and has data
    if (_project == null || _project!.id.isEmpty) {
      return;
    }

    _isSaving = true;
    notifyListeners();

    _persistence.debouncedSaveProject(_project!);

    // Reset saving state after a short delay
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_isSaving) {
        _isSaving = false;
        _lastSavedTime = DateTime.now();
        notifyListeners();
      }
    });
  }

  /// Immediately save current project without debounce
  /// Use before switching projects or on critical operations
  Future<void> saveCurrentProject() async {
    // ✅ PREVENT EMPTY OVERWRITE: Only save if project exists and has data
    if (_project == null || _project!.id.isEmpty) {
      debugPrint('⚠️ Skipping save: Project is empty or null');
      return;
    }

    _isSaving = true;
    notifyListeners();

    try {
      await _persistence.saveProjectImmediately(_project!);
      _lastSavedTime = DateTime.now();
    } catch (e) {
      debugPrint('❌ Save failed: $e');
    }

    _isSaving = false;
    notifyListeners();
  }

  /// Switch to another project with auto-save of current
  Future<void> switchProject(String newProjectId) async {
    // Save current project before switching
    if (_project != null) {
      await saveCurrentProject();
    }

    // Load new project
    await loadProject(newProjectId);
    _currentActiveProjectId = newProjectId;
    notifyListeners();
  }

  /// Cleanup on provider disposal
  @override
  void dispose() {
    _persistence.cancelPendingSaves();
    super.dispose();
  }

  void applyProject(ProjectModel updated) {
    _project = updated;
    notifyListeners();
    _autosave();
  }
}
