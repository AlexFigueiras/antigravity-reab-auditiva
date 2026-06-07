import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../services/locale_controller.dart';
import '../../services/theme_controller.dart';
import '../theme/app_palette.dart';
import 'home_screen.dart';

/// Tela de entrada: simples e acolhedora (ver PRODUTO.md §5 e §7).
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false;

  AppPalette get _p => context.watch<ThemeController>().palette;
  Color get _bg => _p.bg;
  Color get _card => _p.card;
  Color get _field => _p.card;
  Color get _primary => _p.primary;
  Color get _textMain => _p.textMain;
  Color get _textSoft => _p.textSoft;

  Future<void> _handleAuth() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;

    try {
      if (_isSignUp) {
        final AuthResponse res = await supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (res.user != null) {
          await supabase.from('profiles').insert({
            'user_id': res.user!.id,
            'subscription_status': 'free',
            'created_at': DateTime.now().toIso8601String(),
          });
          if (mounted) {
            _showSnackbar(l10n.authSignUpSuccess);
          }
        }
      } else {
        await supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar(l10n.authError);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showLanguageSheet(BuildContext context) {
    final controller = context.read<LocaleController>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Text(AppLocalizations.of(context).settingsLanguage,
                  style: TextStyle(
                      color: _textMain,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.check, color: _primary, size: 20),
                title: Text("Português", style: TextStyle(color: _textMain)),
                onTap: () {
                  controller.setLocale(const Locale('pt'));
                  Navigator.of(sheetContext).pop();
                },
              ),
              ListTile(
                leading: Icon(Icons.check, color: _primary, size: 20),
                title: Text("English", style: TextStyle(color: _textMain)),
                onTap: () {
                  controller.setLocale(const Locale('en'));
                  Navigator.of(sheetContext).pop();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _showLanguageSheet(context),
                    icon: Icon(Icons.language, color: _textSoft, size: 20),
                    label: Text(
                      l10n.languageName,
                      style: TextStyle(color: _textSoft, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildLogo(l10n),
                const SizedBox(height: 48),
                _buildTextField(l10n.authEmailLabel, _emailController,
                    keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 20),
                _buildTextField(l10n.authPasswordLabel, _passwordController, obscure: true),
                const SizedBox(height: 32),
                _buildAuthButton(l10n),
                const SizedBox(height: 12),
                _buildToggleMode(l10n),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.hearing, color: _primary, size: 56),
        const SizedBox(height: 20),
        Text(
          _isSignUp ? l10n.authCreateAccount : l10n.authWelcomeBack,
          style: TextStyle(
              color: _textMain, fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          _isSignUp ? l10n.authCreateSubtitle : l10n.authWelcomeSubtitle,
          style: TextStyle(color: _textSoft, fontSize: 16, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {bool obscure = false, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: _textSoft, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: TextStyle(color: _textMain, fontSize: 17),
          decoration: InputDecoration(
            filled: true,
            fillColor: _field,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: _textSoft.withValues(alpha: 0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: _primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAuthButton(AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: _isLoading ? null : _handleAuth,
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
            : Text(_isSignUp ? l10n.authSignUp : l10n.authSignIn,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildToggleMode(AppLocalizations l10n) {
    return Center(
      child: TextButton(
        onPressed: () => setState(() => _isSignUp = !_isSignUp),
        child: Text(
          _isSignUp ? l10n.authSwitchToSignIn : l10n.authSwitchToSignUp,
          style: TextStyle(color: _primary, fontSize: 15),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
