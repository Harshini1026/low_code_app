import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/builder_provider.dart';
import '../../models/widget_model.dart';

class CanvasArea extends StatelessWidget {
  final BuilderProvider provider;
  final Function(WidgetModel) onWidgetTap;
  const CanvasArea({super.key, required this.provider, required this.onWidgetTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A1520),
      child: Center(
        child: SingleChildScrollView(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(
              '${provider.activeScreen?.name ?? ""} · ${provider.currentWidgets.length} components',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            // Phone frame
            Container(
              width: 360, height: 680,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(36),
                border: Border.all(color: AppTheme.darkBorder, width: 8),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40, offset: const Offset(0, 16)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: DragTarget<String>(
                  onAcceptWithDetails: (details) {
                    final box = context.findRenderObject() as RenderBox;
                    final local = box.globalToLocal(details.offset);
                    // Approximate canvas position
                    provider.addWidget(details.data, x: (local.dx - 100).clamp(8.0, 280.0), y: (local.dy - 100).clamp(50.0, 600.0));
                  },
                  builder: (ctx, candidates, rejected) => Stack(
                    children: [
                      // Grid
                      Container(
                        color: candidates.isNotEmpty
                            ? AppTheme.primary.withOpacity(0.05)
                            : Colors.white,
                        child: CustomPaint(painter: _GridPainter(), size: Size.infinite),
                      ),
                      // Status bar
                      Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: provider.project != null
                              ? Color(int.parse(
                                  (provider.project!.theme.primaryColor).replaceAll('#', '0xFF')
                                ))
                              : AppTheme.primary,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 14),
                              child: Text(
                                provider.activeScreen?.name ?? '',
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.only(right: 14),
                              child: Row(children: [
                                Icon(Icons.signal_cellular_4_bar, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Icon(Icons.battery_full, color: Colors.white, size: 14),
                              ]),
                            ),
                          ],
                        ),
                      ),
                      // Widgets
                      ...provider.currentWidgets.map((w) => _DraggableWidget(
                        widget: w,
                        isSelected: provider.selectedWidget?.id == w.id,
                        onTap: () => onWidgetTap(w),
                        onDragUpdate: (delta) {
                          provider.moveWidget(w.id, w.x + delta.dx, w.y + delta.dy);
                        },
                      )),
                      // Empty state
                      if (provider.currentWidgets.isEmpty)
                        Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.drag_indicator, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 8),
                            Text('Drag widgets here', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text('or tap any widget on the left', style: TextStyle(color: Colors.grey.shade300, fontSize: 11)),
                          ]),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(mainAxisSize: MainAxisSize.min, children: [
              _ViewBtn(Icons.phone_android, 'Mobile', true),
              const SizedBox(width: 8),
              _ViewBtn(Icons.tablet_android, 'Tablet', false),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _DraggableWidget extends StatelessWidget {
  final WidgetModel widget;
  final bool isSelected;
  final VoidCallback onTap;
  final Function(Offset) onDragUpdate;
  const _DraggableWidget({required this.widget, required this.isSelected, required this.onTap, required this.onDragUpdate});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.x,
      top: widget.y,
      child: GestureDetector(
        onTap: onTap,
        onPanUpdate: (d) => onDragUpdate(d.delta),
        child: Container(
          width: widget.width,
          constraints: BoxConstraints(minHeight: widget.height),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? AppTheme.secondary : Colors.transparent,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Stack(children: [
            WidgetRenderer(widgetModel: widget),
            if (isSelected)
              Positioned(
                top: -10, right: -10,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(color: AppTheme.secondary, shape: BoxShape.circle),
                  child: const Icon(Icons.drag_indicator, color: Colors.white, size: 14),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class WidgetRenderer extends StatelessWidget {
  final WidgetModel widgetModel;
  const WidgetRenderer({super.key, required this.widgetModel});

  Color _color(String hex) {
    try { return Color(int.parse(hex.replaceAll('#', '0xFF'))); }
    catch (_) { return Colors.grey; }
  }

  @override
  Widget build(BuildContext context) {
    final p = widgetModel.properties;
    switch (widgetModel.type) {
      case 'button':
        return ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: _color(p['color'] ?? '#00C896'),
            foregroundColor: _color(p['textColor'] ?? '#FFFFFF'),
            minimumSize: Size(widgetModel.width, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular((p['borderRadius'] as num?)?.toDouble() ?? 12)),
          ),
          child: Text(p['label'] ?? 'Button', style: TextStyle(fontSize: (p['fontSize'] as num?)?.toDouble() ?? 16, fontWeight: FontWeight.bold)),
        );
      case 'text':
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text(p['content'] ?? 'Text Here',
            textAlign: p['align'] == 'center' ? TextAlign.center : p['align'] == 'right' ? TextAlign.right : TextAlign.left,
            style: TextStyle(
              fontSize: (p['fontSize'] as num?)?.toDouble() ?? 16,
              color: _color(p['color'] ?? '#1A1A2E'),
              fontWeight: p['bold'] == true ? FontWeight.bold : FontWeight.normal,
            )),
        );
      case 'input':
        return TextField(
          decoration: InputDecoration(
            hintText: p['hint'] ?? 'Enter text...',
            labelText: p['label'],
            labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          style: const TextStyle(color: Colors.black87, fontSize: 14),
        );
      case 'image':
        return Container(
          width: widgetModel.width, height: widgetModel.height,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular((p['borderRadius'] as num?)?.toDouble() ?? 8),
          ),
          child: (p['src'] as String?)?.isNotEmpty == true
            ? ClipRRect(
                borderRadius: BorderRadius.circular((p['borderRadius'] as num?)?.toDouble() ?? 8),
                child: Image.network(p['src'], fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey)),
              )
            : const Center(child: Icon(Icons.image, color: Colors.grey, size: 36)),
        );
      case 'card':
        return Card(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(p['title'] ?? 'Card Title', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
              if ((p['subtitle'] as String?)?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(p['subtitle'], style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ]),
          ),
        );
      case 'list':
        final items = (p['items'] as List?)?.cast<String>() ?? ['Item 1', 'Item 2', 'Item 3'];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(children: items.take(4).map((item) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(item, style: const TextStyle(fontSize: 13, color: Colors.black87)),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 16),
            ]),
          )).toList()),
        );
      case 'navbar':
        final items = (p['items'] as String? ?? 'Home,Search,Profile').split(',');
        return Container(
          height: 64, color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.asMap().entries.map((e) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(e.key == 0 ? Icons.home : e.key == 1 ? Icons.search : Icons.person,
                    color: e.key == 0 ? _color(p['color'] ?? '#00C896') : Colors.grey, size: 22),
                const SizedBox(height: 4),
                Text(e.value.trim(), style: TextStyle(fontSize: 10, color: e.key == 0 ? _color(p['color'] ?? '#00C896') : Colors.grey)),
              ],
            )).toList(),
          ),
        );
      case 'appbar':
        return Container(
          height: 56,
          color: _color(p['color'] ?? '#00C896'),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(p['title'] ?? 'My App', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const Icon(Icons.menu, color: Colors.white),
          ]),
        );
      case 'divider':
        return Divider(color: _color(p['color'] ?? '#E0E0E0'), thickness: (p['thickness'] as num?)?.toDouble() ?? 1);
      case 'icon':
        return Center(child: Icon(Icons.star, color: _color(p['color'] ?? '#FFD700'), size: (p['size'] as num?)?.toDouble() ?? 40));
      case 'dropdown':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(p['hint'] ?? 'Select...', style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          ]),
        );
      case 'checkbox':
        return Row(children: [
          Checkbox(value: p['checked'] == true, onChanged: null, activeColor: AppTheme.primary),
          Text(p['label'] ?? 'Checkbox', style: const TextStyle(fontSize: 14, color: Colors.black87)),
        ]);
      case 'switch_w':
        return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(p['label'] ?? 'Toggle', style: const TextStyle(fontSize: 14, color: Colors.black87)),
          Switch(value: p['value'] == true, onChanged: null, activeColor: AppTheme.primary),
        ]);
      case 'form':
        final fields = (p['fields'] as String? ?? 'Name,Email').split(',');
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
          child: Column(children: [
            ...fields.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                decoration: InputDecoration(labelText: f.trim(), border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), isDense: true),
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
            )),
            ElevatedButton(onPressed: () {}, child: Text(p['submitLabel'] ?? 'Submit'), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, minimumSize: const Size(double.infinity, 40))),
          ]),
        );
      case 'chart':
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
          child: Column(children: [
            Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [40.0, 70.0, 55.0, 85.0, 60.0, 90.0].map((h) => Container(
                width: 28, height: h * 0.8,
                decoration: BoxDecoration(
                  color: _color(p['color'] ?? '#00C896'),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              )).toList(),
            ),
            const SizedBox(height: 6),
            const Text('Bar Chart', style: TextStyle(fontSize: 10, color: Colors.grey)),
          ]),
        );
      default:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
          child: Center(child: Text(widgetModel.type.toUpperCase(), style: const TextStyle(fontSize: 11, color: Colors.grey))),
        );
    }
  }
}

class _ViewBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  const _ViewBtn(this.icon, this.label, this.active);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      color: active ? AppTheme.primary.withOpacity(0.15) : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: active ? AppTheme.primary : AppTheme.darkBorder),
    ),
    child: Row(children: [
      Icon(icon, size: 14, color: active ? AppTheme.primary : AppTheme.textMuted),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 12, color: active ? AppTheme.primary : AppTheme.textMuted, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.grey.withOpacity(0.07)..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 20) canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    for (double y = 0; y < size.height; y += 20) canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }
  @override bool shouldRepaint(_) => false;
}



