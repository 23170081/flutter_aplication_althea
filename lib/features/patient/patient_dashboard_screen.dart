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
      final user = context.read<UserProvider>().user;
      if (user == null) throw Exception('No autenticado');

      final data = await supabase
          .from('citas')
          .select('''
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
      ''')
          .eq('usuario_id', user.id)
          .eq('estado', 'programada');

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
              doctorName =
                  row['doctores']['usuarios']['nombre_completo'] ?? 'Doctor';
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

      upcoming.sort(
        (a, b) =>
            (a['dateTime'] as DateTime).compareTo(b['dateTime'] as DateTime),
      );

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

  void _showAppointmentDetails(Map<String, dynamic> appointment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Detalles de la Cita',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AltheaColors.navy,
                ),
              ),
              const SizedBox(height: 24),
              
              // Detalles
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AltheaColors.lightBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(Icons.person_outline, 'Doctor', appointment['doctor']!),
                    const Divider(height: 24),
                    _buildDetailRow(Icons.medical_services_outlined, 'Especialidad', appointment['specialty']!),
                    const Divider(height: 24),
                    _buildDetailRow(Icons.business_outlined, 'Sucursal', appointment['branch']!),
                    const Divider(height: 24),
                    _buildDetailRow(Icons.calendar_today_outlined, 'Fecha', appointment['dateFormatted']!),
                    const Divider(height: 24),
                    _buildDetailRow(Icons.access_time_rounded, 'Hora', appointment['timeFormatted']!),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Botón de cancelar cita
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Cerrar bottom sheet
                  _cancelAppointment(appointment);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Cancelar Cita',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Cerrar',
                  style: TextStyle(
                    color: AltheaColors.navy,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AltheaColors.gold, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AltheaColors.textSecondary,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AltheaColors.navy,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _cancelAppointment(Map<String, dynamic> appointment) async {
    final dateTime = appointment['dateTime'] as DateTime;
    final timeDiff = dateTime.difference(DateTime.now());
    final isMoreThanOneDay = timeDiff.inHours > 24;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Cancelar Cita',
          style: TextStyle(
            color: AltheaColors.navy,
            fontWeight: FontWeight.bold,
          ),
        ),
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
            child: const Text(
              'Volver',
              style: TextStyle(
                color: AltheaColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Sí, Cancelar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final supabase = Supabase.instance.client;
        final user = context.read<UserProvider>().user;
        if (user == null) throw Exception('No autenticado');

        // Obtener detalles de la cita
        final citaData = await supabase
            .from('citas')
            .select('metodo_pago, referencia_pago')
            .eq('id', appointment['id'])
            .single();

        final metodoPago = citaData['metodo_pago'] as String?;
        final referenciaPago = citaData['referencia_pago'] as String?;

        // Monto fijo del anticipo según casos de uso
        const montoAnticipo = 500.0;

        // Determinar estado del reembolso según las reglas de negocio
        final estadoReembolso = isMoreThanOneDay ? 'pendiente' : 'no_aplicable';
        final notas = isMoreThanOneDay
            ? 'Reembolso pendiente de procesamiento'
            : 'No aplica reembolso por cancelación con menos de 24 horas de anticipación';

        // Actualizar la cita
        await supabase
            .from('citas')
            .update({
              'estado': 'cancelada',
              'cancelada_por': user.id,
              'fecha_cancelacion': DateTime.now().toIso8601String(),
            })
            .eq('id', appointment['id']);

        // Crear registro de reembolso
        await supabase.from('reembolsos').insert({
          'cita_id': appointment['id'],
          'usuario_id': user.id,
          'monto': montoAnticipo,
          'estado': estadoReembolso,
          'motivo_cancelacion': 'paciente',
          'metodo_pago': metodoPago,
          'referencia_pago': referenciaPago,
          'notas': notas,
        });

        _fetchUpcomingAppointments();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isMoreThanOneDay
                    ? 'Cita cancelada. Reembolso en proceso.'
                    : 'Cita cancelada. No aplica reembolso.',
              ),
              backgroundColor: isMoreThanOneDay ? Colors.green : Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error al cancelar: $e')));
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
                    const SizedBox(height: 250),
                  ],
                ),
                Positioned(
                  bottom: 0,
                  left: 20,
                  right: 20,
                  child: _QuickActionsCard(
                    primaryAction: _QuickAction(
                      icon: Icons.add_rounded,
                      label: 'Agendar Cita',
                      primary: true,
                      onTap: () => context.go('/patient/doctors'),
                    ),
                    secondaryActions: [
                      _QuickAction(
                        icon: Icons.calendar_today_outlined,
                        label: 'Mis Citas',
                        onTap: () => context.go('/patient/appointments'),
                      ),
                      _QuickAction(
                        icon: Icons.receipt_long_outlined,
                        label: 'Reembolsos',
                        onTap: () => context.go('/patient/refunds'),
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
                    const Center(
                      child: CircularProgressIndicator(
                        color: AltheaColors.navy,
                      ),
                    )
                  else if (_upcomingAppointments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'No tienes citas próximas',
                          style: TextStyle(
                            fontSize: 16,
                            color: AltheaColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  else
                    ..._upcomingAppointments.map(
                      (a) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _AppointmentCard(
                          appointment: a,
                          onTap: () => _showAppointmentDetails(a),
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
  final _QuickAction primaryAction;
  final List<_QuickAction> secondaryActions;
  const _QuickActionsCard({
    required this.primaryAction,
    required this.secondaryActions,
  });

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
      child: Column(
        children: [
          // 3 botones pequeños arriba
          Row(
            children: secondaryActions.map((a) => Expanded(child: _buildBtn(a))).toList(),
          ),
          const SizedBox(height: 12),
          // Botón extendido abajo
          _QuickActionButton(action: primaryAction, isExtended: true),
        ],
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
  final bool isExtended;
  const _QuickActionButton({required this.action, this.isExtended = false});
  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final a = widget.action;
    final isExtended = widget.isExtended;
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
          padding: isExtended
              ? const EdgeInsets.symmetric(vertical: 16, horizontal: 20)
              : const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
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
          child: isExtended
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        a.icon,
                        color: AltheaColors.navy,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      a.label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AltheaColors.navy,
                      ),
                    ),
                  ],
                )
              : Column(
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
  final VoidCallback? onTap;
  const _AppointmentCard({required this.appointment, this.onTap});

  @override
  Widget build(BuildContext context) {
    final a = appointment;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
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
                Text(
                  a['specialty']!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AltheaColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  a['branch']!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AltheaColors.navy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${a['dateFormatted']} · ${a['timeFormatted']}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AltheaColors.navy,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AltheaColors.gold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Próxima',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AltheaColors.gold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
        ),
      ),
    );
  }
}
