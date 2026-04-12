import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
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
    final authState = ref.watch(authControllerProvider);

    // 5. Side-effect: Pokud nastane chyba, zobrazíme Toast (SnackBar)
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!)), // Styly řeší globální AppTheme
        );
      }
    });

    return Scaffold(
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
                  // --- Logo ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'DE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18, // mírně menší než vedlejší text, CSS většinou řeší line-height
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Inter',
                            height: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DanceEval',
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 20, // 1.25rem = 20px
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Inter',
                              height: 1.1,
                            ),
                          ),
                          Text(
                            'JUDGE',
                            style: TextStyle(
                              color: Color(0xFF8B5CF6),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Inter',
                              letterSpacing: 2.0,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),

                  // --- Formular Container (Interactive Card) ---
                  Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.onSurface.withOpacity(0.06), // ambientní stín
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- Email Input (Separated Label) ---
                        Text(
                          'Email',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          style: Theme.of(context).textTheme.bodyMedium,
                          decoration: const InputDecoration(
                            hintText: 'Např. judge@danceeval.com',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
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
                        const SizedBox(height: 24),

                        // --- Password Input (Separated Label) ---
                        Text(
                          'Heslo',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          style: Theme.of(context).textTheme.bodyMedium,
                          decoration: InputDecoration(
                            hintText: 'Minimálně 6 znaků',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                            ),
                          ),
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
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
                        const SizedBox(height: 48),

                        // --- Submit Button (Glass & Gradient) ---
                        Container(
                          height: 56, // Min height pro touch target
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.primaryContainer],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(32), // `xl` roundedness (3rem aprox)
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: authState.isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(32),
                              ),
                            ),
                            child: Center(
                              child: authState.isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text(
                                      'Přihlásit se',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white, // on_primary fallback
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
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
