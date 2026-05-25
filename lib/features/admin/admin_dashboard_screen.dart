import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flutter_application_althea/core/theme/app_theme.dart';
import 'package:flutter_application_althea/core/providers/user_provider.dart';
import 'package:flutter_application_althea/core/utils/confirm_dialog.dart';
import 'package:flutter_application_althea/shared/widgets/althea_header.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;

    final stats = [
      {
        'icon': Icons.groups_rounded,
        'value': '156',
        'label': 'Total Pacientes',
        'highlighted': false,
      },
      {
        'icon': Icons.medical_services_rounded,
        'value': '12',
        'label': 'Doctores Activos',
        'highlighted': true,
      },
      {
        'icon': Icons.calendar_month_rounded,
        'value': '89',
        'label': 'Citas Este Mes',
        'highlighted': false,
      },
      {
        'icon': Icons.description_rounded,
        'value': '42',
        'label': 'Nuevos Reportes',
        'highlighted': false,
      },
    ];

    final modules = [
      {
        'icon': Icons.account_tree_rounded,
        'label': 'Sucursales',
        'route': '/admin/branch-management',
      },
      {
        'icon': Icons.calendar_today_rounded,
        'label': 'Agenda General',
        'route': null,
      },
      {
        'icon': Icons.person_add_rounded,
        'label': 'Agregar Doctor',
        'route': '/admin/add-doctor',
      },
      {
        'icon': Icons.add_business_rounded,
        'label': 'Agregar Sucursal',
        'route': '/admin/add-branch',
      },
    ];

    final activity = [
      {
        'event': 'Nueva cita registrada',
        'time': 'Hace 5 min',
        'icon': Icons.calendar_today_rounded,
        'gold': false,
      },
      {
        'event': 'Nuevo paciente registrado',
        'time': 'Hace 15 min',
        'icon': Icons.person_add_rounded,
        'gold': false,
      },
      {
        'event': 'Nuevo doctor registrado',
        'time': 'Hace 2 horas',
        'icon': Icons.medical_services_rounded,
        'gold': true,
      },
    ];

    return Scaffold(
      backgroundColor: AltheaColors.lightBg,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              alignment: Alignment.topCenter,
              children: [
                Column(
                  children: [
                    AltheaHeader(
                      roleLabel: 'ADMINISTRACIÓN',
                      userName: user?.name ?? 'Administrador',
                      subtitle: 'Panel de Control',
                      bottomPadding: 30,
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
                    const SizedBox(height: 300),
                  ],
                ),
                Positioned(
                  bottom: 0,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
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
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisExtent: 110,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      itemCount: stats.length,
                      itemBuilder: (_, i) {
                        final s = stats[i];
                        final isGold = s['highlighted'] as bool;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AltheaColors.lightCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AltheaColors.borderLight),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                s['icon'] as IconData,
                                color: isGold
                                    ? AltheaColors.gold
                                    : AltheaColors.navy,
                                size: 22,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                s['value'] as String,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: isGold
                                      ? AltheaColors.gold
                                      : AltheaColors.navy,
                                ),
                              ),
                              Text(
                                s['label'] as String,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AltheaColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Modules
                  const Text(
                    'Módulos',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AltheaColors.navy,
                    ),
                  ),
                  const SizedBox(height: 14),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisExtent: 100,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: modules.length,
                    itemBuilder: (_, i) {
                      final m = modules[i];
                      return GestureDetector(
                        onTap: m['route'] != null
                            ? () => context.go(m['route'] as String)
                            : null,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AltheaColors.borderLight),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AltheaColors.lightCard,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  m['icon'] as IconData,
                                  color: AltheaColors.navy,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                m['label'] as String,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AltheaColors.navy,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Activity
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Actividad',
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
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AltheaColors.borderLight),
                    ),
                    child: Column(
                      children: activity
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: (item['gold'] as bool)
                                          ? AltheaColors.gold.withOpacity(0.12)
                                          : AltheaColors.navy.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      item['icon'] as IconData,
                                      color: (item['gold'] as bool)
                                          ? AltheaColors.gold
                                          : AltheaColors.navy,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['event'] as String,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: AltheaColors.navy,
                                          ),
                                        ),
                                        Text(
                                          item['time'] as String,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AltheaColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
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
