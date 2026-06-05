import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  static const Color _bg = Color(0xFF101418);
  static const Color _field = Color(0xFF1B2128);
  static const Color _primary = Color(0xFF4F8DF7);
  static const Color _textMain = Color(0xFFF2F4F7);
  static const Color _textSoft = Color(0xFFB4BCC8);

  Future<void> _handleAuth() async {
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
            _showSnackbar("Conta criada! Verifique seu e-mail para confirmar.");
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
        _showSnackbar("Não foi possível entrar. Confira seu e-mail e senha.");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLogo(),
                const SizedBox(height: 48),
                _buildTextField("Seu e-mail", _emailController,
                    keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 20),
                _buildTextField("Sua senha", _passwordController, obscure: true),
                const SizedBox(height: 32),
                _buildAuthButton(),
                const SizedBox(height: 12),
                _buildToggleMode(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.hearing, color: _primary, size: 56),
        const SizedBox(height: 20),
        Text(
          _isSignUp ? "Vamos criar sua conta" : "Bem-vindo de volta",
          style: const TextStyle(
              color: _textMain, fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          _isSignUp
              ? "É rápido. Depois preparamos tudo no seu ritmo."
              : "Entre para continuar seu treino auditivo.",
          style: const TextStyle(color: _textSoft, fontSize: 16, height: 1.4),
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
            style: const TextStyle(
                color: _textSoft, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: const TextStyle(color: _textMain, fontSize: 17),
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
              borderSide: const BorderSide(color: _primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAuthButton() {
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
            : Text(_isSignUp ? "Criar conta" : "Entrar",
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildToggleMode() {
    return Center(
      child: TextButton(
        onPressed: () => setState(() => _isSignUp = !_isSignUp),
        child: Text(
          _isSignUp
              ? "Já tem conta? Entrar"
              : "Ainda não tem conta? Criar agora",
          style: const TextStyle(color: _primary, fontSize: 15),
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
