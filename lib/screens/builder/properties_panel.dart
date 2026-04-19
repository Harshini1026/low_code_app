import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/widget_model.dart';
import '../../providers/builder_provider.dart';

// ── FIX 15: PropertiesPanel now takes the BuilderProvider directly so it can
// call updateWidgetSize() for width/height changes in addition to the existing
// updateWidgetProperty() for all other fields.
class PropertiesPanel extends StatelessWidget {
  final WidgetModel widget;
  final BuilderProvider provider; // added
  final Function(String key, dynamic value) onPropertyChanged;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final VoidCallback onBindData;
  final VoidCallback onDeselect;

  const PropertiesPanel({
    super.key,
    required this.widget,
    required this.provider,
    required this.onPropertyChanged,
    required this.onDelete,
    required this.onDuplicate,
    required this.onBindData,
    required this.onDeselect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: AppTheme.darkCard,
        border: Border(left: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Properties',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.type,
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onDeselect,
                  color: AppTheme.textMuted,
                ),
              ],
            ),
          ),
          const Divider(color: AppTheme.darkBorder, height: 1),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Data binding badge
                  if (widget.boundTable != null &&
                      widget.boundTable!.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.secondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppTheme.secondary.withOpacity(0.3)),
                      ),
                      child: Text(
                        '🔗 ${widget.boundTable}.${widget.boundField}',
                        style: const TextStyle(
                          color: AppTheme.secondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── FIX 16: Width & Height size controls appear for every
                  // widget type, immediately above the widget-specific fields.
                  _SizeControls(widget: widget, provider: provider),
                  const SizedBox(height: 4),

                  // Dynamic widget-specific fields
                  ..._buildFields(),

                  const SizedBox(height: 16),
                  const Divider(color: AppTheme.darkBorder),
                  const SizedBox(height: 12),

                  const Text(
                    'ACTIONS',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ActionBtn(
                    Icons.link,
                    'Bind to Database',
                    AppTheme.secondary,
                    onBindData,
                  ),
                  const SizedBox(height: 6),
                  _ActionBtn(
                    Icons.copy,
                    'Duplicate Widget',
                    AppTheme.textMuted,
                    onDuplicate,
                  ),
                  const SizedBox(height: 6),
                  _ActionBtn(
                    Icons.delete_outline,
                    'Delete Widget',
                    AppTheme.accent,
                    onDelete,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFields() {
    final fields = <Widget>[];

    void add(
      String label,
      String key, {
      String type = 'text',
      List<String>? options,
      double? min,
      double? max,
    }) {
      fields.add(
        _PropRow(
          label: label,
          value: widget.properties[key],
          type: type,
          options: options,
          min: min,
          max: max,
          onChanged: (v) => onPropertyChanged(key, v),
        ),
      );
      fields.add(const SizedBox(height: 12));
    }

    switch (widget.type) {
      case 'button':
        add('Label', 'label');
        add('Background', 'color', type: 'color');
        add('Text Color', 'textColor', type: 'color');
        add('Font Size', 'fontSize', type: 'slider', min: 10, max: 32);
        add('Border Radius', 'borderRadius', type: 'slider', min: 0, max: 32);
        add('On Tap', 'action',
            type: 'select',
            options: ['none', 'navigate', 'submit', 'open_url']);
        break;
      case 'text':
        add('Content', 'content');
        add('Color', 'color', type: 'color');
        add('Font Size', 'fontSize', type: 'slider', min: 10, max: 48);
        add('Bold', 'bold', type: 'select', options: ['false', 'true']);
        add('Alignment', 'align',
            type: 'select', options: ['left', 'center', 'right']);
        break;
      case 'input':
        add('Placeholder', 'hint');
        add('Label', 'label');
        add('Type', 'type',
            type: 'select',
            options: ['text', 'email', 'password', 'number', 'phone']);
        break;
      case 'image':
        add('Image URL', 'src');
        add('Border Radius', 'borderRadius', type: 'slider', min: 0, max: 32);
        add('Fit', 'fit',
            type: 'select', options: ['cover', 'contain', 'fill']);
        break;
      case 'card':
        add('Title', 'title');
        add('Subtitle', 'subtitle');
        add('Elevation', 'elevation', type: 'slider', min: 0, max: 16);
        break;
      case 'appbar':
        add('Title', 'title');
        add('Background', 'color', type: 'color');
        add('Show Back Button', 'showBack',
            type: 'select', options: ['false', 'true']);
        break;
      case 'navbar':
        add('Active Color', 'color', type: 'color');
        add('Items (comma sep)', 'items');
        break;
      case 'icon':
        add('Color', 'color', type: 'color');
        add('Size', 'size', type: 'slider', min: 16, max: 80);
        break;
      case 'form':
        add('Fields (comma sep)', 'fields');
        add('Submit Label', 'submitLabel');
        add('Submit Color', 'color', type: 'color');
        break;
      case 'checkbox':
        add('Label', 'label');
        add('Color', 'color', type: 'color');
        add('Checked', 'checked',
            type: 'select', options: ['false', 'true']);
        break;
      case 'switch_w':
        add('Label', 'label');
        add('Active Color', 'color', type: 'color');
        add('Value', 'value',
            type: 'select', options: ['false', 'true']);
        break;
      case 'dropdown':
        add('Hint', 'hint');
        add('Options (comma sep)', 'options');
        add('Color', 'color', type: 'color');
        break;
      case 'list':
        add('Items (comma sep)', 'items');
        add('Show Divider', 'divider',
            type: 'select', options: ['true', 'false']);
        break;
      case 'grid':
        add('Columns', 'columns', type: 'slider', min: 1, max: 6);
        add('Items (comma sep)', 'items');
        break;
      case 'chart':
        add('Chart Type', 'type',
            type: 'select', options: ['line', 'bar', 'pie', 'area']);
        add('Color', 'color', type: 'color');
        break;
      case 'container':
        add('Background Color', 'bgColor', type: 'color');
        add('Border Color', 'borderColor', type: 'color');
        add('Border Width', 'borderWidth', type: 'slider', min: 0, max: 8);
        add('Border Radius', 'borderRadius', type: 'slider', min: 0, max: 32);
        break;
      case 'divider':
        add('Color', 'color', type: 'color');
        add('Thickness', 'thickness', type: 'slider', min: 1, max: 8);
        break;
      case 'todo':
        add('Title', 'title');
        add('Accent Color', 'color', type: 'color');
        add('Empty Message', 'emptyMessage');
        break;
      case 'dialog':
        add('Title', 'title');
        add('Body', 'body');
        add('Buttons (comma sep)', 'buttons');
        break;
      default:
        add('Label', 'label');
        add('Color', 'color', type: 'color');
    }

    return fields;
  }

  Widget _ActionBtn(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) =>
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color.withOpacity(0.4)),
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          icon: Icon(icon, size: 16),
          label: Text(label,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// FIX 16 — Width & Height size controls (always visible in panel)
// ══════════════════════════════════════════════════════════════════════════════
class _SizeControls extends StatefulWidget {
  final WidgetModel widget;
  final BuilderProvider provider;
  const _SizeControls({required this.widget, required this.provider});

  @override
  State<_SizeControls> createState() => _SizeControlsState();
}

class _SizeControlsState extends State<_SizeControls> {
  late TextEditingController _wCtrl;
  late TextEditingController _hCtrl;

  @override
  void initState() {
    super.initState();
    _wCtrl = TextEditingController(
        text: widget.widget.safeWidth.toInt().toString());
    _hCtrl = TextEditingController(
        text: widget.widget.safeHeight.toInt().toString());
  }

  @override
  void didUpdateWidget(_SizeControls old) {
    super.didUpdateWidget(old);
    // Refresh when a different widget is selected
    if (old.widget.id != widget.widget.id) {
      _wCtrl.text = widget.widget.safeWidth.toInt().toString();
      _hCtrl.text = widget.widget.safeHeight.toInt().toString();
    }
  }

  @override
  void dispose() {
    _wCtrl.dispose();
    _hCtrl.dispose();
    super.dispose();
  }

  void _commit() {
    final w = double.tryParse(_wCtrl.text) ?? widget.widget.safeWidth;
    final h = double.tryParse(_hCtrl.text) ?? widget.widget.safeHeight;
    widget.provider.updateWidgetSize(widget.widget.id, w, h);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SIZE',
          style: TextStyle(
            color: AppTheme.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _SizeField(
                label: 'W',
                controller: _wCtrl,
                onSubmitted: _commit,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SizeField(
                label: 'H',
                controller: _hCtrl,
                onSubmitted: _commit,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(color: AppTheme.darkBorder, height: 1),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _SizeField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final VoidCallback onSubmitted;
  const _SizeField({
    required this.label,
    required this.controller,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      onFieldSubmitted: (_) => onSubmitted(),
      onEditingComplete: onSubmitted,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
      decoration: InputDecoration(
        prefixText: '$label  ',
        prefixStyle:
            const TextStyle(color: AppTheme.textMuted, fontSize: 11),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
    );
  }
}

// ── Single property row ───────────────────────────────────────────────────────
class _PropRow extends StatelessWidget {
  final String label;
  final dynamic value;
  final String type;
  final List<String>? options;
  final double? min, max;
  final Function(dynamic) onChanged;

  const _PropRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.type = 'text',
    this.options,
    this.min,
    this.max,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 5),
          _buildControl(context),
        ],
      );

  Widget _buildControl(BuildContext context) {
    switch (type) {
      case 'color':
        final hex =
            value is String ? value as String : '#00C896';
        Color c;
        try {
          c = Color(int.parse(hex.replaceAll('#', '0xFF')));
        } catch (_) {
          c = AppTheme.primary;
        }
        return Row(
          children: [
            GestureDetector(
              onTap: () => _showColorPicker(context, c),
              child: Container(
                width: 36,
                height: 32,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.darkBorder),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: hex,
                onChanged: onChanged,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
                decoration: const InputDecoration(
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true,
                ),
              ),
            ),
          ],
        );

      case 'slider':
        final double sliderMin = min ?? 0;
        final double sliderMax = max ?? 100;
        final double v =
            (value is num ? (value as num).toDouble() : sliderMin)
                .clamp(sliderMin, sliderMax);
        return Row(
          children: [
            Expanded(
              child: Slider(
                value: v,
                min: sliderMin,
                max: sliderMax,
                activeColor: AppTheme.primary,
                inactiveColor: AppTheme.darkBorder,
                onChanged: (double newVal) => onChanged(newVal),
              ),
            ),
            SizedBox(
              width: 28,
              child: Text(
                v.toInt().toString(),
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 12),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        );

      case 'select':
        final String v =
            value?.toString() ?? (options?.first ?? '');
        final String? safeVal =
            options?.contains(v) == true ? v : options?.first;
        return DropdownButtonFormField<String>(
          value: safeVal,
          items: (options ?? [])
              .map((o) => DropdownMenuItem(
                    value: o,
                    child: Text(o,
                        style: const TextStyle(fontSize: 12)),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          dropdownColor: AppTheme.darkCard,
          style:
              const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        );

      default:
        return TextFormField(
          initialValue: value?.toString() ?? '',
          onChanged: onChanged,
          style: const TextStyle(
              color: AppTheme.textPrimary, fontSize: 12),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        );
    }
  }

  void _showColorPicker(BuildContext context, Color current) {
    const palette = [
      '#00C896', '#6C63FF', '#FF6B6B', '#FF6B35',
      '#3498DB', '#E74C3C', '#F39C12', '#8E44AD',
      '#2ECC71', '#1ABC9C', '#34495E', '#2C3E50',
      '#FFFFFF', '#F5F5F5', '#333333', '#000000',
    ];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Pick a Color',
            style: TextStyle(
                color: AppTheme.textPrimary, fontSize: 16)),
        content: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: palette.map((hex) {
            final c = Color(int.parse(hex.replaceAll('#', '0xFF')));
            return GestureDetector(
              onTap: () {
                onChanged(hex);
                Navigator.pop(context);
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: c == current
                        ? Colors.white
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}