import 'package:flutter/material.dart';
import '../services/api.dart';
import '../services/session.dart';
import '../theme/anon_theme.dart';
import '../widgets/brand_header.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.api, required this.onAuthenticated});
  final ApiService api;
  final void Function(AnonUser user) onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  bool loginMode = true;
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  bool showPass = false;
  bool showConfirm = false;
  bool remember = false;
  bool busy = false;
  String? error;
  final fieldErrors = <String, String?>{};
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    SessionStore.instance.getRememberedEmail().then((email) {
      if (email != null && email.isNotEmpty && mounted) {
        setState(() {
          emailCtrl.text = email;
          remember = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    confirmCtrl.dispose();
    super.dispose();
  }

  bool _validate() {
    fieldErrors.clear();
    final email = emailCtrl.text.trim();
    if (email.isEmpty) {
      fieldErrors['email'] = 'Email is required';
    } else if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      fieldErrors['email'] = 'Enter a valid email address';
    }
    if (passCtrl.text.isEmpty) {
      fieldErrors['password'] = 'Password is required';
    } else if (!loginMode && passCtrl.text.length < 8) {
      fieldErrors['password'] = 'Use at least 8 characters';
    }
    if (!loginMode) {
      if (confirmCtrl.text.isEmpty) {
        fieldErrors['confirm'] = 'Confirm your password';
      } else if (confirmCtrl.text != passCtrl.text) {
        fieldErrors['confirm'] = 'Passwords do not match';
      }
    }
    setState(() {});
    return fieldErrors.isEmpty;
  }

  Future<void> _submit() async {
    setState(() => error = null);
    if (!_validate()) return;
    setState(() => busy = true);
    try {
      final user = loginMode
          ? await widget.api.login(email: emailCtrl.text, password: passCtrl.text, remember: remember)
          : await widget.api.register(
              email: emailCtrl.text,
              password: passCtrl.text,
              passwordConfirm: confirmCtrl.text,
              remember: remember,
            );
      widget.onAuthenticated(user);
    } catch (e) {
      setState(() => error = widget.api.friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.75),
                radius: 1.2,
                colors: [Color(0xFF2A1450), Color(0xFF120C1F), AnonColors.bg],
                stops: [0, 0.4, 0.85],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                children: [
                  const BrandHeader(),
                  const SizedBox(height: 8),
                  const Text(
                    'Private by design. Protected by Anon.',
                    style: TextStyle(color: AnonColors.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
                    decoration: BoxDecoration(
                      color: const Color(0xF0120F1A),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AnonColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          loginMode ? 'Welcome back' : 'Create your account',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          loginMode
                              ? 'Sign in to your protected dashboard.'
                              : 'One account. Full privacy console.',
                          style: const TextStyle(color: AnonColors.muted, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF0E0C14),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AnonColors.border),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            children: [
                              _tab('Log in', loginMode, () {
                                if (!busy) setState(() { loginMode = true; error = null; fieldErrors.clear(); });
                              }),
                              _tab('Create account', !loginMode, () {
                                if (!busy) setState(() { loginMode = false; error = null; fieldErrors.clear(); });
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: emailCtrl,
                          enabled: !busy,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            hintText: 'you@example.com',
                            errorText: fieldErrors['email'],
                            prefixIcon: const Icon(Icons.mail_outline, size: 18),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: passCtrl,
                          enabled: !busy,
                          obscureText: !showPass,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            hintText: loginMode ? 'Your password' : 'At least 8 characters',
                            errorText: fieldErrors['password'],
                            prefixIcon: const Icon(Icons.lock_outline, size: 18),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => showPass = !showPass),
                              icon: Icon(showPass ? Icons.visibility_off : Icons.visibility, size: 18),
                            ),
                          ),
                        ),
                        if (!loginMode) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: confirmCtrl,
                            enabled: !busy,
                            obscureText: !showConfirm,
                            decoration: InputDecoration(
                              labelText: 'Confirm password',
                              errorText: fieldErrors['confirm'],
                              prefixIcon: const Icon(Icons.lock_outline, size: 18),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => showConfirm = !showConfirm),
                                icon: Icon(showConfirm ? Icons.visibility_off : Icons.visibility, size: 18),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Checkbox(
                              value: remember,
                              onChanged: busy ? null : (v) => setState(() => remember = v ?? false),
                              activeColor: AnonColors.purple,
                            ),
                            const Text('Remember me on this device', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(error!, style: const TextStyle(color: AnonColors.danger, fontSize: 13)),
                          ),
                        ElevatedButton(
                          onPressed: busy ? null : _submit,
                          child: busy
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(loginMode ? 'Continue securely' : 'Create protected account'),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'By continuing you agree to the Terms and Privacy Policy.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AnonColors.muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tab(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: active
                ? const LinearGradient(colors: [Color(0xFF7B2ED2), Color(0xFFBD70FF)])
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: active ? Colors.white : AnonColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}
