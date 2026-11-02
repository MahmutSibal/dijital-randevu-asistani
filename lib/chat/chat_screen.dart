import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import 'assistant_client.dart';

const _suggestions = [
  'Randevu nasıl alırım?',
  'Randevumu nasıl iptal ederim?',
  'Hangi hastane ve bölümler var?',
];

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _client = AssistantClient(baseUrl: defaultApiBaseUrl);
  final _messages = <ChatMessage>[];
  final _input = TextEditingController();
  final _scroll = ScrollController();

  StreamSubscription<ChatChunk>? _subscription;
  bool _streaming = false;
  String? _model;

  /// "Detaylı düşün": the model reasons first. Off by default since it takes about a minute.
  bool _think = false;

  void _toggleThink() {
    setState(() => _think = !_think);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            _think
                ? 'Detaylı düşünme açık: cevaplar daha uzun sürer.'
                : 'Hızlı mod: cevaplar birkaç saniyede gelir.',
          ),
        ),
      );
  }

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      final model = await _client.fetchModel();
      if (mounted) setState(() => _model = model);
    } catch (_) {
      if (mounted) setState(() => _model = null);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _client.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// A photo waiting to be sent with the next message.
  Uint8List? _photo;

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => const _PhotoSourceSheet(),
    );
    if (source == null) return;
    try {
      // Downscaled: enough to read a document, small enough to send quickly.
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() => _photo = bytes);
    } catch (e) {
      _showError('Fotoğraf alınamadı: $e');
    }
  }

  void _send([String? suggestion]) {
    final photo = _photo;
    var text = (suggestion ?? _input.text).trim();
    if (text.isEmpty && photo != null) text = 'Bu belgeyi oku ve özetle.';
    if (text.isEmpty || _streaming) return;

    final reply = ChatMessage(role: 'assistant');
    setState(() {
      _messages.add(
        ChatMessage(
          role: 'user',
          content: text,
          images: photo == null ? const [] : [photo],
        ),
      );
      _input.clear();
      _photo = null;
      _streaming = true;
    });
    // History sent to the backend excludes the empty assistant placeholder.
    final history = List<ChatMessage>.of(_messages);
    setState(() => _messages.add(reply));
    _scrollToEnd();

    _subscription = _client
        .chat(history, think: _think)
        .listen(
          (chunk) {
            setState(() {
              reply.thinking += chunk.thinking;
              reply.content += chunk.content;
              reply.fromCache |= chunk.cached;
            });
            _scrollToEnd();
          },
          onError: (Object e) {
            setState(() {
              _streaming = false;
              if (reply.content.isEmpty && reply.thinking.isEmpty) {
                _messages.remove(reply);
              }
            });
            _showError(e.toString());
          },
          onDone: () => setState(() => _streaming = false),
          cancelOnError: true,
        );
  }

  void _stop() {
    _subscription?.cancel();
    _client.cancel();
    setState(() => _streaming = false);
  }

  void _clear() {
    _stop();
    setState(_messages.clear);
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Hata: $message')));
  }

  Future<void> _editSettings() async {
    final urlController = TextEditingController(text: _client.baseUrl);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sunucu ayarları'),
        content: TextField(
          controller: urlController,
          decoration: const InputDecoration(labelText: 'API adresi'),
          keyboardType: TextInputType.url,
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.surfaceHigh,
            ),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İPTAL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('KAYDET'),
          ),
        ],
      ),
    );
    if (saved == true) {
      setState(() => _client.baseUrl = urlController.text.trim());
      _loadModel();
    }
    urlController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Asistan'),
            Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 9,
                  color: _model == null ? AppColors.danger : AppColors.success,
                ),
                const SizedBox(width: 6),
                Text(
                  _model ?? 'Sunucuya bağlanılamadı',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Detaylı düşün',
            isSelected: _think,
            icon: const Icon(Icons.psychology_outlined),
            selectedIcon: const Icon(
              Icons.psychology_rounded,
              color: AppColors.warning,
            ),
            onPressed: _streaming ? null : _toggleThink,
          ),
          IconButton(
            tooltip: 'Sohbeti temizle',
            icon: const Icon(Icons.delete_outline),
            onPressed: _messages.isEmpty ? null : _clear,
          ),
          IconButton(
            tooltip: 'Ayarlar',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _editSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _EmptyChat(onSuggestion: _send, onPhoto: _pickPhoto)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) => _MessageBubble(
                      message: _messages[i],
                      streaming: _streaming && i == _messages.length - 1,
                    ),
                  ),
          ),
          const Divider(),
          if (_photo != null)
            _PhotoDraft(
              photo: _photo!,
              onRemove: () => setState(() => _photo = null),
              onAction: _send,
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Fotoğraf veya belge ekle',
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    color: AppColors.primary,
                    iconSize: 28,
                    onPressed: _streaming ? null : _pickPhoto,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: _photo == null
                            ? 'Mesajınızı yazın…'
                            : 'Fotoğrafla ilgili sorunuz…',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: AppColors.divider,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: AppColors.divider,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _RoundButton(
                    tooltip: _streaming ? 'Durdur' : 'Gönder',
                    icon: _streaming ? Icons.stop_rounded : Icons.send_rounded,
                    onPressed: _streaming ? _stop : _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _photoActions = [
  (
    Icons.receipt_long_rounded,
    'Reçetemi oku',
    'Bu reçeteyi oku: ilaçları, nasıl kullanılacaklarını ve varsa kontrol randevusunu yaz.',
  ),
  (
    Icons.science_rounded,
    'Tahlili açıkla',
    'Bu tahlil sonucundaki değerleri oku, referans aralığı dışında olanları belirt.',
  ),
  (
    Icons.event_note_rounded,
    'Randevu kâğıdı',
    'Bu belgedeki randevu bilgilerini (tarih, saat, bölüm, doktor) oku.',
  ),
  (
    Icons.local_hospital_rounded,
    'Hangi bölüm?',
    'Bu fotoğraftaki şikâyetim için hangi bölümden randevu almalıyım?',
  ),
];

/// Choose camera or gallery.
class _PhotoSourceSheet extends StatelessWidget {
  const _PhotoSourceSheet();

  @override
  Widget build(BuildContext context) {
    Widget option(
      IconData icon,
      Color color,
      String title,
      String subtitle,
      ImageSource source,
    ) => ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      leading: TintedIcon(icon, color: color, size: 46),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.textMuted),
      ),
      onTap: () => Navigator.pop(context, source),
    );

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 20, 24, 4),
            child: Text(
              'Fotoğraf veya belge ekle',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              'Reçete, tahlil sonucu, rapor veya randevu kâğıdı gönderebilirsiniz.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          option(
            Icons.photo_camera_rounded,
            AppColors.primary,
            'Fotoğraf çek',
            'Belgeyi düz ve aydınlık bir yerde çekin',
            ImageSource.camera,
          ),
          option(
            Icons.photo_library_rounded,
            const Color(0xFFA78BFA),
            'Galeriden seç',
            'Telefonunuzdaki bir fotoğrafı seçin',
            ImageSource.gallery,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// The picked photo above the message field, with one-tap requests about it.
class _PhotoDraft extends StatelessWidget {
  const _PhotoDraft({
    required this.photo,
    required this.onRemove,
    required this.onAction,
  });

  final Uint8List photo;
  final VoidCallback onRemove;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(
                  photo,
                  width: 72,
                  height: 92,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: -8,
                right: -8,
                child: Material(
                  color: AppColors.surfaceHigh,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onRemove,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close_rounded, size: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (icon, label, prompt) in _photoActions)
                  ActionChip(
                    avatar: Icon(icon, size: 18, color: AppColors.primary),
                    label: Text(label),
                    backgroundColor: AppColors.surface,
                    onPressed: () => onAction(prompt),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.onSuggestion, required this.onPhoto});

  final ValueChanged<String> onSuggestion;
  final VoidCallback onPhoto;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              gradient: AppGradients.primary,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.indigo.withValues(alpha: 0.45),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 42,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Size nasıl yardımcı olabilirim?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Randevular ve sağlık hizmetleriyle ilgili sorularınızı yazın.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: AppColors.textMuted),
        ),
        const SizedBox(height: 28),
        // Gradient-bordered card inviting a photo of a document.
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(1.2),
          decoration: BoxDecoration(
            gradient: AppGradients.primary,
            borderRadius: BorderRadius.circular(AppRadius.card + 1),
          ),
          child: Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPhoto,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    TintedIcon(
                      Icons.document_scanner_rounded,
                      color: AppColors.cyan,
                      size: 48,
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Belge veya fotoğraf gönder',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15.5,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Reçete, tahlil sonucu veya randevu kâğıdınızı okuyup özetleyeyim.',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.add_a_photo_rounded, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ),
        ),
        for (final s in _suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                leading: const TintedIcon(
                  Icons.lightbulb_outline_rounded,
                  color: AppColors.primary,
                  size: 38,
                ),
                title: Text(
                  s,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: const Icon(
                  Icons.north_east_rounded,
                  color: AppColors.textMuted,
                  size: 18,
                ),
                onTap: () => onSuggestion(s),
              ),
            ),
          ),
      ],
    );
  }
}

/// Round gradient icon button next to the message field.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(gradient: AppGradients.primary),
          child: InkWell(
            onTap: onPressed,
            child: Icon(icon, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.streaming});

  final ChatMessage message;
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final answering = message.content.isNotEmpty;

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * (isUser ? 0.8 : 0.74),
      ),
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: isUser ? AppGradients.primary : null,
        color: isUser ? null : AppColors.surface,
        border: isUser ? null : Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isUser ? 20 : 6),
          bottomRight: Radius.circular(isUser ? 6 : 20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.fromCache)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt_rounded, size: 16, color: AppColors.warning),
                  SizedBox(width: 4),
                  Text(
                    'Kayıtlı cevap',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          if (message.thinking.isNotEmpty)
            _ThinkingSection(
              thinking: message.thinking,
              // Open while reasoning streams in, collapse once the answer starts.
              active: streaming && !answering,
            ),
          for (final image in message.images)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    backgroundColor: Colors.black,
                    insetPadding: const EdgeInsets.all(12),
                    child: InteractiveViewer(child: Image.memory(image)),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.memory(image, height: 220, fit: BoxFit.cover),
                ),
              ),
            ),
          if (answering && isUser)
            SelectableText(
              message.content,
              style: const TextStyle(fontSize: 15, height: 1.4),
            )
          else if (answering)
            _MarkdownAnswer(message.content)
          else if (streaming && message.thinking.isEmpty)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );

    if (isUser) return Align(alignment: Alignment.centerRight, child: bubble);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(right: 8, bottom: 6),
          decoration: const BoxDecoration(
            gradient: AppGradients.primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: 17,
          ),
        ),
        Flexible(child: bubble),
      ],
    );
  }
}

/// Assistant answer rendered as markdown (bold, lists, headings, code, links).
class _MarkdownAnswer extends StatelessWidget {
  const _MarkdownAnswer(this.data);

  final String data;

  Future<void> _openLink(BuildContext context, String? href) async {
    final uri = href == null ? null : Uri.tryParse(href);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Bağlantı açılamadı: $href')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyMedium!
        .copyWith(color: Colors.white, height: 1.45);
    return MarkdownBody(
      data: data,
      selectable: true,
      onTapLink: (text, href, title) => _openLink(context, href),
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: base,
        listBullet: base,
        strong: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        a: const TextStyle(
          color: AppColors.primary,
          decoration: TextDecoration.underline,
        ),
        h1: base.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
        h2: base.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
        h3: base.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
        code: base.copyWith(
          fontFamily: 'monospace',
          backgroundColor: AppColors.surfaceHigh,
        ),
        codeblockDecoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(6),
        ),
        blockquoteDecoration: const BoxDecoration(
          border: Border(left: BorderSide(color: AppColors.primary, width: 3)),
        ),
        horizontalRuleDecoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
      ),
    );
  }
}

class _ThinkingSection extends StatefulWidget {
  const _ThinkingSection({required this.thinking, required this.active});

  final String thinking;
  final bool active;

  @override
  State<_ThinkingSection> createState() => _ThinkingSectionState();
}

class _ThinkingSectionState extends State<_ThinkingSection> {
  late bool _expanded = widget.active;

  @override
  void didUpdateWidget(_ThinkingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active && !widget.active) _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontStyle: FontStyle.italic,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.psychology_outlined, size: 16, color: muted?.color),
                const SizedBox(width: 4),
                Text(
                  widget.active ? 'Düşünüyor…' : 'Düşünce süreci',
                  style: muted,
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: muted?.color,
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: theme.dividerColor, width: 2),
              ),
            ),
            child: Text(widget.thinking, style: muted),
          ),
      ],
    );
  }
}
