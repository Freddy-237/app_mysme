part of 'splash_screen.dart';

extension _SplashScreenSections on _SplashScreenState {
  Widget _buildBody() {
    return Center(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo placeholder (purple circle + mask icon)
            Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF5A2EBE), Color(0xFF9B6DFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(
                Icons.masks_outlined,
                color: Colors.white,
                size: 56,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'MystMe',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5A2EBE),
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9B6DFF)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
