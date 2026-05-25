import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_althea/core/theme/app_theme.dart';
import 'package:flutter_application_althea/core/providers/notification_provider.dart';

/// Shared curved header for all dashboards (matches TS gradient header)
class AltheaHeader extends StatelessWidget {
  final String roleLabel;
  final String userName;
  final String subtitle;
  final VoidCallback onLogout;
  final VoidCallback? onSettings;
  final VoidCallback? onNotifications;
  final VoidCallback? onLogoTap;
  final double bottomPadding;

  const AltheaHeader({
    super.key,
    required this.roleLabel,
    required this.userName,
    required this.subtitle,
    required this.onLogout,
    this.onSettings,
    this.onNotifications,
    this.onLogoTap,
    this.bottomPadding = 48,
  });

  @override
  Widget build(BuildContext context) {
    final unreadCount = context.watch<NotificationProvider>().unreadCount;
    final onSettingsCallback = onSettings;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AltheaColors.navy, AltheaColors.navyMid, AltheaColors.navy],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: Stack(
        children: [
          // Decorative blur top-right
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AltheaColors.gold.withOpacity(0.15),
              ),
            ),
          ),
          // Decorative blur bottom-left
          Positioned(
            bottom: -40,
            left: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top bar: logo + actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Logo
                      InkWell(
                        onTap: onLogoTap ?? () {
                          final role = roleLabel.toLowerCase();
                          if (role.contains('doctor')) {
                            context.go('/doctor/dashboard');
                          } else if (role.contains('paciente') || role.contains('patient')) {
                            context.go('/patient/dashboard');
                          } else if (role.contains('recepcion')) {
                            context.go('/receptionist/dashboard');
                          } else if (role.contains('admin')) {
                            context.go('/admin/dashboard');
                          } else {
                            context.go('/');
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                ),
                              ),
                              child: Image.asset(
                                'assets/images/logoAlthea.png',
                                width: 32,
                                height: 32,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.local_hospital_rounded,
                                  color: AltheaColors.gold,
                                  size: 28,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ALTHEA',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                roleLabel,
                                style: const TextStyle(
                                  color: AltheaColors.gold,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      ),
                      // Actions
                      Row(
                        children: [
                          Stack(
                            children: [
                              _HeaderIconButton(
                                icon: Icons.notifications_outlined,
                                onTap: onNotifications ?? () => context.push('/notifications'),
                              ),
                              if (unreadCount > 0)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AltheaColors.navy, width: 2),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (onSettingsCallback != null) ...[
                            const SizedBox(width: 8),
                            _HeaderIconButton(
                              icon: Icons.settings_outlined,
                              onTap: onSettingsCallback,
                            ),
                          ],
                          const SizedBox(width: 8),
                          _HeaderIconButton(
                            icon: Icons.logout_rounded,
                            onTap: onLogout,
                            isDestructive: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  // Welcome text
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;

  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  State<_HeaderIconButton> createState() => _HeaderIconButtonState();
}

class _HeaderIconButtonState extends State<_HeaderIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.white.withOpacity(0.2)
                : Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Icon(
            widget.icon,
            color: _hovered && widget.isDestructive
                ? Colors.red[300]
                : Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}
