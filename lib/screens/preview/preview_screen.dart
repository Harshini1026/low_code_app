import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../models/project_model.dart';
import '../../models/screen_model.dart';
import '../../services/firestore_service.dart';
import '../builder/canvas_area.dart';
import '../../widgets/floating_ai_button.dart';

class PreviewScreen extends StatefulWidget {
  final String projectId;
  const PreviewScreen({super.key, required this.projectId});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  ProjectModel? _project;
  bool _loading = true;
  bool _isHorizontal = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await FirestoreService().getProject(widget.projectId);
    setState(() {
      _project = p;
      _loading = false;
    });
  }

  List<Widget> _intersperse(List<Widget> items, Widget separator) {
    if (items.isEmpty) return [];
    return [
      for (int i = 0; i < items.length; i++) ...[
        items[i],
        if (i < items.length - 1) separator,
      ],
    ];
  }

  Color get _primaryColor {
    try {
      return Color(
        int.parse(
          (_project?.theme.primaryColor ?? '#00C896').replaceAll('#', '0xFF'),
        ),
      );
    } catch (_) {
      return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppTheme.darkBg,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    final screens = _project?.screens ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF060F1A),
      floatingActionButton: const FloatingAiButton(),
      appBar: AppBar(
        backgroundColor: AppTheme.darkCard,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.go('/builder/${widget.projectId}'),
        ),
        title: Text('Preview — ${_project?.name ?? ''}'),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/publish/${widget.projectId}'),
            icon: const Icon(
              Icons.rocket_launch,
              size: 16,
              color: AppTheme.primary,
            ),
            label: const Text(
              'Publish',
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: screens.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.dashboard, size: 48, color: AppTheme.textMuted),
                  const SizedBox(height: 16),
                  Text(
                    'No screens to preview',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // ── Orientation Toggle Bar ──────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: const BoxDecoration(
                    color: AppTheme.darkCard,
                    border: Border(
                      bottom: BorderSide(color: AppTheme.darkBorder),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Preview Orientation:',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => setState(() {
                          _isHorizontal = true;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _isHorizontal
                                ? AppTheme.primary.withOpacity(0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _isHorizontal
                                  ? AppTheme.primary
                                  : AppTheme.darkBorder,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.arrow_forward,
                                size: 14,
                                color: _isHorizontal
                                    ? AppTheme.primary
                                    : AppTheme.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Horizontal',
                                style: TextStyle(
                                  color: _isHorizontal
                                      ? AppTheme.primary
                                      : AppTheme.textMuted,
                                  fontSize: 12,
                                  fontWeight: _isHorizontal
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() {
                          _isHorizontal = false;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: !_isHorizontal
                                ? AppTheme.primary.withOpacity(0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: !_isHorizontal
                                  ? AppTheme.primary
                                  : AppTheme.darkBorder,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.arrow_downward,
                                size: 14,
                                color: !_isHorizontal
                                    ? AppTheme.primary
                                    : AppTheme.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Vertical',
                                style: TextStyle(
                                  color: !_isHorizontal
                                      ? AppTheme.primary
                                      : AppTheme.textMuted,
                                  fontSize: 12,
                                  fontWeight: !_isHorizontal
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${screens.length} screen${screens.length != 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Scrollable Screens ──────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: _isHorizontal
                        ? Axis.horizontal
                        : Axis.vertical,
                    padding: const EdgeInsets.all(24),
                    child: _isHorizontal
                        ? Row(
                            children: _intersperse(
                              screens
                                  .map(
                                    (screen) => _PreviewScreenFrame(
                                      screen: screen,
                                      primaryColor: _primaryColor,
                                    ),
                                  )
                                  .toList(),
                              const SizedBox(width: 24),
                            ),
                          )
                        : Column(
                            children: _intersperse(
                              screens
                                  .map(
                                    (screen) => _PreviewScreenFrame(
                                      screen: screen,
                                      primaryColor: _primaryColor,
                                    ),
                                  )
                                  .toList(),
                              const SizedBox(height: 24),
                            ),
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Preview Screen Frame (renders a single screen)
// ══════════════════════════════════════════════════════════════════════════════
class _PreviewScreenFrame extends StatelessWidget {
  final AppScreen screen;
  final Color primaryColor;

  const _PreviewScreenFrame({required this.screen, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      height: 620,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: AppTheme.darkBorder, width: 8),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.25),
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
              color: primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      screen.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
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
                      Icon(Icons.battery_full, color: Colors.white, size: 14),
                    ],
                  ),
                ],
              ),
            ),

            // Widget content
            Expanded(
              child: screen.widgets.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.phone_android,
                            size: 48,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Empty screen',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: screen.widgets
                            .map(
                              (w) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: WidgetRenderer(widgetModel: w),
                              ),
                            )
                            .toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
