import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mysme/core/providers/providers.dart';
import 'package:mysme/core/theme/app_colors.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

void _shareWithLog(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

class _ShareChannel {
  const _ShareChannel({
    required this.label,
    required this.icon,
    required this.accent,
    required this.composeMessage,
  });

  final String label;
  final FaIconData icon;
  final Color accent;
  final String Function(String pseudo, String url) composeMessage;
}

/// "Share with" section showing WhatsApp, Instagram, Snapchat icons.
class ShareWith extends ConsumerStatefulWidget {
  const ShareWith({super.key});

  @override
  ConsumerState<ShareWith> createState() => _ShareWithState();
}

class _ShareWithState extends ConsumerState<ShareWith> {
  String? _sharingChannelLabel;

  static const _channels = <_ShareChannel>[
    _ShareChannel(
      label: 'WhatsApp',
      icon: FontAwesomeIcons.whatsapp,
      accent: Color(0xFF25D366),
      composeMessage: _composeWhatsAppMessage,
    ),
    _ShareChannel(
      label: 'Instagram',
      icon: FontAwesomeIcons.instagram,
      accent: Color(0xFFE1306C),
      composeMessage: _composeInstagramMessage,
    ),
    _ShareChannel(
      label: 'Snapchat',
      icon: FontAwesomeIcons.snapchat,
      accent: Color(0xFFFFFC00),
      composeMessage: _composeSnapchatMessage,
    ),
  ];

  static String _composeWhatsAppMessage(String pseudo, String url) {
    return 'Salut, envoie-moi un message anonyme sur MystMe. '
        'Clique ici pour me répondre: $url';
  }

  static String _composeInstagramMessage(String pseudo, String url) {
    return 'Ajoute ce lien en story ou en bio pour recevoir des messages '
        'anonymes sur MystMe: $url';
  }

  static String _composeSnapchatMessage(String pseudo, String url) {
    return 'Pose-moi une question anonyme sur MystMe: $url';
  }

  Future<void> _shareForChannel(_ShareChannel channel) async {
    if (_sharingChannelLabel != null) return;

    final activeChannelLabel = channel.label;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sharingChannelLabel = activeChannelLabel);

    try {
      final link = await ref.read(linkProvider.notifier).getOrCreateLink();
      final auth = ref.read(authProvider);
      final pseudo = auth.pseudo ?? 'Anonyme';
      final url = link.shareUrl(pseudo);
      final message = channel.composeMessage(pseudo, url);

      _shareWithLog('[ShareWith] sharing via ${channel.label}');
      final openedDirectly = await _openChannelApp(channel.label, message);
      if (!openedDirectly) {
        final result = await Share.share(
          message,
          subject: 'MystMe • $pseudo',
        );

        if (!mounted) return;
        final feedback = switch (result.status) {
          ShareResultStatus.success => 'Partage ${channel.label} prêt',
          ShareResultStatus.dismissed => 'Partage annulé',
          ShareResultStatus.unavailable =>
            'Partage indisponible pour le moment',
        };
        messenger.showSnackBar(
          SnackBar(
            content: Text(feedback),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        final openMessage = switch (channel.label) {
          'Instagram' => 'Instagram ouvert ; lien copié pour story',
          'Snapchat' => 'Snapchat ouvert ; lien copié pour story',
          _ => '${channel.label} ouvert',
        };

        messenger.showSnackBar(
          SnackBar(
            content: Text(openMessage),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (error) {
      _shareWithLog('[ShareWith] share failed for ${channel.label}: $error');
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Impossible de préparer le partage'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted && _sharingChannelLabel == activeChannelLabel) {
        setState(() => _sharingChannelLabel = null);
      }
    }
  }

  Future<bool> _openChannelApp(String label, String message) async {
    late final Uri uri;

    switch (label) {
      case 'WhatsApp':
        uri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(message)}');
        break;
      case 'Instagram':
        await Clipboard.setData(ClipboardData(text: message));
        uri = Uri.parse('instagram://story-camera');
        break;
      case 'Snapchat':
        await Clipboard.setData(ClipboardData(text: message));
        uri = Uri.parse('snapchat://camera');
        break;
      default:
        return false;
    }

    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
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
          const SizedBox(height: 4),
          const Text(
            'Texte adapté selon le canal et feedback après partage',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: _channels
                .map(
                  (channel) => Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: _SocialIcon(
                      label: channel.label,
                      icon: channel.icon,
                      accent: channel.accent,
                      isLoading: _sharingChannelLabel == channel.label,
                      onTap: _sharingChannelLabel == null
                          ? () => _shareForChannel(channel)
                          : null,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

/// A single social media icon inside a rounded purple square.
class _SocialIcon extends StatelessWidget {
  const _SocialIcon({
    required this.label,
    required this.icon,
    required this.accent,
    required this.isLoading,
    required this.onTap,
  });

  final String label;
  final FaIconData icon;
  final Color accent;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accent, AppColors.deepPurple],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : FaIcon(
                      icon,
                      color: Colors.white,
                      size: 26,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
