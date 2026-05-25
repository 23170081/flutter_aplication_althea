import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flutter_application_althea/core/theme/app_theme.dart';
import 'package:flutter_application_althea/core/providers/user_provider.dart';
import 'package:flutter_application_althea/shared/widgets/althea_header.dart';

class ReceptionistDashboardScreen extends StatelessWidget {
  const ReceptionistDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;

    final activity = [
      {
        'action': 'Cita agendada',
        'patient': 'Juan Pérez',
        'time': 'Hace 10 min',
        'icon': Icons.calendar_today_rounded,
        'color': AltheaColors.navy,
      },
      {
        'action': 'Pago registrado',
        'patient': 'María López',
        'time': 'Hace 25 min',
        'icon': Icons.receipt_rounded,
        'color': Color(0xFF28A745),
      },
      {
        'action': 'Paciente registrado',
        'patient': 'Carlos Gómez',
        'time': 'Hace 1 hora',
        'icon': Icons.person_add_rounded,
        'color': AltheaColors.gold,
      },
      {
        'action': 'Cita cancelada',
        'patient': 'Ana Torres',
        'time': 'Hace 2 horas',
        'icon': Icons.cancel_rounded,
        'color': Color(0xFFD32F2F),
      },
    ];

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
                context.read<UserProvider>().logout();
                context.go('/');
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
                          height: 118,
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
                          height: 118,
                          child: _ReceptionBtn(
                            icon: Icons.person_add_rounded,
                            label: 'Nuevo Paciente',
                            dark: true,
                            onTap: () => context.go('/receptionist/register-patient'),
                          ),
                        ),
                        SizedBox(
                          width: buttonWidth,
                          height: 118,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Activity
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Actividad Reciente',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AltheaColors.navy,
                        ),
                      ),
                      const Text(
                        'Ver todo',
                        style: TextStyle(
                          color: AltheaColors.gold,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ...activity.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AltheaColors.borderLight),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: (item['color'] as Color).withOpacity(
                                  0.12,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                item['icon'] as IconData,
                                color: item['color'] as Color,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['action'] as String,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AltheaColors.navy,
                                    ),
                                  ),
                                  Text(
                                    item['patient'] as String,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AltheaColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              item['time'] as String,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AltheaColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
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
