import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mysme/core/providers/providers.dart';
import 'package:mysme/core/theme/app_colors.dart';
import 'package:share_plus/share_plus.dart';

/// "Share with" section showing WhatsApp, Instagram, Snapchat icons.
class ShareWith extends ConsumerWidget {
  const ShareWith({super.key});

  Future<void> _shareGeneric(BuildContext context, WidgetRef ref) async {
    debugPrint('[ShareWith._shareGeneric] START');
    try {
      final link = await ref.read(linkProvider.notifier).getOrCreateLink();
      debugPrint('[ShareWith._shareGeneric] got link: ${link.code}');
      final auth = ref.read(authProvider);
      debugPrint('[ShareWith._shareGeneric] pseudo=${auth.pseudo}');
      final url = link.shareUrl(auth.pseudo ?? 'Anonyme');
      debugPrint('[ShareWith._shareGeneric] sharing URL: $url');
      final result =
          await Share.share('Envoie-moi un message anonyme sur MystMe ! $url');
      debugPrint('[ShareWith._shareGeneric] Share.share result: $result');
    } catch (e, st) {
      debugPrint('[ShareWith._shareGeneric] ERROR: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Share with',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryStart,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _SocialIcon(
                icon: FontAwesomeIcons.whatsapp,
                onTap: () => _shareGeneric(context, ref),
              ),
              const SizedBox(width: 16),
              _SocialIcon(
                icon: FontAwesomeIcons.instagram,
                onTap: () => _shareGeneric(context, ref),
              ),
              const SizedBox(width: 16),
              _SocialIcon(
                icon: FontAwesomeIcons.snapchat,
                onTap: () => _shareGeneric(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A single social media icon inside a rounded purple square.
class _SocialIcon extends StatelessWidget {
  const _SocialIcon({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryStart, AppColors.deepPurple],
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: FaIcon(
            icon,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }
}
