import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../models/project_model.dart';
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
  int _activeScreen = 0;
  bool _loading = true;

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
    final activeScreen = screens.isNotEmpty ? screens[_activeScreen] : null;

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
      body: Column(
        children: [
          // Screen selector tabs
          if (screens.length > 1)
            Container(
              color: AppTheme.darkCard,
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                itemCount: screens.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final active = i == _activeScreen;
                  return GestureDetector(
                    onTap: () => setState(() => _activeScreen = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: active ? _primaryColor : AppTheme.darkSurface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        screens[i].name,
                        style: TextStyle(
                          color: active ? Colors.white : AppTheme.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // Phone preview
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Phone frame
                    Container(
                      width: 320,
                      height: 620,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(36),
                        border: Border.all(
                          color: AppTheme.darkBorder,
                          width: 8,
                        ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    activeScreen?.name ?? _project?.name ?? '',
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

                            // Widget content
                            Expanded(
                              child:
                                  activeScreen == null ||
                                      activeScreen.widgets.isEmpty
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: activeScreen.widgets
                                            .map(
                                              (w) => Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 8,
                                                ),
                                                child: WidgetRenderer(
                                                  widgetModel: w,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                      ),
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
                        '📱 ${_project?.name ?? ''} · ${screens.length} screen${screens.length != 1 ? 's' : ''}',
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
          ),
        ],
      ),
    );
  }
}
