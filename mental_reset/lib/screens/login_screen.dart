import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/result.dart';
import '../state/auth_model.dart';
import '../state/sessions_model.dart';

/// L5: форма из L3, теперь логинится на backend-е и сохраняет JWT.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _register = false;
  bool _busy = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final r = await context
        .read<AuthModel>()
        .login(_emailCtrl.text.trim(), _passwordCtrl.text, register: _register);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case Ok():
        context.read<SessionsModel>().load();
        context.go('/home');
      case Err(:final message):
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Text('Mental Reset', style: TextStyle(fontSize: 26)),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'E-mail'),
                    validator: (v) => (v == null || !v.contains('@'))
                        ? 'Введите корректный e-mail (содержащий @)'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Пароль'),
                    validator: (v) => (v == null || v.length < 6)
                        ? 'Пароль должен содержать минимум 6 символов'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _login,
                    child: Text(_register ? 'Зарегистрироваться' : 'Войти'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _register = !_register),
                    child: Text(_register ? 'Уже есть аккаунт? Войти' : 'Нет аккаунта? Регистрация'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
