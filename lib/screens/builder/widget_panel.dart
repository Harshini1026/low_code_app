import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

const _categories = {
  'Basic': [
    {'type': 'text',    'label': 'Text',    'icon': '📝', 'color': 0xFF6C63FF},
    {'type': 'button',  'label': 'Button',  'icon': '⬛', 'color': 0xFF00C896},
    {'type': 'image',   'label': 'Image',   'icon': '🖼',  'color': 0xFF3498DB},
    {'type': 'icon',    'label': 'Icon',    'icon': '⭐', 'color': 0xFFF39C12},
    {'type': 'divider', 'label': 'Divider', 'icon': '—',  'color': 0xFF95A5A6},
  ],
  'Forms': [
    {'type': 'input',    'label': 'Text Field', 'icon': '📋', 'color': 0xFFE74C3C},
    {'type': 'dropdown', 'label': 'Dropdown',   'icon': '▼',  'color': 0xFF9B59B6},
    {'type': 'checkbox', 'label': 'Checkbox',   'icon': '☑',  'color': 0xFF1ABC9C},
    {'type': 'switch_w', 'label': 'Switch',     'icon': '🔄', 'color': 0xFF2ECC71},
    {'type': 'form',     'label': 'Form',       'icon': '📄', 'color': 0xFF16A085},
  ],
  'Layout': [
    {'type': 'card',   'label': 'Card',    'icon': '🃏', 'color': 0xFF6C63FF},
    {'type': 'list',   'label': 'List',    'icon': '📋', 'color': 0xFF00C896},
    {'type': 'grid',   'label': 'Grid',    'icon': '⊞',  'color': 0xFFFF6B35},
    {'type': 'navbar', 'label': 'Nav Bar', 'icon': '🧭', 'color': 0xFF2C3E50},
    {'type': 'appbar', 'label': 'App Bar', 'icon': '📊', 'color': 0xFF16A085},
    {'type': 'tabs',   'label': 'Tabs',    'icon': '📑', 'color': 0xFF8E44AD},
  ],
  'Media': [
    {'type': 'chart',    'label': 'Chart',    'icon': '📈', 'color': 0xFF2980B9},
    {'type': 'map',      'label': 'Map',      'icon': '🗺',  'color': 0xFF27AE60},
    {'type': 'video',    'label': 'Video',    'icon': '🎬', 'color': 0xFFC0392B},
    {'type': 'carousel', 'label': 'Carousel', 'icon': '🎠', 'color': 0xFF8E44AD},
  ],
};

class WidgetPanel extends StatefulWidget {
  final Function(String type) onAdd;
  const WidgetPanel({super.key, required this.onAdd});

  @override
  State<WidgetPanel> createState() => _WidgetPanelState();
}

class _WidgetPanelState extends State<WidgetPanel> {
  String _activeCategory = 'Basic';
  String _search = '';

  List<Map> get _items {
    if (_search.isNotEmpty) {
      return _categories.values
          .expand((v) => v)
          .where((w) => (w['label'] as String).toLowerCase().contains(_search.toLowerCase()))
          .toList();
    }
    return _categories[_activeCategory] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [

      // Search bar
      Padding(
        padding: const EdgeInsets.all(10),
        child: TextField(
          onChanged: (v) => setState(() => _search = v),
          style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Search widgets...',
            prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.textMuted),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            isDense: true,
          ),
        ),
      ),

      // Category tabs (hidden when searching)
      if (_search.isEmpty)
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: _categories.keys.map((cat) {
              final active = cat == _activeCategory;
              return GestureDetector(
                onTap: () => setState(() => _activeCategory = cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: active ? AppTheme.primary.withOpacity(0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: active ? AppTheme.primary : AppTheme.darkBorder),
                  ),
                  child: Text(cat,
                    style: TextStyle(
                      color: active ? AppTheme.primary : AppTheme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    )),
                ),
              );
            }).toList(),
          ),
        ),

      const SizedBox(height: 8),

      // Widget grid
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.1,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _items.length,
            itemBuilder: (_, i) {
              final w = _items[i];
              final color = Color(w['color'] as int);
              return Draggable<String>(
                data: w['type'] as String,
                feedback: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 12)],
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(w['icon'] as String, style: const TextStyle(fontSize: 24)),
                      Text(w['label'] as String, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
                childWhenDragging: Opacity(opacity: 0.4, child: _Tile(w, color, () {})),
                child: _Tile(w, color, () => widget.onAdd(w['type'] as String)),
              );
            },
          ),
        ),
      ),
    ]);
  }
}

class _Tile extends StatefulWidget {
  final Map w;
  final Color color;
  final VoidCallback onTap;
  const _Tile(this.w, this.color, this.onTap);

  @override
  State<_Tile> createState() => _TileState();
}

class _TileState extends State<_Tile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _hovered ? widget.color.withOpacity(0.1) : AppTheme.darkSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _hovered ? widget.color : AppTheme.darkBorder),
          boxShadow: _hovered ? [BoxShadow(color: widget.color.withOpacity(0.2), blurRadius: 8)] : [],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: widget.color.withOpacity(0.3)),
            ),
            child: Center(child: Text(widget.w['icon'] as String, style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(height: 6),
          Text(widget.w['label'] as String,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center),
        ]),
      ),
    ),
  );
}
