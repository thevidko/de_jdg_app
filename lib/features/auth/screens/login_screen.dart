import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // 1. Lokální proměnné (jako ref() ve Vue)
  final _formKey = GlobalKey<FormState>(); // Pro validaci formuláře
  final _emailController = TextEditingController(); // v-model pro email
  final _passwordController = TextEditingController(); // v-model pro heslo
  bool _isPasswordVisible = false;

  // 2. Úklid při zničení komponenty (unmounted)
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 3. Logika odeslání
  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      // Zavoláme metodu z našeho AuthControlleru
      // ref.read() se používá pro akce (nechceme překreslovat, jen zavolat funkci)
      await ref
          .read(authControllerProvider.notifier)
          .login(_emailController.text.trim(), _passwordController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 4. Sledujeme stav AuthControlleru (loading, error)
    // ref.watch() způsobí rebuild této metody při změně stavu
    final authState = ref.watch(authControllerProvider);

    // 5. Side-effect: Pokud nastane chyba, zobrazíme Toast (SnackBar)
    // ref.listen() se používá pro jednorázové reakce na změnu stavu
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: Colors.red),
        );
      }
    });

    return Scaffold(
      // SafeArea zajistí, že nezasahujeme do "notche" nebo status baru
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Logo / Nadpis ---
                  const Icon(Icons.lock_person, size: 80, color: Colors.blue),
                  const SizedBox(height: 24),
                  Text(
                    'Vítejte zpět',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // --- Email Input ---
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    // Validátor (vrací null pokud OK, string pokud chyba)
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Prosím zadejte email';
                      }
                      if (!value.contains('@')) {
                        return 'Neplatný formát emailu';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // --- Password Input ---
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible, // Skrývání hesla
                    decoration: InputDecoration(
                      labelText: 'Heslo',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(), // Enter odešle form
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Prosím zadejte heslo';
                      }
                      if (value.length < 6) {
                        return 'Heslo musí mít alespoň 6 znaků';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // --- Submit Button ---
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: authState.isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: authState.isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Přihlásit se',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
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
