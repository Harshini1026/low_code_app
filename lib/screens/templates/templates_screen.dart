import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../models/template_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../widgets/floating_ai_button.dart';

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  String _category = 'All';
  bool _creating = false;

  List<TemplateModel> get _filtered => AppTemplates.byCategory(_category);

  Future<void> _onSelectTemplate(TemplateModel template) async {
    final nameCtrl = TextEditingController(text: '${template.name} App');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Text(template.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 10),
          Expanded(child: Text(template.name,
              style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(template.description,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.5)),
          const SizedBox(height: 16),
          const Text('APP NAME',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 10,
                  fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          const SizedBox(height: 8),
          TextField(
            controller: nameCtrl,
            autofocus: true,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppTheme.darkSurface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create App')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    setState(() => _creating = true);
    try {
      final projectId = await FirestoreService().createFromTemplate(
        template, user.uid,
        nameCtrl.text.trim().isEmpty ? '${template.name} App' : nameCtrl.text.trim(),
      );
      if (mounted) context.go('/builder/$projectId');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.accent),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      floatingActionButton: const FloatingAiButton(),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.go('/home'),
        ),
        title: const Text('Choose Template'),
        centerTitle: true,
      ),
      body: _creating
          ? const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(color: AppTheme.primary),
                SizedBox(height: 16),
                Text('Creating your app...', style: TextStyle(color: AppTheme.textMuted)),
              ]),
            )
          : CustomScrollView(slivers: [

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _StepIndicator(currentStep: 0, totalSteps: 4),
                ).animate().fadeIn(),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Start with a Template',
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('${AppTemplates.all.length} ready-made templates — or start blank',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 14)),
                  ]),
                ).animate().fadeIn(delay: 100.ms),
              ),

              SliverToBoxAdapter(
                child: SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: AppTemplates.categories.map((cat) {
                      final active = cat == _category;
                      return GestureDetector(
                        onTap: () => setState(() => _category = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: active ? AppTheme.primary : AppTheme.darkCard,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: active ? AppTheme.primary : AppTheme.darkBorder),
                          ),
                          child: Text(cat,
                              style: TextStyle(
                                color: active ? Colors.white : AppTheme.textMuted,
                                fontSize: 13, fontWeight: FontWeight.w600,
                              )),
                        ),
                      );
                    }).toList(),
                  ),
                ).animate().fadeIn(delay: 150.ms),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ✅ KEY FIX: childAspectRatio 0.68 gives cards enough height
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.68, // ✅ was 0.82
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _TemplateCard(
                      template: _filtered[i],
                      onTap: () => _onSelectTemplate(_filtered[i]),
                    )
                        .animate()
                        .fadeIn(delay: Duration(milliseconds: i * 50))
                        .scale(begin: const Offset(0.95, 0.95)),
                    childCount: _filtered.length,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ]),
    );
  }
}

// ── Step indicator ────────────────────────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int currentStep, totalSteps;
  const _StepIndicator({required this.currentStep, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    final labels = ['Template', 'Name', 'Backend', 'Launch'];
    return Row(
      children: List.generate(totalSteps, (i) {
        final done   = i < currentStep;
        final active = i == currentStep;
        return Expanded(
          child: Row(children: [
            Column(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 28, height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done || active ? AppTheme.primary : AppTheme.darkCard,
                  border: Border.all(
                      color: done || active ? AppTheme.primary : AppTheme.darkBorder,
                      width: 2),
                ),
                child: Center(
                  child: done
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : Text('${i + 1}',
                          style: TextStyle(
                            color: active ? Colors.white : AppTheme.textMuted,
                            fontSize: 12, fontWeight: FontWeight.w700,
                          )),
                ),
              ),
              const SizedBox(height: 4),
              Text(labels[i],
                  style: TextStyle(
                    color: active ? AppTheme.primary : AppTheme.textMuted,
                    fontSize: 10, fontWeight: FontWeight.w600,
                  )),
            ]),
            if (i < totalSteps - 1)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 18),
                  color: i < currentStep ? AppTheme.primary : AppTheme.darkBorder,
                ),
              ),
          ]),
        );
      }),
    );
  }
}

// ── Template card ─────────────────────────────────────────────────────────────
class _TemplateCard extends StatefulWidget {
  final TemplateModel template;
  final VoidCallback onTap;
  const _TemplateCard({required this.template, required this.onTap});

  @override
  State<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<_TemplateCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.template;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _hovered ? t.primaryColor : AppTheme.darkBorder,
              width: _hovered ? 2 : 1,
            ),
            boxShadow: _hovered
                ? [BoxShadow(
                    color: t.primaryColor.withOpacity(0.2),
                    blurRadius: 16, offset: const Offset(0, 4))]
                : [],
          ),
          // ✅ ClipRRect stops any child overflowing outside card bounds
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Emoji strip — fixed height
                Container(
                  height: 82, // ✅ reduced from 90
                  decoration: BoxDecoration(
                    color: t.primaryColor.withOpacity(0.15),
                    border: Border(
                        bottom: BorderSide(color: t.primaryColor.withOpacity(0.2))),
                  ),
                  child: Center(
                    child: Text(t.emoji,
                        style: const TextStyle(fontSize: 40)), // ✅ reduced from 44
                  ),
                ),

                // Info section — Expanded fills remaining space
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // Name
                        Text(t.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 3),

                        // Category dot + label
                        Row(children: [
                          Container(
                            width: 7, height: 7,
                            decoration: BoxDecoration(
                                color: t.primaryColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(t.category,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppTheme.textMuted, fontSize: 11),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 6),

                        // Screen chips
                        Wrap(
                          spacing: 4, runSpacing: 4,
                          children: t.defaultScreens.take(3).map((s) =>
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: t.primaryColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(s,
                                style: TextStyle(
                                  color: t.primaryColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                )),
                            ),
                          ).toList(),
                        ),
                      ],
                    ),
                  ),
                ),

                // Use Template button — pinned to bottom
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _hovered
                          ? t.primaryColor
                          : t.primaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text('Use Template',
                        style: TextStyle(
                          color: _hovered ? Colors.white : t.primaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        )),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
