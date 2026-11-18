import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mysme/core/providers/conversation_provider.dart';
import 'package:mysme/core/services/transfer_service.dart';
import 'package:mysme/core/utils/helpers.dart';

/// Claims a transfer code and refreshes the conversation list.
/// Returns a user-facing success message, or throws.
Future<String> claimWebTransfer(WidgetRef ref, String code) async {
  final result = await ref.read(transferServiceProvider).claim(code);
  await ref.read(conversationProvider.notifier).fetchAllSilently();
  final count = result.conversationIds.length;
  if (count == 0) return 'Session web récupérée.';
  return count == 1
      ? 'Ta conversation web est maintenant dans l\'app.'
      : 'Tes $count conversations web sont maintenant dans l\'app.';
}

/// "You started on the web?" dialog: type or paste the code shown by the PWA.
Future<void> showWebTransferDialog(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _WebTransferDialog(),
  );
}

class _WebTransferDialog extends ConsumerStatefulWidget {
  const _WebTransferDialog();

  @override
  ConsumerState<_WebTransferDialog> createState() => _WebTransferDialogState();
}

class _WebTransferDialogState extends ConsumerState<_WebTransferDialog> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final code = TransferService.extractCode(data?.text);
    if (!mounted) return;
    setState(() {
      if (code != null) {
        _controller.text = code;
        _error = null;
      } else {
        _error = 'Aucun code MystMe trouvé dans le presse-papier.';
      }
    });
  }

  Future<void> _submit() async {
    final code = TransferService.extractCode(_controller.text);
    if (code == null) {
      setState(() => _error = 'Le code ressemble à ABCD-2345.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final message = await claimWebTransfer(ref, code);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = Helpers.friendlyErrorMessage(
          error,
          fallback: 'Impossible de récupérer la conversation pour le moment.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Récupérer ma conversation web'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Saisis le code affiché sur la page web MystMe '
            '(il est aussi copié quand tu appuies sur « Télécharger l\'app »).',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            enabled: !_loading,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: 'ABCD-2345',
              errorText: _error,
              suffixIcon: IconButton(
                tooltip: 'Coller',
                icon: const Icon(Icons.content_paste_rounded),
                onPressed: _loading ? null : _paste,
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Récupérer'),
        ),
      ],
    );
  }
}
