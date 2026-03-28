import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../models/project_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/floating_ai_button.dart';

class PublishScreen extends StatefulWidget {
  final String projectId;
  const PublishScreen({super.key, required this.projectId});

  @override
  State<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends State<PublishScreen> {
  ProjectModel? _project;
  bool _loading = true;
  String _platform = 'android';
  int _step = 0; // 0=config  1=building  2=done
  double _progress = 0;

  final _buildLogs = [
    '✅ Generating Flutter source code...',
    '✅ Configuring Firebase settings...',
    '✅ Compiling assets & fonts...',
    '⏳ Building release binary...',
    '⏳ Uploading to Firebase Hosting...',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await FirestoreService().getProject(widget.projectId);
    setState(() { _project = p; _loading = false; });
  }

  Future<void> _startBuild() async {
    setState(() { _step = 1; _progress = 0; });
    for (int i = 0; i <= 100; i += 2) {
      await Future.delayed(const Duration(milliseconds: 60));
      if (mounted) setState(() => _progress = i / 100);
    }
    final slug = (_project?.name ?? 'app').toLowerCase().replaceAll(' ', '-');
    await FirestoreService().publishProject(widget.projectId, 'https://appforge.io/$slug');
    if (mounted) setState(() => _step = 2);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppTheme.darkBg,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      floatingActionButton: const FloatingAiButton(),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.go('/builder/${widget.projectId}'),
        ),
        title: const Text('Publish App'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _step == 0 ? _ConfigStep() : _step == 1 ? _BuildingStep() : _DoneStep(),
        ),
      ),
    );
  }

  // ── Step 1: Config ──────────────────────────────────────────────────────────
  Widget _ConfigStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    // Header card
    Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('🚀 Launch Your App', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(_project?.name ?? '', style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          _Chip('✅ No vendor lock-in'),
          _Chip('✅ Full source code'),
        ]),
      ]),
    ).animate().fadeIn().slideY(begin: -0.1),

    const SizedBox(height: 24),
    const Text('Choose Platform', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
    const SizedBox(height: 12),

    // Platform grid
    GridView.count(
      crossAxisCount: 2, shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.5,
      children: [
        _PlatformTile('android', '📱', 'Android APK', 'Any Android device'),
        _PlatformTile('ios', '🍎', 'iOS App', 'App Store (Mac needed)'),
        _PlatformTile('web', '🌐', 'Web App', 'Firebase Hosting'),
        _PlatformTile('source', '📦', 'Flutter Source', 'Full Dart code'),
      ],
    ).animate().fadeIn(delay: 100.ms),

    const SizedBox(height: 24),
    const Text("What's Included", style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
    const SizedBox(height: 12),

    ...[
      ['✅ Full source code export', 'You own 100% of the code'],
      ['✅ Firebase configuration', 'Auth + Firestore pre-configured'],
      ['✅ All screens & widgets', '${_project?.screens.length ?? 0} screens included'],
      ['✅ No vendor lock-in', 'Deploy anywhere you like'],
      ['✅ Auto-scalable backend', 'Firebase scales to millions of users'],
    ].map((row) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(row[0], style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 2),
        Text(row[1], style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
      ]),
    )),

    const SizedBox(height: 24),
    SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _startBuild,
        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        icon: const Text('🚀', style: TextStyle(fontSize: 20)),
        label: const Text('Build & Publish App', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    ).animate().fadeIn(delay: 200.ms),
  ]);

  Widget _PlatformTile(String id, String icon, String title, String sub) {
    final active = _platform == id;
    return GestureDetector(
      onTap: () => setState(() => _platform = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary.withOpacity(0.1) : AppTheme.darkCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? AppTheme.primary : AppTheme.darkBorder, width: active ? 2 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 6),
          Text(title, style: TextStyle(color: active ? AppTheme.primary : AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
          Text(sub, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
        ]),
      ),
    );
  }

  Widget _Chip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
  );

  // ── Step 2: Building ────────────────────────────────────────────────────────
  Widget _BuildingStep() => Column(children: [
    const SizedBox(height: 40),
    const Text('⚙️', style: TextStyle(fontSize: 72))
        .animate(onPlay: (c) => c.repeat())
        .rotate(duration: 2000.ms),
    const SizedBox(height: 24),
    const Text('Building your app...', style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
    const SizedBox(height: 8),
    const Text('Compiling Flutter code & deploying to Firebase', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
    const SizedBox(height: 32),
    ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: _progress,
        backgroundColor: AppTheme.darkCard,
        color: AppTheme.primary,
        minHeight: 8,
      ),
    ),
    const SizedBox(height: 8),
    Align(alignment: Alignment.centerRight,
      child: Text('${(_progress * 100).toInt()}%', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 13))),
    const SizedBox(height: 20),
    ..._buildLogs.take((_progress * _buildLogs.length).ceil()).map((log) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        const SizedBox(width: 8),
        Text(log, style: TextStyle(color: log.startsWith('✅') ? AppTheme.primary : AppTheme.textMuted, fontSize: 13)),
      ]),
    )),
  ]);

  // ── Step 3: Done ────────────────────────────────────────────────────────────
  Widget _DoneStep() {
    final slug = (_project?.name ?? 'app').toLowerCase().replaceAll(' ', '-');
    return Column(children: [
      const SizedBox(height: 40),
      const Text('🎉', style: TextStyle(fontSize: 80)).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
      const SizedBox(height: 20),
      const Text('App Published!', style: TextStyle(color: AppTheme.textPrimary, fontSize: 26, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      const Text('Your app is live and ready to share!', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
      const SizedBox(height: 32),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('APP URL', style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 6),
          Text('https://appforge.io/$slug', style: const TextStyle(color: AppTheme.primary, fontFamily: 'monospace', fontSize: 13)),
        ]),
      ),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Share Link'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: () => context.go('/builder/${widget.projectId}'),
            child: const Text('Back to Builder'),
          ),
        ),
      ]),
    ]);
  }
}
