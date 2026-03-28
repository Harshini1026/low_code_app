import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/widget_model.dart';

class PropertiesPanel extends StatelessWidget {
  final WidgetModel widget;
  final Function(String key, dynamic value) onPropertyChanged;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final VoidCallback onBindData;
  final VoidCallback onDeselect;

  const PropertiesPanel({
    super.key,
    required this.widget,
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
      child: Column(children: [

        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Properties',
                    style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(widget.type,
                      style: const TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onDeselect,
              color: AppTheme.textMuted,
            ),
          ]),
        ),
        const Divider(color: AppTheme.darkBorder, height: 1),

        // Scrollable property list
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Data binding badge
              if (widget.boundTable != null && widget.boundTable!.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.secondary.withOpacity(0.3)),
                  ),
                  child: Text(
                    '🔗 ${widget.boundTable}.${widget.boundField}',
                    style: const TextStyle(color: AppTheme.secondary, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Dynamic fields
              ..._buildFields(),

              const SizedBox(height: 16),
              const Divider(color: AppTheme.darkBorder),
              const SizedBox(height: 12),

              // Actions
              const Text('ACTIONS',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
              const SizedBox(height: 8),
              _ActionBtn(Icons.link, 'Bind to Database', AppTheme.secondary, onBindData),
              const SizedBox(height: 6),
              _ActionBtn(Icons.copy, 'Duplicate Widget', AppTheme.textMuted, onDuplicate),
              const SizedBox(height: 6),
              _ActionBtn(Icons.delete_outline, 'Delete Widget', AppTheme.accent, onDelete),
            ]),
          ),
        ),
      ]),
    );
  }

  List<Widget> _buildFields() {
    final fields = <Widget>[];

    void add(String label, String key,
        {String type = 'text', List<String>? options, double? min, double? max}) {
      fields.add(_PropRow(
        label: label,
        value: widget.properties[key],
        type: type,
        options: options,
        min: min,
        max: max,
        onChanged: (v) => onPropertyChanged(key, v),
      ));
      fields.add(const SizedBox(height: 12));
    }

    switch (widget.type) {
      case 'button':
        add('Label', 'label');
        add('Background', 'color', type: 'color');
        add('Text Color', 'textColor', type: 'color');
        add('Font Size', 'fontSize', type: 'slider', min: 10, max: 32);
        add('Border Radius', 'borderRadius', type: 'slider', min: 0, max: 32);
        add('On Tap', 'action', type: 'select', options: ['none', 'navigate', 'submit', 'open_url']);
        break;
      case 'text':
        add('Content', 'content');
        add('Color', 'color', type: 'color');
        add('Font Size', 'fontSize', type: 'slider', min: 10, max: 48);
        add('Bold', 'bold', type: 'select', options: ['false', 'true']);
        add('Alignment', 'align', type: 'select', options: ['left', 'center', 'right']);
        break;
      case 'input':
        add('Placeholder', 'hint');
        add('Label', 'label');
        add('Type', 'type', type: 'select', options: ['text', 'email', 'password', 'number', 'phone']);
        break;
      case 'search':
        add('Hint Text', 'hint');
        add('Label', 'label');
        add('Prefix Icon', 'prefixIcon', type: 'select', options: ['search', 'mic', 'location']);
        break;
      case 'image':
        add('Image URL', 'src');
        add('Border Radius', 'borderRadius', type: 'slider', min: 0, max: 32);
        add('Fit', 'fit', type: 'select', options: ['cover', 'contain', 'fill']);
        break;
      case 'card':
        add('Title', 'title');
        add('Subtitle', 'subtitle');
        add('Elevation', 'elevation', type: 'slider', min: 0, max: 16);
        break;
      case 'appbar':
        add('Title', 'title');
        add('Background', 'color', type: 'color');
        add('Show Back Button', 'showBack', type: 'select', options: ['false', 'true']);
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
      case 'spacer':
        add('Height', 'height', type: 'slider', min: 8, max: 64);
        break;
      case 'badge':
        add('Label', 'label');
        add('Background', 'color', type: 'color');
        add('Text Color', 'textColor', type: 'color');
        add('Badge Count', 'count');
        break;
      case 'checkbox':
        add('Label', 'label');
        add('Color', 'color', type: 'color');
        add('Value (true/false)', 'value', type: 'select', options: ['false', 'true']);
        break;
      case 'radio':
        add('Label', 'label');
        add('Options (comma sep)', 'options');
        add('Color', 'color', type: 'color');
        break;
      case 'switch_w':
        add('Label', 'label');
        add('Active Color', 'activeColor', type: 'color');
        break;
      case 'slider':
        add('Min Value', 'min', type: 'slider', min: 0, max: 100);
        add('Max Value', 'max', type: 'slider', min: 1, max: 100);
        add('Color', 'color', type: 'color');
        break;
      case 'dropdown':
        add('Hint', 'hint');
        add('Options (comma sep)', 'options');
        add('Color', 'color', type: 'color');
        break;
      case 'rating':
        add('Max Stars', 'max', type: 'slider', min: 1, max: 10);
        add('Initial Value', 'value', type: 'slider', min: 0, max: 5);
        add('Color', 'color', type: 'color');
        add('Size', 'size', type: 'slider', min: 16, max: 48);
        break;
      case 'progress':
        add('Value (0-100)', 'value', type: 'slider', min: 0, max: 100);
        add('Color', 'color', type: 'color');
        add('Show Label', 'showLabel', type: 'select', options: ['false', 'true']);
        break;
      case 'datepick':
        add('Format', 'format', type: 'select', options: ['MM/DD/YYYY', 'DD/MM/YYYY', 'YYYY-MM-DD']);
        add('Color', 'color', type: 'color');
        break;
      case 'timepick':
        add('Format', 'format', type: 'select', options: ['12h', '24h']);
        add('Color', 'color', type: 'color');
        break;
      case 'row':
        add('Alignment', 'mainAxisAlignment', type: 'select', options: ['start', 'center', 'end', 'spaced']);
        add('Cross Alignment', 'crossAxisAlignment', type: 'select', options: ['start', 'center', 'end']);
        break;
      case 'column':
        add('Alignment', 'mainAxisAlignment', type: 'select', options: ['start', 'center', 'end', 'spaced']);
        add('Cross Alignment', 'crossAxisAlignment', type: 'select', options: ['start', 'center', 'end']);
        break;
      case 'stack':
        add('Fit', 'fit', type: 'select', options: ['loose', 'expand']);
        break;
      case 'tooltip':
        add('Message', 'message');
        add('Background Color', 'color', type: 'color');
        break;
      case 'dialog':
        add('Title', 'title');
        add('Body', 'body');
        add('Buttons (comma sep)', 'buttons');
        break;
      case 'snackbar':
        add('Message', 'message');
        add('Background Color', 'color', type: 'color');
        add('Duration (ms)', 'duration', type: 'slider', min: 1000, max: 5000);
        break;
      case 'lottie':
        add('Animation URL', 'animationUrl');
        add('Loop', 'loop', type: 'select', options: ['false', 'true']);
        break;
      case 'chart':
        add('Chart Type', 'type', type: 'select', options: ['line', 'bar', 'pie', 'area']);
        add('Color', 'color', type: 'color');
        break;
      case 'list':
        add('Item Count', 'itemCount', type: 'slider', min: 1, max: 20);
        add('Divider', 'showDivider', type: 'select', options: ['false', 'true']);
        break;
      case 'grid':
        add('Columns', 'columns', type: 'slider', min: 1, max: 6);
        add('Spacing', 'spacing', type: 'slider', min: 4, max: 24);
        break;
      case 'tabs':
        add('Tab Labels (comma sep)', 'labels');
        add('Indicator Color', 'color', type: 'color');
        break;
      case 'map':
        add('Latitude', 'latitude');
        add('Longitude', 'longitude');
        add('Zoom Level', 'zoom', type: 'slider', min: 1, max: 20);
        break;
      case 'video':
        add('Video URL', 'videoUrl');
        add('Show Controls', 'showControls', type: 'select', options: ['false', 'true']);
        add('Autoplay', 'autoplay', type: 'select', options: ['false', 'true']);
        break;
      case 'carousel':
        add('Item Count', 'itemCount', type: 'slider', min: 2, max: 10);
        add('Auto Play', 'autoPlay', type: 'select', options: ['false', 'true']);
        break;
      case 'richtext':
        add('Content', 'content');
        add('Font Size', 'fontSize', type: 'slider', min: 10, max: 48);
        add('Colors (comma sep)', 'colors');
        break;
      case 'iconbtn':
        add('Icon', 'icon', type: 'select', options: ['menu', 'search', 'close', 'add', 'delete']);
        add('Icon Color', 'color', type: 'color');
        add('Size', 'size', type: 'slider', min: 16, max: 48);
        break;
      case 'fab':
        add('Label', 'label');
        add('Icon', 'icon', type: 'select', options: ['add', 'edit', 'phone', 'message', 'favorite']);
        add('Background Color', 'color', type: 'color');
        add('Position', 'position', type: 'select', options: ['bottom-right', 'bottom-left', 'bottom-center']);
        add('On Tap', 'action', type: 'select', options: ['none', 'navigate', 'submit', 'open_url']);
        break;
      case 'multiline':
        add('Placeholder', 'hint');
        add('Label', 'label');
        add('Min Lines', 'minLines', type: 'slider', min: 1, max: 5);
        add('Max Lines', 'maxLines', type: 'slider', min: 3, max: 20);
        break;
      case 'multiselect':
        add('Options (comma sep)', 'options');
        add('Hint', 'hint');
        add('Color', 'color', type: 'color');
        break;
      case 'autocomplete':
        add('Placeholder', 'hint');
        add('Options (comma sep)', 'options');
        add('Min Chars', 'minChars', type: 'slider', min: 1, max: 5);
        break;
      case 'padding':
        add('Horizontal Padding', 'horizontalPadding', type: 'slider', min: 0, max: 32);
        add('Vertical Padding', 'verticalPadding', type: 'slider', min: 0, max: 32);
        break;
      case 'expanded':
        add('Flex', 'flex', type: 'slider', min: 1, max: 10);
        break;
      case 'flexible':
        add('Flex', 'flex', type: 'slider', min: 1, max: 10);
        add('Fit', 'fit', type: 'select', options: ['tight', 'loose']);
        break;
      case 'wrapper':
        add('Spacing', 'spacing', type: 'slider', min: 4, max: 24);
        add('Run Spacing', 'runSpacing', type: 'slider', min: 4, max: 24);
        break;
      case 'rangeslider':
        add('Min Value', 'minValue', type: 'slider', min: 0, max: 100);
        add('Max Value', 'maxValue', type: 'slider', min: 1, max: 100);
        add('Start', 'start', type: 'slider', min: 0, max: 50);
        add('End', 'end', type: 'slider', min: 50, max: 100);
        add('Color', 'color', type: 'color');
        break;
      case 'accordion':
        add('Title', 'title');
        add('Content', 'content');
        add('Color', 'color', type: 'color');
        add('Initially Expanded', 'expanded', type: 'select', options: ['false', 'true']);
        break;
      case 'stepper':
        add('Step Count', 'stepCount', type: 'slider', min: 1, max: 10);
        add('Current Step', 'currentStep', type: 'slider', min: 0, max: 9);
        add('Type', 'type', type: 'select', options: ['vertical', 'horizontal']);
        break;
      case 'timeline':
        add('Items', 'items');
        add('Direction', 'direction', type: 'select', options: ['vertical', 'horizontal']);
        break;
      case 'table':
        add('Columns', 'columns', type: 'slider', min: 1, max: 10);
        add('Rows', 'rows', type: 'slider', min: 1, max: 20);
        add('Scrollable', 'scrollable', type: 'select', options: ['false', 'true']);
        break;
      case 'chip':
        add('Label', 'label');
        add('Background Color', 'color', type: 'color');
        add('Text Color', 'textColor', type: 'color');
        add('Avatar', 'avatar', type: 'select', options: ['none', 'icon', 'image']);
        break;
      case 'segcontrol':
        add('Options (comma sep)', 'options');
        add('Color', 'color', type: 'color');
        break;
      case 'pincode':
        add('Length', 'length', type: 'slider', min: 3, max: 8);
        add('Field Shape', 'shape', type: 'select', options: ['box', 'circle', 'underline']);
        add('Field Color', 'color', type: 'color');
        break;
      case 'signature':
        add('Background Color', 'backgroundColor', type: 'color');
        add('Pen Color', 'penColor', type: 'color');
        add('Pen Width', 'penWidth', type: 'slider', min: 1, max: 10);
        break;
      case 'drawer':
        add('Width', 'width', type: 'slider', min: 200, max: 400);
        add('Items', 'items');
        break;
      case 'navdrawer':
        add('Items', 'items');
        add('Selected Index', 'selectedIndex', type: 'slider', min: 0, max: 10);
        break;
      case 'menu':
        add('Items (comma sep)', 'items');
        add('Trigger Type', 'triggerType', type: 'select', options: ['tap', 'longpress']);
        break;
      case 'breadcrumb':
        add('Items (comma sep)', 'items');
        add('Separator', 'separator', type: 'select', options: ['slash', 'arrow', 'dot']);
        break;
      case 'pagination':
        add('Total Pages', 'totalPages', type: 'slider', min: 1, max: 100);
        add('Current Page', 'currentPage', type: 'slider', min: 1, max: 100);
        add('Color', 'color', type: 'color');
        break;
      case 'alert':
        add('Title', 'title');
        add('Message', 'message');
        add('Type', 'type', type: 'select', options: ['info', 'warning', 'error', 'success']);
        break;
      case 'bottomsheet':
        add('Title', 'title');
        add('Content', 'content');
        add('Height', 'height', type: 'slider', min: 100, max: 600);
        break;
      case 'loader':
        add('Type', 'type', type: 'select', options: ['circular', 'linear', 'dots', 'pulse']);
        add('Color', 'color', type: 'color');
        add('Size', 'size', type: 'slider', min: 20, max: 80);
        break;
      case 'skeleton':
        add('Width', 'width', type: 'slider', min: 50, max: 300);
        add('Height', 'height', type: 'slider', min: 10, max: 100);
        add('Border Radius', 'borderRadius', type: 'slider', min: 0, max: 20);
        break;
      case 'emptystate':
        add('Icon', 'icon', type: 'select', options: ['inbox', 'search', 'box', 'star']);
        add('Title', 'title');
        add('Message', 'message');
        break;
      case 'errorstate':
        add('Error Code', 'code');
        add('Message', 'message');
        add('Action Text', 'actionText');
        break;
      case 'googlelogin':
        add('Button Text', 'text');
        add('On Success', 'onSuccess', type: 'select', options: ['navigate', 'submit', 'custom']);
        break;
      case 'fblogin':
        add('Button Text', 'text');
        add('On Success', 'onSuccess', type: 'select', options: ['navigate', 'submit', 'custom']);
        break;
      case 'sharebutton':
        add('Share Text', 'shareText');
        add('Share URL', 'shareUrl');
        add('Color', 'color', type: 'color');
        break;
      case 'likebutton':
        add('Initial Count', 'count', type: 'slider', min: 0, max: 1000);
        add('Color', 'color', type: 'color');
        break;
      case 'comment':
        add('Author Name', 'author');
        add('Comment Text', 'text');
        add('Avatar URL', 'avatar');
        break;
      case 'container':
        add('Background Color', 'backgroundColor', type: 'color');
        add('Border Color', 'borderColor', type: 'color');
        add('Border Width', 'borderWidth', type: 'slider', min: 0, max: 8);
        add('Border Radius', 'borderRadius', type: 'slider', min: 0, max: 32);
        break;
      case 'camera':
        add('Resolution', 'resolution', type: 'select', options: ['low', 'medium', 'high', 'max']);
        add('Facing', 'facing', type: 'select', options: ['front', 'back']);
        break;
      case 'gallery':
        add('Columns', 'columns', type: 'slider', min: 2, max: 5);
        add('Spacing', 'spacing', type: 'slider', min: 2, max: 16);
        break;
      case 'qrcode':
        add('Data', 'data');
        add('Size', 'size', type: 'slider', min: 100, max: 400);
        break;
      case 'webview':
        add('URL', 'url');
        add('JavaScript Enabled', 'jsEnabled', type: 'select', options: ['false', 'true']);
        break;
      case 'followbtn':
        add('Button Text', 'text');
        add('Following Text', 'followingText');
        add('Color', 'color', type: 'color');
        break;
      default:
        add('Label', 'label');
        add('Color', 'color', type: 'color');
    }

    return fields;
  }

  Widget _ActionBtn(IconData icon, String label, Color color, VoidCallback onTap) =>
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color.withOpacity(0.4)),
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: Icon(icon, size: 16),
          label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      );
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
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
        const SizedBox(height: 5),
        _buildControl(context),
      ]);

  Widget _buildControl(BuildContext context) {
    switch (type) {
      case 'color':
        final hex = value is String ? value as String : '#00C896';
        Color c;
        try {
          c = Color(int.parse(hex.replaceAll('#', '0xFF')));
        } catch (_) {
          c = AppTheme.primary;
        }
        return Row(children: [
          GestureDetector(
            onTap: () => _showColorPicker(context, c),
            child: Container(
              width: 36, height: 32,
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
                  color: AppTheme.textPrimary, fontSize: 12, fontFamily: 'monospace'),
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
              ),
            ),
          ),
        ]);

      case 'slider':
        // ✅ FIX: clamp to double range, pass typed double to Slider.onChanged
        final double sliderMin = min ?? 0;
        final double sliderMax = max ?? 100;
        final double v = (value is num
                ? (value as num).toDouble()
                : sliderMin)
            .clamp(sliderMin, sliderMax);

        return Row(children: [
          Expanded(
            child: Slider(
              value: v,
              min: sliderMin,
              max: sliderMax,
              activeColor: AppTheme.primary,
              inactiveColor: AppTheme.darkBorder,
              // ✅ onChanged receives double — pass it directly (no dynamic cast)
              onChanged: (double newVal) => onChanged(newVal),
            ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              v.toInt().toString(),
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
              textAlign: TextAlign.right,
            ),
          ),
        ]);

      case 'select':
        final String v = value?.toString() ?? (options?.first ?? '');
        final String? safeVal =
            options?.contains(v) == true ? v : options?.first;
        return DropdownButtonFormField<String>(
          value: safeVal,
          items: (options ?? [])
              .map((o) => DropdownMenuItem(
                  value: o,
                  child: Text(o, style: const TextStyle(fontSize: 12))))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          dropdownColor: AppTheme.darkCard,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        );

      default:
        return TextFormField(
          initialValue: value?.toString() ?? '',
          onChanged: onChanged,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
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
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: c == current ? Colors.white : Colors.transparent,
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
              child: const Text('Cancel')),
        ],
      ),
    );
  }
}