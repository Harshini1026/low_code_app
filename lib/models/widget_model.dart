class WidgetModel {
  final String id;
  final String type;
  double x, y, width, height;
  Map<String, dynamic> properties;
  String? boundTable;
  String? boundField;
  List<WidgetModel> children;
  Map<String, dynamic> state;

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
    this.children = const [],
    this.state = const {},
  });

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
                .toList() ??
            [],
        state: Map<String, dynamic>.from(m['state'] ?? {}),
      );

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

  // ── FIX 1: Removed duplicate keys ('dropdown', 'list', 'grid') from the map
  // literal. Dart silently uses the last value for duplicate keys, which caused
  // the first definitions for those types to be ignored entirely.
  static Map<String, dynamic> defaultPropsFor(String type) =>
      {
        'button': {
          'label': 'Button',
          'color': '#00C896',
          'textColor': '#FFFFFF',
          'fontSize': 16.0,
          'action': 'none',
          'borderRadius': 12.0,
        },
        'text': {
          'content': 'Sample Text',
          'fontSize': 16.0,
          'color': '#F0FFF8',
          'bold': false,
          'align': 'left',
        },
        'input': {'hint': 'Enter text...', 'label': 'Field', 'type': 'text'},
        'image': {'src': '', 'fit': 'cover', 'borderRadius': 8.0},
        'card': {'title': 'Card Title', 'subtitle': 'Subtitle text'},
        'navbar': {'items': 'Home,Search,Profile', 'color': '#00C896'},
        'appbar': {'title': 'My App', 'color': '#00C896'},
        // ── FIX 1a: Single canonical 'dropdown' entry (was duplicated)
        'dropdown': {
          'hint': 'Select...',
          'options': 'Option 1,Option 2,Option 3',
          'color': '#00C896',
        },
        'checkbox': {'label': 'Check me', 'checked': false, 'color': '#00C896'},
        'switch_w': {'label': 'Toggle', 'value': false, 'color': '#00C896'},
        'divider': {'color': '#2E4A5A', 'thickness': 1.0},
        'icon': {'name': 'star', 'color': '#FFD700', 'size': 40.0},
        'form': {'fields': 'Name,Email,Phone', 'submitLabel': 'Submit'},
        'chart': {'type': 'bar', 'color': '#00C896'},
        // ── FIX 1b: Single canonical 'list' entry (was duplicated).
        // Use string for items so the _list() helper in WidgetRenderer parses it.
        'list': {'items': 'Item 1,Item 2,Item 3', 'divider': true},
        // ── FIX 1c: Single canonical 'grid' entry (was duplicated)
        'grid': {
          'columns': 2.0,
          'items': 'Item 1,Item 2,Item 3,Item 4,Item 5,Item 6',
        },
        'checkbox_todo': {'items': 'Todo 1,Todo 2,Todo 3', 'color': '#00C896'},
        'container': {
          'label': 'Container',
          'bgColor': '#E8E8E8',
          'borderColor': '#CCCCCC',
          'borderWidth': 1.0,
          'borderRadius': 8.0,
          'width': 200.0,
          'height': 100.0,
        },
        'todo': {
          'title': 'My Tasks',
          'color': '#00C896',
          'emptyMessage': 'No tasks yet. Add one!',
        },
      }[type] ??
      {};

  static double defaultHeightFor(String type) =>
      {
        'button': 52.0,
        'text': 40.0,
        'input': 56.0,
        'card': 120.0,
        'image': 180.0,
        'list': 160.0,
        'grid': 200.0,
        'navbar': 64.0,
        'appbar': 56.0,
        'chart': 160.0,
        'form': 200.0,
        'divider': 16.0,
        'dropdown': 56.0,
        'checkbox': 44.0,
        'checkbox_todo': 120.0,
        'switch_w': 44.0,
        'container': 100.0,
        'icon': 64.0,
        'todo': 300.0,
      }[type] ??
      60.0;

  double get safeWidth => (width <= 0) ? 300 : width;
  double get safeHeight => (height <= 0) ? defaultHeightFor(type) : height;
}