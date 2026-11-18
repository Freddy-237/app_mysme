import 'package:flutter/material.dart';
import 'package:mysme/core/theme/app_colors.dart';

/// Shown instead of the input bar once a conversation is blocked
/// (by either participant): nobody can write in it any more.
class ChatBlockedBanner extends StatelessWidget {
  const ChatBlockedBanner({super.key, required this.bottomPadding});

  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + bottomPadding),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: const Row(
        children: [
          Icon(Icons.block, color: AppColors.textSecondary, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Discussion bloquée. Plus personne ne peut y écrire.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
