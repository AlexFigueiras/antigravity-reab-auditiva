import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';

/// AUTH SCREEN: Portal Industrial de Acesso [SEGURANÇA]
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

  Future<void> _handleAuth() async {
    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;

    try {
      if (_isSignUp) {
        // Registro de Novo Usuário
        final AuthResponse res = await supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (res.user != null) {
          // Criação Automática de Perfil [REGRA DE NEGÓCIO]
          await supabase.from('profiles').insert({
            'user_id': res.user!.id,
            'subscription_status': 'free',
            'created_at': DateTime.now().toIso8601String(),
          });
          if (mounted) _showSnackbar("CONTA CRIADA COM SUCESSO. VERIFIQUE SEU E-MAIL.");
        }
      } else {
        // Login Existente
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
      if (mounted) _showSnackbar("ERRO DE AUTENTICAÇÃO: ${e.toString().toUpperCase()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1A1A1A),
        content: Text(message, style: const TextStyle(color: Color(0xFF00FF41), fontFamily: 'monospace', fontSize: 10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLogo(),
              const SizedBox(height: 50),
              _buildTextField("IDENTIFICADOR (E-MAIL)", _emailController),
              const SizedBox(height: 20),
              _buildTextField("CHAVE DE ACESSO (SENHA)", _passwordController, obscure: true),
              const SizedBox(height: 40),
              _buildAuthButton(),
              const SizedBox(height: 20),
              _buildToggleMode(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("BOSYN NEURAL ENGINE", style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 4)),
        const SizedBox(height: 8),
        Text(_isSignUp ? "INITIALIZING ID" : "TERMINAL ACCESS", 
          style: const TextStyle(color: Color(0xFF00FF41), fontSize: 28, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
        Container(height: 2, width: 80, color: const Color(0xFF00FF41)),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool obscure = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 8, letterSpacing: 2)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF1A1A1A),
            enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
            focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FF41))),
          ),
        ),
      ],
    );
  }

  Widget _buildAuthButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          shape: const BeveledRectangleBorder(),
        ),
        onPressed: _isLoading ? null : _handleAuth,
        child: _isLoading 
          ? const CircularProgressIndicator(color: Colors.white)
          : Text(_isSignUp ? "CONFIRMAR REGISTRO" : "SOLICITAR ACESSO", 
              style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
      ),
    );
  }

  Widget _buildToggleMode() {
    return Center(
      child: TextButton(
        onPressed: () => setState(() => _isSignUp = !_isSignUp),
        child: Text(
          _isSignUp ? "JÁ POSSUI IDENTIFICADOR? LOGIN" : "NOVO OPERADOR? CRIAR CONTA",
          style: const TextStyle(color: Colors.white24, fontSize: 10, fontFamily: 'monospace', decoration: TextDecoration.underline),
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
