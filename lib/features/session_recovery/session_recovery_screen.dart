import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mysme/core/providers/providers.dart';
import 'package:mysme/core/utils/helpers.dart';

part 'session_recovery_screen_dialogs.dart';
part 'session_recovery_screen_sections.dart';

class SessionRecoveryScreen extends ConsumerStatefulWidget {
  const SessionRecoveryScreen({super.key});

  @override
  ConsumerState<SessionRecoveryScreen> createState() =>
      _SessionRecoveryScreenState();
}

class _SessionRecoveryScreenState extends ConsumerState<SessionRecoveryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _buildBody(),
    );
  }
}
