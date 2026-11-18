part of '../main.dart';

class NotesTab extends StatefulWidget {
  const NotesTab({super.key});

  @override
  State<NotesTab> createState() => _NotesTabState();
}

class _NoteItem {
  _NoteItem({required this.title, required this.body});
  final String title;
  final String body;
}

class _NotesTabState extends State<NotesTab> {
  final List<_NoteItem> _notes = [];

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final loaded = <_NoteItem>[];
    for (final item in await UserStore.readList('notes_v2')) {
      if (item is! Map) continue; // bozuk kayıt tüm listeyi çökertmesin
      loaded.add(
        _NoteItem(title: asString(item['title']), body: asString(item['body'])),
      );
    }
    if (!mounted) return;
    setState(() {
      _notes
        ..clear()
        ..addAll(loaded);
    });
  }

  Future<void> _saveNotes() async {
    final list = _notes.map((n) => {'title': n.title, 'body': n.body}).toList();
    await UserStore.setString('notes_v2', jsonEncode(list));
  }

  Future<void> _addNote() async {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Yeni not'.tr(context)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Başlık'.tr(context),
                    hintText: 'Not başlığı'.tr(context),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Not'.tr(context),
                    hintText: 'Notunu yaz...'.tr(context),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Vazgeç'.tr(context)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty &&
                    bodyController.text.trim().isEmpty) {
                  return;
                }
                if (mounted) {
                  setState(() {
                    _notes.insert(
                      0,
                      _NoteItem(
                        title: titleController.text.trim(),
                        body: bodyController.text.trim(),
                      ),
                    );
                  });
                }
                await _saveNotes();
                if (!mounted || !context.mounted) return;
                Navigator.of(context).pop();
              },
              child: Text('Kaydet'.tr(context)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Text(
            'Notlarım'.tr(context),
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 28,
              color: context.pal.ink,
              letterSpacing: -1,
            ),
          ),
        ),
        Expanded(
          child: _notes.isEmpty
              ? EmptyState(
                  icon: Icons.note_alt_rounded,
                  message: 'Henüz bir notun yok.'.tr(context),
                  hint: 'Fikirlerini ve hatırlatmalarını buraya yaz.'.tr(
                    context,
                  ),
                  actionLabel: 'İlk notunu ekle'.tr(context),
                  onAction: _addNote,
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _notes.length,
                  itemBuilder: (context, index) {
                    final note = _notes[index];
                    final displayTitle = note.title.isEmpty
                        ? (note.body.isEmpty ? 'Başlıksız' : note.body)
                        : note.title;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: context.pal.surface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: context.pal.shadow.withValues(alpha: 0.04),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _editNote(index),
                          borderRadius: BorderRadius.circular(24),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: context.pal.ink.withValues(
                                      alpha: 0.05,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    Icons.description_rounded,
                                    color: context.pal.ink,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayTitle,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 17,
                                          color: context.pal.ink,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (note.body.isNotEmpty &&
                                          note.title.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                          ),
                                          child: Text(
                                            note.body,
                                            style: TextStyle(
                                              color: context.pal.muted,
                                              fontSize: 13,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 14,
                                  color: context.pal.subtle,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: ElevatedButton.icon(
            onPressed: _addNote,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.pal.ink,
              foregroundColor: context.pal.onInk,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.add_rounded),
            label: Text(
              'Yeni Not Oluştur'.tr(context),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _editNote(int index) async {
    if (index < 0 || index >= _notes.length) return;
    final note = _notes[index];
    final titleController = TextEditingController(text: note.title);
    final bodyController = TextEditingController(text: note.body);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Notu düzenle'.tr(context)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Başlık'.tr(context),
                    hintText: 'Not başlığı'.tr(context),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Not'.tr(context),
                    hintText: 'Notunu yaz...'.tr(context),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('delete'),
              child: Text(
                'Sil'.tr(context),
                style: TextStyle(color: context.pal.negative),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('cancel'),
              child: Text('Vazgeç'.tr(context)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop('save'),
              child: Text('Kaydet'.tr(context)),
            ),
          ],
        );
      },
    );

    if (result == 'delete') {
      if (mounted) {
        setState(() {
          _notes.removeAt(index);
        });
      }
      await _saveNotes();
    } else if (result == 'save') {
      setState(() {
        _notes[index] = _NoteItem(
          title: titleController.text.trim(),
          body: bodyController.text.trim(),
        );
      });
      await _saveNotes();
    }
  }
}

/// Sağdaki ayarlar ekranı
