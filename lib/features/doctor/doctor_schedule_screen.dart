import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_althea/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_althea/core/providers/user_provider.dart';

class DoctorScheduleScreen extends StatefulWidget {
  const DoctorScheduleScreen({super.key});
  @override
  State<DoctorScheduleScreen> createState() => _DoctorScheduleScreenState();
}

class _DoctorScheduleScreenState extends State<DoctorScheduleScreen> {
  DateTime _selectedDay = DateTime.now();
  bool _isLoading = true;
  Set<int> _workingDays = {}; // 0 = Domingo, 1 = Lunes, ..., 6 = Sábado
  List<Map<String, dynamic>> _appointments = [];
  String? _doctorId;

  @override
  void initState() {
    super.initState();
    // Limpiar _selectedDay a medianoche para evitar problemas con la hora
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final user = context.read<UserProvider>().user;
      if (user == null) return;

      final supabase = Supabase.instance.client;

      final doctorData = await supabase
          .from('doctores')
          .select('id')
          .eq('usuario_id', user.id)
          .maybeSingle();

      if (doctorData == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      _doctorId = doctorData['id'];

      final horariosData = await supabase
          .from('horarios_doctor')
          .select('dia_semana')
          .eq('doctor_id', _doctorId as String);

      final List<dynamic> horarios = horariosData as List<dynamic>;
      for (var h in horarios) {
        if (h['dia_semana'] != null) {
          _workingDays.add(h['dia_semana'] as int);
        }
      }

      // Evitar crash si initialDate no está en workingDays
      if (_workingDays.isNotEmpty &&
          !_workingDays.contains(_selectedDay.weekday - 1)) {
        for (int i = 1; i <= 7; i++) {
          final nextDay = _selectedDay.add(Duration(days: i));
          if (_workingDays.contains(nextDay.weekday - 1)) {
            _selectedDay = nextDay;
            break;
          }
        }
      }

      await _fetchAppointmentsForDate(_selectedDay);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cargar agenda: $e')));
      }
    }
  }

  Future<void> _fetchAppointmentsForDate(DateTime date) async {
    if (_doctorId == null) return;

    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final data = await Supabase.instance.client
          .from('citas')
          .select('''
            id,
            hora,
            estado,
            usuarios (
              nombre_completo
            ),
            sucursales (
              nombre
            )
          ''')
          .eq('doctor_id', _doctorId as String)
          .eq('fecha', dateStr);

      final List<dynamic> citas = data as List<dynamic>;
      List<Map<String, dynamic>> apps = [];

      for (var c in citas) {
        final status = (c['estado'] as String?)?.toLowerCase().trim() ?? '';
        if (status == 'cancelada') continue;

        apps.add({
          'id': c['id'],
          'date': dateStr,
          'time': c['hora'] as String,
          'patient': c['usuarios']?['nombre_completo'] ?? 'Paciente',
          'type': c['sucursales']?['nombre'] ?? 'Consulta',
          'isCompleted': status == 'terminada',
        });
      }

      apps.sort((a, b) => (a['time'] as String).compareTo(b['time'] as String));

      if (mounted) {
        setState(() {
          _appointments = apps;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cargar citas: $e')));
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
          '¿Estás seguro de cancelar esta cita? Se le hará el reembolso completo del anticipo al paciente y se le notificará de la cancelación.',
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
          _fetchAppointmentsForDate(_selectedDay);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AltheaColors.lightBg,
      appBar: AppBar(
        backgroundColor: AltheaColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Mi Agenda',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/doctor/dashboard'),
        ),
      ),
      body: _isLoading && _workingDays.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AltheaColors.navy),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AltheaColors.borderLight),
                    ),
                    child: CalendarDatePicker(
                      initialDate:
                          _workingDays.isEmpty ||
                              _workingDays.contains(_selectedDay.weekday - 1)
                          ? _selectedDay
                          : List.generate(
                              7,
                              (i) => _selectedDay.add(Duration(days: i + 1)),
                            ).firstWhere(
                              (d) => _workingDays.contains(d.weekday - 1),
                              orElse: () => _selectedDay,
                            ),
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 30),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                      onDateChanged: (d) {
                        _selectedDay = d;
                        _fetchAppointmentsForDate(d);
                      },
                      selectableDayPredicate: (DateTime date) {
                        if (_workingDays.isEmpty) return true;
                        return _workingDays.contains(date.weekday - 1);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Horario del Día',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AltheaColors.navy,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                          color: AltheaColors.navy,
                        ),
                      ),
                    )
                  else if (_appointments.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'No hay citas programadas para este día.',
                          style: TextStyle(color: AltheaColors.textSecondary),
                        ),
                      ),
                    )
                  else
                    ..._appointments.map(
                      (a) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _AppointmentItem(
                          appointment: a,
                          onViewRecord: () => context.go(
                            '/doctor/medical-record?patient=${Uri.encodeComponent(a['patient']!)}',
                          ),
                          onCancel: () => _cancelAppointment(a),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _AppointmentItem extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final VoidCallback onViewRecord;
  final VoidCallback onCancel;

  String _formatTimeStr(String time) {
    final parts = time.split(':');
    if (parts.length >= 2) {
      return '${parts[0]}:${parts[1]}';
    }
    return time;
  }

  const _AppointmentItem({
    required this.appointment,
    required this.onViewRecord,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = appointment['isCompleted'] == true;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AltheaColors.borderLight),
      ),
      child: Column(
        children: [
          Row(
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
                  const Icon(
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
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!isCompleted)
                GestureDetector(
                  onTap: onCancel,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ),
              if (!isCompleted) const SizedBox(width: 10),
              GestureDetector(
                onTap: onViewRecord,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AltheaColors.borderLight),
                  ),
                  child: const Text(
                    'Expediente',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AltheaColors.navy,
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
