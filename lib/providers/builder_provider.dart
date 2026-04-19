import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/project_model.dart';
import '../models/screen_model.dart';
import '../models/widget_model.dart';
import '../services/firestore_service.dart';

class BuilderProvider extends ChangeNotifier {
  final _fs = FirestoreService();
  final _uuid = const Uuid();
  ProjectModel? _project;
  bool get canUndo => _history.isNotEmpty;

  int _activeScreen = 0;
  WidgetModel? _selectedWidget;
  bool _isLoading = false, _isSaving = false;
  final List<ProjectModel> _history = [];

  ProjectModel? get project => _project;
  int get activeScreenIndex => _activeScreen;
  AppScreen? get activeScreen => _project?.screens.isNotEmpty == true
      ? _project!.screens[_activeScreen]
      : null;
  String? get currentScreenId => activeScreen?.id;
  WidgetModel? get selectedWidget => _selectedWidget;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  List<WidgetModel> get currentWidgets => activeScreen?.widgets ?? [];

  Future<void> loadProject(String id) async {
    _isLoading = true;
    notifyListeners();
    _project = await _fs.getProject(id);
    _activeScreen = 0;
    _isLoading = false;
    notifyListeners();
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

  Future<void> _autosave() async {
    if (_project == null) return;
    _isSaving = true;
    notifyListeners();
    await _fs.updateProject(_project!);
    _isSaving = false;
    notifyListeners();
  }

  void applyProject(ProjectModel updated) {
    _project = updated;
    notifyListeners();
    _autosave();
  }
}