import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mysme/core/providers/providers.dart';
import 'package:mysme/core/theme/app_colors.dart';

void _linkCardLog(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

/// Gradient card displaying the user's unique anonymous link with copy action.
class LinkCard extends ConsumerStatefulWidget {
  const LinkCard({super.key});

  @override
  ConsumerState<LinkCard> createState() => _LinkCardState();
}

class _LinkCardState extends ConsumerState<LinkCard> {
  bool _linkRequested = false;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final linkState = ref.watch(linkProvider);
    final activeLink = linkState.activeLink;
    final isLoading = linkState.isLoading;
    final hasError = linkState.error != null;

    // Wait for auth to be ready, then fetch link once.
    if (auth.isAuthenticated &&
        !_linkRequested &&
        activeLink == null &&
        !isLoading) {
      _linkRequested = true;
      Future.microtask(() async {
        try {
          await ref.read(linkProvider.notifier).getOrCreateLink();
        } catch (e) {
          _linkCardLog('[LinkCard] getOrCreateLink failed: $e');
        }
      });
    }

    void copyLink() {
      if (activeLink == null) {
        return;
      }
      final url = activeLink.shareUrl(auth.pseudo ?? 'Anonyme');
      Clipboard.setData(ClipboardData(text: url));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lien copié !'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    final displayText = isLoading
        ? 'Chargement…'
        : hasError
            ? 'Erreur — appuie pour réessayer'
            : (activeLink?.displayLink ?? 'mysme.link/...').toUpperCase();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.deepPurple, AppColors.primaryStart],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryStart.withAlpha(80),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Copie ton lien et partage-le',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: hasError
                ? () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await ref.read(linkProvider.notifier).getOrCreateLink();
                    } catch (error) {
                      _linkCardLog(
                          '[LinkCard] retry getOrCreateLink failed: $error');
                      if (!mounted) return;
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Impossible de récupérer le lien'),
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                : copyLink,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              displayText,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: hasError
                                    ? Colors.red
                                    : AppColors.primaryStart,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            hasError
                                ? Icons.refresh_rounded
                                : Icons.copy_rounded,
                            color:
                                hasError ? Colors.red : AppColors.primaryStart,
                            size: 18,
                          ),
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
