part of 'settings_page.dart';

extension _SettingsPageSections on _SettingsPageState {
  /// Violet gradient header - same style as other pages.
  Widget _buildHeader() {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryStart, AppColors.primaryEnd],
        ),
        borderRadius: BorderRadius.only(
          bottomRight: Radius.circular(80),
        ),
      ),
      padding: const EdgeInsets.only(top: 56, left: 24),
      child: const Align(
        alignment: Alignment.topLeft,
        child: Text(
          'REGLAGES',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
