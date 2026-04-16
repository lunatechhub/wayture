import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_theme.dart';

/// ──────────────────────────────────────────────────────────────────────────
/// AppDialog
/// ──────────────────────────────────────────────────────────────────────────
/// Single reusable dialog widget used across the whole app. Provides five
/// named factories — [AppDialog.success], [AppDialog.warning],
/// [AppDialog.traffic], [AppDialog.error], [AppDialog.info] — each of which
/// opens a styled dialog that matches the Wayture design system:
///
///   • white background, 20-radius rounded corners, soft black shadow
///   • 56x56 colored icon circle
///   • Poppins Bold 18sp title, Poppins Regular 14sp body
///   • 48-tall full-width primary button with 12-radius
///   • optional secondary `Dismiss` button
///   • optional [autoDismiss] — dialog closes itself after 2 seconds
///
/// Any screen that previously constructed its own custom dialog should call
/// one of these factories instead, so the visual language stays consistent.
/// ──────────────────────────────────────────────────────────────────────────
class AppDialog {
  AppDialog._();

  // ── Public factories ──────────────────────────────────────────────────────

  /// Green success dialog. Supply [autoDismiss] to close after 2 seconds, or
  /// [buttonText] / [onPressed] to render a confirmation button.
  static Future<void> success(
    BuildContext context, {
    String title = 'Success',
    String message = '',
    IconData icon = Icons.check_circle_rounded,
    Color iconColor = AppColors.successGreen,
    String buttonText = 'OK',
    VoidCallback? onPressed,
    bool autoDismiss = false,
  }) {
    return _show(
      context: context,
      icon: icon,
      iconColor: iconColor,
      title: title,
      message: message,
      buttonText: buttonText,
      onPressed: onPressed,
      autoDismiss: autoDismiss,
    );
  }

  /// Orange warning dialog — e.g. no internet, GPS disabled.
  static Future<void> warning(
    BuildContext context, {
    String title = 'Warning',
    String message = '',
    IconData icon = Icons.warning_amber_rounded,
    Color iconColor = AppColors.warningOrange,
    String buttonText = 'OK',
    VoidCallback? onPressed,
    String? secondaryText,
    VoidCallback? onSecondary,
    bool autoDismiss = false,
  }) {
    return _show(
      context: context,
      icon: icon,
      iconColor: iconColor,
      title: title,
      message: message,
      buttonText: buttonText,
      onPressed: onPressed,
      secondaryText: secondaryText,
      onSecondary: onSecondary,
      autoDismiss: autoDismiss,
    );
  }

  /// Red "heavy traffic detected" dialog — typically has a `Show Routes`
  /// primary button and a `Dismiss` secondary button.
  static Future<void> traffic(
    BuildContext context, {
    String title = 'Traffic Alert',
    String message = '',
    IconData icon = Icons.traffic_rounded,
    Color iconColor = AppColors.primaryRed,
    String buttonText = 'Show Routes',
    VoidCallback? onPressed,
    String? secondaryText = 'Dismiss',
    VoidCallback? onSecondary,
  }) {
    return _show(
      context: context,
      icon: icon,
      iconColor: iconColor,
      title: title,
      message: message,
      buttonText: buttonText,
      onPressed: onPressed,
      secondaryText: secondaryText,
      onSecondary: onSecondary,
    );
  }

  /// Dark-red error dialog.
  static Future<void> error(
    BuildContext context, {
    String title = 'Something went wrong',
    String message = '',
    IconData icon = Icons.error_outline_rounded,
    Color iconColor = AppColors.errorRed,
    String buttonText = 'Try Again',
    VoidCallback? onPressed,
    String? secondaryText,
    VoidCallback? onSecondary,
  }) {
    return _show(
      context: context,
      icon: icon,
      iconColor: iconColor,
      title: title,
      message: message,
      buttonText: buttonText,
      onPressed: onPressed,
      secondaryText: secondaryText,
      onSecondary: onSecondary,
    );
  }

  /// Blue informational dialog — typically auto-dismissing.
  static Future<void> info(
    BuildContext context, {
    String title = 'Information',
    String message = '',
    IconData icon = Icons.info_outline_rounded,
    Color iconColor = AppColors.infoBlue,
    String buttonText = 'OK',
    VoidCallback? onPressed,
    bool autoDismiss = false,
  }) {
    return _show(
      context: context,
      icon: icon,
      iconColor: iconColor,
      title: title,
      message: message,
      buttonText: buttonText,
      onPressed: onPressed,
      autoDismiss: autoDismiss,
    );
  }

  // ── Internal shared showGeneralDialog ────────────────────────────────────

  static Future<void> _show({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String buttonText,
    VoidCallback? onPressed,
    String? secondaryText,
    VoidCallback? onSecondary,
    bool autoDismiss = false,
  }) {
    Timer? dismissTimer;

    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: !autoDismiss,
      barrierLabel: title,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim, _) {
        if (autoDismiss) {
          dismissTimer = Timer(const Duration(seconds: 2), () {
            if (Navigator.of(ctx, rootNavigator: true).canPop()) {
              Navigator.of(ctx, rootNavigator: true).pop();
            }
          });
        }
        return _DialogShell(
          icon: icon,
          iconColor: iconColor,
          title: title,
          message: message,
          buttonText: buttonText,
          onPressed: onPressed,
          secondaryText: secondaryText,
          onSecondary: onSecondary,
          autoDismiss: autoDismiss,
        );
      },
      transitionBuilder: (ctx, anim, _, child) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    ).whenComplete(() => dismissTimer?.cancel());
  }
}

// ─── Dialog body ─────────────────────────────────────────────────────────────

class _DialogShell extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String buttonText;
  final VoidCallback? onPressed;
  final String? secondaryText;
  final VoidCallback? onSecondary;
  final bool autoDismiss;

  const _DialogShell({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.buttonText,
    required this.onPressed,
    required this.secondaryText,
    required this.onSecondary,
    required this.autoDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadii.dialog),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Icon circle ──
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: iconColor.withValues(alpha: 0.12),
                  ),
                  child: Icon(icon, color: iconColor, size: 30),
                ),
                const SizedBox(height: 16),
                // ── Title ──
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textBlack,
                  ),
                ),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  // ── Message ──
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textBlack.withValues(alpha: 0.72),
                      height: 1.45,
                    ),
                  ),
                ],
                if (!autoDismiss) ...[
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryRed,
                        foregroundColor: AppColors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadii.button),
                        ),
                      ),
                      onPressed: () {
                        if (Navigator.of(context, rootNavigator: true)
                            .canPop()) {
                          Navigator.of(context, rootNavigator: true).pop();
                        }
                        onPressed?.call();
                      },
                      child: Text(
                        buttonText,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                  if (secondaryText != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: TextButton(
                        onPressed: () {
                          if (Navigator.of(context, rootNavigator: true)
                              .canPop()) {
                            Navigator.of(context, rootNavigator: true).pop();
                          }
                          onSecondary?.call();
                        },
                        child: Text(
                          secondaryText!,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mutedText,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
