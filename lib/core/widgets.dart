import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'api_client.dart';

/// Loads a list from the API and shows it with pull-to-refresh, a spinner,
/// an error with retry, or [emptyText] when there is nothing to show.
class AsyncList<T> extends StatefulWidget {
  const AsyncList({
    super.key,
    required this.load,
    required this.itemBuilder,
    required this.emptyText,
    this.emptyIcon = Icons.inbox_rounded,
  });

  final Future<List<T>> Function() load;
  final Widget Function(BuildContext context, T item, VoidCallback reload)
  itemBuilder;
  final String emptyText;
  final IconData emptyIcon;

  @override
  State<AsyncList<T>> createState() => AsyncListState<T>();
}

class AsyncListState<T> extends State<AsyncList<T>> {
  late Future<List<T>> _future = widget.load();

  void reload() => setState(() => _future = widget.load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<T>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return MessageView(
            icon: Icons.cloud_off_rounded,
            text: snapshot.error.toString(),
            action: FilledButton(
              onPressed: reload,
              child: const Text('TEKRAR DENE'),
            ),
          );
        }
        final items = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async => reload(),
          child: items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 80),
                    MessageView(icon: widget.emptyIcon, text: widget.emptyText),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) =>
                      widget.itemBuilder(context, items[i], reload),
                ),
        );
      },
    );
  }
}

class MessageView extends StatelessWidget {
  const MessageView({
    super.key,
    required this.icon,
    required this.text,
    this.action,
  });

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TintedIcon(icon, color: AppColors.textMuted, size: 72),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 15),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// Slate card row used by all management lists.
class InfoTile extends StatelessWidget {
  const InfoTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: TintedIcon(icon, color: color, size: 46),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                style: const TextStyle(color: AppColors.textMuted),
              ),
        trailing: trailing,
      ),
    );
  }
}

/// Coloured pill showing an appointment status.
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final String status;

  static (String, Color) describe(String status) => switch (status) {
    'Pending' => ('Onay bekliyor', AppColors.warning),
    'Approved' => ('Onaylandı', AppColors.primary),
    'Completed' => ('Tamamlandı', AppColors.success),
    'Cancelled' => ('İptal edildi', AppColors.textMuted),
    'NoShow' => ('Gelmedi', AppColors.danger),
    _ => (status, AppColors.textMuted),
  };

  @override
  Widget build(BuildContext context) {
    final (label, color) = describe(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Runs [action], showing its error (or [success]) in a snackbar. Returns whether it succeeded.
Future<bool> runWithFeedback(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    if (success != null) {
      messenger.showSnackBar(SnackBar(content: Text(success)));
    }
    return true;
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Hata: $e')));
  }
  return false;
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String message, {
  String ok = 'TAMAM',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(
        message,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.surfaceHigh),
          onPressed: () => Navigator.pop(context, false),
          child: const Text('İPTAL'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// "25.10.2026 14:30" in local time.
String formatDateTime(String iso) {
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return iso;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
}

/// Section scaffold for a role panel: dark app bar with a sign-out button.
class PanelScaffold extends StatelessWidget {
  const PanelScaffold({
    super.key,
    required this.title,
    required this.body,
    this.onSignOut,
    this.floatingActionButton,
  });

  final String title;
  final Widget body;
  final VoidCallback? onSignOut;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (onSignOut != null)
            IconButton(
              tooltip: 'Çıkış yap',
              icon: const Icon(Icons.power_settings_new_rounded),
              onPressed: onSignOut,
            ),
        ],
      ),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}
