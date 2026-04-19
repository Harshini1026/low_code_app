# 📦 Low-Code Widget System - Architecture Reference

## System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│ WidgetPanel (widget_panel.dart)                                     │
│ ┌─────────────────────────────────────────────────────────────┐   │
│ │ Draggable<String>                                           │   │
│ │ data: 'button' | 'text' | 'image' | 'card' | ...          │   │
│ │ feedback: Widget card showing icon + label                │   │
│ └─────────────────────────────────────────────────────────────┘   │
└────────────────────────────▼─────────────────────────────────────────┘
                           DRAG
┌─────────────────────────────────────────────────────────────────────┐
│ CanvasArea (canvas_area.dart)                                       │
│ ┌─────────────────────────────────────────────────────────────┐   │
│ │ DragTarget<String>                                          │   │
│ │ onAcceptWithDetails: (details) {                           │   │
│ │   final x = localPosition.dx                              │   │
│ │   final y = localPosition.dy                              │   │
│ │   provider.addWidget(details.data, x, y)  ← TYPE + POS   │   │
│ │ }                                                           │   │
│ └─────────────────────────────────────────────────────────────┘   │
└────────────────────────────▼─────────────────────────────────────────┘
                          CREATE
┌─────────────────────────────────────────────────────────────────────┐
│ BuilderProvider (builder_provider.dart)                             │
│ ┌─────────────────────────────────────────────────────────────┐   │
│ │ addWidget(String type, double x, double y) {              │   │
│ │   WidgetModel w = WidgetModel(                            │   │
│ │     id: uuid,                                             │   │
│ │     type: type,        ← 'button'|'text'|'image'|'card'  │   │
│ │     x: x, y: y,        ← Canvas position                 │   │
│ │     width: 300,        ← Default canvas width            │   │
│ │     height: heightFor(type),  ← Type-specific height     │   │
│ │     properties: propsFor(type) ← Default props            │   │
│ │   )                                                        │   │
│ │   addToScreen(w)                                          │   │
│ │ }                                                           │   │
│ └─────────────────────────────────────────────────────────────┘   │
└────────────────────────────▼─────────────────────────────────────────┘
                           RENDER
┌─────────────────────────────────────────────────────────────────────┐
│ CanvasArea → _PositionedWidget → WidgetRenderer (canvas_area.dart) │
│ ┌─────────────────────────────────────────────────────────────┐   │
│ │ switch(widgetModel.type) {                                │   │
│ │   case 'button':                                          │   │
│ │     return SizedBox(                                      │   │
│ │       width: widgetModel.width,      ← USE CANVAS SIZE   │   │
│ │       height: widgetModel.height,    ← USE CANVAS SIZE   │   │
│ │       child: ElevatedButton(...)                         │   │
│ │     )                                                     │   │
│ │   case 'text':                                            │   │
│ │     return SizedBox(                                      │   │
│ │       width: widgetModel.width,      ← USE CANVAS SIZE   │   │
│ │       height: widgetModel.height,    ← USE CANVAS SIZE   │   │
│ │       child: Text(...)                                  │   │
│ │     )                                                     │   │
│ │   // ... all cases follow same pattern                  │   │
│ │ }                                                         │   │
│ └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                    ✅ REAL WIDGET RENDERED
```

---

## Key Models

### **WidgetModel** (lib/models/widget_model.dart)

```dart
class WidgetModel {
  final String id;                      // Unique identifier (UUID)
  final String type;                    // 'button', 'text', 'image', 'card'
  double x, y;                          // Position on canvas
  double width, height;                 // ✅ CRITICAL: Canvas dimensions
  Map<String, dynamic> properties;      // Widget-specific properties
  String? boundTable;                   // Data binding (optional)
  String? boundField;                   // Data binding (optional)
}
```

**Default Dimensions:**
- All widgets: `width = 300` (default)
- Button: `height = 52`
- Text: `height = 40`
- Input: `height = 56`
- Card: `height = 120`
- Image: `height = 180`
- Icon: height from `defaultHeightFor(type)`

---

## Complete Widget Type Mapping

```dart
{
  'button': {
    'label': 'Button Text',
    'color': '#00C896',
    'textColor': '#FFFFFF',
    'fontSize': 16.0,
    'borderRadius': 12.0,
  },
  'text': {
    'content': 'Sample Text',
    'fontSize': 16.0,
    'color': '#F0FFF8',
    'bold': false,
    'align': 'left',
  },
  'image': {
    'src': '',              // Empty = placeholder
    'fit': 'cover',
    'borderRadius': 8.0,
  },
  'card': {
    'title': 'Card Title',
    'subtitle': 'Subtitle text',
    'elevation': 2.0,
  },
  'container': {
    'label': 'Container',
    'bgColor': '#E8E8E8',
    'borderColor': '#CCCCCC',
    'borderWidth': 1.0,
    'borderRadius': 8.0,
  },
  'input': {
    'hint': 'Enter text...',
    'label': 'Field',
    'type': 'text',
  },
  'icon': {
    'name': 'star',
    'color': '#FFD700',
    'size': 40.0,
  },
  'divider': {
    'color': '#2E4A5A',
    'thickness': 1.0,
  },
  'checkbox': {
    'label': 'Check me',
    'checked': false,
    'color': '#00C896',
  },
  'switch_w': {
    'label': 'Toggle',
    'value': false,
    'color': '#00C896',
  },
  'appbar': {
    'title': 'Screen Title',
    'color': '#00C896',
    'showBack': false,
  },
  'navbar': {
    'items': 'Home,Search,Profile',
    'color': '#00C896',
  },
}
```

---

## Rendering Pattern (WidgetRenderer)

All widgets now follow this pattern:

```dart
case 'widget_type':
  return SizedBox(
    width: widgetModel.width,       // ✅ Respect canvas width
    height: widgetModel.height,     // ✅ Respect canvas height
    child: /* actual widget */,
  );
```

**Key Improvements:**
1. **SizedBox wrapper** ensures dimensions are always respected
2. **SingleChildScrollView** prevents overflow for text-heavy widgets
3. **Center/Expanded** used for icons, dividers, centered widgets
4. **TextOverflow.ellipsis** prevents text from breaking layout
5. **Consistent styling** using helper methods (_c, _d, _s, _align)

---

## Helper Methods (in WidgetRenderer)

```dart
// Parse hex color string to Color
Color _c(Map<String, dynamic> p, String k, Color fb) { ... }

// Parse double from properties
double _d(Map<String, dynamic> p, String k, double fb) { ... }

// Parse string from properties
String _s(Map<String, dynamic> p, String k, String fb) { ... }

// Parse text alignment
TextAlign _align(String? v) { ... }
```

---

## Data Flow Example: Dropping a Button

```
1. USER ACTION
   ↓
   User drags "Button" from WidgetPanel

2. DRAG EVENT
   ↓
   Draggable<String>(
     data: 'button',  ← Type string
     feedback: /* visual card */
   )

3. DROP DETECTION
   ↓
   DragTarget.onAcceptWithDetails(details) {
     final x = 150.0    ← Drop X coordinate
     final y = 200.0    ← Drop Y coordinate
     provider.addWidget('button', 150.0, 200.0)
   }

4. WIDGET CREATION
   ↓
   BuilderProvider.addWidget('button', 150.0, 200.0) {
     WidgetModel w = WidgetModel(
       id: '12345',
       type: 'button',
       x: 150.0,
       y: 200.0,
       width: 300,           ← Canvas width
       height: 52,           ← Button height
       properties: {
         'label': 'Button',
         'color': '#00C896',
         'fontSize': 16.0,
         // ...
       }
     )
     screen.widgets.add(w)
     notifyListeners()
   }

5. RENDERING
   ↓
   CanvasArea rebuilds...
   _PositionedWidget(
     left: 150,
     top: 200,
     child: WidgetRenderer(model: w)
   )
   
   WidgetRenderer.build() {
     switch(w.type) {
       case 'button':
         return SizedBox(
           width: 300,         ← Canvas width
           height: 52,         ← Canvas height
           child: ElevatedButton(
             label: 'Button',
             color: Color(0xFF00C896),
             ...
           )
         )
     }
   }

6. RESULT ✅
   ↓
   ElevatedButton rendered at (150, 200)
   with dimensions 300×52
   and all properties applied
```

---

## File Structure

```
lib/
├── models/
│   ├── widget_model.dart          ← WidgetModel definition & defaults
│   ├── screen_model.dart          ← AppScreen, DatabaseTable
│   └── project_model.dart         ← ProjectModel
│
├── providers/
│   └── builder_provider.dart      ← addWidget(), createWidget(), etc.
│
├── screens/
│   └── builder/
│       ├── canvas_area.dart       ← DragTarget + WidgetRenderer (FIXED)
│       ├── widget_panel.dart      ← Draggable widgets
│       ├── properties_panel.dart  ← Edit widget properties
│       ├── builder_screen.dart    ← Main layout
│       ├── backend_panel.dart     ← Data binding
│       └── bind_data_panel.dart   ← Link to database
│
└── widgets/
    ├── draggable_component.dart   ← Selection/drag UI
    └── phone_frame_widget.dart    ← Canvas frame
```

---

## Common Tasks

### Add a New Widget Type

1. **Add to widget_panel.dart** (line 11-27):
```dart
const _categories = {
  'Basic': [
    // ...
    {'type': 'mywidget', 'label': 'My Widget', 'icon': '🎨', 'color': 0xFF...},
  ],
};
```

2. **Add default properties** in widget_model.dart:
```dart
'mywidget': {
  'label': 'Default Label',
  'color': '#00C896',
  // ... other props
},
```

3. **Add default height** in widget_model.dart:
```dart
static double defaultHeightFor(String type) => {
  // ...
  'mywidget': 60.0,
}[type] ?? 60.0;
```

4. **Add rendering case** in canvas_area.dart WidgetRenderer:
```dart
case 'mywidget':
  return SizedBox(
    width: w,
    height: h,
    child: MyWidget(
      /* use _c, _d, _s helpers for properties */
    ),
  );
```

---

## Testing Checklist

- [ ] Drag button → renders ElevatedButton at correct size
- [ ] Drag text → renders Text respecting width/height
- [ ] Drag image → shows placeholder at correct dimensions
- [ ] Drag card → shows Material card properly sized
- [ ] Drag container → renders as before (already worked)
- [ ] Resize widget in properties → dimensions update on canvas
- [ ] Change colors/labels → properties update immediately
- [ ] All widgets have overflow handling (no layout breaks)
- [ ] No case mismatch errors (all lowercase types)

---

## Performance Notes

- ✅ SizedBox is lightweight (no layout overhead)
- ✅ WidgetRenderer uses const constructors where possible
- ✅ Properties accessed with fallback defaults (no null errors)
- ✅ Switch-case is fast (vs. if-else chains)
- ✅ No widget rebuilds unless properties change

---

## Future Enhancements

1. Add widget resizing handles
2. Add z-index/layering
3. Add nested widgets (parent-child)
4. Add responsive sizing (percentages)
5. Add animation preview in builder
6. Add preview device skins (phone, tablet, web)
