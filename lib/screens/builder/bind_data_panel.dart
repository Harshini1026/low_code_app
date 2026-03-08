import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/builder_provider.dart';
import '../../models/widget_model.dart';
import '../../models/project_model.dart';

class BindDataPanel extends StatefulWidget {
  final BuilderProvider provider;
  final WidgetModel widget;

  const BindDataPanel({
    super.key,
    required this.provider,
    required this.widget,
  });

  /// Open as modal bottom sheet
  static Future<void> show(
    BuildContext context, {
    required BuilderProvider provider,
    required WidgetModel widget,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BindDataPanel(provider: provider, widget: widget),
    );
  }

  @override
  State<BindDataPanel> createState() => _BindDataPanelState();
}

class _BindDataPanelState extends State<BindDataPanel> {
  String? _table;
  String? _field;

  List<DatabaseTable> get _tables =>
      widget.provider.project?.backendConfig.tables ?? [];

  List<String> get _fields =>
      _tables.firstWhere((t) => t.name == _table,
          orElse: () => DatabaseTable(id: '', name: '', fields: [])).fields;

  bool get _canBind => _table != null && _field != null;

  void _bind() {
    widget.provider.bindWidgetToData(widget.widget.id, _table!, _field!);
    Navigator.pop(context);
  }

  void _unbind() {
    widget.provider.bindWidgetToData(widget.widget.id, '', '');
    Navigator.pop(context);
  }

  @override
  void initState() {
    super.initState();
    // Pre-fill if already bound
    if (widget.widget.boundTable?.isNotEmpty == true) {
      _table = widget.widget.boundTable;
      _field = widget.widget.boundField;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [

        // Handle
        Container(
          width: 40, height: 4,
          margin: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(
            color: AppTheme.darkBorder,
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppTheme.secondary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.secondary.withOpacity(0.3)),
              ),
              child: const Center(child: Text('🔗', style: TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Bind Data to UI', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 17)),
                Text('Connect a Firestore field to this widget', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              ]),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: AppTheme.textMuted),
              onPressed: () => Navigator.pop(context),
            ),
          ]),
        ),

        const SizedBox(height: 4),
        const Divider(color: AppTheme.darkBorder),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Already bound badge
              if (widget.widget.boundTable?.isNotEmpty == true)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.secondary.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.link, color: AppTheme.secondary, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Currently bound to: ${widget.widget.boundTable}.${widget.widget.boundField}',
                        style: const TextStyle(color: AppTheme.secondary, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: _unbind,
                      child: const Text('Remove', style: TextStyle(color: AppTheme.accent, fontSize: 12)),
                    ),
                  ]),
                ).animate().fadeIn(),

              // Widget type badge
              _Label('Widget Type'),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.darkSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.darkBorder),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(widget.widget.type,
                        style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                  const SizedBox(width: 10),
                  Text('ID: ${widget.widget.id.substring(0, 8)}...',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontFamily: 'monospace')),
                ]),
              ),

              const SizedBox(height: 20),

              // No tables warning
              if (_tables.isEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
                  ),
                  child: const Column(children: [
                    Text('⚠️', style: TextStyle(fontSize: 32)),
                    SizedBox(height: 8),
                    Text('No database tables yet', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                    SizedBox(height: 4),
                    Text('Go to the Backend tab and create a\nFirestore collection first.',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 12), textAlign: TextAlign.center),
                  ]),
                ),
              ] else ...[

                // Table picker
                _Label('Firestore Collection (Table)'),
                DropdownButtonFormField<String>(
                  value: _table,
                  hint: const Text('Choose a collection', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
                  items: _tables.map((t) => DropdownMenuItem(
                    value: t.name,
                    child: Row(children: [
                      const Icon(Icons.table_chart_outlined, size: 16, color: AppTheme.primary),
                      const SizedBox(width: 8),
                      Text(t.name),
                    ]),
                  )).toList(),
                  onChanged: (v) => setState(() { _table = v; _field = null; }),
                  dropdownColor: AppTheme.darkCard,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    filled: true, fillColor: AppTheme.darkSurface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.darkBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.darkBorder)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  ),
                ),

                const SizedBox(height: 16),

                // Field picker
                _Label('Field to Display'),
                DropdownButtonFormField<String>(
                  value: _field,
                  hint: Text(
                    _table == null ? 'Select a table first' : 'Choose a field',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
                  ),
                  items: _fields.map((f) => DropdownMenuItem(
                    value: f,
                    child: Row(children: [
                      const Icon(Icons.data_object, size: 16, color: AppTheme.secondary),
                      const SizedBox(width: 8),
                      Text(f),
                    ]),
                  )).toList(),
                  onChanged: _table == null ? null : (v) => setState(() => _field = v),
                  dropdownColor: AppTheme.darkCard,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    filled: true, fillColor: AppTheme.darkSurface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.darkBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.darkBorder)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  ),
                ),

                const SizedBox(height: 24),

                // Preview
                if (_canBind) ...[
                  _Label('Binding Preview'),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Text('Widget', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 12, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        const Text('Firestore', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                      ]),
                      const SizedBox(height: 8),
                      Text(
                        '${widget.widget.type}  →  $_table / $_field',
                        style: const TextStyle(color: AppTheme.primary, fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'At runtime, this widget will display the "$_field" value from the "$_table" collection.',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, height: 1.5),
                      ),
                    ]),
                  ).animate().fadeIn(),
                  const SizedBox(height: 20),
                ],
              ],
            ]),
          ),
        ),

        // Bottom actions
        Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _canBind ? _bind : null,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                icon: const Text('🔗'),
                label: const Text('Bind Data', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _Label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text.toUpperCase(),
        style: const TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
  );
}
