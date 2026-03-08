class WidgetModel {
  final String id;
  final String type;
  double x, y, width, height;
  Map<String, dynamic> properties;
  String? boundTable;
  String? boundField;

  WidgetModel({
    required this.id, required this.type,
    this.x = 20, this.y = 20, this.width = 300, this.height = 52,
    this.properties = const {}, this.boundTable, this.boundField,
  });

  factory WidgetModel.fromMap(Map<String, dynamic> m) => WidgetModel(
    id: m['id'], type: m['type'],
    x: (m['x'] as num).toDouble(), y: (m['y'] as num).toDouble(),
    width: (m['width'] as num).toDouble(), height: (m['height'] as num).toDouble(),
    properties: Map<String, dynamic>.from(m['properties'] ?? {}),
    boundTable: m['boundTable'], boundField: m['boundField'],
  );

  Map<String, dynamic> toMap() => {
    'id': id, 'type': type, 'x': x, 'y': y,
    'width': width, 'height': height, 'properties': properties,
    'boundTable': boundTable, 'boundField': boundField,
  };

  static Map<String, dynamic> defaultPropsFor(String type) => {
    'button':   {'label': 'Button', 'color': '#00C896', 'textColor': '#FFFFFF', 'fontSize': 16.0, 'action': 'none', 'borderRadius': 12.0},
    'text':     {'content': 'Sample Text', 'fontSize': 16.0, 'color': '#F0FFF8', 'bold': false, 'align': 'left'},
    'input':    {'hint': 'Enter text...', 'label': 'Field', 'type': 'text'},
    'image':    {'src': '', 'fit': 'cover', 'borderRadius': 8.0},
    'card':     {'title': 'Card Title', 'subtitle': 'Subtitle text'},
    'list':     {'items': ['Item 1', 'Item 2', 'Item 3'], 'divider': true},
    'grid':     {'columns': 2},
    'navbar':   {'items': 'Home,Search,Profile', 'color': '#00C896'},
    'appbar':   {'title': 'My App', 'color': '#00C896'},
    'dropdown': {'hint': 'Select...', 'options': 'Option 1,Option 2,Option 3'},
    'checkbox': {'label': 'Check me', 'checked': false},
    'switch_w': {'label': 'Toggle', 'value': false},
    'divider':  {'color': '#2E4A5A', 'thickness': 1.0},
    'icon':     {'name': 'star', 'color': '#FFD700', 'size': 40.0},
    'form':     {'fields': 'Name,Email,Phone', 'submitLabel': 'Submit'},
    'chart':    {'type': 'bar', 'color': '#00C896'},
  }[type] ?? {};

  static double defaultHeightFor(String type) => {
    'button': 52.0, 'text': 40.0, 'input': 56.0, 'card': 120.0,
    'image': 180.0, 'list': 160.0, 'grid': 200.0, 'navbar': 64.0,
    'appbar': 56.0, 'chart': 160.0, 'form': 200.0, 'divider': 16.0,
    'dropdown': 56.0, 'checkbox': 44.0, 'switch_w': 44.0,
  }[type] ?? 60.0;
}