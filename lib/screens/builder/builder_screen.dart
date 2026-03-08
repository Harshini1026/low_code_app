import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:low_code_app/models/project_model.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/builder_provider.dart';
import '../../widgets/floating_ai_button.dart';
import 'canvas_area.dart';
import 'widget_panel.dart';
import 'properties_panel.dart';
import 'backend_panel.dart';
import 'bind_data_panel.dart';

class BuilderScreen extends StatefulWidget {
  final String projectId;
  const BuilderScreen({super.key, required this.projectId});
  @override
  State<BuilderScreen> createState() => _BuilderScreenState();
}

class _BuilderScreenState extends State<BuilderScreen>
    with SingleTickerProviderStateMixin {
  int _sideTab = 0; // 0=Components, 1=Screens, 2=Theme, 3=Backend
  late TabController _tabCtrl;

  final _sideTabs = const [
    {'icon': Icons.widgets_outlined, 'label': 'Widgets'},
    {'icon': Icons.phone_android_outlined, 'label': 'Screens'},
    {'icon': Icons.palette_outlined, 'label': 'Theme'},
    {'icon': Icons.storage_outlined, 'label': 'Backend'},
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BuilderProvider>().loadProject(widget.projectId);
    });
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Consumer<BuilderProvider>(builder: (context, provider, _) {
      if (provider.isLoading) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        );
      }
      return Scaffold(
        backgroundColor: AppTheme.darkBg,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => context.go('/home'),
          ),
          title: Row(children: [
            Flexible(
              child: Text(
                provider.project?.name ?? 'Builder',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(width: 8),
            if (provider.isSaving)
              const SizedBox(width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)),
          ]),
          actions: [
            IconButton(
              icon: const Icon(Icons.undo, size: 20),
              onPressed: provider.undo,
              tooltip: 'Undo',
            ),
            TextButton.icon(
              icon: const Icon(Icons.visibility_outlined, size: 18, color: AppTheme.primary),
              label: const Text('Preview', style: TextStyle(color: AppTheme.primary)),
              onPressed: () => context.go('/preview/${widget.projectId}'),
            ),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent, padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onPressed: () => context.go('/publish/${widget.projectId}'),
                child: const Text('Publish App', style: TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ),
        body: Row(children: [
          // ── LEFT SIDEBAR ─────────────────────────────────────────────────
          Container(
            width: 72,
            color: AppTheme.darkCard,
            child: Column(children: [
              ..._sideTabs.asMap().entries.map((e) {
                final active = _sideTab == e.key;
                return GestureDetector(
                  onTap: () => setState(() => _sideTab = e.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: active ? AppTheme.primary : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      color: active ? AppTheme.primary.withOpacity(0.1) : Colors.transparent,
                    ),
                    child: Column(children: [
                      Icon(e.value['icon'] as IconData,
                          color: active ? AppTheme.primary : AppTheme.textMuted, size: 22),
                      const SizedBox(height: 4),
                      Text(e.value['label'] as String,
                          style: TextStyle(
                            fontSize: 9, fontWeight: FontWeight.w600,
                            color: active ? AppTheme.primary : AppTheme.textMuted,
                          )),
                    ]),
                  ),
                );
              }),
            ]),
          ),

          // ── SIDE PANEL CONTENT ────────────────────────────────────────────
          Container(
            width: 220,
            decoration: const BoxDecoration(
              color: AppTheme.darkCard,
              border: Border(right: BorderSide(color: AppTheme.darkBorder)),
            ),
            child: IndexedStack(
              index: _sideTab,
              children: [
                WidgetPanel(onAdd: (type) => provider.addWidget(type)),
                _ScreensPanel(provider: provider),
                _ThemePanel(provider: provider),
                BackendPanel(provider: provider),
              ],
            ),
          ),

          // ── CENTER CANVAS ─────────────────────────────────────────────────
          Expanded(
            child: CanvasArea(
              provider: provider,
              onWidgetTap: (w) => provider.selectWidget(w),
            ),
          ),

          // ── RIGHT PROPERTIES PANEL ────────────────────────────────────────
          if (provider.selectedWidget != null)
            PropertiesPanel(
              widget: provider.selectedWidget!,
              onPropertyChanged: (k, v) =>
                  provider.updateWidgetProperty(provider.selectedWidget!.id, k, v),
              onDelete: () => provider.removeWidget(provider.selectedWidget!.id),
              onDuplicate: () => provider.duplicateWidget(provider.selectedWidget!.id),
              onBindData: () => _showBindData(context, provider),
              onDeselect: () => provider.selectWidget(null),
            ),
        ]),
        floatingActionButton: const FloatingAiButton(),
      );
    });
  }

  void _showBindData(BuildContext context, BuilderProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BindDataPanel(
        provider: provider,
        widget: provider.selectedWidget!,
      ),
    );
  }
}

// ── Screens Panel ──────────────────────────────────────────────────────────────
class _ScreensPanel extends StatefulWidget {
  final BuilderProvider provider;
  const _ScreensPanel({required this.provider});
  @override
  State<_ScreensPanel> createState() => _ScreensPanelState();
}

class _ScreensPanelState extends State<_ScreensPanel> {
  bool _adding = false;
  final _ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final screens = widget.provider.project?.screens ?? [];
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          const Expanded(child: Text('Screens', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
          Text('${screens.length}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: screens.length,
          itemBuilder: (_, i) {
            final s = screens[i];
            final active = i == widget.provider.activeScreenIndex;
            return GestureDetector(
              onTap: () => widget.provider.setActiveScreen(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: active ? AppTheme.primary.withOpacity(0.15) : AppTheme.darkSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: active ? AppTheme.primary : AppTheme.darkBorder),
                ),
                child: Row(children: [
                  Icon(Icons.phone_android, size: 16,
                      color: active ? AppTheme.primary : AppTheme.textMuted),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s.name,
                      style: TextStyle(
                        color: active ? AppTheme.primary : AppTheme.textPrimary,
                        fontWeight: active ? FontWeight.w700 : FontWeight.normal,
                        fontSize: 13,
                      ))),
                  Text('${s.widgets.length}',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  if (screens.length > 1)
                    IconButton(
                      icon: const Icon(Icons.close, size: 14, color: AppTheme.accent),
                      onPressed: () => widget.provider.removeScreen(i),
                      padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                    ),
                ]),
              ),
            );
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(8),
        child: _adding
          ? Row(children: [
              Expanded(child: TextField(
                controller: _ctrl, autofocus: true,
                style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Screen name...',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) widget.provider.addScreen(v.trim());
                  _ctrl.clear(); setState(() => _adding = false);
                },
              )),
              const SizedBox(width: 6),
              ElevatedButton(
                onPressed: () {
                  if (_ctrl.text.trim().isNotEmpty) widget.provider.addScreen(_ctrl.text.trim());
                  _ctrl.clear(); setState(() => _adding = false);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                child: const Text('+'),
              ),
            ])
          : SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _adding = true),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add New Screen', style: TextStyle(fontSize: 13)),
              ),
            ),
      ),
    ]);
  }
}

// ── Theme Panel ────────────────────────────────────────────────────────────────
class _ThemePanel extends StatelessWidget {
  final BuilderProvider provider;
  const _ThemePanel({required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = provider.project?.theme;
    return ListView(padding: const EdgeInsets.all(12), children: [
      const Text('Primary Color', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: ['#00C896','#6C63FF','#FF6B35','#3498DB','#E74C3C','#F39C12','#8E44AD','#2ECC71']
            .map((c) {
          final color = Color(int.parse(c.replaceAll('#', '0xFF')));
          final selected = theme?.primaryColor == c;
          return GestureDetector(
            onTap: () => provider.updateTheme(
              ProjectTheme(primaryColor: c,
                secondaryColor: theme?.secondaryColor ?? '#6C63FF',
                fontFamily: theme?.fontFamily ?? 'Poppins'),
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(8),
                border: Border.all(color: selected ? Colors.white : Colors.transparent, width: 3),
                boxShadow: selected ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)] : [],
              ),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 16),
      const Divider(color: AppTheme.darkBorder),
      const SizedBox(height: 10),
      const Text('Font Family', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        value: theme?.fontFamily ?? 'Poppins',
        items: ['Poppins','Roboto','Inter','Montserrat','Lato','Open Sans']
            .map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
        onChanged: (f) => provider.updateTheme(
          ProjectTheme(primaryColor: theme?.primaryColor ?? '#00C896', fontFamily: f ?? 'Poppins'),
        ),
        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
        dropdownColor: AppTheme.darkCard,
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
      ),
      const SizedBox(height: 16),
      const Divider(color: AppTheme.darkBorder),
      const SizedBox(height: 10),
      const Text('App Icon', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      const SizedBox(height: 8),
      Container(
        height: 80, decoration: BoxDecoration(
          color: AppTheme.darkSurface, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.darkBorder, style: BorderStyle.solid),
        ),
        child: const Center(child: Text('+ Upload App Icon', style: TextStyle(color: AppTheme.textMuted, fontSize: 13))),
      ),
    ]);
  }
}