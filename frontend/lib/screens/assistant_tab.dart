part of '../main.dart';

class AssistantTab extends StatefulWidget {
  const AssistantTab({super.key});

  @override
  State<AssistantTab> createState() => _AssistantTabState();
}

class _AssistantTabState extends State<AssistantTab> {
  final List<_ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Cihazda en çok bu kadar mesaj saklanır (sunucu tarafı ayrıca sınırlıdır).
  static const int _maxStoredMessages = 200;

  Future<void> _loadMessages() async {
    final data = await UserStore.readList('assistant_messages');
    final loaded = <_ChatMessage>[];
    for (final e in data) {
      if (e is! Map) continue;
      final ts = asInt(e['ts']);
      loaded.add(
        _ChatMessage(
          text: asString(e['text']),
          fromUser: asBool(e['fromUser']),
          time: ts == null ? null : DateTime.fromMillisecondsSinceEpoch(ts),
        ),
      );
    }
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(loaded);
    });
    _scrollToBottom();
  }

  Future<void> _saveMessages() async {
    if (_messages.length > _maxStoredMessages) {
      _messages.removeRange(0, _messages.length - _maxStoredMessages);
    }
    final data = _messages
        .map(
          (m) => {
            'text': m.text,
            'fromUser': m.fromUser,
            'ts': m.time?.millisecondsSinceEpoch,
          },
        )
        .toList();
    await UserStore.writeJson('assistant_messages', data);
  }

  Future<void> _clearChat() async {
    if (!mounted) return;
    final appState = context.read<AppState>();
    setState(() {
      _messages.clear();
    });
    await _saveMessages();
    try {
      await appState.clearRemoteChatHistory();
    } on SessionExpiredException {
      // oturum kapandı
    }
  }

  void _addAssistantMessage(String text) {
    if (!mounted) return;
    setState(
      () => _messages.add(
        _ChatMessage(text: text, fromUser: false, time: DateTime.now()),
      ),
    );
    _saveMessages();
    _scrollToBottom();
  }

  Future<void> _sendMessage([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || _isSending) return;

    // Veriler üçüncü taraf yapay zekaya gidecek: önce açık izin al.
    if (!await ensureAiConsent(context)) return;
    if (!mounted) return;
    setState(() {
      _messages.add(
        _ChatMessage(text: text, fromUser: true, time: DateTime.now()),
      );
      _controller.clear();
      _isSending = true;
    });
    _scrollToBottom();
    _saveMessages();

    final appState = context.read<AppState>();
    try {
      final contextPayload = await AssistantContext.build();
      final response = await appState.authedRequest(
        'POST',
        '/assistant/chat',
        body: {'message': text, 'context': contextPayload},
        timeout: const Duration(seconds: 90),
      );
      if (!mounted) return;

      if (response.statusCode != 200) {
        if (response.statusCode == 503) {
          _addAssistantMessage(
            'Asistan şu anda kullanılamıyor. Lütfen biraz sonra tekrar dene.'
                .tr(context),
          );
          return;
        }
        _addAssistantMessage(
          '${'Asistan şu an yanıt veremiyor (hata kodu: '.tr(context)}${response.statusCode}). '
          '${'Bir süre sonra tekrar dene.'.tr(context)}',
        );
        return;
      }

      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final reply =
          data['reply']?.toString() ??
          'Asistan şu an beklenmedik bir cevap döndürdü.'.tr(context);
      final action = data['action'];
      _addAssistantMessage(reply);
      if (action is Map<String, dynamic>) {
        await _handleAction(action);
      }
    } on SessionExpiredException {
      // AppState oturumu kapattı; AuthGate giriş ekranına döner.
    } catch (e) {
      if (!mounted) return;
      _addAssistantMessage(
        '${'Asistan ile bağlantı kurarken bir hata oluştu: '.tr(context)}$e',
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToBottom();
      }
    }
  }

  late final AssistantActions _actions = AssistantActions(
    nextNotificationId: nextNotificationId,
    scheduleActivity: scheduleActivityReminder,
    scheduleRoutine: scheduleRoutineReminder,
  );

  /// Asistanın önerdiği action'ı uygular; başarısızsa sohbete bir uyarı ekler.
  Future<void> _handleAction(Map<String, dynamic> action) async {
    final error = await _actions.apply(action);
    if (error == null || !mounted) return;
    setState(() {
      _messages.add(
        _ChatMessage(
          text: '${'Asistanın önerdiği kayıt eklenemedi:'.tr(context)} $error',
          fromUser: false,
          time: DateTime.now(),
        ),
      );
    });
    _saveMessages();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Scaffold(
      backgroundColor: pal.bg,
      body: Stack(
        children: [
          Positioned(
            top: 150,
            left: 0,
            right: 0,
            child: Opacity(
              opacity: 0.03,
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 320,
                color: pal.ink,
              ),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                        itemCount: _messages.length + (_isSending ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _messages.length && _isSending) {
                            return _buildTypingIndicator();
                          }
                          return _buildMessageBubble(_messages[index]);
                        },
                      ),
              ),
              _buildInputArea(),
            ],
          ),
        ],
      ),
    );
  }

  static const List<String> _suggestions = [
    'Bugün neler yapmalıyım?',
    'Bu hafta ne kadar harcadım?',
    'Bana bir spor planı hazırla',
    'Yarın sabah 7\'ye yürüyüş ekle',
  ];

  Widget _buildEmptyState() {
    final pal = context.pal;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: pal.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: pal.shadow.withValues(alpha: 0.05),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 40,
                color: pal.ink,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Smart AI ile Konuş'.tr(context),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: pal.ink,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sana bugün nasıl yardımcı olabilirim?'.tr(context),
              style: TextStyle(color: pal.muted, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Text(
              'Yanıtlar yapay zeka tarafından üretilir ve hatalı olabilir.'.tr(
                context,
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: pal.subtle, fontSize: 12),
            ),
            const SizedBox(height: 28),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final q in _suggestions)
                  ActionChip(
                    label: Text(q.tr(context)),
                    onPressed: () => _sendMessage(q.tr(context)),
                    backgroundColor: pal.surface,
                    side: BorderSide(color: pal.border),
                    labelStyle: TextStyle(
                      color: pal.ink,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    final pal = context.pal;
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        label: 'Asistan yazıyor'.tr(context),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: pal.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
              bottomLeft: Radius.circular(6),
              bottomRight: Radius.circular(24),
            ),
            border: Border.all(color: pal.border),
          ),
          child: const _TypingDots(),
        ),
      ),
    );
  }

  /// Uygunsuz ya da hatalı bir asistan yanıtını sunucuya bildirir.
  Future<void> _reportMessage(_ChatMessage msg) async {
    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Yanıtı bildir'.tr(ctx)),
        content: Text(
          'Bu yanıtı uygunsuz veya hatalı olarak bildirmek istiyor musun?'.tr(
            ctx,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Vazgeç'.tr(ctx)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Bildir'.tr(ctx)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final response = await appState.authedRequest(
        'POST',
        '/assistant/report',
        body: {'content': msg.text, 'reason': 'inappropriate_or_incorrect'},
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            (response.statusCode == 204
                    ? 'Bildirimin alındı. Teşekkürler.'
                    : 'Bildirim gönderilemedi.')
                .tr(context),
          ),
        ),
      );
    } on SessionExpiredException {
      // oturum kapandı
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Bildirim gönderilemedi.'.tr(context))),
      );
    }
  }

  Widget _buildMessageBubble(_ChatMessage msg) {
    final pal = context.pal;
    final isMe = msg.fromUser;
    final t = msg.time;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isMe ? pal.ink : pal.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(24),
                  topRight: const Radius.circular(24),
                  bottomLeft: Radius.circular(isMe ? 24 : 6),
                  bottomRight: Radius.circular(isMe ? 6 : 24),
                ),
                border: isMe ? null : Border.all(color: pal.border),
              ),
              child: SelectableText(
                msg.text,
                style: TextStyle(
                  color: isMe ? pal.onInk : pal.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (t != null)
                    Text(
                      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: pal.subtle,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (!isMe) ...[
                    if (t != null) const SizedBox(width: 10),
                    InkWell(
                      onTap: () => _reportMessage(msg),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.flag_outlined,
                              size: 13,
                              color: pal.subtle,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Bildir'.tr(context),
                              style: TextStyle(
                                color: pal.subtle,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    final pal = context.pal;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: pal.shadow.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_messages.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _clearChat,
                icon: Icon(Icons.refresh_rounded, size: 16, color: pal.muted),
                label: Text(
                  'Yeni Sohbet'.tr(context),
                  style: TextStyle(
                    color: pal.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: pal.bg,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: pal.ink,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Asistanına bir şey sor...'.tr(context),
                      hintStyle: TextStyle(
                        color: pal.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Semantics(
                button: true,
                label: 'Gönder'.tr(context),
                child: GestureDetector(
                  onTap: _isSending ? null : _sendMessage,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isSending ? pal.subtle : pal.ink,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.send_rounded, color: pal.onInk, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Üç nokta "yazıyor" animasyonu.
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.pal.muted;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_controller.value - i * 0.18) % 1.0;
            final lift = phase < 0.5
                ? (phase / 0.5)
                : (1 - (phase - 0.5) / 0.5);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              width: 8,
              height: 8,
              transform: Matrix4.translationValues(0, -4 * lift, 0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.4 + 0.6 * lift),
              ),
            );
          }),
        );
      },
    );
  }
}

class _ChatMessage {
  _ChatMessage({required this.text, required this.fromUser, this.time});

  final String text;
  final bool fromUser;

  /// Gönderim zamanı (eski kayıtlarda yoktur).
  final DateTime? time;
}
