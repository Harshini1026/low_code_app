import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/builder_provider.dart';
import '../../models/project_model.dart';
import '../../models/screen_model.dart'; // ✅ AppScreen lives here
import '../../models/widget_model.dart';
import '../../widgets/floating_ai_button.dart';
import 'canvas_area.dart';
import 'widget_panel.dart';
import 'properties_panel.dart';
import 'backend_panel.dart';
import 'bind_data_panel.dart';

// ── Tool panel enum ───────────────────────────────────────────────────────────
enum _Panel { widgets, screens, theme, backend }

class BuilderScreen extends StatefulWidget {
  final String projectId;
  const BuilderScreen({super.key, required this.projectId});

  @override
  State<BuilderScreen> createState() => _BuilderScreenState();
}

class _BuilderScreenState extends State<BuilderScreen>
    with SingleTickerProviderStateMixin {
  bool _drawerOpen = false;
  _Panel _activePanel = _Panel.widgets;
  String _deviceMode = 'Mobile';

  late AnimationController _drawerCtrl;
  late Animation<double> _drawerAnim;

  @override
  void initState() {
    super.initState();
    _drawerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _drawerAnim = CurvedAnimation(
      parent: _drawerCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BuilderProvider>().loadProject(widget.projectId);
    });
  }

  @override
  void dispose() {
    _drawerCtrl.dispose();
    super.dispose();
  }

  void _toggleDrawer(_Panel panel) {
    setState(() {
      if (_drawerOpen && _activePanel == panel) {
        _drawerOpen = false;
        _drawerCtrl.reverse();
      } else {
        _drawerOpen = true;
        _activePanel = panel;
        _drawerCtrl.forward();
      }
    });
  }

  void _closeDrawer() {
    setState(() => _drawerOpen = false);
    _drawerCtrl.reverse();
  }

  Widget _buildPropertiesBottomSheet(
    BuildContext context,
    WidgetModel selected,
    BuilderProvider provider,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: const BoxDecoration(
        color: AppTheme.darkCard,
        border: Border(top: BorderSide(color: AppTheme.darkBorder)),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: SingleChildScrollView(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppTheme.darkBorder),
                  ),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Properties',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 17),
                      onPressed: () {
                        provider.selectWidget(null);
                        setState(() {});
                      },
                      color: AppTheme.textMuted,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              // Properties panel content
              Expanded(
                child: PropertiesPanel(
                  widget: selected,
                  provider: provider,
                  onPropertyChanged: (key, val) =>
                      provider.updateWidgetProperty(selected.id, key, val),
                  onDelete: () {
                    provider.removeWidget(selected.id);
                    provider.selectWidget(null);
                    setState(() {});
                  },
                  onDuplicate: () => provider.duplicateWidget(selected.id),
                  onBindData: () => BindDataPanel.show(
                    context,
                    provider: provider,
                    widget: selected,
                  ),
                  onDeselect: () {
                    provider.selectWidget(null);
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BuilderProvider>(
      builder: (context, provider, _) {
        // ── Loading state ─────────────────────────────────────────────
        if (provider.project == null) {
          return Scaffold(
            backgroundColor: AppTheme.darkBg,
            body: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppTheme.primary),
                  SizedBox(height: 16),
                  Text(
                    'Loading project…',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          );
        }

        final project = provider.project!;
        final selected = provider.selectedWidget;

        return SafeArea(
          child: Scaffold(
            backgroundColor: AppTheme.darkBg,

            // ── AppBar ────────────────────────────────────────────────────
            appBar: _BuilderAppBar(
              projectName: project.name,
              deviceMode: _deviceMode,
              canUndo: provider.canUndo,
              isSaving: provider.isSaving,
              onMenuTap: () => _toggleDrawer(_activePanel),
              onDeviceChange: (m) => setState(() => _deviceMode = m),
              onUndo: provider.canUndo ? provider.undo : null,
              onPreview: () => context.go('/preview/${widget.projectId}'),
              onPublish: () => context.go('/publish/${widget.projectId}'),
              onBack: () => context.go('/home'),
            ),

            // ── Body ──────────────────────────────────────────────────────
            body: SafeArea(
              child: Stack(
                children: [
                  // Full-screen canvas
                  Column(
                    children: [
                      _ScreenStrip(provider: provider),
                      Expanded(
                        child: _CanvasCenter(
                          provider: provider,
                          deviceMode: _deviceMode,
                          activeScreen: provider.activeScreen,
                          onWidgetTap: (w) {
                            // ✅ selectWidget takes String? id
                            provider.selectWidget(w);
                            setState(() {});
                          },
                        ),
                      ),
                    ],
                  ),

                  // Backdrop
                  if (_drawerOpen)
                    GestureDetector(
                      onTap: _closeDrawer,
                      child: AnimatedBuilder(
                        animation: _drawerAnim,
                        builder: (_, __) => Container(
                          color: Colors.black.withOpacity(
                            0.45 * _drawerAnim.value,
                          ),
                        ),
                      ),
                    ),

                  // Left drawer
                  AnimatedBuilder(
                    animation: _drawerAnim,
                    builder: (_, child) => Transform.translate(
                      offset: Offset(-300 * (1 - _drawerAnim.value), 0),
                      child: child,
                    ),
                    child: _ToolDrawer(
                      panel: _activePanel,
                      provider: provider,
                      onClose: _closeDrawer,
                    ),
                  ),

                  // Bottom sheet properties
                  if (selected != null)
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: GestureDetector(
                          onTap: () {}, // Prevent closing when tapping sheet
                          child: _buildPropertiesBottomSheet(
                            context,
                            selected,
                            provider,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Floating AI button
            floatingActionButton: const FloatingAiButton(),

            // Bottom toolbar
            bottomNavigationBar: _BottomBar(
              active: _drawerOpen ? _activePanel : null,
              onTap: _toggleDrawer,
            ),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// AppBar
// ══════════════════════════════════════════════════════════════════════════════
class _BuilderAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String projectName, deviceMode;
  final bool canUndo, isSaving;
  final VoidCallback onMenuTap, onPreview, onPublish, onBack;
  final VoidCallback? onUndo;
  final Function(String) onDeviceChange;

  const _BuilderAppBar({
    required this.projectName,
    required this.deviceMode,
    required this.canUndo,
    required this.isSaving,
    required this.onMenuTap,
    required this.onDeviceChange,
    required this.onUndo,
    required this.onPreview,
    required this.onPublish,
    required this.onBack,
  });

  @override
  Size get preferredSize => const Size.fromHeight(50);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: const BoxDecoration(
        color: AppTheme.darkCard,
        border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 17),
            onPressed: onBack,
            color: AppTheme.textMuted,
          ),
          IconButton(
            icon: const Icon(Icons.menu, size: 20),
            onPressed: onMenuTap,
            color: AppTheme.textPrimary,
            tooltip: 'Tools',
          ),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    projectName,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSaving) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.undo, size: 18),
            onPressed: onUndo,
            color: canUndo ? AppTheme.textMuted : AppTheme.darkBorder,
          ),

          TextButton.icon(
            onPressed: onPreview,
            icon: const Icon(
              Icons.visibility_outlined,
              size: 16,
              color: AppTheme.primary,
            ),
            label: const Text(
              'Preview',
              style: TextStyle(
                color: AppTheme.primary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
            ),
          ),
          TextButton.icon(
            onPressed: onPublish,
            icon: const Icon(
              Icons.rocket_launch,
              size: 16,
              color: AppTheme.primary,
            ),
            label: const Text(
              'Publish',
              style: TextStyle(
                color: AppTheme.primary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Screen strip
// ══════════════════════════════════════════════════════════════════════════════
class _ScreenStrip extends StatelessWidget {
  final BuilderProvider provider;
  const _ScreenStrip({required this.provider});

  @override
  Widget build(BuildContext context) {
    final screens = provider.project?.screens ?? [];
    // ✅ currentScreenId — correct getter
    final currentId = provider.currentScreenId;

    return Container(
      height: 36,
      color: AppTheme.darkCard,
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              itemCount: screens.length,
              itemBuilder: (_, i) {
                final s = screens[i];
                final active = s.id == currentId;
                return GestureDetector(
                  // ✅ setCurrentScreen(String id)
                  onTap: () => provider.setCurrentScreen(s.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? AppTheme.primary.withOpacity(0.18)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: active ? AppTheme.primary : AppTheme.darkBorder,
                      ),
                    ),
                    child: Text(
                      s.name,
                      style: TextStyle(
                        color: active ? AppTheme.primary : AppTheme.textMuted,
                        fontSize: 12,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 15),
            color: AppTheme.textMuted,
            padding: const EdgeInsets.all(6),
            onPressed: () => _addScreenDialog(context, provider),
          ),
        ],
      ),
    );
  }

  void _addScreenDialog(BuildContext context, BuilderProvider provider) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'New Screen',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'e.g. Profile',
            hintStyle: const TextStyle(color: AppTheme.textMuted),
            filled: true,
            fillColor: AppTheme.darkSurface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final n = ctrl.text.trim();
              if (n.isNotEmpty) provider.addScreen(n);
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Canvas center
// ══════════════════════════════════════════════════════════════════════════════
class _CanvasCenter extends StatelessWidget {
  final BuilderProvider provider;
  final String deviceMode;
  // ✅ AppScreen is in project_model.dart — no separate screen_model import
  final AppScreen? activeScreen;
  final Function(WidgetModel?) onWidgetTap;

  const _CanvasCenter({
    required this.provider,
    required this.deviceMode,
    required this.activeScreen,
    required this.onWidgetTap,
  });

  Color get _primaryColor {
    final hex = provider.project?.theme.primaryColor ?? '#00C896';
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.darkBg,
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              // Phone frame
              Container(
                width: 320,
                height: 620,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(color: AppTheme.darkBorder, width: 8),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withOpacity(0.25),
                      blurRadius: 48,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Column(
                    children: [
                      // Status bar
                      Container(
                        height: 36,
                        color: _primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              activeScreen?.name ?? '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const Row(
                              children: [
                                Icon(
                                  Icons.signal_cellular_4_bar,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.battery_full,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Canvas area
                      Expanded(
                        child: CanvasArea(
                          screen: activeScreen,
                          provider: provider,
                          onWidgetSelected: onWidgetTap,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // App info pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.darkBorder),
                ),
                child: Text(
                  '📱 ${provider.project?.name ?? ''} · ${provider.project?.screens.length ?? 0} screen${(provider.project?.screens.length ?? 0) != 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Tool drawer
// ══════════════════════════════════════════════════════════════════════════════
class _ToolDrawer extends StatelessWidget {
  final _Panel panel;
  final BuilderProvider provider;
  final VoidCallback onClose;

  const _ToolDrawer({
    required this.panel,
    required this.provider,
    required this.onClose,
  });

  String get _title {
    switch (panel) {
      case _Panel.widgets:
        return 'Widgets';
      case _Panel.screens:
        return 'Screens';
      case _Panel.theme:
        return 'Theme';
      case _Panel.backend:
        return 'Backend';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 300,
          height: double.infinity,
          decoration: const BoxDecoration(
            color: AppTheme.darkCard,
            border: Border(right: BorderSide(color: AppTheme.darkBorder)),
            boxShadow: [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 24,
                offset: Offset(4, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppTheme.darkBorder),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      _title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 17),
                      onPressed: onClose,
                      color: AppTheme.textMuted,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              Expanded(child: _content(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    switch (panel) {
      case _Panel.widgets:
        return WidgetPanel(
          // ✅ addWidget(type, x, y) — place at centre of canvas
          onAdd: (type) => provider.addWidget(type, 40, 80),
        );
      case _Panel.screens:
        return _ScreensDrawerContent(provider: provider, onClose: onClose);
      case _Panel.theme:
        return _ThemeDrawerContent(provider: provider);
      case _Panel.backend:
        return BackendPanel(provider: provider);
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Screens list inside drawer
// ══════════════════════════════════════════════════════════════════════════════
class _ScreensDrawerContent extends StatelessWidget {
  final BuilderProvider provider;
  final VoidCallback onClose;
  const _ScreensDrawerContent({required this.provider, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final screens = provider.project?.screens ?? [];
    // ✅ activeScreenIndex
    final activeIndex = provider.activeScreenIndex;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        ...screens.asMap().entries.map((entry) {
          final i = entry.key;
          final s = entry.value;
          final active = i == activeIndex;
          return GestureDetector(
            onTap: () {
              // ✅ setActiveScreen(int)
              provider.setActiveScreen(i);
              onClose();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: active
                    ? AppTheme.primary.withOpacity(0.1)
                    : AppTheme.darkSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: active ? AppTheme.primary : AppTheme.darkBorder,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.phone_android,
                    size: 15,
                    color: active ? AppTheme.primary : AppTheme.textMuted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.name,
                      style: TextStyle(
                        color: active ? AppTheme.primary : AppTheme.textPrimary,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    '${s.widgets.length}w',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _addDialog(context),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: 15, color: AppTheme.primary),
                SizedBox(width: 6),
                Text(
                  'Add Screen',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _addDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'New Screen',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Screen name',
            hintStyle: const TextStyle(color: AppTheme.textMuted),
            filled: true,
            fillColor: AppTheme.darkSurface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final n = ctrl.text.trim();
              if (n.isNotEmpty) provider.addScreen(n);
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Theme editor — ProjectTheme has NO copyWith, construct manually
// Fields: primaryColor, secondaryColor, backgroundColor,
//         fontFamily, borderRadius, isDarkMode
// ══════════════════════════════════════════════════════════════════════════════
class _ThemeDrawerContent extends StatelessWidget {
  final BuilderProvider provider;
  const _ThemeDrawerContent({required this.provider});

  static const _colors = [
    '#00C896',
    '#6C63FF',
    '#FF6B35',
    '#3498DB',
    '#E74C3C',
    '#F39C12',
    '#8E44AD',
    '#2ECC71',
  ];
  static const _fonts = ['Poppins', 'Roboto', 'Inter', 'Lato', 'Montserrat'];

  // ✅ No copyWith on ProjectTheme — build new instance manually
  void _setPrimary(ProjectTheme t, String hex) => provider.updateTheme(
    ProjectTheme(
      primaryColor: hex,
      secondaryColor: t.secondaryColor,
      backgroundColor: t.backgroundColor,
      fontFamily: t.fontFamily,
      borderRadius: t.borderRadius,
      isDarkMode: t.isDarkMode,
    ),
  );

  void _setFont(ProjectTheme t, String font) => provider.updateTheme(
    ProjectTheme(
      primaryColor: t.primaryColor,
      secondaryColor: t.secondaryColor,
      backgroundColor: t.backgroundColor,
      fontFamily: font,
      borderRadius: t.borderRadius,
      isDarkMode: t.isDarkMode,
    ),
  );

  void _setDarkMode(ProjectTheme t, bool dark) => provider.updateTheme(
    ProjectTheme(
      primaryColor: t.primaryColor,
      secondaryColor: t.secondaryColor,
      backgroundColor: t.backgroundColor,
      fontFamily: t.fontFamily,
      borderRadius: t.borderRadius,
      // ✅ isDarkMode — correct field name
      isDarkMode: dark,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = provider.project?.theme ?? const ProjectTheme();

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        const Text(
          'PRIMARY COLOR',
          style: TextStyle(
            color: AppTheme.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _colors.map((hex) {
            final color = Color(int.parse(hex.replaceAll('#', '0xFF')));
            final selected = theme.primaryColor == hex;
            return GestureDetector(
              onTap: () => _setPrimary(theme, hex),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? Colors.white : Colors.transparent,
                    width: 2.5,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: color.withOpacity(0.5),
                            blurRadius: 8,
                          ),
                        ]
                      : [],
                ),
                child: selected
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 20),
        const Text(
          'FONT FAMILY',
          style: TextStyle(
            color: AppTheme.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        ..._fonts.map((f) {
          final selected = theme.fontFamily == f;
          return GestureDetector(
            onTap: () => _setFont(theme, f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.primary.withOpacity(0.1)
                    : AppTheme.darkSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? AppTheme.primary : AppTheme.darkBorder,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      f,
                      style: TextStyle(
                        color: selected
                            ? AppTheme.primary
                            : AppTheme.textPrimary,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (selected)
                    const Icon(Icons.check, color: AppTheme.primary, size: 16),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 20),
        const Text(
          'APP STYLE',
          style: TextStyle(
            color: AppTheme.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _modeChip(theme, 'Dark', Icons.dark_mode, true),
            const SizedBox(width: 8),
            _modeChip(theme, 'Light', Icons.light_mode, false),
          ],
        ),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _modeChip(ProjectTheme theme, String label, IconData icon, bool dark) {
    // ✅ isDarkMode — correct field name (not darkMode)
    final selected = theme.isDarkMode == dark;
    return Expanded(
      child: GestureDetector(
        onTap: () => _setDarkMode(theme, dark),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primary.withOpacity(0.1)
                : AppTheme.darkSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.darkBorder,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? AppTheme.primary : AppTheme.textMuted,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppTheme.primary : AppTheme.textMuted,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Bottom toolbar
// ══════════════════════════════════════════════════════════════════════════════
class _BottomBar extends StatelessWidget {
  final _Panel? active;
  final Function(_Panel) onTap;
  const _BottomBar({required this.active, required this.onTap});

  static const _items = [
    (_Panel.widgets, Icons.widgets_outlined, 'Widgets'),
    (_Panel.screens, Icons.phone_android_outlined, 'Screens'),
    (_Panel.theme, Icons.palette_outlined, 'Theme'),
    (_Panel.backend, Icons.storage_outlined, 'Backend'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: const BoxDecoration(
        color: AppTheme.darkCard,
        border: Border(top: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: _items.map((item) {
          final (panel, icon, label) = item;
          final isActive = active == panel;
          return GestureDetector(
            onTap: () => onTap(panel),
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 76,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppTheme.primary.withOpacity(0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: isActive ? AppTheme.primary : AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      color: isActive ? AppTheme.primary : AppTheme.textMuted,
                      fontSize: 10,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
