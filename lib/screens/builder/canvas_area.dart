import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/screen_model.dart';   // ✅ AppScreen lives here
import '../../models/widget_model.dart';
import '../../providers/builder_provider.dart';

// ══════════════════════════════════════════════════════════════════════════════
// CanvasArea
// ══════════════════════════════════════════════════════════════════════════════
class CanvasArea extends StatefulWidget {
  // ✅ AppScreen from screen_model.dart
  final AppScreen?             screen;
  final BuilderProvider        provider;
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
    final screen   = widget.screen;
    final provider = widget.provider;
    final selected = provider.selectedWidget;

    if (screen == null) {
      return const Center(
        child: Text('No screen selected',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
      );
    }

    return DragTarget<String>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final local = box.globalToLocal(details.offset);
        // ✅ clamp().toDouble() fixes the num→double type error
        final dx = local.dx.clamp(0.0, box.size.width  - 80).toDouble();
        final dy = local.dy.clamp(0.0, box.size.height - 60).toDouble();
        // ✅ addWidget(String type, double x, double y)
        provider.addWidget(details.data, dx.round(), dy.round());
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
      // Dot-grid
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(painter: _DotGridPainter()),
        ),
      ),

      // Empty hint
      if (screen.widgets.isEmpty)
        _EmptyHint(isHovering: isHovering),

      // Placed widgets
      ...screen.widgets.map((w) => _PositionedWidget(
            key: ValueKey(w.id),
            model: w,
            isSelected: selected?.id == w.id,
            onTap: () {
              provider.selectWidget(w);
              widget.onWidgetSelected(w);
            },
            onMoved: (pos) =>
                provider.moveWidget(w.id, pos.dx, pos.dy),
          )),
    ],
  ),
),);
      },
    );
  }

  Color _parseBg(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.white;
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return Colors.white;
    }
  }
}

// ── Empty hint ────────────────────────────────────────────────────────────────
class _EmptyHint extends StatelessWidget {
  final bool isHovering;
  const _EmptyHint({required this.isHovering});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            shape:  BoxShape.circle,
            color:  isHovering
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
            color:      isHovering
                ? AppTheme.primary
                : Colors.grey.withOpacity(0.4),
            fontSize:   12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ]),
    );
  }
}

// ── Dot grid ──────────────────────────────────────────────────────────────────
class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color       = Colors.grey.withOpacity(0.12)
      ..strokeWidth = 1;
    const step = 24.0;
    for (double x = 0; x < size.width;  x += step) {
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
  final WidgetModel      model;
  final bool             isSelected;
  final VoidCallback     onTap;
  final Function(Offset) onMoved;

  const _PositionedWidget({
    super.key,
    required this.model,
    required this.isSelected,
    required this.onTap,
    required this.onMoved,
  });

  @override
  State<_PositionedWidget> createState() => _PositionedWidgetState();
}

class _PositionedWidgetState extends State<_PositionedWidget> {
  late Offset _pos;
  bool        _dragging = false;

  @override
  void initState() {
    super.initState();
    _pos = Offset(widget.model.x.toDouble(), widget.model.y.toDouble());
  }

  @override
  void didUpdateWidget(_PositionedWidget old) {
    super.didUpdateWidget(old);
    if (!_dragging) {
      _pos = Offset(widget.model.x.toDouble(), widget.model.y.toDouble());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _pos.dx,
      top:  _pos.dy,
      child: GestureDetector(
        onTap: widget.onTap,
        onPanStart: (_) => _dragging = true,
        onPanUpdate: (d) {
          setState(() {
            _pos = Offset(
              (_pos.dx + d.delta.dx).clamp(0.0, 240.0),
              (_pos.dy + d.delta.dy).clamp(0.0, 500.0),
            );
          });
        },
        onPanEnd: (_) {
          _dragging = false;
          widget.onMoved(_pos);
        },
        child: _SelectionBorder(
          isSelected: widget.isSelected,
          child:      WidgetRenderer(widgetModel: widget.model),
        ),
      ),
    );
  }
}

// ── Selection border ──────────────────────────────────────────────────────────
class _SelectionBorder extends StatelessWidget {
  final bool   isSelected;
  final Widget child;
  const _SelectionBorder(
      {required this.isSelected, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: isSelected
          ? BoxDecoration(
              border:       Border.all(color: AppTheme.primary, width: 2),
              borderRadius: BorderRadius.circular(4),
            )
          : null,
      child: child,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WidgetRenderer — public so preview_screen.dart can import it
// ══════════════════════════════════════════════════════════════════════════════
class WidgetRenderer extends StatelessWidget {
  final WidgetModel widgetModel;
  const WidgetRenderer({super.key, required this.widgetModel});

  // ── typed helpers (class-level, NOT nested inside build) ─────────
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

  TextAlign _align(String? v) {
    if (v == 'center') return TextAlign.center;
    if (v == 'right')  return TextAlign.right;
    return TextAlign.left;
  }

  @override
  Widget build(BuildContext context) {
    final props = widgetModel.properties;

    switch (widgetModel.type) {

      case 'button':
        return ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: _c(props, 'color', AppTheme.primary),
            foregroundColor: _c(props, 'textColor', Colors.white),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                    _d(props, 'borderRadius', 8))),
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 12),
            minimumSize:   Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(_s(props, 'label', 'Button'),
              style: TextStyle(fontSize: _d(props, 'fontSize', 14))),
        );

      case 'text':
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Text(
            _s(props, 'content', 'Text'),
            style: TextStyle(
              color:      _c(props, 'color', Colors.black87),
              fontSize:   _d(props, 'fontSize', 16),
              fontWeight: props['bold'] == 'true'
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
            textAlign: _align(props['align']?.toString()),
          ),
        );

      case 'input':
        return SizedBox(
          width: 220,
          child: TextField(
            enabled: false,
            decoration: InputDecoration(
              hintText:       _s(props, 'hint', 'Enter text…'),
              labelText:      props['label']?.toString(),
              filled:         true,
              fillColor:      Colors.grey[100],
              border:         OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              isDense:        true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
            ),
          ),
        );

      case 'image':
        final src = _s(props, 'src', '');
        return ClipRRect(
          borderRadius: BorderRadius.circular(
              _d(props, 'borderRadius', 8)),
          child: src.startsWith('http')
              ? Image.network(src,
                  width: 200, height: 150, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _imgPlaceholder())
              : _imgPlaceholder(),
        );

      case 'card':
        return SizedBox(
          width: 220,
          child: Card(
            elevation: _d(props, 'elevation', 2),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_s(props, 'title', 'Card Title'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(_s(props, 'subtitle', 'Subtitle'),
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          ),
        );

      case 'icon':
        return Icon(Icons.star,
            color: _c(props, 'color', AppTheme.primary),
            size:  _d(props, 'size', 32));

      case 'divider':
        return SizedBox(
          width: 200,
          child: Divider(
              color:     _c(props, 'color', Colors.grey),
              thickness: 1),
        );

      case 'appbar':
        return Container(
          width:   double.infinity,
          height:  48,
          color:   _c(props, 'color', AppTheme.primary),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(children: [
            if (props['showBack'] == 'true')
              const Icon(Icons.arrow_back,
                  color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_s(props, 'title', 'Screen Title'),
                  style: const TextStyle(
                      color:      Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize:   16)),
            ),
          ]),
        );

      case 'navbar':
        return Container(
          width:  double.infinity,
          height: 52,
          decoration: const BoxDecoration(
            color:     Colors.white,
            boxShadow: [BoxShadow(
                color: Colors.black12, blurRadius: 8)],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [Icons.home, Icons.search, Icons.person]
                .map((ic) => Icon(ic,
                    color: _c(props, 'color', AppTheme.primary),
                    size:  22))
                .toList(),
          ),
        );

      case 'checkbox':
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Checkbox(
              value:       false,
              onChanged:   null,
              activeColor: _c(props, 'color', AppTheme.primary)),
          Text(_s(props, 'label', 'Checkbox'),
              style: const TextStyle(fontSize: 13)),
        ]);

      case 'switch_w':
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Switch(
              value:       false,
              onChanged:   null,
              activeColor: _c(props, 'color', AppTheme.primary)),
          Text(_s(props, 'label', 'Switch'),
              style: const TextStyle(fontSize: 13)),
        ]);

      default:
        return Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color:        AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border:       Border.all(
                color: AppTheme.primary.withOpacity(0.3)),
          ),
          child: Text(widgetModel.type,
              style: const TextStyle(
                  color: AppTheme.primary, fontSize: 12)),
        );
    }
  }

  Widget _imgPlaceholder() => Container(
        width:  200,
        height: 140,
        decoration: BoxDecoration(
            color:        Colors.grey[200],
            borderRadius: BorderRadius.circular(8)),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_outlined,
                color: Colors.grey, size: 36),
            SizedBox(height: 6),
            Text('Image',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
}