import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flutter_application_althea/core/theme/app_theme.dart';
import 'package:flutter_application_althea/core/providers/user_provider.dart';
import 'package:flutter_application_althea/core/utils/confirm_dialog.dart';
import 'package:flutter_application_althea/shared/widgets/althea_header.dart';

class ReceptionistDashboardScreen extends StatelessWidget {
  const ReceptionistDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;

    return Scaffold(
      backgroundColor: AltheaColors.lightBg,
      body: SingleChildScrollView(
        child: Column(
          children: [
            AltheaHeader(
              roleLabel: 'RECEPCIÓN',
              userName: user?.name ?? 'Recepcionista',
              subtitle: 'Bienvenida,',
              bottomPadding: 24,
              onLogout: () {
                showConfirmDialog(
                  context,
                  title: 'Cerrar Sesión',
                  message: '¿Estás seguro de cerrar sesión?',
                  confirmLabel: 'Sí, salir',
                ).then((confirmed) {
                  if (confirmed == true) {
                    context.read<UserProvider>().logout();
                    context.go('/');
                  }
                });
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 520;
                    final buttonWidth = isWide
                        ? (constraints.maxWidth - 10) / 2
                        : constraints.maxWidth;

                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        SizedBox(
                          width: buttonWidth,
                          height: 180,
                          child: _ReceptionBtn(
                            icon: Icons.search_rounded,
                            label: 'Buscar Paciente',
                            primary: true,
                            onTap: () =>
                                context.go('/receptionist/search-patient'),
                          ),
                        ),
                        SizedBox(
                          width: buttonWidth,
                          height: 180,
                          child: _ReceptionBtn(
                            icon: Icons.person_add_rounded,
                            label: 'Nuevo Paciente',
                            dark: true,
                            onTap: () => context.go('/receptionist/register-patient'),
                          ),
                        ),
                        SizedBox(
                          width: buttonWidth,
                          height: 180,
                          child: _ReceptionBtn(
                            icon: Icons.event_busy_rounded,
                            label: 'Citas',
                            primary: true,
                            onTap: () => context.go('/receptionist/appointments'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }
}

class _ReceptionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool primary;
  final bool dark;
  final VoidCallback onTap;
  const _ReceptionBtn({
    required this.icon,
    required this.label,
    this.primary = false,
    this.dark = false,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: primary
              ? const LinearGradient(
                  colors: [AltheaColors.gold, AltheaColors.goldLight],
                )
              : dark
              ? const LinearGradient(
                  colors: [AltheaColors.navy, AltheaColors.navyMid],
                )
              : null,
          color: (primary || dark) ? null : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: (primary || dark)
              ? null
              : Border.all(color: AltheaColors.borderLight),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: (primary || dark)
                  ? (primary ? AltheaColors.navy : Colors.white)
                  : AltheaColors.navy,
              size: 26,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: (primary || dark)
                    ? (primary ? AltheaColors.navy : Colors.white)
                    : AltheaColors.navy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final bool last;
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: AltheaColors.gold, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        if (!last) ...[
          const SizedBox(height: 12),
          Divider(color: Colors.white.withOpacity(0.1)),
        ],
      ],
    );
  }
}
