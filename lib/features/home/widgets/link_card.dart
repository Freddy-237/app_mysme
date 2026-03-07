import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mysme/core/providers/providers.dart';
import 'package:mysme/core/theme/app_colors.dart';

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

    debugPrint('[LinkCard.build] auth.isAuthenticated=${auth.isAuthenticated}, '
        'activeLink=${activeLink?.code}, isLoading=$isLoading, '
        'hasError=$hasError, error=${linkState.error}, _linkRequested=$_linkRequested');

    // Wait for auth to be ready, then fetch link once.
    if (auth.isAuthenticated &&
        !_linkRequested &&
        activeLink == null &&
        !isLoading) {
      _linkRequested = true;
      debugPrint('[LinkCard] triggering getOrCreateLink (first time)');
      Future.microtask(() async {
        try {
          await ref.read(linkProvider.notifier).getOrCreateLink();
          debugPrint('[LinkCard] getOrCreateLink completed OK');
        } catch (e) {
          debugPrint('[LinkCard] getOrCreateLink FAILED: $e');
        }
      });
    }

    void copyLink() {
      if (activeLink == null) {
        debugPrint('[LinkCard.copyLink] activeLink is null — abort');
        return;
      }
      final url = activeLink.shareUrl(auth.pseudo ?? 'Anonyme');
      debugPrint('[LinkCard.copyLink] copying URL to clipboard: $url');
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
                    try {
                      await ref.read(linkProvider.notifier).getOrCreateLink();
                    } catch (_) {}
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
