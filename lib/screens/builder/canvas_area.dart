import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme/app_theme.dart';
import '../../models/screen_model.dart';
import '../../models/widget_model.dart';
import '../../providers/builder_provider.dart';

// ══════════════════════════════════════════════════════════════════════════════
// CanvasArea
// ══════════════════════════════════════════════════════════════════════════════
class CanvasArea extends StatefulWidget {
  final AppScreen? screen;
  final BuilderProvider provider;
  final Function(WidgetModel?) onWidgetSelected;

  const CanvasArea({
    super.key,
    required this.screen,
    required this.provider,
    required this.onWidgetSelected,
  });

  @override
  State<CanvasArea> createState() => _CanvasAreaState();
}

class _CanvasAreaState extends State<CanvasArea> {
  @override
  Widget build(BuildContext context) {
    final screen = widget.screen;
    final provider = widget.provider;
    final selected = provider.selectedWidget;

    if (screen == null) {
      return const Center(
        child: Text(
          'No screen selected',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
      );
    }

    return DragTarget<String>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final local = box.globalToLocal(details.offset);
        final x = local.dx.clamp(0.0, box.size.width - 100).toDouble();
        final y = local.dy.clamp(0.0, box.size.height - 80).toDouble();
        provider.addWidget(details.data, x, y);
      },
      builder: (context, candidateData, _) {
        final isHovering = candidateData.isNotEmpty;
        return GestureDetector(
          onTap: () {
            provider.selectWidget(null);
            widget.onWidgetSelected(null);
          },
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              border: isHovering
                  ? Border.all(color: AppTheme.primary, width: 2)
                  : null,
            ),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // Dot-grid background
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: _DotGridPainter()),
                  ),
                ),

                // Empty state hint
                if (screen.widgets.isEmpty) _EmptyHint(isHovering: isHovering),

                // ── FIX 7: Each placed widget is keyed by its model id so Flutter
                // can correctly reconcile widgets after add/remove/reorder operations
                // without confusing positions from stale widget state.
                ...screen.widgets.map(
                  (w) => _PositionedWidget(
                    key: ValueKey(w.id),
                    model: w,
                    isSelected: selected?.id == w.id,
                    onTap: () {
                      provider.selectWidget(w);
                      widget.onWidgetSelected(w);
                    },
                    onMoved: (pos) => provider.moveWidget(w.id, pos.dx, pos.dy),
                    // ── FIX 8: Wire resize events to the new updateWidgetSize
                    // method so width/height changes propagate to the canvas.
                    onResized: (width, height) =>
                        provider.updateWidgetSize(w.id, width, height),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Empty hint ────────────────────────────────────────────────────────────────
class _EmptyHint extends StatelessWidget {
  final bool isHovering;
  const _EmptyHint({required this.isHovering});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isHovering
                  ? AppTheme.primary.withOpacity(0.12)
                  : Colors.grey.withOpacity(0.07),
              border: Border.all(
                color: isHovering
                    ? AppTheme.primary
                    : Colors.grey.withOpacity(0.2),
                width: isHovering ? 2 : 1,
              ),
            ),
            child: Icon(
              isHovering ? Icons.add : Icons.widgets_outlined,
              color: isHovering
                  ? AppTheme.primary
                  : Colors.grey.withOpacity(0.35),
              size: 22,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isHovering ? 'Drop here' : 'Drag or tap a widget below',
            style: TextStyle(
              color: isHovering
                  ? AppTheme.primary
                  : Colors.grey.withOpacity(0.4),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dot grid ──────────────────────────────────────────────────────────────────
class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.grey.withOpacity(0.12)
      ..strokeWidth = 1;
    const step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.2, p);
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Positioned & draggable widget ─────────────────────────────────────────────
class _PositionedWidget extends StatefulWidget {
  final WidgetModel model;
  final bool isSelected;
  final VoidCallback onTap;
  final Function(Offset) onMoved;
  final Function(double width, double height) onResized;

  const _PositionedWidget({
    super.key,
    required this.model,
    required this.isSelected,
    required this.onTap,
    required this.onMoved,
    required this.onResized,
  });

  @override
  State<_PositionedWidget> createState() => _PositionedWidgetState();
}

class _PositionedWidgetState extends State<_PositionedWidget> {
  late Offset _pos;
  late double _width;
  late double _height;
  bool _dragging = false;

  // ── FIX 9: Track resize drag state separately from move drag state so
  // the two gestures don't interfere with each other.
  bool _resizing = false;
  Offset _resizeStart = Offset.zero;
  double _resizeStartW = 0;
  double _resizeStartH = 0;

  @override
  void initState() {
    super.initState();
    _syncFromModel();
  }

  @override
  void didUpdateWidget(_PositionedWidget old) {
    super.didUpdateWidget(old);
    // Only sync from model when we are not in the middle of dragging/resizing,
    // so live drag feels smooth and we don't fight the provider.
    if (!_dragging && !_resizing) {
      _syncFromModel();
    }
  }

  void _syncFromModel() {
    _pos = Offset(widget.model.x, widget.model.y);
    _width = widget.model.safeWidth;
    _height = widget.model.safeHeight;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _pos.dx,
      top: _pos.dy,
      child: GestureDetector(
        onTap: widget.onTap,
        onPanStart: (_) {
          widget.onTap(); // auto-select on drag start
          _dragging = true;
        },
        onPanUpdate: (d) {
          setState(() {
            _pos = Offset(
              (_pos.dx + d.delta.dx).clamp(0.0, 260.0),
              (_pos.dy + d.delta.dy).clamp(0.0, 520.0),
            );
          });
        },
        onPanEnd: (_) {
          _dragging = false;
          widget.onMoved(_pos);
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // ── The rendered widget itself ────────────────────────────
            _SelectionBorder(
              isSelected: widget.isSelected,
              child: WidgetRenderer(widgetModel: widget.model),
            ),

            // ── FIX 10: Resize handle — bottom-right corner drag dot.
            // Only visible when the widget is selected.
            if (widget.isSelected)
              Positioned(
                right: -8,
                bottom: -8,
                child: GestureDetector(
                  // Stop the pan from bubbling up to the move gesture.
                  onPanStart: (d) {
                    _resizing = true;
                    _resizeStart = d.globalPosition;
                    _resizeStartW = _width;
                    _resizeStartH = _height;
                  },
                  onPanUpdate: (d) {
                    final delta = d.globalPosition - _resizeStart;
                    setState(() {
                      _width = (_resizeStartW + delta.dx).clamp(80.0, 310.0);
                      _height = (_resizeStartH + delta.dy).clamp(24.0, 580.0);
                    });
                  },
                  onPanEnd: (_) {
                    _resizing = false;
                    widget.onResized(_width, _height);
                  },
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.4),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.open_in_full,
                      size: 8,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Selection border ──────────────────────────────────────────────────────────
class _SelectionBorder extends StatelessWidget {
  final bool isSelected;
  final Widget child;
  const _SelectionBorder({required this.isSelected, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: isSelected
          ? BoxDecoration(
              border: Border.all(color: AppTheme.primary, width: 2),
              borderRadius: BorderRadius.circular(4),
            )
          : null,
      child: child,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WidgetRenderer — reads from widgetModel.properties on every build so any
// property change from the panel triggers an immediate visual update.
// ══════════════════════════════════════════════════════════════════════════════
class WidgetRenderer extends StatelessWidget {
  final WidgetModel widgetModel;
  const WidgetRenderer({super.key, required this.widgetModel});

  double get _safeWidth => (widgetModel.width <= 0) ? 300 : widgetModel.width;
  double get _safeHeight => (widgetModel.height <= 0)
      ? WidgetModel.defaultHeightFor(widgetModel.type)
      : widgetModel.height;

  Color _c(Map<String, dynamic> p, String k, Color fb) {
    try {
      final hex = p[k] as String? ?? '';
      if (hex.isEmpty) return fb;
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return fb;
    }
  }

  double _d(Map<String, dynamic> p, String k, double fb) {
    final v = p[k];
    return (v is num) ? v.toDouble() : fb;
  }

  String _s(Map<String, dynamic> p, String k, String fb) =>
      p[k]?.toString() ?? fb;

  List<String> _list(Map<String, dynamic> p, String k, List<String> fb) {
    final v = p[k];
    if (v is List) return List<String>.from(v);
    if (v is String) return v.split(',').map((e) => e.trim()).toList();
    return fb;
  }

  TextAlign _align(String? v) {
    if (v == 'center') return TextAlign.center;
    if (v == 'right') return TextAlign.right;
    return TextAlign.left;
  }

  @override
  Widget build(BuildContext context) {
    final props = widgetModel.properties;
    final w = _safeWidth;
    final h = _safeHeight;

    switch (widgetModel.type) {
      // ── Button ─────────────────────────────────────────────────────────────
      case 'button':
        return SizedBox(
          width: w,
          height: h,
          child: ElevatedButton(
            onPressed: () {
              final action = _s(props, 'action', 'none');
              if (action != 'none') {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Button action: $action')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _c(props, 'color', AppTheme.primary),
              foregroundColor: _c(props, 'textColor', Colors.white),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  _d(props, 'borderRadius', 8),
                ),
              ),
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              _s(props, 'label', 'Button'),
              style: TextStyle(fontSize: _d(props, 'fontSize', 14)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );

      // ── Text ───────────────────────────────────────────────────────────────
      case 'text':
        return SizedBox(
          width: w,
          height: h,
          child: SingleChildScrollView(
            child: Text(
              _s(props, 'content', 'Text'),
              style: TextStyle(
                color: _c(props, 'color', Colors.black87),
                fontSize: _d(props, 'fontSize', 16),
                fontWeight: props['bold'] == 'true' || props['bold'] == true
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
              textAlign: _align(props['align']?.toString()),
            ),
          ),
        );

      // ── Input ──────────────────────────────────────────────────────────────
      case 'input':
        return SizedBox(
          width: w,
          height: h,
          child: TextField(
            keyboardType: _s(props, 'type', 'text') == 'email'
                ? TextInputType.emailAddress
                : TextInputType.text,
            decoration: InputDecoration(
              hintText: _s(
                props,
                'placeholder',
                _s(props, 'hint', 'Enter text…'),
              ),
              labelText: _s(props, 'label', ''),
              filled: true,
              fillColor: _c(props, 'bgColor', Colors.grey[100]!),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  _d(props, 'borderRadius', 8),
                ),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            style: TextStyle(color: _c(props, 'textColor', Colors.black)),
          ),
        );

      // ── Image ──────────────────────────────────────────────────────────────
      case 'image':
        final src = _s(props, 'src', '');
        final fitStr = _s(props, 'fit', 'cover');
        final fit =
            const {
              'cover': BoxFit.cover,
              'contain': BoxFit.contain,
              'fill': BoxFit.fill,
              'fitWidth': BoxFit.fitWidth,
              'fitHeight': BoxFit.fitHeight,
            }[fitStr] ??
            BoxFit.cover;
        return SizedBox(
          width: w,
          height: h,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_d(props, 'borderRadius', 8)),
            child: src.startsWith('http')
                ? Image.network(
                    src,
                    fit: fit,
                    errorBuilder: (_, __, ___) => _imgPlaceholder(w, h),
                  )
                : _imgPlaceholder(w, h),
          ),
        );

      // ── Card ───────────────────────────────────────────────────────────────
      case 'card':
        final borderRadius = _d(props, 'borderRadius', 12);
        return SizedBox(
          width: w,
          height: h,
          child: Card(
            elevation: _d(props, 'elevation', 2),
            color: _c(props, 'bgColor', Colors.white),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _s(props, 'title', 'Card Title'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _s(props, 'subtitle', 'Subtitle'),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

      // ── Icon ───────────────────────────────────────────────────────────────
      case 'icon':
        final iconMap = {
          'star': Icons.star,
          'heart': Icons.favorite,
          'home': Icons.home,
          'search': Icons.search,
          'settings': Icons.settings,
          'user': Icons.person,
          'menu': Icons.menu,
          'close': Icons.close,
          'add': Icons.add,
          'delete': Icons.delete,
          'edit': Icons.edit,
          'share': Icons.share,
          'like': Icons.thumb_up,
          'notifications': Icons.notifications,
          'email': Icons.email,
          'phone': Icons.phone,
          'location': Icons.location_on,
          'calendar': Icons.calendar_today,
          'clock': Icons.access_time,
          'arrow_back': Icons.arrow_back,
        };

        final iconName = _s(props, 'iconName', 'star').toLowerCase();
        final selectedIcon = iconMap[iconName] ?? Icons.star;

        return SizedBox(
          width: w,
          height: h,
          child: Center(
            child: Icon(
              selectedIcon,
              color: _c(props, 'color', AppTheme.primary),
              size: _d(props, 'size', 32),
            ),
          ),
        );

      // ── Divider ────────────────────────────────────────────────────────────
      case 'divider':
        final direction = _s(props, 'direction', 'horizontal');
        return SizedBox(
          width: w,
          height: h,
          child: direction == 'vertical'
              ? Center(
                  child: VerticalDivider(
                    color: _c(props, 'color', Colors.grey),
                    thickness: _d(props, 'thickness', 1),
                  ),
                )
              : Center(
                  child: Divider(
                    color: _c(props, 'color', Colors.grey),
                    thickness: _d(props, 'thickness', 1),
                  ),
                ),
        );

      // ── App Bar ────────────────────────────────────────────────────────────
      case 'appbar':
        return SizedBox(
          width: w,
          height: h,
          child: Container(
            color: _c(props, 'color', AppTheme.primary),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                if (props['showBack'] == 'true')
                  const Icon(Icons.arrow_back, color: Colors.white, size: 20)
                else
                  const Icon(Icons.menu, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _s(props, 'title', 'Screen Title'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search, color: Colors.white),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        );

      // ── Nav Bar ────────────────────────────────────────────────────────────
      case 'navbar':
        return SizedBox(
          width: w,
          height: h,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [Icons.home, Icons.search, Icons.person]
                  .map(
                    (ic) => Icon(
                      ic,
                      color: _c(props, 'color', AppTheme.primary),
                      size: 22,
                    ),
                  )
                  .toList(),
            ),
          ),
        );

      // ── Checkbox ───────────────────────────────────────────────────────────
      // FIX 11: Checkbox is now a StatefulWidget wrapper so tapping it actually
      // toggles the visual state in the canvas preview.
      case 'checkbox':
        return _CheckboxWidget(props: props, width: w, height: h);

      // ── Switch ─────────────────────────────────────────────────────────────
      // FIX 12: Switch gets the same stateful treatment as Checkbox.
      case 'switch_w':
        return _SwitchWidget(props: props, width: w, height: h);

      // ── Dropdown ───────────────────────────────────────────────────────────
      // FIX 13: Dropdown was broken because it used a plain DropdownButton
      // with no local state — the selected value was always null so Flutter
      // emitted an assertion error. Now it maintains its own selection state.
      case 'dropdown':
        return _DropdownWidget(props: props, width: w, height: h);

      // ── Checkbox Todo list ─────────────────────────────────────────────────
      case 'checkbox_todo':
        final items = _list(props, 'items', ['Todo 1', 'Todo 2', 'Todo 3']);
        return SizedBox(
          width: w,
          height: h,
          child: SingleChildScrollView(
            child: Column(
              children: items
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _list(props, 'selected', []).contains(item),
                            onChanged: (_) {},
                            activeColor: _c(props, 'color', AppTheme.primary),
                          ),
                          Expanded(
                            child: Text(
                              item,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        );

      // ── List ───────────────────────────────────────────────────────────────
      case 'list':
        final items = _list(props, 'items', ['Item 1', 'Item 2', 'Item 3']);
        final showDivider =
            props['divider'] != 'false' && props['divider'] != false;
        return SizedBox(
          width: w,
          height: h,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => showDivider
                  ? const Divider(height: 1)
                  : const SizedBox.shrink(),
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Text(
                  items[i],
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        );

      // ── Grid ───────────────────────────────────────────────────────────────
      case 'grid':
        final cols = _d(props, 'columns', 2).toInt();
        final items = _list(
          props,
          'items',
          List.generate(6, (i) => 'Item ${i + 1}'),
        );
        final imageUrls = _list(props, 'imageUrls', []);
        final videoUrls = _list(props, 'videoUrls', []);
        return SizedBox(
          width: w,
          height: h,
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.2,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final hasImageUrl =
                  imageUrls.isNotEmpty &&
                  i < imageUrls.length &&
                  imageUrls[i].isNotEmpty;
              final hasVideoUrl =
                  videoUrls.isNotEmpty &&
                  i < videoUrls.length &&
                  videoUrls[i].isNotEmpty;
              return Container(
                decoration: BoxDecoration(
                  color: _c(props, 'itemColor', Colors.grey[200]!),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Image, Video, or placeholder
                      if (hasVideoUrl)
                        Expanded(
                          flex: 2,
                          child: Container(
                            width: double.infinity,
                            color: Colors.black,
                            child: _GridItemVideoWidget(videoUrl: videoUrls[i]),
                          ),
                        )
                      else if (hasImageUrl)
                        Expanded(
                          flex: 2,
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(color: Colors.grey[300]),
                            child: Image.network(
                              imageUrls[i],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Icon(
                                  Icons.broken_image,
                                  size: 24,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          ),
                        )
                      else if (_s(props, 'showImage', 'false') == 'true')
                        Expanded(
                          flex: 2,
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(color: Colors.grey[300]),
                            child: Icon(
                              Icons.image,
                              size: 24,
                              color: Colors.grey[600],
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 4),
                      // Text content
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            items[i],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: _c(props, 'textColor', Colors.black),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );

      // ── Form ───────────────────────────────────────────────────────────────
      case 'form':
        final fields = _list(props, 'fields', ['Name', 'Email', 'Phone']);
        final fieldColor = _c(props, 'fieldBgColor', Colors.white);
        final fieldBorderColor = _c(props, 'fieldBorderColor', Colors.grey);
        return SizedBox(
          width: w,
          height: h,
          child: Container(
            color: _c(props, 'bgColor', Colors.transparent),
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: h - 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Form title if provided
                    if (_s(props, 'title', '').isNotEmpty) ...[
                      Text(
                        _s(props, 'title', ''),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Dynamic form fields
                    ...fields.map(
                      (field) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: field,
                            filled: true,
                            fillColor: fieldColor,
                            labelStyle: const TextStyle(color: Colors.black87),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: fieldBorderColor),
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          style: const TextStyle(color: Colors.black),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Submit button
                    SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _c(
                            props,
                            'submitColor',
                            AppTheme.primary,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          _s(props, 'submitLabel', 'Submit'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

      // ── Container ──────────────────────────────────────────────────────────
      case 'container':
        final imageUrl = _s(props, 'imageUrl', '');
        final hasImage = imageUrl.isNotEmpty;
        return SizedBox(
          width: w,
          height: h,
          child: Container(
            decoration: BoxDecoration(
              color: _c(props, 'bgColor', Colors.grey[300]!),
              borderRadius: BorderRadius.circular(_d(props, 'borderRadius', 8)),
              border: Border.all(
                color: _c(props, 'borderColor', Colors.transparent),
                width: _d(props, 'borderWidth', 1),
              ),
            ),
            child: hasImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(
                      _d(props, 'borderRadius', 8),
                    ),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.image_not_supported,
                              size: 32,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Invalid Image URL',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image, size: 40, color: Colors.grey[600]),
                        const SizedBox(height: 8),
                        Text(
                          _s(props, 'label', 'Container'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add imageUrl property to display image',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
          ),
        );

      // ── Chart ──────────────────────────────────────────────────────────────
      case 'chart':
        return SizedBox(
          width: w,
          height: h,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bar_chart,
                    size: 48,
                    color: _c(props, 'color', AppTheme.primary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Chart: ${_s(props, 'type', 'bar')}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

      // ── Todo ───────────────────────────────────────────────────────────────
      case 'todo':
        return _TodoWidget(props: props, width: w, height: h);

      // ── Multiline ──────────────────────────────────────────────────────────
      case 'multiline':
        final maxLines = _d(props, 'maxLines', 3).toInt();
        return SizedBox(
          width: w,
          height: h,
          child: TextField(
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: _s(props, 'hint', 'Enter text...'),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.all(10),
            ),
          ),
        );

      // ── Search ─────────────────────────────────────────────────────────────
      case 'search':
        return SizedBox(
          width: w,
          height: h,
          child: TextField(
            decoration: InputDecoration(
              hintText: _s(props, 'placeholder', 'Search...'),
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            style: TextStyle(color: _c(props, 'color', Colors.black)),
          ),
        );

      // ── Radio ──────────────────────────────────────────────────────────────
      case 'radio':
        return _RadioWidget(props: props, width: w, height: h);

      // ── Slider ─────────────────────────────────────────────────────────────
      case 'slider':
        final value = _d(
          props,
          'value',
          50,
        ).clamp(_d(props, 'min', 0), _d(props, 'max', 100));
        return SizedBox(
          width: w,
          height: h,
          child: Center(
            child: Slider(
              value: value,
              min: _d(props, 'min', 0),
              max: _d(props, 'max', 100),
              onChanged: (_) {},
              activeColor: _c(props, 'color', AppTheme.primary),
            ),
          ),
        );

      // ── Rich Text ──────────────────────────────────────────────────────────
      case 'richtext':
        final text1 = _s(props, 'text1', 'Rich ');
        final text2 = _s(props, 'text2', 'Text');
        return SizedBox(
          width: w,
          height: h,
          child: SingleChildScrollView(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: text1,
                    style: TextStyle(
                      fontSize: _d(props, 'fontSize', 14),
                      fontWeight: FontWeight.bold,
                      color: _c(props, 'color1', Colors.black),
                    ),
                  ),
                  TextSpan(
                    text: text2,
                    style: TextStyle(
                      fontSize: _d(props, 'fontSize', 14),
                      color: _c(props, 'color2', Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

      // ── Badge ──────────────────────────────────────────────────────────────
      case 'badge':
        return SizedBox(
          width: w,
          height: h,
          child: Center(
            child: Badge(
              label: Text(
                _s(props, 'label', '5'),
                style: TextStyle(
                  color: _c(props, 'textColor', Colors.white),
                  fontSize: 10,
                ),
              ),
              backgroundColor: _c(props, 'bgColor', AppTheme.primary),
              child: Icon(
                Icons.notifications,
                size: _d(props, 'iconSize', 24),
                color: _c(props, 'color', AppTheme.primary),
              ),
            ),
          ),
        );

      // ── Chip ───────────────────────────────────────────────────────────────
      case 'chip':
        return SizedBox(
          width: w,
          height: h,
          child: Center(
            child: Chip(
              label: Text(_s(props, 'label', 'Chip')),
              deleteIcon: const Icon(Icons.close),
              onDeleted: () {},
            ),
          ),
        );

      // ── Row ────────────────────────────────────────────────────────────────
      case 'row':
        final items = _list(props, 'items', ['Item 1', 'Item 2', 'Item 3']);
        final alignStr = _s(props, 'alignment', 'start');
        final alignment =
            const {
              'start': MainAxisAlignment.start,
              'center': MainAxisAlignment.center,
              'end': MainAxisAlignment.end,
              'spaceAround': MainAxisAlignment.spaceAround,
              'spaceBetween': MainAxisAlignment.spaceBetween,
            }[alignStr] ??
            MainAxisAlignment.start;
        final spacing = _d(props, 'spacing', 4);
        return SizedBox(
          width: w,
          height: h,
          child: Row(
            mainAxisAlignment: alignment,
            children: items
                .asMap()
                .entries
                .expand(
                  (e) => [
                    Expanded(
                      child: Container(
                        margin: EdgeInsets.all(spacing),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          e.value,
                          style: const TextStyle(fontSize: 12),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (e.key < items.length - 1) SizedBox(width: spacing),
                  ],
                )
                .toList(),
          ),
        );

      // ── Column ─────────────────────────────────────────────────────────────
      case 'column':
        final items = _list(props, 'items', ['Item 1', 'Item 2', 'Item 3']);
        final alignStr = _s(props, 'alignment', 'start');
        final alignment =
            const {
              'start': MainAxisAlignment.start,
              'center': MainAxisAlignment.center,
              'end': MainAxisAlignment.end,
              'spaceAround': MainAxisAlignment.spaceAround,
              'spaceBetween': MainAxisAlignment.spaceBetween,
            }[alignStr] ??
            MainAxisAlignment.start;
        final spacing = _d(props, 'spacing', 4);
        return SizedBox(
          width: w,
          height: h,
          child: Column(
            mainAxisAlignment: alignment,
            children: items
                .asMap()
                .entries
                .expand(
                  (e) => [
                    Expanded(
                      child: Container(
                        margin: EdgeInsets.all(spacing),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          e.value,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (e.key < items.length - 1) SizedBox(height: spacing),
                  ],
                )
                .toList(),
          ),
        );

      // ── Padding ────────────────────────────────────────────────────────────
      case 'padding':
        final padding = _d(props, 'padding', 16);
        return SizedBox(
          width: w,
          height: h,
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'Padded Content',
                  style: TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        );

      // ── Expanded ───────────────────────────────────────────────────────────
      case 'expanded':
        return Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: Colors.blue[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue),
          ),
          child: const Center(
            child: Text(
              'Expanded',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        );

      // ── Flexible ───────────────────────────────────────────────────────────
      case 'flexible':
        return Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: Colors.green[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green),
          ),
          child: const Center(
            child: Text(
              'Flexible',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        );

      // ── Spacer ─────────────────────────────────────────────────────────────
      case 'spacer':
        return SizedBox(
          width: w,
          height: h,
          child: Container(
            decoration: BoxDecoration(
              color: _c(props, 'bgColor', Colors.grey[100]!),
              border: Border.all(
                color: _c(props, 'borderColor', Colors.grey),
                style: BorderStyle.solid,
              ),
            ),
          ),
        );

      // ── Stack ──────────────────────────────────────────────────────────────
      case 'stack':
        return SizedBox(
          width: w,
          height: h,
          child: Stack(
            children: [
              Container(color: Colors.blue[100]),
              Container(
                margin: const EdgeInsets.all(20),
                color: Colors.blue[300],
              ),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Stack',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );

      // ── Wrapper ────────────────────────────────────────────────────────────
      case 'wrapper':
        return SizedBox(
          width: w,
          height: h,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.purple[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.purple),
            ),
            child: const Center(
              child: Text('Wrapper', style: TextStyle(fontSize: 12)),
            ),
          ),
        );

      // ── Tabs ───────────────────────────────────────────────────────────────
      case 'tabs':
        final tabCount = _d(props, 'tabs', 3).toInt().clamp(1, 10);
        final activeTab = _d(props, 'activeTab', 0).toInt();
        final tabLabels = _list(
          props,
          'tabLabels',
          List.generate(tabCount, (i) => 'Tab ${i + 1}'),
        );
        return DefaultTabController(
          length: tabCount,
          initialIndex: activeTab.clamp(0, tabCount - 1),
          child: SizedBox(
            width: w,
            height: h,
            child: Column(
              children: [
                TabBar(
                  tabs: List.generate(tabCount, (i) => Tab(text: tabLabels[i])),
                ),
                Expanded(
                  child: TabBarView(
                    children: List.generate(
                      tabCount,
                      (i) => Center(
                        child: Text(
                          'Content ${i + 1}',
                          style: TextStyle(fontSize: _d(props, 'fontSize', 14)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

      // ── Stepper ────────────────────────────────────────────────────────────
      case 'stepper':
        return SizedBox(
          width: w,
          height: h,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildStepperItem(1, 'Step 1', 'Step 1 content', true),
                _buildStepperItem(2, 'Step 2', 'Step 2 content', false),
                _buildStepperItem(3, 'Step 3', 'Step 3 content', false),
              ],
            ),
          ),
        );

      // ── Icon Button ────────────────────────────────────────────────────────
      case 'iconbtn':
        return SizedBox(
          width: w,
          height: h,
          child: Center(
            child: IconButton(
              icon: Icon(
                Icons.favorite,
                color: _c(props, 'color', AppTheme.primary),
              ),
              onPressed: () {},
            ),
          ),
        );

      // ── FAB ────────────────────────────────────────────────────────────────
      case 'fab':
        return SizedBox(
          width: w,
          height: h,
          child: Center(
            child: FloatingActionButton(
              backgroundColor: _c(props, 'color', AppTheme.primary),
              child: const Icon(Icons.add, color: Colors.white),
              onPressed: () {},
            ),
          ),
        );

      // ── Rating ─────────────────────────────────────────────────────────────
      case 'rating':
        return _RatingWidget(props: props, width: w, height: h);

      // ── Progress ───────────────────────────────────────────────────────────
      case 'progress':
        final value = _d(props, 'value', 0.65).clamp(0.0, 1.0);
        return SizedBox(
          width: w,
          height: h,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                LinearProgressIndicator(
                  value: value,
                  minHeight: 10,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _c(props, 'color', AppTheme.primary),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(value * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        );

      // ── Date Picker ────────────────────────────────────────────────────────
      case 'datepick':
        return _DatePickerWidget(props: props, width: w, height: h);

      // ── Time Picker ────────────────────────────────────────────────────────
      case 'timepick':
        return _TimePickerWidget(props: props, width: w, height: h);

      // ── Autocomplete ───────────────────────────────────────────────────────
      case 'autocomplete':
        return SizedBox(
          width: w,
          height: h,
          child: TextField(
            decoration: InputDecoration(
              hintText: _s(props, 'placeholder', 'Type to search...'),
              suffixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  _d(props, 'borderRadius', 8),
                ),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.all(10),
            ),
          ),
        );

      // ── Multi-Select ───────────────────────────────────────────────────────
      case 'multiselect':
        return _MultiSelectWidget(props: props, width: w, height: h);

      // ── Range Slider ───────────────────────────────────────────────────────
      case 'rangeslider':
        final min = _d(props, 'min', 0);
        final max = _d(props, 'max', 100);
        final startVal = _d(props, 'start', 20).clamp(min, max);
        final endVal = _d(props, 'end', 80).clamp(min, max);
        return SizedBox(
          width: w,
          height: h,
          child: Center(
            child: RangeSlider(
              values: RangeValues(startVal, endVal),
              min: min,
              max: max,
              onChanged: (_) {},
              activeColor: _c(props, 'color', AppTheme.primary),
            ),
          ),
        );

      // ── Snackbar ───────────────────────────────────────────────────────────
      case 'snackbar':
        return SizedBox(
          width: w,
          height: h,
          child: Container(
            decoration: BoxDecoration(
              color: _c(props, 'bgColor', Colors.grey[800]!),
              borderRadius: BorderRadius.circular(_d(props, 'borderRadius', 4)),
            ),
            padding: EdgeInsets.all(_d(props, 'padding', 12)),
            child: Text(
              _s(props, 'message', 'This is a snackbar'),
              style: TextStyle(
                color: _c(props, 'textColor', Colors.white),
                fontSize: _d(props, 'fontSize', 12),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );

      // ── Tooltip ────────────────────────────────────────────────────────────
      case 'tooltip':
        return SizedBox(
          width: w,
          height: h,
          child: Center(
            child: Tooltip(
              message: _s(props, 'message', 'Hover for tooltip'),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.info, size: 20),
              ),
            ),
          ),
        );

      // ── Dialog ─────────────────────────────────────────────────────────────
      case 'dialog':
        return SizedBox(
          width: w,
          height: h,
          child: Container(
            decoration: BoxDecoration(
              color: _c(props, 'bgColor', Colors.white),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _s(props, 'title', 'Dialog Title'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _c(props, 'textColor', Colors.black),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _s(props, 'message', 'Dialog message'),
                    style: TextStyle(
                      fontSize: 12,
                      color: _c(props, 'textColor', Colors.black87),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 5,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _c(
                            props,
                            'btnColor',
                            AppTheme.primary,
                          ),
                        ),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );

      // ── Bottom Sheet ───────────────────────────────────────────────────────
      case 'bottomsheet':
        return SizedBox(
          width: w,
          height: h,
          child: Container(
            decoration: BoxDecoration(
              color: _c(props, 'bgColor', Colors.white),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _s(props, 'title', 'Bottom Sheet'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _s(props, 'content', 'Bottom sheet content'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        );

      // ── Loader ─────────────────────────────────────────────────────────────
      case 'loader':
        final typeStr = _s(props, 'type', 'circular');
        return SizedBox(
          width: w,
          height: h,
          child: Center(
            child: typeStr == 'linear'
                ? LinearProgressIndicator(
                    minHeight: _d(props, 'size', 4),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _c(props, 'color', AppTheme.primary),
                    ),
                  )
                : CircularProgressIndicator(
                    strokeWidth: _d(props, 'size', 4),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _c(props, 'color', AppTheme.primary),
                    ),
                  ),
          ),
        );

      // ── Skeleton ───────────────────────────────────────────────────────────
      case 'skeleton':
        final shapeStr = _s(props, 'shape', 'rect');
        final borderRadius = _d(props, 'borderRadius', 8);
        return SizedBox(
          width: w,
          height: h,
          child: shapeStr == 'circle'
              ? Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _c(props, 'bgColor', Colors.grey[300]!),
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    color: _c(props, 'bgColor', Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                ),
        );

      // ── Breadcrumb ─────────────────────────────────────────────────────────
      case 'breadcrumb':
        final items = _list(props, 'items', ['Home', 'Category', 'Current']);
        return SizedBox(
          width: w,
          height: h,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: items
                  .asMap()
                  .entries
                  .expand(
                    (e) => [
                      Text(
                        e.value,
                        style: TextStyle(
                          fontSize: 12,
                          color: e.key == items.length - 1
                              ? _c(props, 'color', Colors.blue)
                              : Colors.black,
                        ),
                      ),
                      if (e.key < items.length - 1)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.chevron_right, size: 16),
                        ),
                    ],
                  )
                  .toList(),
            ),
          ),
        );

      // ── Pagination ────────────────────────────────────────────────────────
      case 'pagination':
        final totalPages = _d(props, 'totalPages', 5).toInt();
        final currentPage = _d(
          props,
          'currentPage',
          1,
        ).toInt().clamp(1, totalPages);
        return SizedBox(
          width: w,
          height: h,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                totalPages,
                (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (i + 1) == currentPage
                        ? _c(props, 'color', AppTheme.primary)
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      color: (i + 1) == currentPage
                          ? Colors.white
                          : Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

      // ── Menu ───────────────────────────────────────────────────────────────
      case 'menu':
        final items = _list(props, 'items', [
          'Home',
          'About',
          'Services',
          'Contact',
        ]);
        return SizedBox(
          width: w,
          height: h,
          child: Container(
            decoration: BoxDecoration(
              color: _c(props, 'bgColor', Colors.grey[100]!),
              border: Border.all(color: _c(props, 'borderColor', Colors.grey)),
              borderRadius: BorderRadius.circular(_d(props, 'borderRadius', 4)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: items.map((item) => _buildMenuItem(item)).toList(),
              ),
            ),
          ),
        );

      // ── Drawer ─────────────────────────────────────────────────────────────
      case 'drawer':
        final items = _list(props, 'items', [
          'Menu Item 1',
          'Menu Item 2',
          'Menu Item 3',
        ]);
        return SizedBox(
          width: w,
          height: h,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _c(props, 'borderColor', Colors.grey)),
            ),
            child: Column(
              children: [
                Container(
                  height: 60,
                  color: _c(props, 'headerColor', AppTheme.primary),
                  child: Center(
                    child: Text(
                      _s(props, 'title', 'Drawer'),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                ...items.map((item) => _buildMenuItem(item)).toList(),
              ],
            ),
          ),
        );

      // ── Alert ──────────────────────────────────────────────────────────────
      case 'alert':
        final title = _s(props, 'title', 'Alert');
        final message = _s(props, 'message', 'Alert message');
        final bgColor = _c(props, 'bgColor', Colors.red.withOpacity(0.1));
        final borderColor = _c(props, 'borderColor', Colors.red);
        return SizedBox(
          width: w,
          height: h,
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(4),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.warning, color: borderColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        message,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

      // ── Accordion ──────────────────────────────────────────────────────────
      case 'accordion':
        return SizedBox(
          width: w,
          height: h,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildAccordionItem('Section 1', 'Content 1'),
                _buildAccordionItem('Section 2', 'Content 2'),
                _buildAccordionItem('Section 3', 'Content 3'),
              ],
            ),
          ),
        );

      // ── Timeline ───────────────────────────────────────────────────────────
      case 'timeline':
        return SizedBox(
          width: w,
          height: h,
          child: ListView(
            children: [
              _buildTimelineItem('Event 1', '10:00 AM'),
              _buildTimelineItem('Event 2', '11:30 AM'),
              _buildTimelineItem('Event 3', '2:00 PM'),
            ],
          ),
        );

      // ── Table ──────────────────────────────────────────────────────────────
      case 'table':
        return SizedBox(
          width: w,
          height: h,
          child: SingleChildScrollView(
            child: Table(
              border: TableBorder.all(color: Colors.grey),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey[300]),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('Col 1', style: TextStyle(fontSize: 12)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('Col 2', style: TextStyle(fontSize: 12)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('Col 3', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                TableRow(
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('Data 1', style: TextStyle(fontSize: 12)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('Data 2', style: TextStyle(fontSize: 12)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('Data 3', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );

      // ── Google Login ───────────────────────────────────────────────────────
      case 'googlelogin':
        return SizedBox(
          width: w,
          height: h,
          child: ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Google Login tapped')),
              );
            },
            icon: const Text('🔐', style: TextStyle(fontSize: 18)),
            label: const Text('Sign in with Google'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDB4437),
              foregroundColor: Colors.white,
            ),
          ),
        );

      // ── Facebook Login ─────────────────────────────────────────────────────
      case 'fblogin':
        return SizedBox(
          width: w,
          height: h,
          child: ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Facebook Login tapped')),
              );
            },
            icon: const Text(
              'f',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            label: const Text('Sign in with Facebook'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4267B2),
              foregroundColor: Colors.white,
            ),
          ),
        );

      // ── Share Button ───────────────────────────────────────────────────────
      case 'sharebutton':
        return SizedBox(
          width: w,
          height: h,
          child: Center(
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Share tapped')));
              },
              icon: const Icon(Icons.share),
              label: const Text('Share'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1ABC9C),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        );

      // ── Like Button ────────────────────────────────────────────────────────
      case 'likebutton':
        return SizedBox(
          width: w,
          height: h,
          child: Center(
            child: IconButton(
              icon: const Icon(Icons.favorite_border),
              onPressed: () {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Liked!')));
              },
              color: const Color(0xFFE74C3C),
              iconSize: 28,
            ),
          ),
        );

      // ── Follow Button ──────────────────────────────────────────────────────
      case 'followbtn':
        return SizedBox(
          width: w,
          height: h,
          child: ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Following!')));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3498DB),
              foregroundColor: Colors.white,
            ),
            child: const Text('Follow'),
          ),
        );

      // ── Comment ────────────────────────────────────────────────────────────
      case 'comment':
        return SizedBox(
          width: w,
          height: h,
          child: Center(
            child: IconButton(
              icon: const Icon(Icons.comment),
              onPressed: () {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Comment tapped')));
              },
              color: const Color(0xFF16A085),
              iconSize: 24,
            ),
          ),
        );

      // ── QR Code ────────────────────────────────────────────────────────────
      case 'qrcode':
        return SizedBox(
          width: w,
          height: h,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _c(props, 'borderColor', Colors.grey)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _c(props, 'color', Colors.black),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.qr_code,
                      color: Colors.white,
                      size: 60,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _s(props, 'data', 'QR Code'),
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );

      // ── Pincode ────────────────────────────────────────────────────────────
      case 'pincode':
        final length = _d(props, 'length', 6).toInt();
        return SizedBox(
          width: w,
          height: h,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                length,
                (i) => Container(
                  width: 40,
                  height: 50,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text('•', style: TextStyle(fontSize: 24)),
                  ),
                ),
              ),
            ),
          ),
        );

      // ── Signature ──────────────────────────────────────────────────────────
      case 'signature':
        return SizedBox(
          width: w,
          height: h,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.draw,
                    size: 48,
                    color: _c(props, 'color', Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _s(props, 'label', 'Draw Signature'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        );

      // ── Video ──────────────────────────────────────────────────────────────
      case 'video':
        return _VideoWidget(props: props, width: w, height: h);

      // ── Camera ─────────────────────────────────────────────────────────────
      case 'camera':
        return SizedBox(
          width: w,
          height: h,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.camera_alt, color: Colors.white, size: 48),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap to capture',
                    style: TextStyle(color: Colors.black, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        );

      // ── Gallery ────────────────────────────────────────────────────────────
      case 'gallery':
        return SizedBox(
          width: w,
          height: h,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.photo_library, size: 48, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text(
                    _s(props, 'label', 'Select Photos'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        );

      // ── Map ────────────────────────────────────────────────────────────────
      case 'map':
        return SizedBox(
          width: w,
          height: h,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_on, size: 48, color: Colors.blue),
                  const SizedBox(height: 8),
                  Text(
                    _s(props, 'address', 'Map Location'),
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );

      // ── Carousel ───────────────────────────────────────────────────────────
      case 'carousel':
        return SizedBox(
          width: w,
          height: h,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.image, size: 48, color: Colors.grey),
                  const SizedBox(height: 8),
                  const Text('Carousel', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        );

      // ── WebView ────────────────────────────────────────────────────────────
      case 'webview':
        return SizedBox(
          width: w,
          height: h,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.language, size: 48, color: Colors.blue),
                  const SizedBox(height: 8),
                  Text(
                    _s(props, 'url', 'https://example.com'),
                    style: const TextStyle(fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );

      // ── Lottie ────────────────────────────────────────────────────────────
      case 'lottie':
        return SizedBox(
          width: w,
          height: h,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.animation, size: 48, color: Colors.blue),
                  const SizedBox(height: 8),
                  Text(
                    _s(props, 'animation', 'animation.json'),
                    style: const TextStyle(fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );

      // ── Navigation Drawer ──────────────────────────────────────────────────
      case 'navdrawer':
        return SizedBox(
          width: w,
          height: h,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey),
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    height: 80,
                    color: _c(props, 'headerColor', AppTheme.primary),
                    child: Center(
                      child: Text(
                        _s(props, 'headerTitle', 'Navigation'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  _buildMenuItem('Home'),
                  _buildMenuItem('About'),
                  _buildMenuItem('Settings'),
                  _buildMenuItem('Logout'),
                ],
              ),
            ),
          ),
        );

      // ── Default fallback ───────────────────────────────────────────────────
      default:
        return SizedBox(
          width: w,
          height: h,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
            ),
            child: Center(
              child: Text(
                widgetModel.type,
                style: const TextStyle(color: AppTheme.primary, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
    }
  }

  Widget _imgPlaceholder(double w, double h) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: Colors.grey[200],
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.image_outlined, color: Colors.grey, size: 36),
        SizedBox(height: 6),
        Text('Image', style: TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    ),
  );

  Widget _buildMenuItem(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
    ),
    child: Row(
      children: [
        const Icon(Icons.menu, size: 18),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    ),
  );

  Widget _buildAccordionItem(String title, String content) => Container(
    margin: const EdgeInsets.symmetric(vertical: 4),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey[300]!),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          color: Colors.grey[200],
          width: double.infinity,
          child: Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          child: Text(content, style: const TextStyle(fontSize: 11)),
        ),
      ],
    ),
  );

  Widget _buildTimelineItem(String title, String time) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.check, color: Colors.white, size: 20),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            Text(
              time,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildStepperItem(
    int number,
    String title,
    String content,
    bool isActive,
  ) => Container(
    margin: const EdgeInsets.symmetric(vertical: 4),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: isActive ? Colors.blue[50] : Colors.grey[50],
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: isActive ? Colors.blue : Colors.grey[300]!),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? Colors.blue : Colors.grey,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                content,
                style: const TextStyle(fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// FIX 15 — Stateful DatePicker widget for canvas preview
// ══════════════════════════════════════════════════════════════════════════════
class _DatePickerWidget extends StatefulWidget {
  final Map<String, dynamic> props;
  final double width, height;
  const _DatePickerWidget({
    required this.props,
    required this.width,
    required this.height,
  });

  @override
  State<_DatePickerWidget> createState() => _DatePickerWidgetState();
}

class _DatePickerWidgetState extends State<_DatePickerWidget> {
  DateTime? _selectedDate;

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: GestureDetector(
        onTap: _pickDate,
        child: TextField(
          enabled: false,
          decoration: InputDecoration(
            hintText: 'Select date',
            prefixIcon: const Icon(Icons.calendar_today),
            suffixText: _selectedDate != null
                ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FIX 16 — Stateful TimePicker widget for canvas preview
// ══════════════════════════════════════════════════════════════════════════════
class _TimePickerWidget extends StatefulWidget {
  final Map<String, dynamic> props;
  final double width, height;
  const _TimePickerWidget({
    required this.props,
    required this.width,
    required this.height,
  });

  @override
  State<_TimePickerWidget> createState() => _TimePickerWidgetState();
}

class _TimePickerWidgetState extends State<_TimePickerWidget> {
  TimeOfDay? _selectedTime;

  Future<void> _pickTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (pickedTime != null) {
      setState(() {
        _selectedTime = pickedTime;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: GestureDetector(
        onTap: _pickTime,
        child: TextField(
          enabled: false,
          decoration: InputDecoration(
            hintText: 'Select time',
            prefixIcon: const Icon(Icons.access_time),
            suffixText: _selectedTime != null
                ? _selectedTime!.format(context)
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Helper — Grid Item Video Player Widget
// ══════════════════════════════════════════════════════════════════════════════
class _GridItemVideoWidget extends StatefulWidget {
  final String videoUrl;
  const _GridItemVideoWidget({required this.videoUrl});

  @override
  State<_GridItemVideoWidget> createState() => _GridItemVideoWidgetState();
}

class _GridItemVideoWidgetState extends State<_GridItemVideoWidget> {
  late VideoPlayerController? _controller;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  void _initializeVideo() {
    if (widget.videoUrl.isEmpty) {
      _controller = null;
      return;
    }

    setState(() => _isLoading = true);

    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
        ..initialize()
            .then((_) {
              if (mounted) setState(() => _isLoading = false);
            })
            .catchError((e) {
              if (mounted) {
                setState(() => _isLoading = false);
                _controller = null;
              }
            });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _controller = null;
      }
    }
  }

  @override
  void didUpdateWidget(_GridItemVideoWidget old) {
    super.didUpdateWidget(old);
    if (old.videoUrl != widget.videoUrl) {
      _controller?.dispose();
      _initializeVideo();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator(color: Colors.white))
        : (_controller != null && _controller!.value.isInitialized)
        ? Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_controller!),
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          )
        : Center(
            child: Icon(Icons.broken_image, size: 24, color: Colors.grey[600]),
          );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FIX — Stateful Video Player widget for canvas preview
// ══════════════════════════════════════════════════════════════════════════════
class _VideoWidget extends StatefulWidget {
  final Map<String, dynamic> props;
  final double width, height;
  const _VideoWidget({
    required this.props,
    required this.width,
    required this.height,
  });

  @override
  State<_VideoWidget> createState() => _VideoWidgetState();
}

class _VideoWidgetState extends State<_VideoWidget> {
  late VideoPlayerController? _controller;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  void _initializeVideo() {
    final videoUrl =
        widget.props['videoUrl']?.toString() ??
        widget.props['src']?.toString() ??
        '';
    if (videoUrl.isEmpty) {
      _controller = null;
      return;
    }

    setState(() => _isLoading = true);

    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
        ..initialize()
            .then((_) {
              if (mounted) setState(() => _isLoading = false);
            })
            .catchError((e) {
              if (mounted) {
                setState(() => _isLoading = false);
                _controller = null;
              }
            });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _controller = null;
      }
    }
  }

  @override
  void didUpdateWidget(_VideoWidget old) {
    super.didUpdateWidget(old);
    final oldUrl =
        old.props['videoUrl']?.toString() ?? old.props['src']?.toString() ?? '';
    final newUrl =
        widget.props['videoUrl']?.toString() ??
        widget.props['src']?.toString() ??
        '';
    if (oldUrl != newUrl) {
      _controller?.dispose();
      _initializeVideo();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.props['imageUrl']?.toString() ?? '';
    final videoUrl =
        widget.props['videoUrl']?.toString() ??
        widget.props['src']?.toString() ??
        '';

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
        ),
        child: imageUrl.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_not_supported,
                          size: 40,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Flexible(
                          child: Text(
                            'Invalid image URL',
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : (_controller != null && _controller!.value.isInitialized)
            ? GestureDetector(
                onTap: () {
                  setState(() {
                    _controller!.value.isPlaying
                        ? _controller!.pause()
                        : _controller!.play();
                  });
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_controller!),
                    if (!_controller!.value.isPlaying)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(12),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                  ],
                ),
              )
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.video_library,
                        color: Colors.grey[400],
                        size: 40,
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: Text(
                          videoUrl.isEmpty
                              ? 'Add imageUrl or videoUrl'
                              : 'Invalid video URL',
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Radio Widget — Stateful for group value tracking
// ══════════════════════════════════════════════════════════════════════════════
class _RadioWidget extends StatefulWidget {
  final Map<String, dynamic> props;
  final double width, height;
  const _RadioWidget({
    required this.props,
    required this.width,
    required this.height,
  });

  @override
  State<_RadioWidget> createState() => _RadioWidgetState();
}

class _RadioWidgetState extends State<_RadioWidget> {
  late String _selectedValue;

  Color _c(String k, Color fb) {
    try {
      final hex = widget.props[k] as String? ?? '';
      if (hex.isEmpty) return fb;
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return fb;
    }
  }

  List<String> _list(String k, List<String> fb) {
    final v = widget.props[k];
    if (v is List) return List<String>.from(v);
    if (v is String) return v.split(',').map((e) => e.trim()).toList();
    return fb;
  }

  @override
  void initState() {
    super.initState();
    final options = _list('options', ['Option 1', 'Option 2', 'Option 3']);
    _selectedValue = widget.props['value']?.toString() ?? options.first;
  }

  @override
  void didUpdateWidget(_RadioWidget old) {
    super.didUpdateWidget(old);
    final newValue = widget.props['value']?.toString();
    if (newValue != null && newValue != old.props['value']?.toString()) {
      setState(() => _selectedValue = newValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _list('options', ['Option 1', 'Option 2', 'Option 3']);

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: options
              .map(
                (opt) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Radio<String>(
                      value: opt,
                      groupValue: _selectedValue,
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedValue = val);
                        }
                      },
                      activeColor: _c('color', AppTheme.primary),
                    ),
                    Expanded(
                      child: Text(
                        opt,
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Rating Widget — Stateful for interactive star rating
// ══════════════════════════════════════════════════════════════════════════════
class _RatingWidget extends StatefulWidget {
  final Map<String, dynamic> props;
  final double width, height;
  const _RatingWidget({
    required this.props,
    required this.width,
    required this.height,
  });

  @override
  State<_RatingWidget> createState() => _RatingWidgetState();
}

class _RatingWidgetState extends State<_RatingWidget> {
  late double _rating;

  Color _c(String k, Color fb) {
    try {
      final hex = widget.props[k] as String? ?? '';
      if (hex.isEmpty) return fb;
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return fb;
    }
  }

  double _d(String k, double fb) {
    final v = widget.props[k];
    return (v is num) ? v.toDouble() : fb;
  }

  String _s(String k, String fb) => widget.props[k]?.toString() ?? fb;

  @override
  void initState() {
    super.initState();
    _rating = _d('value', 0).clamp(0, 5).toDouble();
  }

  @override
  void didUpdateWidget(_RatingWidget old) {
    super.didUpdateWidget(old);
    final newValue = _d('value', 0).clamp(0, 5).toDouble();
    if (newValue != old.props['value']) {
      setState(() => _rating = newValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isInteractive = _s('interactive', 'true') == 'true';
    final color = _c('color', AppTheme.primary);

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            5,
            (i) => GestureDetector(
              onTap: isInteractive
                  ? () {
                      setState(() => _rating = (i + 1).toDouble());
                    }
                  : null,
              child: Icon(
                (i + 1) <= _rating ? Icons.star : Icons.star_border,
                color: color,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MultiSelect Widget — Stateful for tracking selections
// ══════════════════════════════════════════════════════════════════════════════
class _MultiSelectWidget extends StatefulWidget {
  final Map<String, dynamic> props;
  final double width, height;
  const _MultiSelectWidget({
    required this.props,
    required this.width,
    required this.height,
  });

  @override
  State<_MultiSelectWidget> createState() => _MultiSelectWidgetState();
}

class _MultiSelectWidgetState extends State<_MultiSelectWidget> {
  late Set<String> _selectedOptions;

  List<String> _list(String k, List<String> fb) {
    final v = widget.props[k];
    if (v is List) return List<String>.from(v);
    if (v is String) return v.split(',').map((e) => e.trim()).toList();
    return fb;
  }

  @override
  void initState() {
    super.initState();
    final selectedStr = widget.props['selected'];
    if (selectedStr is List) {
      _selectedOptions = Set<String>.from(selectedStr);
    } else if (selectedStr is String) {
      _selectedOptions = selectedStr.split(',').map((e) => e.trim()).toSet();
    } else {
      _selectedOptions = {};
    }
  }

  @override
  void didUpdateWidget(_MultiSelectWidget old) {
    super.didUpdateWidget(old);
    final newSelected = widget.props['selected'];
    if (newSelected != old.props['selected']) {
      if (newSelected is List) {
        setState(() => _selectedOptions = Set<String>.from(newSelected));
      } else if (newSelected is String) {
        setState(
          () => _selectedOptions = newSelected
              .split(',')
              .map((e) => e.trim())
              .toSet(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _list('options', ['Option 1', 'Option 2', 'Option 3']);

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: options
              .map(
                (opt) => CheckboxListTile(
                  value: _selectedOptions.contains(opt),
                  title: Text(opt, style: const TextStyle(fontSize: 13)),
                  onChanged: (_) {
                    setState(() {
                      if (_selectedOptions.contains(opt)) {
                        _selectedOptions.remove(opt);
                      } else {
                        _selectedOptions.add(opt);
                      }
                    });
                  },
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FIX 11 — Stateful Checkbox widget for canvas preview
// ══════════════════════════════════════════════════════════════════════════════
class _CheckboxWidget extends StatefulWidget {
  final Map<String, dynamic> props;
  final double width, height;
  const _CheckboxWidget({
    required this.props,
    required this.width,
    required this.height,
  });

  @override
  State<_CheckboxWidget> createState() => _CheckboxWidgetState();
}

class _CheckboxWidgetState extends State<_CheckboxWidget> {
  late bool _checked;

  Color _c(String k, Color fb) {
    try {
      final hex = widget.props[k] as String? ?? '';
      if (hex.isEmpty) return fb;
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return fb;
    }
  }

  @override
  void initState() {
    super.initState();
    final v = widget.props['checked'];
    _checked = v == true || v == 'true';
  }

  @override
  void didUpdateWidget(_CheckboxWidget old) {
    super.didUpdateWidget(old);
    // Sync when the property is changed from the panel
    final v = widget.props['checked'];
    _checked = v == true || v == 'true';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: _checked,
              onChanged: (val) => setState(() => _checked = val ?? false),
              activeColor: _c('color', AppTheme.primary),
            ),
            Expanded(
              child: Text(
                widget.props['label']?.toString() ?? 'Checkbox',
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FIX 12 — Stateful Switch widget for canvas preview
// ══════════════════════════════════════════════════════════════════════════════
class _SwitchWidget extends StatefulWidget {
  final Map<String, dynamic> props;
  final double width, height;
  const _SwitchWidget({
    required this.props,
    required this.width,
    required this.height,
  });

  @override
  State<_SwitchWidget> createState() => _SwitchWidgetState();
}

class _SwitchWidgetState extends State<_SwitchWidget> {
  late bool _value;

  Color _c(String k, Color fb) {
    try {
      final hex = widget.props[k] as String? ?? '';
      if (hex.isEmpty) return fb;
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return fb;
    }
  }

  @override
  void initState() {
    super.initState();
    final v = widget.props['value'];
    _value = v == true || v == 'true';
  }

  @override
  void didUpdateWidget(_SwitchWidget old) {
    super.didUpdateWidget(old);
    final v = widget.props['value'];
    _value = v == true || v == 'true';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: _value,
              onChanged: (val) => setState(() => _value = val),
              activeColor: _c('color', AppTheme.primary),
            ),
            Expanded(
              child: Text(
                widget.props['label']?.toString() ?? 'Switch',
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FIX 13 — Stateful Dropdown widget for canvas preview
// ══════════════════════════════════════════════════════════════════════════════
class _DropdownWidget extends StatefulWidget {
  final Map<String, dynamic> props;
  final double width, height;
  const _DropdownWidget({
    required this.props,
    required this.width,
    required this.height,
  });

  @override
  State<_DropdownWidget> createState() => _DropdownWidgetState();
}

class _DropdownWidgetState extends State<_DropdownWidget> {
  String? _selected;

  List<String> get _options {
    final v = widget.props['options'];
    if (v is List) return List<String>.from(v);
    if (v is String) return v.split(',').map((e) => e.trim()).toList();
    return ['Option 1', 'Option 2', 'Option 3'];
  }

  @override
  Widget build(BuildContext context) {
    final options = _options;
    // Guard: reset selected if it's no longer in the list
    if (_selected != null && !options.contains(_selected)) {
      _selected = null;
    }
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selected,
          hint: Text(widget.props['hint']?.toString() ?? 'Select...'),
          items: options
              .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
              .toList(),
          onChanged: (val) => setState(() => _selected = val),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FIX 14 — Fully functional interactive Todo widget
// Supports adding tasks, marking complete, and deleting — all within the canvas.
// ══════════════════════════════════════════════════════════════════════════════
class _TodoWidget extends StatefulWidget {
  final Map<String, dynamic> props;
  final double width, height;
  const _TodoWidget({
    required this.props,
    required this.width,
    required this.height,
  });

  @override
  State<_TodoWidget> createState() => _TodoWidgetState();
}

class _TodoWidgetState extends State<_TodoWidget> {
  final List<_Task> _tasks = [];
  final TextEditingController _ctrl = TextEditingController();

  Color get _accentColor {
    try {
      final hex = widget.props['color'] as String? ?? '#00C896';
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return AppTheme.primary;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _addTask() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _tasks.add(_Task(text));
      _ctrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.props['title']?.toString() ?? 'My Tasks';
    final emptyMsg =
        widget.props['emptyMessage']?.toString() ?? 'No tasks yet. Add one!';
    final color = _accentColor;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.task_alt, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${_tasks.where((t) => t.done).length}/${_tasks.length}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),

            // Input row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      style: const TextStyle(fontSize: 12),
                      onSubmitted: (_) => _addTask(),
                      decoration: InputDecoration(
                        hintText: 'Add a task...',
                        hintStyle: const TextStyle(fontSize: 12),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _addTask,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Task list
            Expanded(
              child: _tasks.isEmpty
                  ? Center(
                      child: Text(
                        emptyMsg,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      itemCount: _tasks.length,
                      itemBuilder: (_, i) {
                        final task = _tasks[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: task.done ? Colors.grey[100] : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: task.done,
                                onChanged: (val) =>
                                    setState(() => task.done = val ?? false),
                                activeColor: color,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              Expanded(
                                child: Text(
                                  task.text,
                                  style: TextStyle(
                                    fontSize: 12,
                                    decoration: task.done
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: task.done
                                        ? Colors.grey
                                        : Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                onPressed: () =>
                                    setState(() => _tasks.removeAt(i)),
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 4),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Task {
  String text;
  bool done = false;
  _Task(this.text);
}
