import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  // Sign-in fields
  final _signInEmail    = TextEditingController();
  final _signInPassword = TextEditingController();

  // Sign-up fields
  final _signUpName     = TextEditingController();
  final _signUpEmail    = TextEditingController();
  final _signUpPassword = TextEditingController();
  final _signUpConfirm  = TextEditingController();

  bool _obscureSignIn  = true;
  bool _obscureSignUp  = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _signInEmail.dispose(); _signInPassword.dispose();
    _signUpName.dispose();  _signUpEmail.dispose();
    _signUpPassword.dispose(); _signUpConfirm.dispose();
    super.dispose();
  }

  Future<void> _signIn(AuthProvider auth) async {
    await auth.signIn(_signInEmail.text.trim(), _signInPassword.text);
    if (auth.status == AuthStatus.authenticated && mounted) {
      context.go('/home');
    }
  }

  Future<void> _signUp(AuthProvider auth) async {
    if (_signUpPassword.text != _signUpConfirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match'), backgroundColor: AppTheme.accent),
      );
      return;
    }
    await auth.register(_signUpEmail.text.trim(), _signUpPassword.text, _signUpName.text.trim());
    if (auth.status == AuthStatus.authenticated && mounted) {
      context.go('/home');
    }
  }

  Future<void> _googleSignIn(AuthProvider auth) async {
    await auth.signInWithGoogle();
    if (auth.status == AuthStatus.authenticated && mounted) {
      context.go('/home');
    }
  }

  void _forgotPassword(AuthProvider auth) async {
    final email = _signInEmail.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email first'), backgroundColor: AppTheme.accent),
      );
      return;
    }
    await auth.sendPasswordReset(email);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reset email sent! Check your inbox.'), backgroundColor: AppTheme.primary),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            const SizedBox(height: 40),

            // ── Logo ──────────────────────────────────────────────────────
            Column(children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 8))],
                ),
                child: const Center(child: Text('⚡', style: TextStyle(fontSize: 40))),
              ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
              const SizedBox(height: 16),
              const Text('AppForge', style: TextStyle(color: AppTheme.textPrimary, fontSize: 28, fontWeight: FontWeight.w900))
                  .animate().fadeIn(delay: 200.ms),
              const Text('Build apps without code', style: TextStyle(color: AppTheme.textMuted, fontSize: 14))
                  .animate().fadeIn(delay: 300.ms),
            ]),

            const SizedBox(height: 36),

            // ── Tab switcher ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.darkBorder),
              ),
              child: TabBar(
                controller: _tabs,
                indicator: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: AppTheme.textMuted,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                dividerColor: Colors.transparent,
                tabs: const [Tab(text: 'Sign In'), Tab(text: 'Sign Up')],
              ),
            ).animate().fadeIn(delay: 400.ms),

            const SizedBox(height: 24),

            // ── Error banner ──────────────────────────────────────────────
            if (auth.errorMessage != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.accent.withOpacity(0.4)),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: AppTheme.accent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(auth.errorMessage!, style: const TextStyle(color: AppTheme.accent, fontSize: 13))),
                ]),
              ).animate().fadeIn().shakeX(),

            // ── Tab forms ─────────────────────────────────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _tabs.index == 0
                  ? _SignInForm(
                      key: const ValueKey('signin'),
                      emailCtrl: _signInEmail,
                      passwordCtrl: _signInPassword,
                      obscure: _obscureSignIn,
                      onToggleObscure: () => setState(() => _obscureSignIn = !_obscureSignIn),
                      onSignIn: () => _signIn(auth),
                      onForgot: () => _forgotPassword(auth),
                      loading: auth.isLoading,
                    )
                  : _SignUpForm(
                      key: const ValueKey('signup'),
                      nameCtrl: _signUpName,
                      emailCtrl: _signUpEmail,
                      passwordCtrl: _signUpPassword,
                      confirmCtrl: _signUpConfirm,
                      obscurePass: _obscureSignUp,
                      obscureConfirm: _obscureConfirm,
                      onTogglePass: () => setState(() => _obscureSignUp = !_obscureSignUp),
                      onToggleConfirm: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      onSignUp: () => _signUp(auth),
                      loading: auth.isLoading,
                    ),
            ),

            const SizedBox(height: 20),

            // ── Divider ───────────────────────────────────────────────────
            Row(children: [
              const Expanded(child: Divider(color: AppTheme.darkBorder)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('or', style: TextStyle(color: AppTheme.textMuted.withOpacity(0.7), fontSize: 13)),
              ),
              const Expanded(child: Divider(color: AppTheme.darkBorder)),
            ]),

            const SizedBox(height: 16),

            // ── Google Sign-In ────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: auth.isLoading ? null : () => _googleSignIn(auth),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppTheme.darkBorder),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Text('G', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                label: const Text('Continue with Google', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ).animate().fadeIn(delay: 500.ms),

            const SizedBox(height: 32),
          ]),
        ),
      ),
    );
  }
}

// ── Sign In form ──────────────────────────────────────────────────────────────
class _SignInForm extends StatelessWidget {
  final TextEditingController emailCtrl, passwordCtrl;
  final bool obscure, loading;
  final VoidCallback onToggleObscure, onSignIn, onForgot;

  const _SignInForm({
    super.key,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.obscure,
    required this.loading,
    required this.onToggleObscure,
    required this.onSignIn,
    required this.onForgot,
  });

  @override
  Widget build(BuildContext context) => Column(children: [
    _Field(ctrl: emailCtrl, hint: 'Email address', icon: Icons.email_outlined, type: TextInputType.emailAddress),
    const SizedBox(height: 12),
    _Field(
      ctrl: passwordCtrl, hint: 'Password',
      icon: Icons.lock_outline, obscure: obscure,
      suffix: IconButton(
        icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20, color: AppTheme.textMuted),
        onPressed: onToggleObscure,
      ),
    ),
    Align(
      alignment: Alignment.centerRight,
      child: TextButton(onPressed: onForgot, child: const Text('Forgot password?', style: TextStyle(color: AppTheme.primary, fontSize: 13))),
    ),
    const SizedBox(height: 8),
    SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onSignIn,
        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        child: loading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    ),
  ]);
}

// ── Sign Up form ──────────────────────────────────────────────────────────────
class _SignUpForm extends StatelessWidget {
  final TextEditingController nameCtrl, emailCtrl, passwordCtrl, confirmCtrl;
  final bool obscurePass, obscureConfirm, loading;
  final VoidCallback onTogglePass, onToggleConfirm, onSignUp;

  const _SignUpForm({
    super.key,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.confirmCtrl,
    required this.obscurePass,
    required this.obscureConfirm,
    required this.loading,
    required this.onTogglePass,
    required this.onToggleConfirm,
    required this.onSignUp,
  });

  @override
  Widget build(BuildContext context) => Column(children: [
    _Field(ctrl: nameCtrl, hint: 'Full name', icon: Icons.person_outline),
    const SizedBox(height: 12),
    _Field(ctrl: emailCtrl, hint: 'Email address', icon: Icons.email_outlined, type: TextInputType.emailAddress),
    const SizedBox(height: 12),
    _Field(
      ctrl: passwordCtrl, hint: 'Password (min 6 chars)',
      icon: Icons.lock_outline, obscure: obscurePass,
      suffix: IconButton(
        icon: Icon(obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20, color: AppTheme.textMuted),
        onPressed: onTogglePass,
      ),
    ),
    const SizedBox(height: 12),
    _Field(
      ctrl: confirmCtrl, hint: 'Confirm password',
      icon: Icons.lock_outline, obscure: obscureConfirm,
      suffix: IconButton(
        icon: Icon(obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20, color: AppTheme.textMuted),
        onPressed: onToggleConfirm,
      ),
    ),
    const SizedBox(height: 20),
    SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onSignUp,
        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        child: loading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Create Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    ),
  ]);
}

// ── Reusable text field ───────────────────────────────────────────────────────
class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType type;
  final Widget? suffix;

  const _Field({
    required this.ctrl,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.type = TextInputType.text,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    obscureText: obscure,
    keyboardType: type,
    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 20, color: AppTheme.textMuted),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppTheme.darkCard,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.darkBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.darkBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
    ),
  );
}
