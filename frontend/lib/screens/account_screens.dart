part of '../main.dart';

String _cleanError(Object e) => e.toString().replaceFirst('Exception: ', '');

/// 6 haneli kod giriş alanı.
class _CodeField extends StatelessWidget {
  const _CodeField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 6,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: TextStyle(
        color: pal.ink,
        fontSize: 26,
        fontWeight: FontWeight.w800,
        letterSpacing: 10,
      ),
      decoration: InputDecoration(
        counterText: '',
        hintText: '••••••',
        labelText: 'Doğrulama kodu'.tr(context),
      ),
      validator: (v) => (v == null || v.trim().length != 6)
          ? '6 haneli kodu gir'.tr(context)
          : null,
    );
  }
}

/// Ortak sayfa iskeleti.
class _AccountScaffold extends StatelessWidget {
  const _AccountScaffold({
    required this.title,
    required this.children,
    this.formKey,
  });

  final String title;
  final List<Widget> children;
  final GlobalKey<FormState>? formKey;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Scaffold(
      backgroundColor: pal.bg,
      appBar: AppBar(title: Text(title), backgroundColor: Colors.transparent),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: pal.ink,
        foregroundColor: pal.onInk,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: busy
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: pal.onInk,
              ),
            )
          : Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

String? _validateNewPassword(BuildContext context, String? v) {
  if (v == null || v.length < 8) {
    return 'Şifre en az 8 karakter olmalı'.tr(context);
  }
  return null;
}

// ---------------------------------------------------------------------------
// Şifremi unuttum: e-posta -> kod + yeni şifre
// ---------------------------------------------------------------------------

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = _cleanError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() => _run(() async {
    await context.read<AppState>().forgotPassword(_email.text);
    if (mounted) setState(() => _codeSent = true);
  });

  Future<void> _reset() => _run(() async {
    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final message = 'Şifren güncellendi. Yeni şifrenle giriş yapabilirsin.'.tr(
      context,
    );
    await appState.resetPassword(_email.text, _code.text, _password.text);
    messenger.showSnackBar(SnackBar(content: Text(message)));
    navigator.pop();
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return _AccountScaffold(
      title: 'Şifremi unuttum'.tr(context),
      formKey: _formKey,
      children: [
        Text(
          (_codeSent
                  ? 'E-postana gelen 6 haneli kodu ve yeni şifreni gir.'
                  : 'E-posta adresini gir, sana bir sıfırlama kodu gönderelim.')
              .tr(context),
          style: TextStyle(color: pal.muted, fontSize: 15, height: 1.4),
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _email,
          enabled: !_codeSent,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(labelText: 'E-posta'.tr(context)),
          validator: (v) => (v == null || !v.contains('@'))
              ? 'Geçerli bir e-posta gir'.tr(context)
              : null,
        ),
        if (_codeSent) ...[
          const SizedBox(height: 16),
          _CodeField(controller: _code),
          const SizedBox(height: 4),
          TextFormField(
            controller: _password,
            obscureText: true,
            decoration: InputDecoration(labelText: 'Yeni şifre'.tr(context)),
            validator: (v) => _validateNewPassword(context, v),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: pal.negative)),
        ],
        const SizedBox(height: 24),
        _PrimaryButton(
          label: (_codeSent ? 'Şifreyi sıfırla' : 'Kod gönder').tr(context),
          busy: _busy,
          onPressed: _codeSent ? _reset : _sendCode,
        ),
        if (_codeSent)
          TextButton(
            onPressed: _busy ? null : _sendCode,
            child: Text('Kodu tekrar gönder'.tr(context)),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// E-posta doğrulama
// ---------------------------------------------------------------------------

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({
    super.key,
    required this.email,
    required this.password,
  });

  final String email;

  /// Doğrulamadan sonra otomatik giriş için.
  final String password;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final appState = context.read<AppState>();
    final navigator = Navigator.of(context);
    try {
      await appState.verifyEmail(widget.email, _code.text);
      await appState.login(widget.email, widget.password);
      navigator.popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) setState(() => _error = _cleanError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    final sent = 'Yeni kod gönderildi.'.tr(context);
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await context.read<AppState>().resendVerification(widget.email);
      if (mounted) setState(() => _info = sent);
    } catch (e) {
      if (mounted) setState(() => _error = _cleanError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return _AccountScaffold(
      title: 'E-postanı doğrula'.tr(context),
      formKey: _formKey,
      children: [
        Text(
          '${widget.email} ${'adresine 6 haneli bir doğrulama kodu gönderdik.'.tr(context)}',
          style: TextStyle(color: pal.muted, fontSize: 15, height: 1.4),
        ),
        const SizedBox(height: 20),
        _CodeField(controller: _code),
        if (_error != null) ...[
          const SizedBox(height: 4),
          Text(_error!, style: TextStyle(color: pal.negative)),
        ],
        if (_info != null) ...[
          const SizedBox(height: 4),
          Text(_info!, style: TextStyle(color: pal.positive)),
        ],
        const SizedBox(height: 20),
        _PrimaryButton(
          label: 'Doğrula'.tr(context),
          busy: _busy,
          onPressed: _verify,
        ),
        TextButton(
          onPressed: _busy ? null : _resend,
          child: Text('Kodu tekrar gönder'.tr(context)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Şifre değiştirme (Ayarlar)
// ---------------------------------------------------------------------------

Future<void> showChangePasswordDialog(BuildContext context) async {
  final appState = context.read<AppState>();
  final messenger = ScaffoldMessenger.of(context);
  final successText = 'Şifren değiştirildi.'.tr(context);

  final changed = await showDialog<bool>(
    context: context,
    builder: (ctx) => _ChangePasswordDialog(appState: appState),
  );
  if (changed == true) {
    messenger.showSnackBar(SnackBar(content: Text(successText)));
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({required this.appState});

  final AppState appState;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    try {
      await widget.appState.changePassword(_current.text, _new.text);
      navigator.pop(true);
    } on SessionExpiredException {
      navigator.pop(false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _cleanError(e);
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return AlertDialog(
      title: Text('Şifreyi değiştir'.tr(context)),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _current,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Mevcut şifre'.tr(context),
                ),
                validator: (v) => (v == null || v.isEmpty)
                    ? 'Lütfen şifre gir'.tr(context)
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _new,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Yeni şifre'.tr(context),
                ),
                validator: (v) => _validateNewPassword(context, v),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: pal.negative)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text('Vazgeç'.tr(context)),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text('Değiştir'.tr(context)),
        ),
      ],
    );
  }
}
