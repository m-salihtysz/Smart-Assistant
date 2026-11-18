part of '../main.dart';

/// Giriş sonucu: başarı, gösterilecek hata ya da (doğrulama ekranına yönlendirildiyse) hiçbiri.
class _LoginOutcome {
  const _LoginOutcome.success() : success = true, error = null;
  const _LoginOutcome.failed(this.error) : success = false;
  const _LoginOutcome.redirected() : success = false, error = null;

  final bool success;
  final String? error;
}

/// Giriş dener; e-posta doğrulanmamışsa doğrulama ekranına yönlendirir.
Future<_LoginOutcome> _attemptLogin(
  BuildContext context,
  String email,
  String password,
) async {
  final appState = context.read<AppState>();
  final wrong = 'E-posta veya şifre hatalı.'.tr(context);
  try {
    final ok = await appState.login(email, password);
    return ok ? const _LoginOutcome.success() : _LoginOutcome.failed(wrong);
  } on EmailNotVerifiedException {
    if (!context.mounted) return const _LoginOutcome.redirected();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VerifyEmailScreen(email: email, password: password),
      ),
    );
    return const _LoginOutcome.redirected();
  } catch (e) {
    return _LoginOutcome.failed(
      e is Exception ? e.toString().replaceFirst('Exception: ', '') : wrong,
    );
  }
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    final outcome = await _attemptLogin(
      context,
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );
    if (!context.mounted) return;
    if (outcome.success) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      setState(() => _errorText = outcome.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 48),
                    Text(
                      'Smart Assistant',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.pal.ink,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Giriş yap veya yeni hesap oluştur'.tr(context),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: context.pal.muted,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(40),
                          topRight: Radius.circular(20),
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: context.pal.shadow.withValues(alpha: 0.15),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Giriş yap'.tr(context),
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 24),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: 'E-posta'.tr(context),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'E-posta girin'.tr(context);
                                  }
                                  if (!v.contains('@')) {
                                    return 'Geçerli bir e-posta girin'.tr(
                                      context,
                                    );
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: true,
                                decoration: InputDecoration(
                                  labelText: 'Şifre'.tr(context),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Şifre girin'.tr(context);
                                  }
                                  return null;
                                },
                              ),
                              if (_errorText != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  _errorText!,
                                  style: TextStyle(
                                    color: colorScheme.error,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),
                              FilledButton(
                                onPressed: () => _handleLogin(context),
                                style: FilledButton.styleFrom(
                                  backgroundColor: context.pal.ink,
                                  foregroundColor: context.pal.onInk,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text('Giriş yap'.tr(context)),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => ForgotPasswordScreen(
                                      initialEmail: _emailController.text
                                          .trim(),
                                    ),
                                  ),
                                ),
                                child: Text('Şifremi unuttum'.tr(context)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'Hesabın yok mu? Kayıt ol'.tr(context),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: context.pal.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    final appState = context.read<AppState>();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    try {
      final verified = await appState.register(email, password);
      if (!context.mounted) return;
      if (!verified) {
        // Doğrulama zorunlu: kod ekranı doğrulamadan sonra otomatik giriş yapar.
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => VerifyEmailScreen(email: email, password: password),
          ),
        );
        return;
      }
      // Kayıttan sonra doğrudan giriş yap.
      final loggedIn = await appState.login(email, password);
      if (!context.mounted) return;
      if (loggedIn) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kayıt başarısız: ${e.toString()}'.tr(context))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                margin: const EdgeInsets.only(top: 40),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: context.pal.shadow.withValues(alpha: 0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      'Yeni hesap oluştur'.tr(context),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Kayıt ol'.tr(context),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'E-posta'.tr(context),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'E-posta girin'.tr(context);
                              }
                              if (!v.contains('@')) {
                                return 'Geçerli bir e-posta girin'.tr(context);
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'Şifre'.tr(context),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Şifre belirleyin'.tr(context);
                              }
                              if (v.trim().length < 8) {
                                return 'Şifre en az 8 karakter olmalı'.tr(
                                  context,
                                );
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: () => _handleRegister(context),
                            style: FilledButton.styleFrom(
                              backgroundColor: context.pal.ink,
                              foregroundColor: context.pal.onInk,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text('Kayıt ol'.tr(context)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Zaten hesabın var mı? Giriş yap'.tr(context),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: context.pal.surface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  DateTime? _selectedDate;
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initialDate = DateTime(now.year - 20, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? initialDate,
      firstDate: DateTime(1900),
      lastDate: latestAllowedBirthDate(),
      helpText: 'Doğum tarihini seç'.tr(context),
    );
    if (picked != null) {
      if (mounted) {
        setState(() {
          _selectedDate = picked;
        });
      }
    }
  }

  Future<void> _completeOnboarding(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lütfen doğum tarihini seç'.tr(context))),
      );
      return;
    }
    if (!isOldEnough(_selectedDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Uygulamayı kullanmak için en az 13 yaşında olmalısın.'.tr(context),
          ),
        ),
      );
      return;
    }
    final appState = context.read<AppState>();
    try {
      await appState.updateProfile(
        name: _nameController.text.trim(),
        birthDate: _selectedDate!,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      return;
    }
    if (!context.mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().currentUser;
    final emailText = user?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Seni Tanıyalım'.tr(context)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                margin: const EdgeInsets.only(top: 40),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: context.pal.shadow.withValues(alpha: 0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${'Merhaba'.tr(context)}, $emailText',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: context.pal.ink,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sana daha iyi yardımcı olabilmem için birkaç bilgi isteyeceğim.'
                            .tr(context),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Adın'.tr(context),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Lütfen adını gir'.tr(context);
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _pickDate,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Doğum tarihin'.tr(context),
                          ),
                          child: Text(
                            _selectedDate == null
                                ? 'Seç'.tr(context)
                                : formatDate(_selectedDate!),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      FilledButton(
                        onPressed: () => _completeOnboarding(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: context.pal.ink,
                          foregroundColor: context.pal.onInk,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text('Devam et'.tr(context)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
