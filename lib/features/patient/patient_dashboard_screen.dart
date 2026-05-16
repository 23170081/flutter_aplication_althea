import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_althea/core/theme/app_theme.dart';
import 'package:flutter_application_althea/core/providers/user_provider.dart';
import 'package:flutter_application_althea/shared/widgets/althea_header.dart';

class PatientDashboardScreen extends StatefulWidget {
  const PatientDashboardScreen({super.key});

  @override
  State<PatientDashboardScreen> createState() => _PatientDashboardScreenState();
}

class _PatientDashboardScreenState extends State<PatientDashboardScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _upcomingAppointments = [];

  @override
  void initState() {
    super.initState();
    _fetchUpcomingAppointments();
  }

  Future<void> _fetchUpcomingAppointments() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('No autenticado');

      final data = await supabase.from('citas').select('''
        id,
        fecha,
        hora,
        estado,
        doctores (
          especialidad,
          usuarios (
            nombre_completo
          )
        ),
        sucursales (
          nombre
        )
      ''').eq('usuario_id', user.id).eq('estado', 'programada');

      final now = DateTime.now();
      List<Map<String, dynamic>> upcoming = [];

      for (var row in data) {
        final dateStr = row['fecha'].toString();
        final timeStr = row['hora'].toString();
        
        final dateTime = DateTime.parse('${dateStr}T$timeStr');
        
        if (dateTime.isAfter(now)) {
          String doctorName = 'Doctor';
          String specialty = 'Especialidad';
          String branchName = 'Sucursal';
          
          if (row['sucursales'] != null) {
            branchName = row['sucursales']['nombre'] ?? 'Sucursal';
          }
          
          if (row['doctores'] != null) {
            specialty = row['doctores']['especialidad'] ?? 'Especialidad';
            if (row['doctores']['usuarios'] != null) {
              doctorName = row['doctores']['usuarios']['nombre_completo'] ?? 'Doctor';
            }
          }

          upcoming.add({
            'id': row['id'],
            'doctor': doctorName,
            'specialty': specialty,
            'branch': branchName,
            'dateTime': dateTime,
            'dateFormatted': DateFormat('dd MMM', 'es_MX').format(dateTime),
            'timeFormatted': DateFormat('h:mm a').format(dateTime),
            'status': 'upcoming',
          });
        }
      }

      upcoming.sort((a, b) => (a['dateTime'] as DateTime).compareTo(b['dateTime'] as DateTime));

      if (mounted) {
        setState(() {
          _upcomingAppointments = upcoming;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cancelAppointment(Map<String, dynamic> appointment) async {
    final dateTime = appointment['dateTime'] as DateTime;
    final timeDiff = dateTime.difference(DateTime.now());
    final isMoreThanOneDay = timeDiff.inHours > 24;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar Cita', style: TextStyle(color: AltheaColors.navy, fontWeight: FontWeight.bold)),
        content: Text(
          isMoreThanOneDay
              ? '¿Estás seguro de cancelar esta cita? Al faltar más de un día, se te hará el reembolso del anticipo dado.'
              : '¿Estás seguro de cancelar esta cita? Al faltar menos de un día, no habrá reembolso del anticipo.',
          style: const TextStyle(color: AltheaColors.textSecondary),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Volver', style: TextStyle(color: AltheaColors.textSecondary, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Sí, Cancelar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final supabase = Supabase.instance.client;
        await supabase.from('citas').update({'estado': 'cancelada'}).eq('id', appointment['id']);
        _fetchUpcomingAppointments();
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cancelar: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;

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
                      roleLabel: 'PACIENTE',
                      userName: user?.name ?? 'Paciente',
                      subtitle: 'Bienvenido de nuevo,',
                      bottomPadding: 30,
                      onLogout: () {
                        context.read<UserProvider>().logout();
                        context.go('/');
                      },
                      onSettings: () => context.go('/patient/profile'),
                    ),
                    const SizedBox(height: 150),
                  ],
                ),
                Positioned(
                  bottom: 0,
                  left: 20,
                  right: 20,
                  child: _QuickActionsCard(
                    actions: [
                      _QuickAction(
                        icon: Icons.add_rounded,
                        label: 'Agendar Cita',
                        primary: true,
                        onTap: () => context.go('/patient/doctors'),
                      ),
                      _QuickAction(
                        icon: Icons.calendar_today_outlined,
                        label: 'Mis Citas',
                        onTap: () => context.go('/patient/appointments'),
                      ),
                      _QuickAction(
                        icon: Icons.person_outline_rounded,
                        label: 'Mi Perfil',
                        onTap: () => context.go('/patient/profile'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Próximas Citas',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AltheaColors.navy,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator(color: AltheaColors.navy))
                  else if (_upcomingAppointments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'No tienes citas próximas',
                          style: TextStyle(fontSize: 16, color: AltheaColors.textSecondary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    )
                  else
                    ..._upcomingAppointments.map(
                      (a) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _AppointmentCard(
                          appointment: a,
                          onCancel: () => _cancelAppointment(a),
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

// ─── Quick Actions Card ──────────────────────────────────────

class _QuickActionsCard extends StatelessWidget {
  final List<_QuickAction> actions;
  const _QuickActionsCard({required this.actions});

  @override
  Widget build(BuildContext context) {
    return Container(
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
      padding: const EdgeInsets.all(16),
      child: Row(
        children: actions.map((a) => Expanded(child: _buildBtn(a))).toList(),
      ),
    );
  }

  Widget _buildBtn(_QuickAction a) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: _QuickActionButton(action: a),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final bool primary;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    this.primary = false,
    required this.onTap,
  });
}

class _QuickActionButton extends StatefulWidget {
  final _QuickAction action;
  const _QuickActionButton({required this.action});
  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final a = widget.action;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        a.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            gradient: a.primary
                ? const LinearGradient(
                    colors: [AltheaColors.gold, AltheaColors.goldLight],
                  )
                : null,
            color: a.primary ? null : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: a.primary
                ? null
                : Border.all(color: AltheaColors.borderLight),
            boxShadow: a.primary
                ? [
                    BoxShadow(
                      color: AltheaColors.gold.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                    ),
                  ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: a.primary
                      ? Colors.white.withOpacity(0.2)
                      : AltheaColors.lightCard,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  a.icon,
                  color: a.primary ? AltheaColors.navy : AltheaColors.navy,
                  size: 20,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                a.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: a.primary
                      ? AltheaColors.navy
                      : AltheaColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Appointment Card ────────────────────────────────────────

class _AppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final VoidCallback? onCancel;
  const _AppointmentCard({required this.appointment, this.onCancel});

  @override
  Widget build(BuildContext context) {
    final a = appointment;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AltheaColors.borderLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a['doctor']!, 
                  style: const TextStyle(
                    fontSize: 17, 
                    fontWeight: FontWeight.w800, 
                    color: AltheaColors.navy, 
                  ),
                ),
                const SizedBox(height: 2),
                Text(a['specialty']!, style: const TextStyle(fontSize: 14, color: AltheaColors.textSecondary, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(a['branch']!, style: const TextStyle(fontSize: 13, color: AltheaColors.navy, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 6),
                    Text('${a['dateFormatted']} · ${a['timeFormatted']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AltheaColors.navy)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AltheaColors.gold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Próxima',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AltheaColors.gold),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: onCancel,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
