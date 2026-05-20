import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_althea/core/theme/app_theme.dart';
import 'package:flutter_application_althea/core/providers/user_provider.dart';
import 'package:flutter_application_althea/shared/widgets/althea_header.dart';

class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  int _todayCount = 0;
  int _weekCount = 0;
  int _uniquePatientsCount = 0;
  bool _isLoading = true;
  List<Map<String, dynamic>> _todayAppointments = [];

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final user = context.read<UserProvider>().user;
      if (user == null) return;

      final supabase = Supabase.instance.client;
      final now = DateTime.now();

      final doctorData = await supabase
          .from('doctores')
          .select('id')
          .eq('usuario_id', user.id)
          .maybeSingle();

      if (doctorData == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No se encontró el perfil de doctor asociado a este usuario.',
              ),
            ),
          );
        }
        return;
      }
      final doctorId = doctorData['id'];

      final data = await supabase
          .from('citas')
          .select('''
            id,
            fecha,
            hora,
            estado,
            usuarios:usuarios!citas_usuario_id_fkey (
              id,
              nombre_completo
            ),
            sucursales (
              nombre
            )
          ''')
          .eq('doctor_id', doctorId);

      final List<dynamic> citas = data as List<dynamic>;

      int todayCount = 0;
      int weekCount = 0;
      Set<String> uniquePatients = {};
      List<Map<String, dynamic>> todayAppointmentsList = [];

      final todayAtMidnight = DateTime(now.year, now.month, now.day);
      final startOfWeek = todayAtMidnight.subtract(
        Duration(days: todayAtMidnight.weekday - 1),
      );
      final endOfWeek = startOfWeek.add(const Duration(days: 6));

      for (var c in citas) {
        final status = (c['estado'] as String?)?.toLowerCase().trim() ?? '';
        if (status == 'cancelada') continue;

        final dateStr = c['fecha'] as String;
        final timeStr = c['hora'] as String;
        final parts = dateStr.split('-');
        if (parts.length != 3) continue;

        final timeParts = timeStr.split(':');
        int hour = 0;
        int minute = 0;
        if (timeParts.length >= 2) {
          hour = int.tryParse(timeParts[0]) ?? 0;
          minute = int.tryParse(timeParts[1]) ?? 0;
        }

        final aptDateTime = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
          hour,
          minute,
        );
        final aptDateAtMidnight = DateTime(
          aptDateTime.year,
          aptDateTime.month,
          aptDateTime.day,
        );

        final isToday = aptDateAtMidnight.isAtSameMomentAs(todayAtMidnight);
        final isThisWeek =
            !aptDateAtMidnight.isBefore(startOfWeek) &&
            !aptDateAtMidnight.isAfter(endOfWeek);

        if (status != 'terminada' && status != 'cancelada') {
          if (isToday) todayCount++;
          if (isThisWeek && !aptDateAtMidnight.isBefore(todayAtMidnight))
            weekCount++;
        }

        if (c['usuarios'] != null && c['usuarios']['id'] != null) {
          uniquePatients.add(c['usuarios']['id'].toString());
        } else if (c['usuarios'] != null &&
            c['usuarios']['nombre_completo'] != null) {
          uniquePatients.add(c['usuarios']['nombre_completo']);
        }

        if (isToday && (status == 'programada' || status == 'pendiente')) {
          todayAppointmentsList.add({
            'id': c['id'],
            'patient': c['usuarios']?['nombre_completo'] ?? 'Paciente',
            'time': c['hora'],
            'type': c['sucursales']?['nombre'] ?? 'Consulta',
            'status': 'pending',
            'isCompleted': false,
          });
        }
      }

      todayAppointmentsList.sort((a, b) {
        final timeA = a['time'] as String;
        final timeB = b['time'] as String;
        return timeA.compareTo(timeB);
      });

      if (mounted) {
        setState(() {
          _todayCount = todayCount;
          _weekCount = weekCount;
          _uniquePatientsCount = uniquePatients.length;
          _todayAppointments = todayAppointmentsList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cargar datos: $e')));
      }
    }
  }

  Future<void> _cancelAppointment(Map<String, dynamic> appointment) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Cancelar Cita',
          style: TextStyle(
            color: AltheaColors.navy,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          '¿Estás seguro de cancelar esta cita? Se le hará el reembolso completo del anticipo al paciente y se le notificará sobre cancelación.',
          style: TextStyle(color: AltheaColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'No, Mantener',
              style: TextStyle(
                color: AltheaColors.navy,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
      try {
        final supabase = Supabase.instance.client;
        await supabase
            .from('citas')
            .update({'estado': 'cancelada'})
            .eq('id', appointment['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cita cancelada exitosamente.')),
          );
          _fetchStats();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error al cancelar: $e')));
        }
      }
    }
  }

  void _showAppointmentDetails(Map<String, dynamic> appointment) {
    final isCompleted = appointment['isCompleted'] == true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
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

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AltheaColors.lightBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(
                      Icons.person_outline,
                      'Paciente',
                      appointment['patient']!,
                    ),
                    const Divider(height: 24),
                    _buildDetailRow(
                      Icons.medical_services_outlined,
                      'Tipo de Consulta',
                      appointment['type']!,
                    ),
                    const Divider(height: 24),
                    _buildDetailRow(
                      Icons.access_time_rounded,
                      'Hora',
                      appointment['time']!,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go(
                    '/doctor/medical-record?patient=${Uri.encodeComponent(appointment['patient']!)}',
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AltheaColors.navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Ver Expediente Médico',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),

              if (!isCompleted) ...[
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Cerrar',
                  style: TextStyle(
                    color: AltheaColors.textSecondary,
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
                      roleLabel: 'DOCTOR',
                      userName: user?.name ?? 'Doctor',
                      subtitle: 'Bienvenido, Dr(a).',
                      bottomPadding: 30,
                      onLogout: () {
                        context.read<UserProvider>().logout();
                        context.go('/');
                      },
                    ),
                    const SizedBox(height: 150),
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
                    child: Row(
                      children: [
                        _StatItem(
                          value: _isLoading ? '-' : '$_todayCount',
                          label: 'Citas Hoy',
                          isHighlighted: true,
                        ),
                        _verticalDivider(),
                        _StatItem(
                          value: _isLoading ? '-' : '$_weekCount',
                          label: 'Esta Semana',
                        ),
                        _verticalDivider(),
                        _StatItem(
                          value: _isLoading ? '-' : '$_uniquePatientsCount',
                          label: 'Pacientes\nHistóricos',
                        ),
                      ],
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
                  // Today's schedule
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Agenda de Hoy',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AltheaColors.navy,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.go('/doctor/schedule'),
                        child: const Row(
                          children: [
                            Text(
                              'Ver Agenda',
                              style: TextStyle(
                                color: AltheaColors.gold,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: AltheaColors.gold,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    const Center(
                      child: CircularProgressIndicator(
                        color: AltheaColors.navy,
                      ),
                    )
                  else if (_todayAppointments.isEmpty)
                    const Text(
                      'No tienes citas para hoy.',
                      style: TextStyle(color: AltheaColors.textSecondary),
                    )
                  else
                    ..._todayAppointments.map(
                      (a) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _AppointmentItem(
                          appointment: a,
                          onTap: () => _showAppointmentDetails(a),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),

                  // Quick Actions
                  const Text(
                    'Accesos Rápidos',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AltheaColors.navy,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _QuickActionCard(
                    icon: Icons.groups_rounded,
                    title: 'Mis Pacientes',
                    subtitle: 'Ver histórico y expedientes',
                    gradient: const [AltheaColors.navy, AltheaColors.navyMid],
                    textColor: Colors.white,
                    onTap: () => context.go('/doctor/patients'),
                  ),
                  const SizedBox(height: 12),
                  _QuickActionCard(
                    icon: Icons.calendar_month_rounded,
                    title: 'Mi Agenda',
                    subtitle: 'Configurar horario y bloqueos',
                    gradient: const [AltheaColors.gold, AltheaColors.goldLight],
                    textColor: AltheaColors.navy,
                    onTap: () => context.go('/doctor/schedule'),
                  ),
                  const SizedBox(height: 12),
                  _QuickActionCard(
                    icon: Icons.description_outlined,
                    title: 'Nuevas Notas Médicas',
                    subtitle: 'Añadir registros rápidamente',
                    light: true,
                    onTap: () => context.go('/doctor/medical-record'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _verticalDivider() => Container(
    height: 40,
    width: 1,
    color: AltheaColors.borderLight,
    margin: const EdgeInsets.symmetric(horizontal: 8),
  );
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final bool isHighlighted;
  const _StatItem({
    required this.value,
    required this.label,
    this.isHighlighted = false,
  });
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: isHighlighted ? AltheaColors.navy : AltheaColors.navy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
              color: isHighlighted
                  ? AltheaColors.gold
                  : AltheaColors.textSecondary,
              letterSpacing: isHighlighted ? 0.8 : 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppointmentItem extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final VoidCallback onTap;

  String _formatTimeStr(String time) {
    final parts = time.split(':');
    if (parts.length >= 2) {
      return '${parts[0]}:${parts[1]}';
    }
    return time;
  }

  const _AppointmentItem({required this.appointment, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isCompleted = appointment['status'] == 'completed';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AltheaColors.borderLight),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment['patient']!,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isCompleted
                            ? AltheaColors.textSecondary
                            : AltheaColors.navy,
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    Text(
                      appointment['type']!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AltheaColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: AltheaColors.gold,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatTimeStr(appointment['time'] as String),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AltheaColors.navy,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey.shade400,
                    size: 20,
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

class _QuickActionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color>? gradient;
  final Color textColor;
  final bool light;
  final VoidCallback onTap;
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.gradient,
    this.textColor = Colors.white,
    this.light = false,
    required this.onTap,
  });
  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: widget.gradient != null
                ? LinearGradient(colors: widget.gradient!)
                : null,
            color: widget.light ? Colors.white : null,
            borderRadius: BorderRadius.circular(20),
            border: widget.light
                ? Border.all(color: AltheaColors.borderLight)
                : null,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.light
                      ? AltheaColors.lightCard
                      : Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  widget.icon,
                  color: widget.light ? AltheaColors.navy : widget.textColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: widget.light
                          ? AltheaColors.navy
                          : widget.textColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: widget.light
                          ? AltheaColors.textSecondary
                          : widget.textColor.withOpacity(0.7),
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
