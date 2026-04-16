import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// ──────────────────────────────────────────────────────────────────────────
/// AestheticDialogs
/// ──────────────────────────────────────────────────────────────────────────
/// Centralised helper for the app's styled popup dialogs.
///
/// All dialogs share:
///   • rounded corners (borderRadius: 20)
///   • white background
///   • subtle drop shadow
///   • Wayture red accent (#E53935)
///
/// Auto-dismiss dialogs close themselves after a short delay; action dialogs
/// expose a button and return control when the user taps it.
/// ──────────────────────────────────────────────────────────────────────────
class AestheticDialogs {
  AestheticDialogs._();

  static const Color wayRed = Color(0xFFE53935);
  static const Color wayGreen = Color(0xFF2E7D32);
  static const Color wayBlue = Color(0xFF1E88E5);
  static const Color wayOrange = Color(0xFFFB8C00);
  static const Color wayGrey = Color(0xFF616161);

  // ─── Public API ───────────────────────────────────────────────────────────

  /// ✅ Login success — auto-dismiss after 2 seconds.
  static Future<void> showLoginSuccess(BuildContext context) {
    return _showAutoDismiss(
      context: context,
      icon: const _AnimatedCheck(color: wayGreen),
      title: 'Welcome Back!',
      subtitle: 'You are now logged in successfully.',
      accent: wayGreen,
    );
  }

  /// ✅ Register success — "Get Started" button.
  static Future<void> showRegisterSuccess(
    BuildContext context, {
    VoidCallback? onContinue,
  }) {
    return _showActionDialog(
      context: context,
      icon: const _ConfettiBurst(),
      title: 'Account Created!',
      subtitle: "Welcome to KTM Traffic. Let's find your route.",
      buttonText: 'Get Started',
      accent: wayRed,
      onPressed: onContinue,
    );
  }

  /// 🔔 Permission granted — auto-dismiss after 2 seconds.
  static Future<void> showPermissionGranted(BuildContext context) {
    return _showAutoDismiss(
      context: context,
      icon: const _AnimatedCheck(color: wayBlue),
      title: 'Permissions Enabled!',
      subtitle: 'You will now receive live traffic alerts.',
      accent: wayBlue,
    );
  }

  /// ⚠️ No internet — "Retry" button.
  static Future<void> showNoInternet(
    BuildContext context, {
    VoidCallback? onRetry,
  }) {
    return _showActionDialog(
      context: context,
      icon: const _WarningIcon(),
      title: 'No Connection',
      subtitle: 'Please check your internet to get live traffic updates.',
      buttonText: 'Retry',
      accent: wayOrange,
      onPressed: onRetry,
    );
  }

  /// 🚨 Heavy traffic detected — "Show Routes" button.
  static Future<void> showHeavyTraffic(
    BuildContext context, {
    VoidCallback? onShowRoutes,
  }) {
    return _showActionDialog(
      context: context,
      icon: const _BlinkingDot(),
      title: 'Heavy Traffic Detected!',
      subtitle: 'Alternative routes are available. Tap to view.',
      buttonText: 'Show Routes',
      accent: wayRed,
      onPressed: onShowRoutes,
    );
  }

  /// 💾 Route saved — auto-dismiss after 2 seconds.
  static Future<void> showRouteSaved(BuildContext context) {
    return _showAutoDismiss(
      context: context,
      icon: const _BookmarkPop(),
      title: 'Route Saved!',
      subtitle: 'This route has been saved to your history.',
      accent: wayRed,
    );
  }

  /// 📍 Location found — auto-dismiss after 2 seconds with checkmark.
  static Future<void> showLocationFound(BuildContext context) {
    return _showAutoDismiss(
      context: context,
      icon: const _AnimatedCheck(color: wayGreen),
      title: 'Location Found',
      subtitle: 'Your GPS position has been located.',
      accent: wayGreen,
    );
  }

  // ─── Location error dialogs ───────────────────────────────────────────────

  /// 🛰️ GPS service disabled — red dialog with "Open Settings" button.
  static Future<void> showGpsDisabled(
    BuildContext context, {
    VoidCallback? onOpenSettings,
  }) {
    return _showActionDialog(
      context: context,
      icon: const _GpsDisabledIcon(),
      title: 'GPS Disabled',
      subtitle: 'Please enable location services to use this feature.',
      buttonText: 'Open Settings',
      accent: wayRed,
      onPressed: onOpenSettings,
    );
  }

  /// 📍 Location permission denied — orange dialog with "Allow" button.
  static Future<void> showLocationPermissionDenied(
    BuildContext context, {
    VoidCallback? onAllow,
  }) {
    return _showActionDialog(
      context: context,
      icon: const _LocationDeniedIcon(),
      title: 'Location Permission Required',
      subtitle: 'Allow location access to get accurate traffic near you.',
      buttonText: 'Allow',
      accent: wayOrange,
      onPressed: onAllow,
    );
  }

  /// ⏱️ GPS fix timed out — grey dialog with "Retry" button.
  static Future<void> showLocationTimeout(
    BuildContext context, {
    VoidCallback? onRetry,
  }) {
    return _showActionDialog(
      context: context,
      icon: const _LocationTimeoutIcon(),
      title: 'Could not get location',
      subtitle: 'Please check your GPS signal.',
      buttonText: 'Retry',
      accent: wayGrey,
      onPressed: onRetry,
    );
  }

  // ─── Internal builders ────────────────────────────────────────────────────

  static Future<void> _showAutoDismiss({
    required BuildContext context,
    required Widget icon,
    required String title,
    required String subtitle,
    required Color accent,
    Duration duration = const Duration(seconds: 2),
  }) async {
    Timer? dismissTimer;
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: title,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, _, _) {
        dismissTimer = Timer(duration, () {
          if (Navigator.of(ctx, rootNavigator: true).canPop()) {
            Navigator.of(ctx, rootNavigator: true).pop();
          }
        });
        return _DialogShell(
          icon: icon,
          title: title,
          subtitle: subtitle,
          accent: accent,
        );
      },
      transitionBuilder: _scaleFadeTransition,
    );
    dismissTimer?.cancel();
  }

  static Future<void> _showActionDialog({
    required BuildContext context,
    required Widget icon,
    required String title,
    required String subtitle,
    required String buttonText,
    required Color accent,
    VoidCallback? onPressed,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: title,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, _, _) => _DialogShell(
        icon: icon,
        title: title,
        subtitle: subtitle,
        accent: accent,
        button: _DialogButton(
          label: buttonText,
          color: accent,
          onPressed: () {
            Navigator.of(ctx, rootNavigator: true).pop();
            onPressed?.call();
          },
        ),
      ),
      transitionBuilder: _scaleFadeTransition,
    );
  }

  static Widget _scaleFadeTransition(
    BuildContext context,
    Animation<double> anim,
    Animation<double> secondary,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
    return FadeTransition(
      opacity: anim,
      child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(curved), child: child),
    );
  }
}

// ─── Shared shell ────────────────────────────────────────────────────────────

class _DialogShell extends StatelessWidget {
  final Widget icon;
  final String title;
  final String subtitle;
  final Color accent;
  final Widget? button;

  const _DialogShell({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    this.button,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          constraints: const BoxConstraints(maxWidth: 340),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(38),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 72, width: 72, child: icon),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF666666),
                  height: 1.4,
                ),
              ),
              if (button != null) ...[
                const SizedBox(height: 20),
                button!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _DialogButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ─── Animated icons ──────────────────────────────────────────────────────────

/// Circular badge with an animated drawn checkmark.
class _AnimatedCheck extends StatefulWidget {
  final Color color;
  const _AnimatedCheck({required this.color});

  @override
  State<_AnimatedCheck> createState() => _AnimatedCheckState();
}

class _AnimatedCheckState extends State<_AnimatedCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        return Container(
          decoration: BoxDecoration(
            color: widget.color.withAlpha(30),
            shape: BoxShape.circle,
          ),
          child: CustomPaint(
            painter: _CheckPainter(progress: _c.value, color: widget.color),
          ),
        );
      },
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double progress;
  final Color color;
  _CheckPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final p1 = Offset(size.width * 0.25, size.height * 0.52);
    final p2 = Offset(size.width * 0.44, size.height * 0.70);
    final p3 = Offset(size.width * 0.76, size.height * 0.36);

    if (progress <= 0.5) {
      final t = progress / 0.5;
      canvas.drawLine(p1, Offset.lerp(p1, p2, t)!, paint);
    } else {
      canvas.drawLine(p1, p2, paint);
      final t = (progress - 0.5) / 0.5;
      canvas.drawLine(p2, Offset.lerp(p2, p3, t)!, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CheckPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Bright burst of confetti particles behind a central celebration icon.
class _ConfettiBurst extends StatefulWidget {
  const _ConfettiBurst();

  @override
  State<_ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<_ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  final List<_Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    final rnd = math.Random(7);
    const palette = [
      AestheticDialogs.wayRed,
      Color(0xFFFFC107),
      Color(0xFF42A5F5),
      Color(0xFF66BB6A),
      Color(0xFFAB47BC),
    ];
    for (var i = 0; i < 16; i++) {
      _particles.add(_Particle(
        angle: rnd.nextDouble() * math.pi * 2,
        distance: 20 + rnd.nextDouble() * 16,
        color: palette[rnd.nextInt(palette.length)],
        size: 3 + rnd.nextDouble() * 3,
      ));
    }
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        return CustomPaint(
          painter: _ConfettiPainter(progress: _c.value, particles: _particles),
          child: Center(
            child: Transform.scale(
              scale: Curves.easeOutBack.transform(_c.value.clamp(0.0, 1.0)),
              child: Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: AestheticDialogs.wayRed,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.celebration, color: Colors.white, size: 28),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Particle {
  final double angle;
  final double distance;
  final Color color;
  final double size;
  _Particle({
    required this.angle,
    required this.distance,
    required this.color,
    required this.size,
  });
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<_Particle> particles;
  _ConfettiPainter({required this.progress, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final t = Curves.easeOut.transform(progress);
    for (final p in particles) {
      final dx = math.cos(p.angle) * p.distance * t;
      final dy = math.sin(p.angle) * p.distance * t;
      final paint = Paint()..color = p.color.withAlpha((255 * (1 - progress * 0.4)).round());
      canvas.drawCircle(center + Offset(dx, dy), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Soft pulsing orange warning triangle.
class _WarningIcon extends StatefulWidget {
  const _WarningIcon();

  @override
  State<_WarningIcon> createState() => _WarningIconState();
}

class _WarningIconState extends State<_WarningIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final scale = 0.95 + 0.1 * _c.value;
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AestheticDialogs.wayOrange.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AestheticDialogs.wayOrange,
                size: 40,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Red blinking dot used for critical traffic alerts.
class _BlinkingDot extends StatefulWidget {
  const _BlinkingDot();

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final t = _c.value;
          return SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Expanding ring
                Container(
                  width: 40 + 32 * t,
                  height: 40 + 32 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AestheticDialogs.wayRed
                          .withAlpha(((1 - t) * 180).round()),
                      width: 2,
                    ),
                  ),
                ),
                // Core dot — blinks opacity
                Opacity(
                  opacity: 0.55 + 0.45 * (0.5 + 0.5 * math.sin(t * math.pi * 2)),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AestheticDialogs.wayRed,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.traffic, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Bookmark icon that pops in with an elastic scale.
class _BookmarkPop extends StatefulWidget {
  const _BookmarkPop();

  @override
  State<_BookmarkPop> createState() => _BookmarkPopState();
}

class _BookmarkPopState extends State<_BookmarkPop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final scale = Curves.elasticOut.transform(_c.value.clamp(0.0, 1.0));
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AestheticDialogs.wayRed.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bookmark_added_rounded,
                color: AestheticDialogs.wayRed,
                size: 36,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Red location-off icon with a soft pulse — used when GPS is disabled.
class _GpsDisabledIcon extends StatefulWidget {
  const _GpsDisabledIcon();

  @override
  State<_GpsDisabledIcon> createState() => _GpsDisabledIconState();
}

class _GpsDisabledIconState extends State<_GpsDisabledIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final scale = 0.95 + 0.08 * _c.value;
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AestheticDialogs.wayRed.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_off_rounded,
                color: AestheticDialogs.wayRed,
                size: 38,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Orange location-disabled icon — used when permission is denied.
class _LocationDeniedIcon extends StatelessWidget {
  const _LocationDeniedIcon();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AestheticDialogs.wayOrange.withAlpha(30),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.location_disabled_rounded,
          color: AestheticDialogs.wayOrange,
          size: 38,
        ),
      ),
    );
  }
}

/// Grey searching-for-signal icon — used when the GPS fix times out.
class _LocationTimeoutIcon extends StatefulWidget {
  const _LocationTimeoutIcon();

  @override
  State<_LocationTimeoutIcon> createState() => _LocationTimeoutIconState();
}

class _LocationTimeoutIconState extends State<_LocationTimeoutIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          return Transform.rotate(
            angle: _c.value * math.pi * 2,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AestheticDialogs.wayGrey.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.gps_not_fixed_rounded,
                color: AestheticDialogs.wayGrey,
                size: 38,
              ),
            ),
          );
        },
      ),
    );
  }
}
